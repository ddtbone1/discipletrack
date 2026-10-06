/// MinistryRepository against the real local stack: the embeds and foreign-key
/// hints resolve, RLS supplies the names each role should see, and failures
/// come back with the reason the operation raised.
library;

import 'package:discipletrack/core/supabase/postgrest_failure.dart';
import 'package:discipletrack/features/ministry/data/ministry_repository.dart';
import 'package:discipletrack/features/ministry/domain/d_group_detail.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/member_option.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestGroup g;
  late TestMember discipler;
  late TestMember disciple;
  late TestMember newcomer;
  late TestMember ungrouped;
  final cleanup = <String>[];

  setUpAll(() async {
    church = await seedChurch(name: 'Ministry Repository Church');
    g = await createGroupWithLeader(church, tag: 'repo-lead');
    discipler = await createActiveMember(
      church.churchId,
      fullName: 'Repo Discipler',
      tag: 'repo-dr',
      phone: '+63 900 000 0010',
    );
    disciple = await createActiveMember(
      church.churchId,
      fullName: 'Repo Disciple',
      tag: 'repo-dd',
    );
    newcomer = await createActiveMember(
      church.churchId,
      fullName: 'Repo Newcomer',
      tag: 'repo-new',
    );
    ungrouped = await createActiveMember(
      church.churchId,
      fullName: 'Repo Ungrouped',
      tag: 'repo-free',
    );
    final drDgm = await place(
      g.leader.user.client,
      g.groupId,
      discipler,
      'DISCIPLER',
    );
    final ddDgm = await place(
      g.leader.user.client,
      g.groupId,
      disciple,
      'DISCIPLE',
    );
    await setDiscipler(g.leader.user.client, ddDgm, drDgm);
    await addMembers(g.leader.user.client, g.groupId, [newcomer.membershipId]);
    cleanup.addAll([
      g.leader.user.userId,
      discipler.user.userId,
      disciple.user.userId,
      newcomer.user.userId,
      ungrouped.user.userId,
    ]);
  });

  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final id in cleanup) {
      await deleteUser(id);
    }
    await deleteUser(church.approver.userId);
  });

  test('the Coordinator lists groups with Leader name and counts', () async {
    final repo = MinistryRepository(church.approver.client);
    final groups = await repo.fetchGroups(church.churchId);
    final mine = groups.singleWhere((s) => s.group.id == g.groupId);
    expect(mine.leaderName, 'Leader repo-lead');
    expect(mine.disciplerCount, 1);
    expect(mine.discipleCount, 1);
    expect(mine.memberCount, 4, reason: 'includes the newcomer not set up');

    expect(
      await MinistryRepository(g.leader.user.client)
          .fetchGroups(church.churchId),
      hasLength(1),
      reason: 'a Leader sees their own group only',
    );
  });

  test('the Leader reads the detail with names, phones, pairings, basis and '
      'who still needs setup', () async {
    final repo = MinistryRepository(g.leader.user.client);
    final detail = (await repo.fetchGroupDetail(g.groupId))!;

    expect(detail.leader!.fullName, 'Leader repo-lead');
    expect(detail.disciplers.single.fullName, 'Repo Discipler');
    expect(detail.disciplers.single.phone, '+63 900 000 0010');
    expect(
      detail.disciplers.single.disciplerBasis,
      DisciplerBasis.initialRollout,
    );
    final d = detail.disciples.single;
    expect(detail.disciplerOf(d)!.fullName, 'Repo Discipler');

    expect(detail.placements, hasLength(4));
    final waiting = detail.people.where(GroupFilter.needsSetup.includes);
    expect(waiting.single.fullName, 'Repo Newcomer');
  });

  test('the Coordinator reads the same detail', () async {
    final detail = (await MinistryRepository(church.approver.client)
        .fetchGroupDetail(g.groupId))!;
    expect(detail.members, hasLength(3));
    expect(detail.placements, hasLength(4));
  });

  test('a Disciple reads their context; a newcomer reads only their group '
      'and Leader', () async {
    final ctx = (await MinistryRepository(disciple.user.client)
        .fetchMyMinistryContext())!;
    expect(ctx.dGroupId, g.groupId);
    expect(ctx.isDisciple, isTrue);
    expect(ctx.myDiscipler!.fullName, 'Repo Discipler');
    expect(ctx.leader!.fullName, 'Leader repo-lead');
    expect(ctx.groupSize, 4, reason: 'includes the newcomer not set up');

    final waiting = (await MinistryRepository(newcomer.user.client)
        .fetchMyMinistryContext())!;
    expect(waiting.needsSetup, isTrue);
    expect(waiting.dGroupName, ctx.dGroupName);
    expect(waiting.leader!.fullName, 'Leader repo-lead');
    expect(waiting.leader!.phone, isNull);

    expect(
      await MinistryRepository(ungrouped.user.client).fetchMyMinistryContext(),
      isNull,
    );
  });

  test('addable members are the ungrouped ones only', () async {
    final addable = await MinistryRepository(g.leader.user.client)
        .fetchAddableMembers(g.groupId);
    final ids = addable.map((m) => m.churchMembershipId).toSet();
    expect(ids, contains(ungrouped.membershipId));
    expect(ids, isNot(contains(newcomer.membershipId)));
    expect(ids, isNot(contains(disciple.membershipId)));
  });

  test('placeable members carry placement; not set up is an empty role '
      'list', () async {
    final options = await MinistryRepository(church.approver.client)
        .fetchPlaceableMembers(churchId: church.churchId);
    MemberOption of(TestMember m) =>
        options.singleWhere((o) => o.churchMembershipId == m.membershipId);

    expect(of(disciple).currentDGroupId, g.groupId);
    expect(of(disciple).currentResponsibilities, {
      DGroupResponsibility.disciple,
    });
    expect(of(newcomer).currentDGroupId, g.groupId);
    expect(of(newcomer).currentResponsibilities, isEmpty);
    expect(of(ungrouped).isPlaced, isFalse);
  });

  test('the setup period is readable by members', () async {
    final status = await MinistryRepository(disciple.user.client)
        .fetchInitialSetupStatus(church.churchId);
    expect(status.isOpen, isTrue);
  });

  test('a refused operation comes back with its reason and wording', () async {
    final repo = MinistryRepository(g.leader.user.client);
    await expectLater(
      repo.addMembers(
        groupId: g.groupId,
        membershipIds: [disciple.membershipId],
      ),
      throwsA(
        isA<MinistryFailure>()
            .having((f) => f.code, 'code', DbFailureCode.conflict)
            .having((f) => f.reason, 'reason', 'member_already_placed')
            .having(
              (f) => f.message,
              'message',
              contains('just added to another D Group'),
            ),
      ),
    );
  });
}
