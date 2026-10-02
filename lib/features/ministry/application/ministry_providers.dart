import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../membership/application/membership_providers.dart';
import '../../membership/domain/church_membership.dart';
import '../../offline/application/offline_providers.dart';
import '../data/ministry_repository.dart';
import '../domain/d_group.dart';
import '../domain/d_group_detail.dart';
import '../domain/d_group_invitation.dart';
import '../domain/member_option.dart';
import '../domain/ministry_context.dart';

/// The person's ACTIVE membership, or null. Every ministry read starts here:
/// RBAC section 1a gives nothing to a non-ACTIVE membership.
ChurchMembership? _activeMembership(Ref ref) {
  final membership = ref.watch(myMembershipProvider).value;
  if (membership == null || !membership.status.grantsChurchAccess) return null;
  return membership;
}

/// Whether the person is their church's Coordinator. Presentation only; the
/// database checks the same thing on every operation.
final isCoordinatorProvider = Provider<bool>((ref) {
  final roles = ref.watch(myChurchRolesProvider).value ?? const {};
  return roles.contains(ChurchRole.coordinator);
});

/// The caller's group and the people who matter to them in it, or null when
/// they are unplaced.
final myMinistryContextProvider = FutureProvider<MinistryContext?>((ref) async {
  if (_activeMembership(ref) == null) return null;
  final repo = ref.watch(ministryRepositoryProvider);
  return liveOrSaved(
    ref,
    live: repo.fetchMyMinistryContext,
    saved: (s) => s.ministry,
  );
});

/// The caller's live invitation, or null.
final myPendingInvitationProvider = FutureProvider<DGroupInvitation?>((
  ref,
) async {
  if (_activeMembership(ref) == null) return null;
  final repo = ref.watch(ministryRepositoryProvider);
  // Not saved: answering needs the server, and offline every action is off.
  return liveOrSaved(
    ref,
    live: repo.fetchMyPendingInvitation,
    saved: (_) => null,
  );
});

/// Every D Group in the church, for the Coordinator. Empty for anyone else.
final dGroupsProvider = FutureProvider<List<DGroupSummary>>((ref) async {
  final membership = _activeMembership(ref);
  if (membership == null || !ref.watch(isCoordinatorProvider)) return const [];
  return ref.watch(ministryRepositoryProvider).fetchGroups(membership.churchId);
});

/// One group for its Coordinator or Leader; null when the caller cannot read
/// it, which is what a deep link by anyone else resolves to.
final dGroupDetailProvider = FutureProvider.family<DGroupDetail?, String>((
  ref,
  groupId,
) async {
  if (_activeMembership(ref) == null) return null;
  return ref.watch(ministryRepositoryProvider).fetchGroupDetail(groupId);
});

/// The members a Coordinator or Leader can pick from. For a group when given
/// its id; with null, every ACTIVE member of the church (the Leader picker of
/// a new group, Coordinator only).
final placeableMembersProvider =
    FutureProvider.family<List<MemberOption>, String?>((ref, groupId) async {
      final membership = _activeMembership(ref);
      if (membership == null) return const [];
      return ref
          .watch(ministryRepositoryProvider)
          .fetchPlaceableMembers(
            groupId: groupId,
            churchId: groupId == null ? membership.churchId : null,
          );
    });

/// How many ACTIVE members hold no D Group responsibility, for the
/// Coordinator's Home row (UI_DESIGN_SYSTEM section 27: unassigned members).
final unplacedMemberCountProvider = FutureProvider<int?>((ref) async {
  if (!ref.watch(isCoordinatorProvider)) return null;
  final members = await ref.watch(placeableMembersProvider(null).future);
  return members.where((m) => !m.isPlaced).length;
});
