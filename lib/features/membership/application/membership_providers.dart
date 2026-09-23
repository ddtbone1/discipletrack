import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/membership_repository.dart';
import '../domain/church_membership.dart';

/// The signed-in user's church membership, or null when they have not joined.
///
/// Loads once per signed-in user. Later changes (a join request, an approval
/// noticed by polling, completing the welcome) arrive through [refresh], which
/// replaces the value in place. It never re-enters a loading or error state,
/// so `sessionStateProvider` never drops back to `unknown` and the router
/// never flashes the splash while the person is mid-flow.
class MembershipController extends AsyncNotifier<ChurchMembership?> {
  @override
  Future<ChurchMembership?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    return ref.watch(membershipRepositoryProvider).fetchMyMembership(userId);
  }

  /// Re-reads the membership and swaps it in on success.
  ///
  /// Returns true when a fresh value was applied. A failure keeps the current
  /// value: a network blip while waiting for approval must not disturb the
  /// screen the person is on.
  Future<bool> refresh() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    try {
      final next = await ref
          .read(membershipRepositoryProvider)
          .fetchMyMembership(userId);
      // The person may have signed out while the request was in flight.
      if (ref.read(currentUserIdProvider) != userId) return false;
      state = AsyncData(next);
      return true;
    } on MembershipFailure {
      return false;
    }
  }
}

final myMembershipProvider =
    AsyncNotifierProvider<MembershipController, ChurchMembership?>(
      MembershipController.new,
    );

/// The church the person has requested or joined, or null without a
/// membership. Readable while PENDING (RBAC section 1a, clarified in this
/// slice: the requested church's name is part of the minimum onboarding
/// state) and while ACTIVE.
final myChurchProvider = FutureProvider<ChurchSummary?>((ref) async {
  final membership = ref.watch(myMembershipProvider).value;
  if (membership == null) return null;
  return ref
      .watch(membershipRepositoryProvider)
      .fetchChurch(membership.churchId);
});

/// The person's active church roles. Empty unless the membership is ACTIVE,
/// matching RBAC section 1a: a role on a non-ACTIVE membership grants nothing.
final myChurchRolesProvider = FutureProvider<Set<ChurchRole>>((ref) async {
  final membership = ref.watch(myMembershipProvider).value;
  if (membership == null || !membership.status.grantsChurchAccess) {
    return const {};
  }
  return ref
      .watch(membershipRepositoryProvider)
      .fetchMyChurchRoles(membership.id);
});

/// Whether the person may review membership requests (RBAC section 2:
/// Approve church membership, ADMIN and COORDINATOR). Presentation only; the
/// database checks the same thing on every call.
final canReviewMembershipsProvider = Provider<bool>((ref) {
  final roles = ref.watch(myChurchRolesProvider).value ?? const {};
  return roles.contains(ChurchRole.admin) ||
      roles.contains(ChurchRole.coordinator);
});
