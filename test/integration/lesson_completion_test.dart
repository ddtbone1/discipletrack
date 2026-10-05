/// ADR-015: the Discipler marks a lesson completed in one step, with an
/// undo window that closes when a meeting is recorded on the next lesson.
/// There is no Leader confirmation. A meeting count never completes a
/// lesson; marking it completed is gated only by the meeting policy's
/// minimum (the placeholder floor of 1 until N1 is decided).
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
  late PairedDisciple a1;
  late PairedDisciple b1;
  late TestMember coordinator;

  final since = DateTime.now().toUtc().subtract(const Duration(days: 60));
  DateTime daysAgo(int d) => DateTime.now().toUtc().subtract(Duration(days: d));

  setUpAll(() async {
    church = await seedChurch(name: 'Lesson Completion Church');
    otherChurch = await seedChurch(name: 'Other Completion Church');
    curriculum = await seedCurriculum(church.churchId, lessons: 3);
    g1 = await createGroupWithLeader(church, tag: 'lc-g1');
    a1 = await placePairedDisciple(church, g1, since: since, tag: 'lc-a');
    b1 = await placePairedDisciple(church, g1, since: since, tag: 'lc-b');

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
        b1.disciple.membershipId,
        coordinator.membershipId,
      ],
    ),
  );
  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final m in [
      g1.leader,
      a1.disciple,
      a1.discipler,
      b1.disciple,
      b1.discipler,
    ]) {
      await deleteUser(m.user.userId);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  String a1Id() => a1.disciple.membershipId;
  List<String> lessons() => curriculum.lessonIds;
  SupabaseClient discipler() => a1.discipler.user.client;

  Matcher refused(String code, String reason) => throwsA(
    isA<PostgrestException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', reason),
  );

  Future<void> record(String outcome, {int lesson = 0, int day = 5}) =>
      recordMeeting(
        discipler(),
        disciplerDgmId: a1.disciplerDgmId,
        lessonId: lessons()[lesson],
        outcomes: {a1Id(): outcome},
        occurredAt: daysAgo(day),
      );

  Future<Map<String, dynamic>> complete(
    SupabaseClient as, {
    String? membershipId,
    int lesson = 0,
  }) => rpcRow(as, 'complete_lesson', {
    'p_membership_id': membershipId ?? a1Id(),
    'p_lesson_id': lessons()[lesson],
  });

  Future<Map<String, dynamic>> undo(SupabaseClient as, {int lesson = 0}) =>
      rpcRow(as, 'undo_lesson_completion', {
        'p_membership_id': a1Id(),
        'p_lesson_id': lessons()[lesson],
      });

  Future<List<Map<String, dynamic>>> journey([SupabaseClient? as]) async => [
    for (final r in await (as ?? discipler()).rpc<List<dynamic>>(
      'get_disciple_journey',
      params: {'p_membership_id': a1Id()},
    ))
      r as Map<String, dynamic>,
  ];

  group('marking a lesson completed', () {
    test(
      'the Discipler completes it in one step and the next lesson opens',
      () async {
        await record('PRESENT');
        expect((await journey()).first['can_complete'], isTrue);

        final result = await complete(discipler());
        expect(result['next_lesson_id'], lessons()[1]);

        final row = (await progressRow(a1Id(), lessons().first))!;
        expect(row['status'], 'COMPLETED');
        expect(row['confirmed_by'], a1.discipler.user.userId);
        expect(row['submitted_by'], a1.discipler.user.userId);
        expect(row['completed_at'], isNotNull);
        expect(row['ready_at'], row['completed_at']);

        final rows = await journey();
        expect(rows[0]['status'], 'COMPLETED');
        expect(rows[1]['is_current'], isTrue);
        expect(rows[1]['is_locked'], isFalse);

        // Every role sees the same current lesson at once.
        final asLeader = await journey(g1.leader.user.client);
        expect(asLeader[1]['is_current'], isTrue);
        final asDisciple = await journey(a1.disciple.user.client);
        expect(asDisciple[1]['is_current'], isTrue);

        final audit = await service
            .from('audit_events')
            .select('action, metadata')
            .eq('entity_id', row['id'] as String)
            .single();
        expect(audit['action'], 'LESSON_COMPLETED');
        expect((audit['metadata'] as Map)['on_behalf_of_discipler'], isFalse);
      },
    );

    test('a lesson with no counted meeting cannot be completed', () async {
      await record('ABSENT');
      expect((await journey()).first['can_complete'], isFalse);
      await expectLater(
        complete(discipler()),
        refused('PT409', 'lesson_not_in_progress'),
      );
    });

    test('only the current lesson, once', () async {
      await record('PRESENT');
      await expectLater(
        complete(discipler(), lesson: 1),
        refused('PT409', 'lesson_not_eligible'),
      );
      await complete(discipler());
      await expectLater(
        complete(discipler()),
        refused('PT409', 'lesson_not_eligible'),
      );
    });

    test(
      'the Leader and the Coordinator complete on the Discipler\'s behalf',
      () async {
        await record('PRESENT');
        await complete(g1.leader.user.client);
        await record('PRESENT', lesson: 1, day: 3);
        await complete(church.approver.client, lesson: 1);

        final audits = await service
            .from('audit_events')
            .select('actor_user_id, metadata')
            .eq('action', 'LESSON_COMPLETED')
            .inFilter('actor_user_id', [
              g1.leader.user.userId,
              church.approver.userId,
            ]);
        expect(audits, hasLength(2));
        for (final a in audits) {
          expect((a['metadata'] as Map)['on_behalf_of_discipler'], isTrue);
        }
      },
    );

    test('nobody completes their own lesson, not even a Coordinator who is a '
        'Disciple', () async {
      await expectLater(
        complete(a1.disciple.user.client),
        refused('PT409', 'cannot_act_on_own_lesson'),
      );
      await expectLater(
        complete(
          church.approver.client,
          membershipId: coordinator.membershipId,
        ),
        refused('PT409', 'cannot_act_on_own_lesson'),
      );
    });

    test('another Discipler and another church are refused', () async {
      await record('PRESENT');
      for (final client in [
        b1.discipler.user.client,
        otherChurch.approver.client,
      ]) {
        await expectLater(complete(client), refused('PT403', 'not_authorized'));
      }
    });
  });

  group('undoing a completion', () {
    test(
      'within the window it returns to in progress, keeping the start date',
      () async {
        await record('PRESENT', day: 8);
        final before = (await progressRow(a1Id(), lessons().first))!;
        await complete(discipler());
        expect((await journey()).first['can_undo'], isTrue);

        final result = await undo(discipler());
        expect(result['status'], 'IN_PROGRESS');
        final row = (await progressRow(a1Id(), lessons().first))!;
        expect(row['started_at'], before['started_at']);
        expect(row['completed_at'], isNull);
        expect(row['confirmed_by'], isNull);
        expect(row['submitted_by'], isNull);
        expect((await journey()).first['is_current'], isTrue);

        final actions = await auditActionsFor(row['id'] as String);
        expect(actions, ['LESSON_COMPLETED', 'LESSON_COMPLETION_UNDONE']);
      },
    );

    test('the window closes once a meeting is recorded on the next lesson, '
        'whatever its outcome', () async {
      await record('PRESENT', day: 8);
      await complete(discipler());
      await record('ABSENT', lesson: 1, day: 2);
      expect((await journey()).first['can_undo'], isFalse);
      await expectLater(
        undo(discipler()),
        refused('PT409', 'next_lesson_started'),
      );
    });

    test('only the latest completed lesson can be undone', () async {
      await record('PRESENT', day: 8);
      await complete(discipler());
      // Completing Lesson 2 needs a counted meeting on it.
      await record('PRESENT', lesson: 1, day: 4);
      await complete(discipler(), lesson: 1);
      await expectLater(
        undo(discipler()),
        refused('PT409', 'later_lesson_completed'),
      );
      await undo(discipler(), lesson: 1);
    });

    test('a lesson that is not completed has nothing to undo', () async {
      await record('PRESENT');
      await expectLater(
        undo(discipler()),
        refused('PT409', 'lesson_not_completed'),
      );
    });

    test(
      'the Leader may undo; another Discipler and the Disciple may not',
      () async {
        await record('PRESENT');
        await complete(discipler());
        await expectLater(
          undo(b1.discipler.user.client),
          refused('PT403', 'not_authorized'),
        );
        await expectLater(
          undo(a1.disciple.user.client),
          refused('PT409', 'cannot_act_on_own_lesson'),
        );
        await undo(g1.leader.user.client);
      },
    );
  });
}
