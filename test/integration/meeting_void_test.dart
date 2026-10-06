/// Slice 5 step 6: voiding a meeting or one participant. Voiding is the
/// only correction of a recorded meeting: nothing is deleted or edited,
/// the record stays VOIDED in history and counts for nothing. Authority
/// is RBAC "Void discipleship meeting or participant"; COMPLETED lessons
/// are protected (DC "COMPLETED Is Protected"); every void is audited.
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
  late ({TestMember disciple, String discipleDgmId}) a2;
  late PairedDisciple b1;
  late PairedDisciple c1;
  late TestMember coordinator;

  final since = DateTime.now().toUtc().subtract(const Duration(days: 60));
  DateTime daysAgo(int d) => DateTime.now().toUtc().subtract(Duration(days: d));

  setUpAll(() async {
    church = await seedChurch(name: 'Meeting Void Church');
    otherChurch = await seedChurch(name: 'Other Void Church');
    curriculum = await seedCurriculum(church.churchId, lessons: 3);
    g1 = await createGroupWithLeader(church, tag: 'mv-g1');
    g2 = await createGroupWithLeader(church, tag: 'mv-g2');
    a1 = await placePairedDisciple(church, g1, since: since, tag: 'mv-a');
    a2 = await addDisciple(
      church,
      g1,
      a1.disciplerDgmId,
      since: since,
      tag: 'mv-a2',
    );
    b1 = await placePairedDisciple(church, g1, since: since, tag: 'mv-b');
    c1 = await placePairedDisciple(church, g1, since: since, tag: 'mv-c');

    // The Coordinator is also a Disciple, paired with Discipler B.
    coordinator = (
      user: church.approver,
      membershipId: church.approverMembershipId,
    );
    final dgm = await place(
      g1.leader.user.client,
      g1.groupId,
      coordinator,
      'DISCIPLE',
    );
    await setDiscipler(g1.leader.user.client, dgm, b1.disciplerDgmId);
    await service
        .from('d_group_memberships')
        .update({'started_at': since.toIso8601String()})
        .eq('id', dgm);
    await service
        .from('discipler_assignments')
        .update({'started_at': since.toIso8601String()})
        .eq('disciple_d_group_membership_id', dgm);
  });
  tearDown(
    () => deleteDiscipleshipRows(
      groupIds: [g1.groupId],
      membershipIds: [
        a1.disciple.membershipId,
        a2.disciple.membershipId,
        b1.disciple.membershipId,
        c1.disciple.membershipId,
        coordinator.membershipId,
      ],
    ),
  );
  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final m in [
      g1.leader,
      g2.leader,
      a1.disciple,
      a1.discipler,
      a2.disciple,
      b1.disciple,
      b1.discipler,
      c1.disciple,
      c1.discipler,
    ]) {
      await deleteUser(m.user.userId);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  String a1Id() => a1.disciple.membershipId;
  String a2Id() => a2.disciple.membershipId;
  List<String> lessons() => curriculum.lessonIds;
  SupabaseClient discipler() => a1.discipler.user.client;
  SupabaseClient leader() => g1.leader.user.client;

  Matcher refused(String code, String reason) => throwsA(
    isA<PostgrestException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', reason),
  );

  Future<String> record(
    Map<String, String> outcomes, {
    SupabaseClient? as,
    String? disciplerDgmId,
    int lesson = 0,
    int day = 5,
  }) => recordMeeting(
    as ?? discipler(),
    disciplerDgmId: disciplerDgmId ?? a1.disciplerDgmId,
    lessonId: lessons()[lesson],
    outcomes: outcomes,
    occurredAt: daysAgo(day),
  );

  Future<Map<String, dynamic>> voidMeeting(SupabaseClient as, String id) =>
      rpcRow(as, 'void_discipleship_meeting', {'p_meeting_id': id});

  Future<Map<String, dynamic>> voidParticipant(SupabaseClient as, String id) =>
      rpcRow(as, 'void_meeting_participant', {'p_participant_id': id});

  Future<Map<String, dynamic>> meetingRow(String id) =>
      service.from('discipleship_meetings').select().eq('id', id).single();

  Future<List<Map<String, dynamic>>> participantRows(String meetingId) async =>
      [
        for (final r
            in await service
                .from('discipleship_meeting_participants')
                .select()
                .eq('meeting_id', meetingId)
                .order('church_membership_id'))
          r,
      ];

  Future<String> participantId(String meetingId, String membershipId) async =>
      (await service
              .from('discipleship_meeting_participants')
              .select('id')
              .eq('meeting_id', meetingId)
              .eq('church_membership_id', membershipId)
              .single())['id']
          as String;

  Future<List<Map<String, dynamic>>> history(
    SupabaseClient as,
    String membershipId,
  ) async => [
    for (final r in await as.rpc<List<dynamic>>(
      'get_meeting_history',
      params: {'p_membership_id': membershipId},
    ))
      r as Map<String, dynamic>,
  ];

  Future<Map<String, dynamic>> complete({int lesson = 0}) => rpcRow(
    discipler(),
    'complete_lesson',
    {'p_membership_id': a1Id(), 'p_lesson_id': lessons()[lesson]},
  );

  group('voiding a meeting', () {
    test('the recording Discipler voids it: the meeting is VOIDED, its '
        'participant rows untouched, progress recomputed, audited', () async {
      final id = await record({a1Id(): 'PRESENT'});
      expect(
        (await progressRow(a1Id(), lessons().first))!['status'],
        'IN_PROGRESS',
      );

      final result = await voidMeeting(discipler(), id);
      expect(result['meeting_id'], id);

      final meeting = await meetingRow(id);
      expect(meeting['status'], 'VOIDED');
      expect(meeting['voided_by'], a1.discipler.user.userId);
      expect(meeting['voided_at'], isNotNull);
      // No cascade: the participant row stays as recorded.
      final rows = await participantRows(id);
      expect(rows.single['status'], 'RECORDED');
      expect(rows.single['voided_at'], isNull);

      final progress = (await progressRow(a1Id(), lessons().first))!;
      expect(progress['status'], 'NOT_STARTED');
      expect(progress['started_at'], isNull);
      expect(
        await auditActionsFor(id),
        contains('DISCIPLESHIP_MEETING_VOIDED'),
      );
    });

    test('a voided meeting cannot be voided again', () async {
      final id = await record({a1Id(): 'PRESENT'});
      await voidMeeting(discipler(), id);
      await expectLater(
        voidMeeting(discipler(), id),
        refused('PT409', 'meeting_not_recorded'),
      );
    });

    test(
      'started_at moves to the earliest remaining credited meeting',
      () async {
        final early = await record({a1Id(): 'PRESENT'}, day: 10);
        await record({a1Id(): 'LATE'}, day: 4);
        await voidMeeting(discipler(), early);
        final progress = (await progressRow(a1Id(), lessons().first))!;
        expect(progress['status'], 'IN_PROGRESS');
        expect(
          DateTime.parse(progress['started_at'] as String).isAfter(daysAgo(5)),
          isTrue,
        );
      },
    );

    test('the Leader voids any meeting of their group, including one '
        'recorded on behalf; the Discipler cannot void that one', () async {
      final id = await record({a1Id(): 'PRESENT'}, as: leader());
      await expectLater(
        voidMeeting(discipler(), id),
        refused('PT403', 'not_authorized'),
      );
      await voidMeeting(leader(), id);
      expect((await meetingRow(id))['status'], 'VOIDED');
    });

    test('the Coordinator voids any meeting in the church', () async {
      final id = await record({a1Id(): 'PRESENT'});
      await voidMeeting(church.approver.client, id);
      expect((await meetingRow(id))['voided_by'], church.approver.userId);
    });

    test(
      'another Discipler of the group, another group\'s Leader, a '
      'non-participant Disciple and another church see no such meeting',
      () async {
        final id = await record({a1Id(): 'PRESENT'});
        for (final client in [
          b1.discipler.user.client,
          g2.leader.user.client,
          b1.disciple.user.client,
          otherChurch.approver.client,
        ]) {
          await expectLater(
            voidMeeting(client, id),
            refused('PT404', 'meeting_not_found'),
          );
        }
        expect((await meetingRow(id))['status'], 'RECORDED');
      },
    );

    test('nobody voids a meeting they took part in, the Coordinator '
        'included', () async {
      final mine = await record({a1Id(): 'PRESENT'});
      await expectLater(
        voidMeeting(a1.disciple.user.client, mine),
        refused('PT409', 'cannot_void_own_meeting'),
      );

      final coordinatorsOwn = await record(
        {coordinator.membershipId: 'PRESENT', b1.disciple.membershipId: 'LATE'},
        as: b1.discipler.user.client,
        disciplerDgmId: b1.disciplerDgmId,
      );
      await expectLater(
        voidMeeting(church.approver.client, coordinatorsOwn),
        refused('PT409', 'cannot_void_own_meeting'),
      );
      expect((await meetingRow(coordinatorsOwn))['status'], 'RECORDED');
    });

    test('a Discipler whose row has ended can no longer void what they '
        'recorded', () async {
      final id = await record(
        {c1.disciple.membershipId: 'PRESENT'},
        as: c1.discipler.user.client,
        disciplerDgmId: c1.disciplerDgmId,
      );
      await rpcRow(leader(), 'end_d_group_membership', {
        'p_d_group_membership_id': c1.disciplerDgmId,
      });
      await expectLater(
        voidMeeting(c1.discipler.user.client, id),
        refused('PT403', 'not_authorized'),
      );
      // The Leader keeps fallback authority.
      await voidMeeting(leader(), id);
    });

    test('an anonymous caller can run neither void operation', () async {
      final id = await record({a1Id(): 'PRESENT'});
      final row = await participantId(id, a1Id());
      final anon = anonClient();
      await expectLater(
        voidMeeting(anon, id),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        voidParticipant(anon, row),
        throwsA(isA<PostgrestException>()),
      );
      expect((await meetingRow(id))['status'], 'RECORDED');
      expect((await participantRows(id)).single['status'], 'RECORDED');
    });

    test('a non-existent meeting is not found', () async {
      await expectLater(
        voidMeeting(discipler(), '00000000-0000-0000-0000-000000000000'),
        refused('PT404', 'meeting_not_found'),
      );
    });
  });

  group('voiding one participant', () {
    test('only that row changes; the meeting and the other participant stay '
        'as recorded; audited', () async {
      final id = await record({a1Id(): 'PRESENT', a2Id(): 'PRESENT'});
      final row = await participantId(id, a2Id());

      final result = await voidParticipant(discipler(), row);
      expect(result['participant_id'], row);

      expect((await meetingRow(id))['status'], 'RECORDED');
      final rows = {
        for (final r in await participantRows(id)) r['church_membership_id']: r,
      };
      expect(rows[a2Id()]!['status'], 'VOIDED');
      expect(rows[a2Id()]!['voided_by'], a1.discipler.user.userId);
      expect(rows[a1Id()]!['status'], 'RECORDED');
      expect(rows[a1Id()]!['voided_at'], isNull);

      expect(
        (await progressRow(a2Id(), lessons().first))!['status'],
        'NOT_STARTED',
      );
      expect(
        (await progressRow(a1Id(), lessons().first))!['status'],
        'IN_PROGRESS',
      );
      expect(
        await auditActionsFor(row),
        contains('MEETING_PARTICIPANT_VOIDED'),
      );
    });

    test('the last recorded participant is refused: void the meeting '
        'instead', () async {
      final id = await record({a1Id(): 'PRESENT', a2Id(): 'ABSENT'});
      await voidParticipant(discipler(), await participantId(id, a2Id()));
      await expectLater(
        voidParticipant(discipler(), await participantId(id, a1Id())),
        refused('PT409', 'void_meeting_instead'),
      );
      final single = await record({a1Id(): 'PRESENT'}, day: 3);
      await expectLater(
        voidParticipant(discipler(), await participantId(single, a1Id())),
        refused('PT409', 'void_meeting_instead'),
      );
    });

    test(
      'a voided row, or a row of a voided meeting, cannot be voided',
      () async {
        final id = await record({a1Id(): 'PRESENT', a2Id(): 'PRESENT'});
        final row = await participantId(id, a2Id());
        await voidParticipant(discipler(), row);
        await expectLater(
          voidParticipant(discipler(), row),
          refused('PT409', 'participant_not_recorded'),
        );
        await voidMeeting(discipler(), id);
        await expectLater(
          voidParticipant(discipler(), await participantId(id, a1Id())),
          refused('PT409', 'meeting_not_recorded'),
        );
      },
    );

    test('nobody voids their own row; a co-participant who may void is '
        'not voiding their own outcome', () async {
      final id = await record(
        {coordinator.membershipId: 'PRESENT', b1.disciple.membershipId: 'LATE'},
        as: b1.discipler.user.client,
        disciplerDgmId: b1.disciplerDgmId,
      );
      await expectLater(
        voidParticipant(
          church.approver.client,
          await participantId(id, coordinator.membershipId),
        ),
        refused('PT409', 'cannot_void_own_meeting'),
      );
      await voidParticipant(
        church.approver.client,
        await participantId(id, b1.disciple.membershipId),
      );
    });

    test('authority follows the parent meeting', () async {
      final id = await record({a1Id(): 'PRESENT', a2Id(): 'PRESENT'});
      final row = await participantId(id, a2Id());
      await expectLater(
        voidParticipant(b1.discipler.user.client, row),
        refused('PT404', 'participant_not_found'),
      );
      await expectLater(
        voidParticipant(a1.disciple.user.client, row),
        refused('PT404', 'participant_not_found'),
      );
    });
  });

  group('a void never changes a COMPLETED lesson (ADR-017)', () {
    test('voiding the only counted meeting of a completed lesson is allowed, '
        'and the lesson stays COMPLETED', () async {
      final id = await record({a1Id(): 'PRESENT'}, day: 10);
      await complete();
      final before = (await progressRow(a1Id(), lessons().first))!;

      await voidMeeting(discipler(), id);
      final after = (await progressRow(a1Id(), lessons().first))!;
      expect(after['status'], 'COMPLETED');
      expect(after['completed_at'], before['completed_at']);
      expect(after['confirmed_by'], before['confirmed_by']);
      expect(
        await auditActionsFor(id),
        contains('DISCIPLESHIP_MEETING_VOIDED'),
      );
      // The next lesson is still the current one.
      final j = await history(discipler(), a1Id());
      expect(
        j.firstWhere((r) => r['meeting_id'] == id)['meeting_status'],
        'VOIDED',
      );
    });

    test(
      'a participant void on a completed lesson leaves it COMPLETED',
      () async {
        final id = await record({
          a1Id(): 'PRESENT',
          a2Id(): 'PRESENT',
        }, day: 10);
        await complete();
        await voidParticipant(discipler(), await participantId(id, a1Id()));
        expect(
          (await progressRow(a1Id(), lessons().first))!['status'],
          'COMPLETED',
        );
      },
    );

    test(
      'voiding every meeting of a completed lesson leaves it COMPLETED',
      () async {
        final first = await record({a1Id(): 'PRESENT'}, day: 12);
        final second = await record({a1Id(): 'LATE'}, day: 10);
        final absent = await record({a1Id(): 'ABSENT'}, day: 8);
        await complete();
        for (final id in [first, second, absent]) {
          await voidMeeting(discipler(), id);
        }
        expect(
          (await progressRow(a1Id(), lessons().first))!['status'],
          'COMPLETED',
        );
      },
    );

    test('voiding the next lesson\'s only meeting reopens the undo window '
        '(DC: void first, then undo)', () async {
      await record({a1Id(): 'PRESENT'}, day: 10);
      await complete();
      final next = await record({a1Id(): 'PRESENT'}, lesson: 1, day: 3);
      final undo = {'p_membership_id': a1Id(), 'p_lesson_id': lessons().first};
      await expectLater(
        rpcRow(discipler(), 'undo_lesson_completion', undo),
        refused('PT409', 'next_lesson_started'),
      );
      await voidMeeting(discipler(), next);
      await rpcRow(discipler(), 'undo_lesson_completion', undo);
      expect(
        (await progressRow(a1Id(), lessons().first))!['status'],
        'IN_PROGRESS',
      );
    });
  });

  group('history void permissions', () {
    Map<String, dynamic> rowFor(List<Map<String, dynamic>> rows, String id) =>
        rows.firstWhere((r) => r['meeting_id'] == id);

    test('the recording Discipler and the Leader may void; the Disciple '
        'may not; a single participant cannot be removed', () async {
      final single = await record({a1Id(): 'PRESENT'}, day: 6);
      final pair = await record({a1Id(): 'PRESENT', a2Id(): 'ABSENT'});

      for (final client in [discipler(), leader()]) {
        final rows = await history(client, a1Id());
        expect(rowFor(rows, single)['can_void_meeting'], isTrue);
        expect(rowFor(rows, single)['can_void_participant'], isFalse);
        expect(rowFor(rows, pair)['can_void_meeting'], isTrue);
        expect(rowFor(rows, pair)['can_void_participant'], isTrue);
      }

      final own = await history(a1.disciple.user.client, a1Id());
      expect(rowFor(own, pair)['can_void_meeting'], isFalse);
      expect(rowFor(own, pair)['can_void_participant'], isFalse);
    });

    test('a Leader-recorded meeting is not voidable by the Discipler, and a '
        'voided meeting by nobody', () async {
      final onBehalf = await record({a1Id(): 'PRESENT'}, as: leader());
      final rows = await history(discipler(), a1Id());
      expect(rowFor(rows, onBehalf)['can_void_meeting'], isFalse);

      await voidMeeting(leader(), onBehalf);
      final after = await history(leader(), a1Id());
      expect(rowFor(after, onBehalf)['can_void_meeting'], isFalse);
      expect(rowFor(after, onBehalf)['can_void_participant'], isFalse);
      expect(rowFor(after, onBehalf)['voided_by_name'], isNotNull);
    });
  });
}
