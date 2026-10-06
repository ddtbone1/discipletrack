import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/postgrest_failure.dart';
import '../../discipleship/application/discipleship_providers.dart';
import '../data/ministry_repository.dart';
import '../domain/d_group_member.dart';
import 'ministry_providers.dart';

/// Which structure change is in flight, and the last failure, if any.
@immutable
class MinistryStructureState {
  const MinistryStructureState({this.inFlight, this.error});

  /// A key naming the action and its target (for example `pair:<dgm id>`),
  /// so a screen disables exactly the control being acted on.
  final String? inFlight;
  final MinistryFailure? error;

  bool get isBusy => inFlight != null;
  bool isRunning(String key) => inFlight == key;
}

/// Runs the Coordinator's and Leader's structure operations one at a time and
/// refreshes what they affect.
///
/// The same in-flight pattern as `MembershipReviewController`: a second tap
/// while one operation runs is ignored (UI_DESIGN_SYSTEM section 46), and a
/// conflict refreshes the screen because it means the data was stale.
class MinistryStructureController extends Notifier<MinistryStructureState> {
  @override
  MinistryStructureState build() => const MinistryStructureState();

  MinistryRepository get _repo => ref.read(ministryRepositoryProvider);

  /// Returns the new group's id, or null on failure.
  Future<String?> createGroup({
    required String name,
    String? description,
    required String leaderMembershipId,
  }) async {
    String? id;
    final ok = await _run('create', () async {
      id = await _repo.createGroup(
        name: name,
        description: description,
        leaderMembershipId: leaderMembershipId,
      );
    });
    return ok ? id : null;
  }

  Future<bool> assignLeader(String groupId, String membershipId) => _run(
    'leader:$groupId',
    () => _repo.assignLeader(groupId: groupId, membershipId: membershipId),
  );

  /// Adds every chosen member, or none of them.
  Future<bool> addMembers(String groupId, List<String> membershipIds) => _run(
    'add:$groupId',
    () => _repo.addMembers(groupId: groupId, membershipIds: membershipIds),
  );

  Future<bool> setUpMember(
    String placementId,
    DGroupResponsibility responsibility,
  ) => _run(
    'setup:$placementId',
    () => _repo.setUpMember(
      placementId: placementId,
      responsibility: responsibility,
    ),
  );

  Future<bool> setInitialSetupOpen(String churchId, {required bool open}) =>
      _run(
        'window:$churchId',
        () => _repo.setInitialSetupOpen(churchId: churchId, open: open),
      );

  /// Coordinator only: appoints an eligible Disciple as a Discipler.
  Future<bool> appointDiscipler(String membershipId) =>
      _run('appoint:$membershipId', () => _repo.appointDiscipler(membershipId));

  Future<bool> addSelfAsDiscipler(String groupId) =>
      _run('self:$groupId', () => _repo.addSelfAsDiscipler(groupId));

  Future<bool> removeFromGroup(String placementId) =>
      _run('remove:$placementId', () => _repo.removeFromGroup(placementId));

  /// Pairs, re-pairs, or with a null [disciplerDGroupMembershipId] unpairs.
  Future<bool> setDiscipler(
    String discipleDGroupMembershipId,
    String? disciplerDGroupMembershipId,
  ) => _run(
    'pair:$discipleDGroupMembershipId',
    () => _repo.setDiscipler(
      discipleDGroupMembershipId: discipleDGroupMembershipId,
      disciplerDGroupMembershipId: disciplerDGroupMembershipId,
    ),
  );

  void clearError() => state = MinistryStructureState(inFlight: state.inFlight);

  Future<bool> _run(String key, Future<void> Function() action) async {
    if (state.isBusy) return false;
    state = MinistryStructureState(inFlight: key);
    try {
      await action();
      _refresh();
      state = const MinistryStructureState();
      return true;
    } on MinistryFailure catch (e) {
      if (e.code == DbFailureCode.conflict) _refresh();
      state = MinistryStructureState(error: e);
      return false;
    }
  }

  void _refresh() {
    ref
      ..invalidate(dGroupsProvider)
      ..invalidate(dGroupDetailProvider)
      ..invalidate(placeableMembersProvider)
      ..invalidate(addableMembersProvider)
      ..invalidate(initialSetupStatusProvider)
      ..invalidate(groupDisciplerCandidatesProvider)
      ..invalidate(churchDisciplerCandidatesProvider)
      ..invalidate(unplacedMemberCountProvider)
      ..invalidate(myMinistryContextProvider)
      // A pairing or removal changes whose progress a Leader sees.
      ..invalidate(groupProgressProvider);
  }
}

final ministryStructureControllerProvider =
    NotifierProvider<MinistryStructureController, MinistryStructureState>(
      MinistryStructureController.new,
    );
