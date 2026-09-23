import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/church_membership.dart';

/// Why a membership operation failed, decided from the PostgREST error code
/// rather than message text. Migration 005 raises the PTxxx SQLSTATEs.
enum MembershipFailureCode {
  /// `PT429`: the per-user join-code rate limit.
  rateLimited,

  /// `PT401`: no session.
  unauthenticated,

  /// `PT403` or `42501`: the caller may not do that.
  forbidden,

  /// `PT404`.
  notFound,

  /// `PT409`: the record is not in a state that allows the operation.
  conflict,
  network,
  unknown,
}

class MembershipFailure implements Exception {
  const MembershipFailure(
    this.message, {
    this.code = MembershipFailureCode.unknown,
  });

  final String message;
  final MembershipFailureCode code;

  @override
  String toString() => message;
}

/// What `request_join_church()` reported. Guessable failures are returned by
/// the function rather than raised, so the rate-limit attempt commits.
enum JoinRequestOutcome {
  requested,
  alreadyPending,
  alreadyActive,

  /// An INACTIVE, TRANSFERRED or ARCHIVED row exists. DC section 1 allows only
  /// controlled reactivation or reinstatement from there, neither of which the
  /// applicant can trigger.
  notRequestable,
  invalidCode;

  static JoinRequestOutcome fromDb(String value) => switch (value) {
    'REQUESTED' => JoinRequestOutcome.requested,
    'ALREADY_PENDING' => JoinRequestOutcome.alreadyPending,
    'ALREADY_ACTIVE' => JoinRequestOutcome.alreadyActive,
    'NOT_REQUESTABLE' => JoinRequestOutcome.notRequestable,
    'INVALID_CODE' => JoinRequestOutcome.invalidCode,
    _ => throw ArgumentError('Unknown request_join_church outcome: $value'),
  };
}

/// The caller's own membership and the controlled operations that move it.
///
/// Every write goes through an RPC from Migration 005. Migration 003 and 005
/// grant clients no INSERT or UPDATE on `church_memberships`, so there is
/// nothing this class could do directly even if it wanted to.
class MembershipRepository {
  MembershipRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, church_id, user_id, status, joined_at, approved_at, created_at, '
      'onboarding_completed_at';

  /// The caller's membership, or null when they have not joined a church.
  ///
  /// `church_memberships_select_own` already restricts this to the caller,
  /// and `UNIQUE(church_id, user_id)` plus the single-church MVP mean at most
  /// one row comes back.
  Future<ChurchMembership?> fetchMyMembership(String userId) async {
    return _guard('Could not load your church membership.', () async {
      final row = await _client
          .from('church_memberships')
          .select(_columns)
          .eq('user_id', userId)
          .maybeSingle();
      return row == null ? null : ChurchMembership.fromMap(row);
    });
  }

  /// `lookup_church_by_join_code()`: the church's id and name, or null when
  /// the code matches nothing. The function never says which.
  Future<ChurchSummary?> lookupChurchByJoinCode(String code) async {
    return _guard('Could not check that code right now.', () async {
      final rows = await _client.rpc<List<dynamic>>(
        'lookup_church_by_join_code',
        params: {'p_code': code},
      );
      if (rows.isEmpty) return null;
      return ChurchSummary.fromMap(rows.first as Map<String, dynamic>);
    });
  }

  /// `request_join_church()`: creates the PENDING membership. The code is sent
  /// again because the database re-validates it against the chosen church.
  Future<JoinRequestOutcome> requestJoinChurch({
    required String churchId,
    required String joinCode,
  }) async {
    return _guard('Could not send your request right now.', () async {
      final rows = await _client.rpc<List<dynamic>>(
        'request_join_church',
        params: {'p_church_id': churchId, 'p_join_code': joinCode},
      );
      final row = rows.single as Map<String, dynamic>;
      return JoinRequestOutcome.fromDb(row['outcome'] as String);
    });
  }

  /// `complete_onboarding()`: records the one-time first-entry welcome.
  Future<void> completeOnboarding() async {
    await _guard('Could not save your progress right now.', () async {
      await _client.rpc<List<dynamic>>('complete_onboarding');
    });
  }

  /// The caller's church. Only `id, name, status` are readable by clients, and
  /// only for a church the caller has a PENDING or ACTIVE membership in.
  Future<ChurchSummary?> fetchChurch(String churchId) async {
    return _guard('Could not load your church.', () async {
      final row = await _client
          .from('churches')
          .select('id, name')
          .eq('id', churchId)
          .maybeSingle();
      return row == null ? null : ChurchSummary.fromMap(row);
    });
  }

  /// The caller's active church roles. Used only to decide what to show; the
  /// database enforces authority on every operation regardless.
  Future<Set<ChurchRole>> fetchMyChurchRoles(String membershipId) async {
    return _guard('Could not load your roles.', () async {
      final rows = await _client
          .from('church_role_assignments')
          .select('role')
          .eq('church_membership_id', membershipId)
          .isFilter('ended_at', null);
      return {for (final row in rows) ChurchRole.fromDb(row['role'] as String)};
    });
  }

  Future<T> _guard<T>(String fallback, Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw MembershipFailure(friendlyMessage(e, fallback), code: codeOf(e));
    } on MembershipFailure {
      rethrow;
    } catch (_) {
      throw MembershipFailure(
        'Could not reach DiscipleTrack. Check your connection and try again.',
        code: MembershipFailureCode.network,
      );
    }
  }

  /// Maps the PostgREST/SQLSTATE code. Exposed for tests.
  static MembershipFailureCode codeOf(PostgrestException e) => switch (e.code) {
    'PT429' => MembershipFailureCode.rateLimited,
    'PT401' => MembershipFailureCode.unauthenticated,
    'PT403' || '42501' => MembershipFailureCode.forbidden,
    'PT404' => MembershipFailureCode.notFound,
    'PT409' => MembershipFailureCode.conflict,
    _ => MembershipFailureCode.unknown,
  };

  static String friendlyMessage(PostgrestException e, String fallback) =>
      switch (codeOf(e)) {
        MembershipFailureCode.rateLimited =>
          'Too many attempts. Try again in a few minutes.',
        MembershipFailureCode.unauthenticated =>
          'Please sign in again to continue.',
        MembershipFailureCode.forbidden => 'You are not allowed to do that.',
        _ => fallback,
      };
}

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepository(ref.watch(supabaseClientProvider));
});
