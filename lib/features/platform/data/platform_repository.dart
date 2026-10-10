import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../membership/domain/church_membership.dart';
import '../domain/platform_models.dart';

/// The platform operations of Migration 024 (ADR-022).
///
/// Every call is a SECURITY DEFINER function that checks the platform role
/// itself, so this class decides nothing: it passes arguments and maps the
/// refusal the database gives.
class PlatformRepository {
  PlatformRepository(this._client);

  final SupabaseClient _client;

  /// The caller's own active platform roles (RLS: own rows only).
  Future<Set<PlatformRole>> fetchMyRoles(String userId) => _guard(
    'Could not load your access.',
    () async {
      final rows = await _client
          .from('platform_roles')
          .select('role')
          .eq('user_id', userId)
          .isFilter('ended_at', null);
      return {for (final r in rows) ?PlatformRole.fromDb(r['role'] as String)};
    },
  );

  Future<List<PlatformChurch>> listChurches() =>
      _guard('Could not load the churches.', () async {
        final rows = await _client.rpc<List<dynamic>>('list_churches');
        return [
          for (final r in rows)
            PlatformChurch.fromMap((r as Map).cast<String, dynamic>()),
        ];
      });

  /// The confirm step: whose account [email] is. [churchId] is null when
  /// creating a church.
  Future<AccountPreview> previewAccount(String? churchId, String email) =>
      _guard('Could not check that email.', () async {
        final rows = await _client.rpc<List<dynamic>>(
          'preview_coordinator_account',
          params: {'p_church_id': churchId, 'p_email': email.trim()},
        );
        return AccountPreview.fromMap(
          (rows.single as Map).cast<String, dynamic>(),
        );
      });

  /// Creates the church with its Coordinator, in one transaction. Returns
  /// the new church id and its join code.
  Future<({String churchId, String joinCode})> createChurch({
    required String name,
    required String coordinatorEmail,
  }) => _guard('Could not create the church.', () async {
    final rows = await _client.rpc<List<dynamic>>(
      'create_church',
      params: {
        'p_name': name.trim(),
        'p_coordinator_email': coordinatorEmail.trim(),
      },
    );
    final row = (rows.single as Map).cast<String, dynamic>();
    return (
      churchId: row['church_id'] as String,
      joinCode: row['join_code'] as String,
    );
  });

  Future<void> assignCoordinator(String churchId, String email) => _guard(
    'Could not add the Coordinator.',
    () => _client.rpc<List<dynamic>>(
      'assign_church_coordinator',
      params: {'p_church_id': churchId, 'p_email': email.trim()},
    ),
  );

  Future<void> replaceCoordinator(
    String churchId, {
    required String currentMembershipId,
    required String email,
  }) => _guard(
    'Could not replace the Coordinator.',
    () => _client.rpc<List<dynamic>>(
      'replace_church_coordinator',
      params: {
        'p_church_id': churchId,
        'p_current_membership_id': currentMembershipId,
        'p_email': email.trim(),
      },
    ),
  );

  Future<void> endCoordinator(String churchId, String membershipId) => _guard(
    'Could not remove the Coordinator.',
    () => _client.rpc<List<dynamic>>(
      'end_church_coordinator',
      params: {'p_church_id': churchId, 'p_membership_id': membershipId},
    ),
  );

  Future<String> regenerateJoinCode(String churchId) =>
      _guard('Could not change the join code.', () async {
        final rows = await _client.rpc<List<dynamic>>(
          'regenerate_join_code',
          params: {'p_church_id': churchId},
        );
        return (rows.single as Map)['join_code'] as String;
      });

  Future<void> setStatus(String churchId, ChurchStatus status) => _guard(
    'Could not change the church status.',
    () => _client.rpc<List<dynamic>>(
      'set_church_status',
      params: {'p_church_id': churchId, 'p_status': status.toDb},
    ),
  );

  Future<List<PlatformEvent>> listEvents({String? churchId}) =>
      _guard('Could not load the activity.', () async {
        final rows = await _client.rpc<List<dynamic>>(
          'list_platform_audit',
          params: {'p_church_id': churchId, 'p_limit': 50},
        );
        return [
          for (final r in rows)
            PlatformEvent.fromMap((r as Map).cast<String, dynamic>()),
        ];
      });

  Future<T> _guard<T>(String fallback, Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      final reason = e.message;
      throw PlatformFailure(
        PlatformFailure.messageFor(reason) ??
            PostgrestFailure.friendlyMessage(e, fallback),
        reason: reason,
      );
    } on PlatformFailure {
      rethrow;
    } on Exception {
      throw const PlatformFailure(
        PostgrestFailure.networkMessage,
        isNetwork: true,
      );
    }
  }
}

final platformRepositoryProvider = Provider<PlatformRepository>((ref) {
  return PlatformRepository(ref.watch(supabaseClientProvider));
});
