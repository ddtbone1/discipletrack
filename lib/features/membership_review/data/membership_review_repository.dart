import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../membership/data/membership_repository.dart';
import '../domain/membership_request.dart';

/// Membership-request review for Admins and Coordinators.
///
/// Reads rely on the `church_memberships_select_church_admin` and
/// `profiles_select_church_admin` policies from Migration 005. Approval and
/// rejection are controlled operations; there is no client UPDATE path.
class MembershipReviewRepository {
  MembershipReviewRepository(this._client);

  final SupabaseClient _client;

  /// PENDING requests in [churchId], oldest first.
  ///
  /// The FK hint is required: `church_memberships` has two foreign keys to
  /// `profiles` (`user_id` and `approved_by`), so an unhinted embed is
  /// ambiguous.
  Future<List<MembershipRequest>> fetchPendingRequests(String churchId) async {
    return _guard('Could not load membership requests.', () async {
      final rows = await _client
          .from('church_memberships')
          .select(
            'id, created_at, status, '
            'profiles!church_memberships_user_id_fkey(full_name)',
          )
          .eq('church_id', churchId)
          .eq('status', 'PENDING')
          .order('created_at', ascending: true);
      return [for (final row in rows) MembershipRequest.fromMap(row)];
    });
  }

  /// `approve_church_membership()`: PENDING -> ACTIVE, audited.
  Future<void> approve(String membershipId) async {
    await _guard('Could not approve that request.', () async {
      await _client.rpc<List<dynamic>>(
        'approve_church_membership',
        params: {'p_membership_id': membershipId},
      );
    });
  }

  /// `reject_church_membership()`: PENDING -> ARCHIVED, audited.
  Future<void> reject(String membershipId) async {
    await _guard('Could not decline that request.', () async {
      await _client.rpc<List<dynamic>>(
        'reject_church_membership',
        params: {'p_membership_id': membershipId},
      );
    });
  }

  Future<T> _guard<T>(String fallback, Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw MembershipFailure(switch (MembershipRepository.codeOf(e)) {
        MembershipFailureCode.conflict =>
          'That request has already been handled.',
        _ => MembershipRepository.friendlyMessage(e, fallback),
      }, code: MembershipRepository.codeOf(e));
    } on MembershipFailure {
      rethrow;
    } catch (_) {
      throw MembershipFailure(
        'Could not reach DiscipleTrack. Check your connection and try again.',
        code: MembershipFailureCode.network,
      );
    }
  }
}

final membershipReviewRepositoryProvider = Provider<MembershipReviewRepository>(
  (ref) => MembershipReviewRepository(ref.watch(supabaseClientProvider)),
);
