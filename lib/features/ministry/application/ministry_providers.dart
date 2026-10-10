import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../membership/application/membership_providers.dart';
import '../../membership/domain/church_membership.dart';
import '../../offline/application/offline_providers.dart';
import '../data/ministry_repository.dart';
import '../domain/d_group.dart';
import '../domain/d_group_detail.dart';
import '../domain/d_group_placement.dart';
import '../domain/discipler_candidate.dart';
import '../domain/member_option.dart';
import '../domain/ministry_context.dart';

/// The person's ACTIVE membership in an ACTIVE church, or null. Every
/// ministry read starts here: RBAC section 1a gives nothing to a non-ACTIVE
/// membership, or to anyone while the church is SUSPENDED or ARCHIVED
/// (ADR-022).
ChurchMembership? _activeMembership(Ref ref) {
  final membership = ref.watch(myMembershipProvider).value;
  if (membership == null || !ref.watch(hasChurchAccessProvider)) return null;
  return membership;
}

/// Whether the person is their church's Coordinator. Presentation only; the
/// database checks the same thing on every operation.
final isCoordinatorProvider = Provider<bool>((ref) {
  final roles = ref.watch(myChurchRolesProvider).value ?? const {};
  return roles.contains(ChurchRole.coordinator);
});

/// The caller's group and the people who matter to them in it, or null when
/// they are in no D Group.
final myMinistryContextProvider = FutureProvider<MinistryContext?>((ref) async {
  if (_activeMembership(ref) == null) return null;
  final repo = ref.watch(ministryRepositoryProvider);
  return liveOrSaved(
    ref,
    live: repo.fetchMyMinistryContext,
    saved: (s) => s.ministry,
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

/// The members a Coordinator can choose a Leader from. For a group when given
/// its id; with null, every ACTIVE member of the church (the Leader picker of
/// a new group).
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

/// The people who can be added to a group: ACTIVE members in no D Group. The
/// database decides who is listed; the screen only filters by name.
final addableMembersProvider =
    FutureProvider.family<List<AddableMember>, String>((ref, groupId) async {
      if (_activeMembership(ref) == null) return const [];
      return ref.watch(ministryRepositoryProvider).fetchAddableMembers(groupId);
    });

/// Whether the church's initial setup window is open, so an Existing
/// Discipler may still be recognized at setup.
final initialSetupStatusProvider = FutureProvider<InitialSetupStatus?>((
  ref,
) async {
  final membership = _activeMembership(ref);
  if (membership == null) return null;
  return ref
      .watch(ministryRepositoryProvider)
      .fetchInitialSetupStatus(membership.churchId);
});

/// How many ACTIVE members are in no D Group, for the Coordinator's Home row
/// (UI_DESIGN_SYSTEM section 27: unassigned members).
final unplacedMemberCountProvider = FutureProvider<int?>((ref) async {
  if (!ref.watch(isCoordinatorProvider)) return null;
  final members = await ref.watch(placeableMembersProvider(null).future);
  return members.where((m) => !m.isPlaced).length;
});

/// Eligible Disciples (Lesson 5 completed) in one group who are not
/// Disciplers, for its Leader and the Coordinator. Eligible is not
/// appointed; the Coordinator decides.
final groupDisciplerCandidatesProvider =
    FutureProvider.family<List<DisciplerCandidate>, String>((
      ref,
      groupId,
    ) async {
      if (_activeMembership(ref) == null) return const [];
      return ref
          .watch(ministryRepositoryProvider)
          .fetchDisciplerCandidates(groupId: groupId);
    });

/// The same, church-wide, for the Coordinator's review. Empty for anyone
/// else.
final churchDisciplerCandidatesProvider =
    FutureProvider<List<DisciplerCandidate>>((ref) async {
      final membership = _activeMembership(ref);
      if (membership == null || !ref.watch(isCoordinatorProvider)) {
        return const [];
      }
      return ref
          .watch(ministryRepositoryProvider)
          .fetchDisciplerCandidates(churchId: membership.churchId);
    });
