import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/church_membership.dart';

class MembershipFailure implements Exception {
  const MembershipFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads the caller's own `church_memberships` row.
///
/// Read-only by design. Membership creation and status transitions are
/// controlled operations, and Migration 003 grants clients no INSERT or UPDATE
/// here. `request_join_church()` arrives in a later slice.
class MembershipRepository {
  MembershipRepository(this._client);

  final SupabaseClient _client;

  /// The caller's membership, or null when they have not joined a church.
  ///
  /// Null is a valid and expected state for the MVP: MVP_SPEC section 11 says
  /// an approved member who has not been assigned anything is legitimate, and
  /// so is a registered user who has not yet joined.
  ///
  /// `church_memberships_select_own` already restricts this to the caller, and
  /// `UNIQUE(church_id, user_id)` plus the single-church MVP mean at most one
  /// row comes back.
  Future<ChurchMembership?> fetchMyMembership(String userId) async {
    try {
      final row = await _client
          .from('church_memberships')
          .select('id, church_id, user_id, status, joined_at')
          .eq('user_id', userId)
          .maybeSingle();
      return row == null ? null : ChurchMembership.fromMap(row);
    } on PostgrestException catch (_) {
      throw const MembershipFailure('Could not load your church membership.');
    } catch (_) {
      throw const MembershipFailure('Could not load your church membership.');
    }
  }
}

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepository(ref.watch(supabaseClientProvider));
});
