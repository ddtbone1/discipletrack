/// Slice 5 step 8: members' progress on D Group detail, for the group's
/// Leader and the Coordinator only. A Discipler sees only their own
/// assigned Disciples (N7), never the group's list. Figures are derived.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/discipleship_fixture.dart';
import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestChurch otherChurch;
  late TestCurriculum curriculum;
  late TestGroup g1;
  late TestGroup g2;
  late PairedDisciple a1;
  late TestMember unpaired;
  late String unpairedDgmId;
  late TestMember leaver;
  late String leaverDgmId;

  final since = DateTime.now().toUtc().subtract(const Duration(days: 60));
  DateTime daysAgo(int d) => DateTime.now().toUtc().subtract(Duration(days: d));

  setUpAll(() async {
    church = await seedChurch(name: 'Group Progress Church');
    otherChurch = await seedChurch(name: 'Other Progress Church');
    curriculum = await seedCurriculum(church.churchId, lessons: 3);
    g1 = await createGroupWithLeader(church, tag: 'gp-g1');
    g2 = await createGroupWithLeader(church, tag: 'gp-g2');
    a1 = await placePairedDisciple(church, g1, since: since, tag: 'gp-a');
    unpaired = await createActiveMember(
      church.churchId,
      fullName: 'Unpaired Disciple',
      tag: 'gp-u',
    );
    unpairedDgmId = await place(
      g1.leader.user.client,
      g1.groupId,
      unpaired,
      'DISCIPLE',
    );
    leaver = await createActiveMember(
      church.churchId,
      fullName: 'Leaving Disciple',
      tag: 'gp-l',
    );
    leaverDgmId = await place(
      g1.leader.user.client,
      g1.groupId,
      leaver,
      'DISCIPLE',
    );
  });
  tearDown(
    () => deleteDiscipleshipRows(
      groupIds: [g1.groupId],
      membershipIds: [a1.disciple.membershipId, unpaired.membershipId],
    ),
  );
  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final m in [
      g1.leader,
      g2.leader,
      a1.disciple,
      a1.discipler,
      unpaired,
      leaver,
    ]) {
      await deleteUser(m.user.userId);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  String a1Id() => a1.disciple.membershipId;

  Future<List<Map<String, dynamic>>> progress(
    SupabaseClient as, [
    String? groupId,
  ]) async => [
    for (final r in await as.rpc<List<dynamic>>(
      'list_group_progress',
      params: {'p_d_group_id': groupId ?? g1.groupId},
    ))
      r as Map<String, dynamic>,
  ];

  Matcher refused(String code, String reason) => throwsA(
    isA<PostgrestException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', reason),
  );

  test('the Leader sees every current Disciple, paired or not, with derived '
      'figures', () async {
    await recordMeeting(
      a1.discipler.user.client,
      disciplerDgmId: a1.disciplerDgmId,
      lessonId: curriculum.lessonIds.first,
      outcomes: {a1Id(): 'PRESENT'},
      occurredAt: daysAgo(10),
    );
    await recordMeeting(
      a1.discipler.user.client,
      disciplerDgmId: a1.disciplerDgmId,
      lessonId: curriculum.lessonIds.first,
      outcomes: {a1Id(): 'ABSENT'},
      occurredAt: daysAgo(3),
    );

    final rows = {
      for (final r in await progress(g1.leader.user.client))
        r['church_membership_id']: r,
    };
    expect(rows.keys, containsAll([a1Id(), unpaired.membershipId]));

    final a = rows[a1Id()]!;
    expect(a['discipler_name'], 'Discipler gp-a');
    expect(a['current_lesson_number'], 1);
    expect(a['current_status'], 'IN_PROGRESS');
    expect(a['credited_count'], 1);
    expect(a['lessons_total'], 3);
    expect(a['lessons_completed'], 0);
    expect(a['recorded_absences'], 1);
    expect(a['last_recorded_meeting_at'], isNotNull);
    expect(a['is_assigned_to_me'], isFalse);

    final u = rows[unpaired.membershipId]!;
    expect(u['discipler_name'], isNull);
    expect(u['current_status'], 'NOT_STARTED');
    expect(u['last_recorded_meeting_at'], isNull);
  });

  test('lessons completed counts completed lessons only', () async {
    await recordMeeting(
      a1.discipler.user.client,
      disciplerDgmId: a1.disciplerDgmId,
      lessonId: curriculum.lessonIds.first,
      outcomes: {a1Id(): 'PRESENT'},
      occurredAt: daysAgo(10),
    );
    await rpcRow(a1.discipler.user.client, 'complete_lesson', {
      'p_membership_id': a1Id(),
      'p_lesson_id': curriculum.lessonIds.first,
    });
    final a = (await progress(church.approver.client))
        .firstWhere((r) => r['church_membership_id'] == a1Id());
    expect(a['lessons_completed'], 1);
    expect(a['current_lesson_number'], 2);
    expect(a['current_status'], 'NOT_STARTED');
  });

  test('the Coordinator sees the group too', () async {
    final rows = await progress(church.approver.client);
    expect(
      rows.map((r) => r['church_membership_id']),
      containsAll([a1Id(), unpaired.membershipId]),
    );
  });

  test('a Discipler, a Disciple, another group\'s Leader, another church '
      'and an unknown group are refused alike (N7)', () async {
    for (final client in [
      a1.discipler.user.client,
      a1.disciple.user.client,
      g2.leader.user.client,
      otherChurch.approver.client,
    ]) {
      await expectLater(progress(client), refused('PT403', 'not_authorized'));
    }
    await expectLater(
      progress(g1.leader.user.client, '00000000-0000-0000-0000-000000000000'),
      refused('PT403', 'not_authorized'),
    );
  });

  test('an anonymous caller is refused', () async {
    await expectLater(
      progress(anonClient()),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('a Disciple whose group row has ended is no longer listed', () async {
    expect(
      (await progress(g1.leader.user.client))
          .map((r) => r['church_membership_id']),
      contains(leaver.membershipId),
    );
    await rpcRow(g1.leader.user.client, 'remove_from_d_group', {
      'p_d_group_placement_id': await activePlacementOf(leaver.membershipId),
    });
    expect(
      (await service
          .from('d_group_memberships')
          .select('ended_at')
          .eq('id', leaverDgmId)
          .single())['ended_at'],
      isNotNull,
    );
    expect(
      (await progress(g1.leader.user.client))
          .map((r) => r['church_membership_id']),
      isNot(contains(leaver.membershipId)),
    );
    expect(unpairedDgmId, isNotEmpty);
  });
}
