/// The integrity rules of the Slice 5 migration hold for every writer,
/// including the service role, which bypasses RLS and the controlled
/// operations. Defence in depth: these rules do not rely on the RPCs.
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
  late TestCurriculum otherCurriculum;
  late TestGroup g1;
  late TestGroup g2;
  late PairedDisciple pair;
  late PairedDisciple otherPair;

  final since = DateTime.now().toUtc().subtract(const Duration(days: 60));

  setUpAll(() async {
    church = await seedChurch(name: 'Discipleship Integrity Church');
    otherChurch = await seedChurch(name: 'Other Discipleship Church');
    curriculum = await seedCurriculum(church.churchId);
    otherCurriculum = await seedCurriculum(otherChurch.churchId);
    g1 = await createGroupWithLeader(church, tag: 'di-g1');
    g2 = await createGroupWithLeader(church, tag: 'di-g2');
    pair = await placePairedDisciple(church, g1, since: since, tag: 'di-a');
    otherPair = await placePairedDisciple(
      church,
      g1,
      since: since,
      tag: 'di-b',
    );
  });
  tearDownAll(() async {
    final people = [
      g1.leader,
      g2.leader,
      pair.disciple,
      pair.discipler,
      otherPair.disciple,
      otherPair.discipler,
    ];
    await deleteChurchRows(church.churchId);
    for (final p in people) {
      await deleteUser(p.user.userId);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  Matcher rejectedWith(String reason) => throwsA(
    isA<PostgrestException>()
        .having((e) => e.code, 'code', '23514')
        .having((e) => e.message, 'message', reason),
  );

  String daysAgo(int days) =>
      DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();

  Future<String> insertMeeting({
    String? groupId,
    String? disciplerDgmId,
    String? lessonId,
    String? occurredAt,
    String status = 'RECORDED',
  }) async {
    final row = await service
        .from('discipleship_meetings')
        .insert({
          'd_group_id': groupId ?? g1.groupId,
          'discipler_d_group_membership_id':
              disciplerDgmId ?? pair.disciplerDgmId,
          'lesson_id': lessonId ?? curriculum.lessonIds.first,
          'occurred_at': occurredAt ?? daysAgo(10),
          'status': status,
          'recorded_by': pair.discipler.user.userId,
          if (status == 'VOIDED') ...{
            'voided_by': pair.discipler.user.userId,
            'voided_at': daysAgo(1),
          },
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<Map<String, dynamic>> insertParticipant(
    String meetingId,
    String membershipId, {
    String? attendance = 'PRESENT',
  }) => service
      .from('discipleship_meeting_participants')
      .insert({
        'meeting_id': meetingId,
        'church_membership_id': membershipId,
        'attendance_status': ?attendance,
      })
      .select()
      .single();

  Future<TestMember> member(String tag, [String? churchId]) async {
    final m = await createActiveMember(
      churchId ?? church.churchId,
      fullName: 'Integrity $tag',
      tag: tag,
    );
    addTearDown(() => deleteUser(m.user.userId));
    return m;
  }

  group('discipleship_meetings', () {
    test(
      'a backdated meeting by an active Discipler row is accepted',
      () async {
        await insertMeeting(occurredAt: daysAgo(59));
      },
    );

    test(
      'the Discipler row must be a DISCIPLER of the meeting\'s group',
      () async {
        await expectLater(
          insertMeeting(disciplerDgmId: g1.leaderDgmId),
          rejectedWith('meeting_discipler_invalid'),
        );
        await expectLater(
          insertMeeting(groupId: g2.groupId),
          rejectedWith('meeting_discipler_invalid'),
        );
      },
    );

    test('the Discipler row must be active at occurred_at', () async {
      await expectLater(
        insertMeeting(occurredAt: daysAgo(61)),
        rejectedWith('meeting_discipler_not_active'),
      );
    });

    test('the lesson must belong to the group\'s church', () async {
      await expectLater(
        insertMeeting(lessonId: otherCurriculum.lessonIds.first),
        rejectedWith('meeting_cross_church'),
      );
    });

    test('context columns are immutable', () async {
      final id = await insertMeeting();
      for (final change in <Map<String, dynamic>>[
        {'occurred_at': daysAgo(11)},
        {'lesson_id': curriculum.lessonIds[1]},
        {'discipler_d_group_membership_id': otherPair.disciplerDgmId},
        {'recorded_by': church.approver.userId},
      ]) {
        await expectLater(
          service.from('discipleship_meetings').update(change).eq('id', id),
          rejectedWith('meeting_immutable'),
          reason: '$change',
        );
      }
    });

    test(
      'RECORDED goes to VOIDED with metadata, and VOIDED is terminal',
      () async {
        final id = await insertMeeting();
        await expectLater(
          service
              .from('discipleship_meetings')
              .update({'status': 'VOIDED'})
              .eq('id', id),
          throwsPostgrestCode('23514'),
          reason: 'void metadata is required',
        );
        await service
            .from('discipleship_meetings')
            .update({
              'status': 'VOIDED',
              'voided_by': church.approver.userId,
              'voided_at': daysAgo(0),
            })
            .eq('id', id);
        await expectLater(
          service
              .from('discipleship_meetings')
              .update({
                'status': 'RECORDED',
                'voided_by': null,
                'voided_at': null,
              })
              .eq('id', id),
          rejectedWith('meeting_voided_terminal'),
        );
      },
    );
  });

  group('discipleship_meeting_participants', () {
    test('an assigned Disciple is recorded, RECORDED by default', () async {
      final meeting = await insertMeeting();
      final row = await insertParticipant(meeting, pair.disciple.membershipId);
      expect(row['status'], 'RECORDED');
      expect(row['attendance_status'], 'PRESENT');
    });

    test('every outcome is accepted and none is assumed', () async {
      for (final outcome in ['PRESENT', 'LATE', 'ABSENT', 'EXCUSED']) {
        final meeting = await insertMeeting();
        await insertParticipant(
          meeting,
          pair.disciple.membershipId,
          attendance: outcome,
        );
      }
      final meeting = await insertMeeting();
      await expectLater(
        insertParticipant(
          meeting,
          pair.disciple.membershipId,
          attendance: null,
        ),
        throwsPostgrestCode('23502'),
      );
    });

    test('P1: the person must be a DISCIPLE at occurred_at', () async {
      final unplaced = await member('unplaced');
      final meeting = await insertMeeting();
      await expectLater(
        insertParticipant(meeting, unplaced.membershipId),
        rejectedWith('participant_not_disciple_at_occurred_at'),
      );
    });

    test('P2: the DISCIPLE row must be in the meeting\'s group', () async {
      final g2Pair = await placePairedDisciple(
        church,
        g2,
        since: since,
        tag: 'di-c',
      );
      addTearDown(() async {
        await deleteUser(g2Pair.disciple.user.userId);
        await deleteUser(g2Pair.discipler.user.userId);
      });
      final meeting = await insertMeeting();
      await expectLater(
        insertParticipant(meeting, g2Pair.disciple.membershipId),
        rejectedWith('participant_not_disciple_at_occurred_at'),
      );
    });

    test('P1 is evaluated as of occurred_at, not insert time', () async {
      // The Discipler row is active, but the Disciple's row starts later.
      final newcomer = await member('late-disciple');
      final dgm = await place(
        g1.leader.user.client,
        g1.groupId,
        newcomer,
        'DISCIPLE',
      );
      await setDiscipler(g1.leader.user.client, dgm, pair.disciplerDgmId);

      final meeting = await insertMeeting(occurredAt: daysAgo(30));
      await expectLater(
        insertParticipant(meeting, newcomer.membershipId),
        rejectedWith('participant_not_disciple_at_occurred_at'),
      );
    });

    test(
      'P3: the Disciple must be assigned to the meeting\'s Discipler',
      () async {
        final meeting = await insertMeeting();
        await expectLater(
          insertParticipant(meeting, otherPair.disciple.membershipId),
          rejectedWith('participant_not_assigned_at_occurred_at'),
        );
      },
    );

    test('a participant from another church is refused', () async {
      final foreign = await member('foreign', otherChurch.churchId);
      final meeting = await insertMeeting();
      await expectLater(
        insertParticipant(meeting, foreign.membershipId),
        rejectedWith('participant_cross_church'),
      );
    });

    test('the meeting\'s Discipler is never a participant', () async {
      final meeting = await insertMeeting();
      await expectLater(
        insertParticipant(meeting, pair.discipler.membershipId),
        rejectedWith('participant_is_discipler'),
      );
    });

    test('a RECORDED participant needs a RECORDED meeting', () async {
      final meeting = await insertMeeting(status: 'VOIDED');
      await expectLater(
        insertParticipant(meeting, pair.disciple.membershipId),
        rejectedWith('participant_meeting_not_recorded'),
      );
    });

    test('person and outcome are immutable, and VOIDED is terminal', () async {
      final meeting = await insertMeeting();
      final row = await insertParticipant(meeting, pair.disciple.membershipId);
      final id = row['id'] as String;
      Future<void> update(Map<String, dynamic> change) => service
          .from('discipleship_meeting_participants')
          .update(change)
          .eq('id', id);

      await expectLater(
        update({'attendance_status': 'ABSENT'}),
        rejectedWith('participant_immutable'),
      );
      await expectLater(
        update({'church_membership_id': otherPair.disciple.membershipId}),
        rejectedWith('participant_immutable'),
      );

      await update({
        'status': 'VOIDED',
        'voided_by': church.approver.userId,
        'voided_at': daysAgo(0),
      });
      await expectLater(
        update({'status': 'RECORDED', 'voided_by': null, 'voided_at': null}),
        rejectedWith('participant_voided_terminal'),
      );
    });
  });

  group('disciple_lesson_progress', () {
    Future<void> insertProgress(
      String membershipId,
      String lessonId,
      Map<String, dynamic> fields,
    ) => service.from('disciple_lesson_progress').insert({
      'church_membership_id': membershipId,
      'lesson_id': lessonId,
      ...fields,
    });

    test('the lesson must belong to the member\'s church', () async {
      await expectLater(
        insertProgress(
          pair.disciple.membershipId,
          otherCurriculum.lessonIds.first,
          {},
        ),
        rejectedWith('progress_cross_church'),
      );
    });

    test('the State Check matches fields to status', () async {
      final m = await member('state');
      addTearDown(
        () => service
            .from('disciple_lesson_progress')
            .delete()
            .eq('church_membership_id', m.membershipId),
      );
      final by = church.approver.userId;
      final at = daysAgo(1);
      final lessons = curriculum.lessonIds;

      final invalid = <String, Map<String, dynamic>>{
        'NOT_STARTED with started_at': {'started_at': at},
        'IN_PROGRESS without started_at': {'status': 'IN_PROGRESS'},
        'IN_PROGRESS with ready_at': {
          'status': 'IN_PROGRESS',
          'started_at': at,
          'ready_at': at,
        },
        'READY_FOR_COMPLETION without submitted_by': {
          'status': 'READY_FOR_COMPLETION',
          'started_at': at,
          'ready_at': at,
        },
        'READY_FOR_COMPLETION with completed_at': {
          'status': 'READY_FOR_COMPLETION',
          'started_at': at,
          'ready_at': at,
          'submitted_by': by,
          'completed_at': at,
        },
        'COMPLETED without confirmed_by': {
          'status': 'COMPLETED',
          'started_at': at,
          'ready_at': at,
          'submitted_by': by,
          'completed_at': at,
        },
      };
      for (final entry in invalid.entries) {
        await expectLater(
          insertProgress(m.membershipId, lessons[0], entry.value),
          throwsPostgrestCode('23514'),
          reason: entry.key,
        );
      }

      final valid = <Map<String, dynamic>>[
        {},
        {'status': 'IN_PROGRESS', 'started_at': at},
        {
          'status': 'READY_FOR_COMPLETION',
          'started_at': at,
          'ready_at': at,
          'submitted_by': by,
        },
        {
          'status': 'COMPLETED',
          'started_at': at,
          'ready_at': at,
          'submitted_by': by,
          'completed_at': at,
          'confirmed_by': by,
        },
      ];
      for (var i = 0; i < valid.length; i++) {
        await insertProgress(m.membershipId, lessons[i], valid[i]);
      }
    });
  });
}
