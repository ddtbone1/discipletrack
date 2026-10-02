/// MinistryRepository against the real local stack: the embeds and foreign-key
/// hints resolve, RLS supplies the names each role should see, and failures
/// come back with the reason the operation raised.
library;

import 'package:discipletrack/core/supabase/postgrest_failure.dart';
import 'package:discipletrack/features/ministry/data/ministry_repository.dart';
import 'package:discipletrack/features/ministry/domain/d_group_invitation.dart';
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
  late TestMember invitee;
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
    invitee = await createActiveMember(
      church.churchId,
      fullName: 'Repo Invitee',
      tag: 'repo-inv',
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
    await invite(
      g.leader.user.client,
      g.groupId,
      invitee.membershipId,
      'DISCIPLE',
    );
    cleanup.addAll([
      g.leader.user.userId,
      discipler.user.userId,
      disciple.user.userId,
      invitee.user.userId,
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

    // Nobody else gets the list.
    expect(
      await MinistryRepository(g.leader.user.client)
          .fetchGroups(church.churchId),
      hasLength(1),
      reason: 'a Leader sees their own group only',
    );
  });

  test('the Leader reads the detail with names, phones, pairings and the '
      'pending invitation', () async {
    final repo = MinistryRepository(g.leader.user.client);
    final detail = (await repo.fetchGroupDetail(g.groupId))!;

    expect(detail.leader!.fullName, 'Leader repo-lead');
    expect(detail.disciplers.single.fullName, 'Repo Discipler');
    expect(detail.disciplers.single.phone, '+63 900 000 0010');
    final d = detail.disciples.single;
    expect(detail.disciplerOf(d)!.fullName, 'Repo Discipler');

    final open = detail.openInvitationsAt(DateTime.now());
    expect(open.single.inviteeName, 'Repo Invitee');
    expect(open.single.invitedBy, g.leader.user.userId);
  });

  test('the Coordinator reads the same detail', () async {
    final detail = (await MinistryRepository(church.approver.client)
        .fetchGroupDetail(g.groupId))!;
    expect(detail.members, hasLength(3));
    expect(detail.openInvitationsAt(DateTime.now()), hasLength(1));
  });

  test('a Disciple reads their context; the invitee reads their '
      'invitation', () async {
    final ctx = (await MinistryRepository(disciple.user.client)
        .fetchMyMinistryContext())!;
    expect(ctx.dGroupId, g.groupId);
    expect(ctx.isDisciple, isTrue);
    expect(ctx.myDiscipler!.fullName, 'Repo Discipler');
    expect(ctx.leader!.fullName, 'Leader repo-lead');

    final inv = (await MinistryRepository(invitee.user.client)
        .fetchMyPendingInvitation())!;
    expect(inv.dGroupId, g.groupId);
    expect(inv.responsibility, DGroupResponsibility.disciple);
    expect(inv.statusAt(DateTime.now()), DGroupInvitationStatus.pending);
    expect(
      await MinistryRepository(invitee.user.client).fetchMyMinistryContext(),
      isNull,
    );
  });

  test('placeable members carry placement and the pending flag', () async {
    final options = await MinistryRepository(church.approver.client)
        .fetchPlaceableMembers(churchId: church.churchId);
    MemberOption of(TestMember m) =>
        options.singleWhere((o) => o.churchMembershipId == m.membershipId);

    expect(of(invitee).hasPendingInvitation, isTrue);
    expect(
      of(invitee).ineligibilityReason(MemberPickPurpose.invite),
      'Has a pending invitation',
    );
    expect(of(disciple).currentDGroupId, g.groupId);
    expect(of(disciple).currentResponsibilities, {
      DGroupResponsibility.disciple,
    });
  });

  test('a refused operation comes back with its reason and wording', () async {
    final repo = MinistryRepository(g.leader.user.client);
    await expectLater(
      repo.invite(
        groupId: g.groupId,
        membershipId: disciple.membershipId,
        responsibility: DGroupResponsibility.disciple,
      ),
      throwsA(
        isA<MinistryFailure>()
            .having((f) => f.code, 'code', DbFailureCode.conflict)
            .having((f) => f.reason, 'reason', 'member_already_placed')
            .having(
              (f) => f.message,
              'message',
              'That person is already in a D Group.',
            ),
      ),
    );
  });
}
