/// Slice 5 step 7: the Coordinator reopens a completed lesson (ADR-015
/// decision 6; DC section 4, reopen_lesson_completion()). A later
/// completed lesson, or a later lesson with any recorded meeting, locks
/// the earlier lesson. Reopening never moves, voids or deletes history,
/// and is audited with the prior completion.
library;

import 'dart:convert';

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

  final since = DateTime.now().toUtc().subtract(const Duration(days: 90));
  DateTime daysAgo(int d) => DateTime.now().toUtc().subtract(Duration(days: d));

  setUpAll(() async {
    church = await seedChurch(name: 'Lesson Reopen Church');
    otherChurch = await seedChurch(name: 'Other Reopen Church');
    // Six lessons, so lessons after the eligibility lesson (5) exist.
    curriculum = await seedCurriculum(church.churchId, lessons: 6);
    g1 = await createGroupWithLeader(church, tag: 'lr-g1');
    a1 = await placePairedDisciple(church, g1, since: since, tag: 'lr-a');
    b1 = await placePairedDisciple(church, g1, since: since, tag: 'lr-b');

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
  tearDown(() async {
    await service
        .from('ministry_role_transitions')
        .delete()
        .eq('church_membership_id', a1.disciple.membershipId);
    await deleteDiscipleshipRows(
      groupIds: [g1.groupId],
      membershipIds: [
        a1.disciple.membershipId,
        b1.disciple.membershipId,
        coordinator.membershipId,
      ],
    );
  });
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
  SupabaseClient coordinatorClient() => church.approver.client;

  Matcher refused(String code, String reason) => throwsA(
    isA<PostgrestException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', reason),
  );

  Matcher lockedBy(String reason, {required int later}) => throwsA(
    isA<PostgrestException>()
        .having((e) => e.code, 'code', 'PT409')
        .having((e) => e.message, 'message', reason)
        .having(
          (e) => jsonDecode(e.details as String) as Map<String, dynamic>,
          'details',
          allOf(
            containsPair('lesson_number', 1),
            containsPair('later_lesson_number', later),
          ),
        ),
  );

  Future<String> record(String outcome, {int lesson = 0, int day = 30}) =>
      recordMeeting(
        discipler(),
        disciplerDgmId: a1.disciplerDgmId,
        lessonId: lessons()[lesson],
        outcomes: {a1Id(): outcome},
        occurredAt: daysAgo(day),
      );

  Future<void> complete({int lesson = 0}) => rpcRow(
    discipler(),
    'complete_lesson',
    {'p_membership_id': a1Id(), 'p_lesson_id': lessons()[lesson]},
  );

  /// Records a counted meeting on each lesson up to [count] and marks each
  /// completed, oldest first.
  Future<void> completeThrough(int count) async {
    for (var i = 0; i < count; i++) {
      await record('PRESENT', lesson: i, day: 60 - i * 5);
      await complete(lesson: i);
    }
  }

  Future<Map<String, dynamic>> reopen(
    SupabaseClient as, {
    String? membershipId,
    int lesson = 0,
  }) => rpcRow(as, 'reopen_lesson_completion', {
    'p_membership_id': membershipId ?? a1Id(),
    'p_lesson_id': lessons()[lesson],
  });

  Future<void> appointAsDiscipler() async {
    await service.from('ministry_role_transitions').insert({
      'church_membership_id': a1Id(),
      'd_group_id': g1.groupId,
      'from_responsibility': 'DISCIPLE',
      'to_responsibility': 'DISCIPLER',
      'approved_by': church.approver.userId,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  group('reopening', () {
    test(
      'the Coordinator reopens the latest completed lesson: IN_PROGRESS, '
      'completion cleared, start kept, audited with the prior values',
      () async {
        await completeThrough(1);
        final before = (await progressRow(a1Id(), lessons().first))!;

        final result = await reopen(coordinatorClient());
        expect(result['status'], 'IN_PROGRESS');

        final row = (await progressRow(a1Id(), lessons().first))!;
        expect(row['status'], 'IN_PROGRESS');
        expect(row['completed_at'], isNull);
        expect(row['confirmed_by'], isNull);
        expect(row['ready_at'], isNull);
        expect(row['submitted_by'], isNull);
        expect(row['started_at'], before['started_at']);

        final audit = await service
            .from('audit_events')
            .select()
            .eq('entity_id', row['id'] as String)
            .eq('action', 'LESSON_COMPLETION_REOPENED')
            .single();
        final meta = audit['metadata'] as Map<String, dynamic>;
        expect(audit['actor_user_id'], church.approver.userId);
        expect(meta['prior_completed_at'], isNotNull);
        expect(meta['prior_confirmed_by'], a1.discipler.user.userId);
        expect(meta['lesson_number'], 1);
      },
    );

    test('a reopened lesson can be marked completed again', () async {
      await completeThrough(1);
      await reopen(coordinatorClient());
      await complete();
      expect(
        (await progressRow(a1Id(), lessons().first))!['status'],
        'COMPLETED',
      );
    });

    test('only the Coordinator reopens: the Discipler, the Leader and '
        'another church\'s Coordinator are refused', () async {
      await completeThrough(1);
      for (final client in [
        discipler(),
        g1.leader.user.client,
        otherChurch.approver.client,
      ]) {
        await expectLater(reopen(client), refused('PT403', 'not_authorized'));
      }
      expect(
        (await progressRow(a1Id(), lessons().first))!['status'],
        'COMPLETED',
      );
    });

    test('the Coordinator cannot reopen their own lesson', () async {
      await recordMeeting(
        b1.discipler.user.client,
        disciplerDgmId: b1.disciplerDgmId,
        lessonId: lessons().first,
        outcomes: {coordinator.membershipId: 'PRESENT'},
        occurredAt: daysAgo(20),
      );
      await rpcRow(b1.discipler.user.client, 'complete_lesson', {
        'p_membership_id': coordinator.membershipId,
        'p_lesson_id': lessons().first,
      });
      await expectLater(
        reopen(coordinatorClient(), membershipId: coordinator.membershipId),
        refused('PT409', 'cannot_act_on_own_lesson'),
      );
    });

    test('a lesson that is not completed cannot be reopened', () async {
      await record('PRESENT');
      await expectLater(
        reopen(coordinatorClient()),
        refused('PT409', 'lesson_not_completed'),
      );
    });

    test('an anonymous caller cannot reopen', () async {
      await completeThrough(1);
      await expectLater(
        reopen(anonClient()),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('later progress locks an earlier lesson', () {
    test('a later completed lesson locks reopening', () async {
      await completeThrough(2);
      await expectLater(
        reopen(coordinatorClient()),
        lockedBy('later_lesson_completed', later: 2),
      );
      expect(
        (await progressRow(a1Id(), lessons().first))!['status'],
        'COMPLETED',
      );
    });

    test('a recorded meeting on a later lesson locks reopening, whatever '
        'the outcome, and the meeting is left untouched', () async {
      await completeThrough(1);
      final later = await record('ABSENT', lesson: 1, day: 5);
      await expectLater(
        reopen(coordinatorClient()),
        lockedBy('later_lesson_has_meetings', later: 2),
      );
      final meeting = await service
          .from('discipleship_meetings')
          .select()
          .eq('id', later)
          .single();
      expect(meeting['status'], 'RECORDED');
      expect(
        (await progressRow(a1Id(), lessons().first))!['status'],
        'COMPLETED',
      );
    });

    test(
      'a voided later record is not a recorded meeting and does not lock',
      () async {
        // An invalid record, voided as a correction, counts for nothing.
        await completeThrough(1);
        final invalid = await record('PRESENT', lesson: 1, day: 5);
        await rpcRow(discipler(), 'void_discipleship_meeting', {
          'p_meeting_id': invalid,
        });
        final result = await reopen(coordinatorClient());
        expect(result['status'], 'IN_PROGRESS');
      },
    );
  });

  group('reopen and the undo window (finding reported with step 7)', () {
    Future<bool> coordinatorCanUndo(int lesson) async {
      final rows = await coordinatorClient().rpc<List<dynamic>>(
        'get_disciple_journey',
        params: {'p_membership_id': a1Id()},
      );
      return (rows[lesson] as Map<String, dynamic>)['can_undo'] as bool;
    }

    test('whenever reopen is allowed, the Coordinator can already undo; once '
        'the window closes, both are refused', () async {
      await completeThrough(1);
      expect(await coordinatorCanUndo(0), isTrue);

      await record('PRESENT', lesson: 1, day: 5);
      expect(await coordinatorCanUndo(0), isFalse);
      await expectLater(
        reopen(coordinatorClient()),
        lockedBy('later_lesson_has_meetings', later: 2),
      );
    });
  });

  group('the eligibility lesson of an appointed person (ADR-012)', () {
    test('cannot be reopened, nor an earlier lesson', () async {
      await completeThrough(1);
      await appointAsDiscipler();
      await expectLater(
        reopen(coordinatorClient()),
        refused('PT409', 'eligibility_lesson_protected'),
      );
    });

    test('a lesson after the eligibility lesson may be reopened', () async {
      await completeThrough(6);
      await appointAsDiscipler();
      final result = await reopen(coordinatorClient(), lesson: 5);
      expect(result['status'], 'IN_PROGRESS');
    });

    test(
      'without an appointment, the eligibility lesson may be reopened',
      () async {
        await completeThrough(5);
        final result = await reopen(coordinatorClient(), lesson: 4);
        expect(result['status'], 'IN_PROGRESS');
      },
    );
  });
}
