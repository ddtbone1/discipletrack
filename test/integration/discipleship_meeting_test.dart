/// Slice 5 step 4: record_discipleship_meeting(), the progress worker it
/// drives, and the reads that recording and Disciple detail use.
///
/// The invariant under test throughout: a meeting count never completes a
/// lesson. Recording only starts a lesson (NOT_STARTED to IN_PROGRESS) and
/// keeps its start date honest; READY_FOR_COMPLETION and COMPLETED are set
/// here through the service role only, standing in for the submission and
/// confirmation operations of a later step.
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
  late TestCurriculum otherCurriculum;
  late TestGroup g1;
  late PairedDisciple a1;
  late ({TestMember disciple, String discipleDgmId}) a2;
  late PairedDisciple b1;
  late TestMember coordinator;

  final since = DateTime.now().toUtc().subtract(const Duration(days: 60));
  DateTime daysAgo(int d) => DateTime.now().toUtc().subtract(Duration(days: d));

  List<String> lessons() => curriculum.lessonIds;
  List<String> everyone() => [
    a1.disciple.membershipId,
    a2.disciple.membershipId,
    b1.disciple.membershipId,
    coordinator.membershipId,
  ];

  setUpAll(() async {
    church = await seedChurch(name: 'Discipleship Meeting Church');
    otherChurch = await seedChurch(name: 'Other Meeting Church');
    curriculum = await seedCurriculum(church.churchId);
    otherCurriculum = await seedCurriculum(otherChurch.churchId, lessons: 1);
    g1 = await createGroupWithLeader(church, tag: 'dm-g1');
    a1 = await placePairedDisciple(church, g1, since: since, tag: 'dm-a');
    a2 = await addDisciple(
      church,
      g1,
      a1.disciplerDgmId,
      since: since,
      tag: 'dm-a2',
    );
    b1 = await placePairedDisciple(church, g1, since: since, tag: 'dm-b');

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
      membershipIds: everyone(),
    ),
  );
  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final m in [
      g1.leader,
      a1.disciple,
      a1.discipler,
      a2.disciple,
      b1.disciple,
      b1.discipler,
    ]) {
      await deleteUser(m.user.userId);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  SupabaseClient discipler() => a1.discipler.user.client;

  Future<String> record(
    Map<String, String> outcomes, {
    SupabaseClient? as,
    String? lessonId,
    DateTime? on,
    String? disciplerDgmId,
    String? notes,
  }) => recordMeeting(
    as ?? discipler(),
    disciplerDgmId: disciplerDgmId ?? a1.disciplerDgmId,
    lessonId: lessonId ?? lessons().first,
    outcomes: outcomes,
    occurredAt: on ?? daysAgo(1),
    notes: notes,
  );

  Matcher refused(String code, String reason) => throwsA(
    isA<PostgrestException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', reason),
  );

  Future<List<Map<String, dynamic>>> journey(
    String membershipId, [
    SupabaseClient? as,
  ]) async => [
    for (final r in await (as ?? discipler()).rpc<List<dynamic>>(
      'get_disciple_journey',
      params: {'p_membership_id': membershipId},
    ))
      r as Map<String, dynamic>,
  ];

  Future<List<Map<String, dynamic>>> history(
    String membershipId, [
    SupabaseClient? as,
  ]) async => [
    for (final r in await (as ?? discipler()).rpc<List<dynamic>>(
      'get_meeting_history',
      params: {'p_membership_id': membershipId},
    ))
      r as Map<String, dynamic>,
  ];

  Future<void> setProgress(
    String membershipId,
    String lessonId,
    String status,
  ) {
    final at = daysAgo(2).toIso8601String();
    final by = g1.leader.user.userId;
    return service.from('disciple_lesson_progress').upsert({
      'church_membership_id': membershipId,
      'lesson_id': lessonId,
      'status': status,
      'started_at': at,
      'ready_at': status == 'IN_PROGRESS' ? null : at,
      'submitted_by': status == 'IN_PROGRESS' ? null : by,
      'completed_at': status == 'COMPLETED' ? at : null,
      'confirmed_by': status == 'COMPLETED' ? by : null,
    }, onConflict: 'church_membership_id, lesson_id');
  }

  String a1Id() => a1.disciple.membershipId;
  String a2Id() => a2.disciple.membershipId;

  group('recording', () {
    test('each outcome is recorded explicitly; Present and Late credit the '
        'lesson, Absent and Excused do not', () async {
      await record({a1Id(): 'PRESENT', a2Id(): 'ABSENT'}, on: daysAgo(3));
      await record({a1Id(): 'LATE', a2Id(): 'EXCUSED'}, on: daysAgo(2));

      final first = await journey(a1Id());
      expect(first.first['credited_count'], 2);
      expect(first.first['status'], 'IN_PROGRESS');

      final second = await journey(a2Id());
      expect(second.first['credited_count'], 0);
      expect(second.first['status'], 'NOT_STARTED');
      final row = await progressRow(a2Id(), lessons().first);
      expect(row!['started_at'], isNull);
    });

    test('the first credited meeting starts the lesson; an absence alone does '
        'not', () async {
      await record({a1Id(): 'ABSENT'}, on: daysAgo(5));
      expect(
        (await progressRow(a1Id(), lessons().first))!['status'],
        'NOT_STARTED',
      );

      final on = daysAgo(4);
      await record({a1Id(): 'PRESENT'}, on: on);
      final row = (await progressRow(a1Id(), lessons().first))!;
      expect(row['status'], 'IN_PROGRESS');
      expect(DateTime.parse(row['started_at'] as String), on);
    });

    test(
      'no number of meetings completes a lesson or marks it finished',
      () async {
        for (var d = 20; d > 12; d--) {
          await record({a1Id(): 'PRESENT'}, on: daysAgo(d));
        }
        final row = (await progressRow(a1Id(), lessons().first))!;
        expect(row['status'], 'IN_PROGRESS');
        expect(row['ready_at'], isNull);
        expect(row['submitted_by'], isNull);

        final rows = await journey(a1Id());
        expect(rows.first['credited_count'], 8);
        expect(rows.first['is_current'], isTrue);
        expect(rows[1]['is_locked'], isTrue);
      },
    );

    test('a backdated meeting moves the start date earlier', () async {
      await record({a1Id(): 'PRESENT'}, on: daysAgo(5));
      final earlier = daysAgo(20);
      await record({a1Id(): 'PRESENT'}, on: earlier);
      final row = (await progressRow(a1Id(), lessons().first))!;
      expect(DateTime.parse(row['started_at'] as String), earlier);
    });

    test('a meetup nobody came to is recorded and credits nobody', () async {
      final id = await record({a1Id(): 'ABSENT', a2Id(): 'ABSENT'});
      final rows = await history(a1Id());
      expect(rows.single['meeting_id'], id);
      expect(rows.single['attendance_status'], 'ABSENT');
      expect(rows.single['is_credited'], isFalse);
      expect(rows.single['ordinal'], isNull);
    });

    test('the ordinal counts credited meetings only, in date order', () async {
      await record({a1Id(): 'PRESENT'}, on: daysAgo(9));
      await record({a1Id(): 'ABSENT'}, on: daysAgo(8));
      await record({a1Id(): 'LATE'}, on: daysAgo(7));
      final rows = await history(a1Id());
      // Newest first.
      expect([for (final r in rows) r['ordinal']], [2, null, 1]);
    });

    test('recording continues while a lesson awaits confirmation, and the '
        'submission is kept', () async {
      await record({a1Id(): 'PRESENT'}, on: daysAgo(6));
      await setProgress(a1Id(), lessons().first, 'READY_FOR_COMPLETION');
      final before = (await progressRow(a1Id(), lessons().first))!;

      await record({a1Id(): 'PRESENT'}, on: daysAgo(1));
      final after = (await progressRow(a1Id(), lessons().first))!;
      expect(after['status'], 'READY_FOR_COMPLETION');
      expect(after['submitted_by'], before['submitted_by']);
      expect(after['ready_at'], before['ready_at']);
    });

    test('notes are trimmed and kept; blank notes are none', () async {
      final kept = await record({a1Id(): 'PRESENT'}, notes: '  Prayer  ');
      final blank = await record({a1Id(): 'PRESENT'}, notes: '   ');
      final rows = await service
          .from('discipleship_meetings')
          .select('id, notes')
          .inFilter('id', [kept, blank]);
      final notes = {for (final r in rows) r['id']: r['notes']};
      expect(notes[kept], 'Prayer');
      expect(notes[blank], isNull);
    });

    test('the meeting is audited with every outcome', () async {
      final id = await record({a1Id(): 'PRESENT', a2Id(): 'ABSENT'});
      final audit = await service
          .from('audit_events')
          .select('action, actor_user_id, metadata')
          .eq('entity_id', id)
          .single();
      expect(audit['action'], 'DISCIPLESHIP_MEETING_RECORDED');
      expect(audit['actor_user_id'], a1.discipler.user.userId);
      final meta = audit['metadata'] as Map<String, dynamic>;
      expect(meta['on_behalf_of_discipler'], isFalse);
      expect(meta['participants'], hasLength(2));
    });
  });

  group('sequence', () {
    test('only the eligible lesson can be recorded; the refusal says which '
        'lesson the person is on', () async {
      await expectLater(
        record({a1Id(): 'PRESENT'}, lessonId: lessons()[1]),
        refused('PT409', 'lesson_not_eligible'),
      );
      try {
        await record({a1Id(): 'PRESENT'}, lessonId: lessons()[1]);
      } on PostgrestException catch (e) {
        final detail = jsonDecode(e.details as String) as Map<String, dynamic>;
        expect(detail['church_membership_id'], a1Id());
        expect(detail['lesson_number'], 1);
      }
    });

    test('a COMPLETED lesson is refused and the next one opens', () async {
      await setProgress(a1Id(), lessons().first, 'COMPLETED');
      await expectLater(
        record({a1Id(): 'PRESENT'}),
        refused('PT409', 'lesson_not_eligible'),
      );
      await record({a1Id(): 'PRESENT'}, lessonId: lessons()[1]);
      final rows = await journey(a1Id());
      expect(rows[0]['status'], 'COMPLETED');
      expect(rows[1]['is_current'], isTrue);
      expect(rows[1]['status'], 'IN_PROGRESS');
    });

    test('Disciples on different lessons cannot share a meeting', () async {
      await setProgress(a1Id(), lessons().first, 'COMPLETED');
      await expectLater(
        record({a1Id(): 'PRESENT', a2Id(): 'PRESENT'}, lessonId: lessons()[1]),
        refused('PT409', 'lesson_not_eligible'),
      );
      expect(await history(a1Id()), isEmpty);
    });
  });

  group('validation', () {
    test('the date must not be in the future', () async {
      await expectLater(
        record({
          a1Id(): 'PRESENT',
        }, on: DateTime.now().toUtc().add(const Duration(days: 1))),
        refused('PT409', 'occurred_at_in_future'),
      );
    });

    test('the Discipler row must be active on the date', () async {
      await expectLater(
        record({a1Id(): 'PRESENT'}, on: daysAgo(70)),
        refused('PT409', 'discipler_not_active_at_occurred_at'),
      );
    });

    test(
      'participants are required, once each, with an explicit outcome',
      () async {
        await expectLater(
          record({}),
          refused('PT400', 'participants_required'),
        );
        await expectLater(
          recordMeeting(
            discipler(),
            disciplerDgmId: a1.disciplerDgmId,
            lessonId: lessons().first,
            outcomes: {a1Id(): 'MAYBE'},
            occurredAt: daysAgo(1),
          ),
          refused('PT400', 'invalid_attendance_status'),
        );
        await expectLater(
          rpcRow(discipler(), 'record_discipleship_meeting', {
            'p_discipler_d_group_membership_id': a1.disciplerDgmId,
            'p_lesson_id': lessons().first,
            'p_occurred_at': daysAgo(1).toIso8601String(),
            'p_participants': [
              {'church_membership_id': a1Id(), 'attendance_status': 'PRESENT'},
              {'church_membership_id': a1Id(), 'attendance_status': 'ABSENT'},
            ],
          }),
          refused('PT400', 'duplicate_participant'),
        );
      },
    );

    test('a Disciple not assigned to this Discipler on the date is refused, '
        'naming them', () async {
      await expectLater(
        record({b1.disciple.membershipId: 'PRESENT'}),
        refused('PT409', 'participant_not_assigned_at_occurred_at'),
      );
    });

    test('an unknown or other church\'s lesson is not found', () async {
      for (final lesson in [
        otherCurriculum.lessonIds.first,
        '00000000-0000-4000-8000-000000000000',
      ]) {
        await expectLater(
          record({a1Id(): 'PRESENT'}, lessonId: lesson),
          refused('PT404', 'lesson_not_found'),
        );
      }
    });

    test('a Disciple who is no longer ACTIVE is refused', () async {
      final extra = await addDisciple(
        church,
        g1,
        a1.disciplerDgmId,
        since: since,
        tag: 'dm-inact',
      );
      addTearDown(() => deleteUser(extra.disciple.user.userId));
      await service
          .from('church_memberships')
          .update({'status': 'INACTIVE'})
          .eq('id', extra.disciple.membershipId);
      await expectLater(
        record({extra.disciple.membershipId: 'PRESENT'}),
        refused('PT409', 'member_not_active'),
      );
    });
  });

  group('authority', () {
    test('the Leader and the Coordinator record on behalf of the Discipler; '
        'recorded_by shows who entered it', () async {
      for (final as in [g1.leader.user, church.approver]) {
        final id = await record({a1Id(): 'PRESENT'}, as: as.client);
        final meeting = await service
            .from('discipleship_meetings')
            .select('recorded_by, discipler_d_group_membership_id')
            .eq('id', id)
            .single();
        expect(meeting['recorded_by'], as.userId);
        expect(meeting['discipler_d_group_membership_id'], a1.disciplerDgmId);
        final audit = await service
            .from('audit_events')
            .select('metadata')
            .eq('entity_id', id)
            .single();
        expect((audit['metadata'] as Map)['on_behalf_of_discipler'], isTrue);
      }
    });

    test(
      'another Discipler cannot record under this Discipler\'s row',
      () async {
        await expectLater(
          record({a1Id(): 'PRESENT'}, as: b1.discipler.user.client),
          refused('PT403', 'not_authorized'),
        );
      },
    );

    test('a Disciple cannot record, not even under their own Discipler\'s '
        'row', () async {
      await expectLater(
        record({a1Id(): 'PRESENT'}, as: a1.disciple.user.client),
        refused('PT403', 'not_authorized'),
      );
    });

    test(
      'a Coordinator who is a Disciple cannot record their own meeting',
      () async {
        await expectLater(
          record(
            {coordinator.membershipId: 'PRESENT'},
            as: church.approver.client,
            disciplerDgmId: b1.disciplerDgmId,
          ),
          refused('PT409', 'cannot_record_own_meeting'),
        );
      },
    );

    test(
      'a Discipler whose row has ended has no recording authority',
      () async {
        final ended = await placePairedDisciple(
          church,
          g1,
          since: since,
          tag: 'dm-end',
        );
        addTearDown(() async {
          await deleteUser(ended.disciple.user.userId);
          await deleteUser(ended.discipler.user.userId);
        });
        final now = DateTime.now().toUtc().toIso8601String();
        await service
            .from('discipler_assignments')
            .update({'ended_at': now})
            .eq('disciple_d_group_membership_id', ended.discipleDgmId);
        await service
            .from('d_group_memberships')
            .update({'ended_at': now})
            .eq('id', ended.disciplerDgmId);
        await expectLater(
          recordMeeting(
            ended.discipler.user.client,
            disciplerDgmId: ended.disciplerDgmId,
            lessonId: lessons().first,
            outcomes: {ended.disciple.membershipId: 'PRESENT'},
            occurredAt: daysAgo(10),
          ),
          refused('PT403', 'not_authorized'),
        );
      },
    );

    test('anyone outside the church is refused', () async {
      await expectLater(
        record({a1Id(): 'PRESENT'}, as: otherChurch.approver.client),
        refused('PT403', 'not_authorized'),
      );
    });
  });

  group('reads', () {
    test('the journey has one row per lesson with the policy values passed '
        'through and the courtesy flag for the viewer', () async {
      await record({a1Id(): 'PRESENT'});
      final rows = await journey(a1Id());
      expect(rows, hasLength(10));
      expect(
        [for (final r in rows) r['lesson_number']],
        [for (var n = 1; n <= 10; n++) n],
      );
      final current = rows.first;
      expect(current['is_current'], isTrue);
      expect(current['submission_minimum'], 1);
      expect(current['recommended_meetings'], isNull);
      expect(current['can_record'], isTrue);
      expect(rows.skip(1).every((r) => r['can_record'] == false), isTrue);

      // The Leader may record too; the Disciple reads their own journey but
      // may not record.
      expect(
        (await journey(a1Id(), g1.leader.user.client)).first['can_record'],
        isTrue,
      );
      expect(
        (await journey(a1Id(), a1.disciple.user.client)).first['can_record'],
        isFalse,
      );
    });

    test(
      'a Discipler cannot open the journey or history of a Disciple not '
      'assigned to them (N7); an unknown person is refused the same way',
      () async {
        for (final call in ['get_disciple_journey', 'get_meeting_history']) {
          for (final id in [
            b1.disciple.membershipId,
            '00000000-0000-4000-8000-000000000000',
          ]) {
            await expectLater(
              discipler().rpc<List<dynamic>>(
                call,
                params: {'p_membership_id': id},
              ),
              refused('PT403', 'not_authorized'),
              reason: '$call $id',
            );
          }
        }
      },
    );

    test(
      'a Disciple\'s history shows only their own row of a shared meeting',
      () async {
        await record({a1Id(): 'PRESENT', a2Id(): 'ABSENT'});
        final own = await history(a1Id(), a1.disciple.user.client);
        expect(own.single['attendance_status'], 'PRESENT');
        await expectLater(
          history(a2Id(), a1.disciple.user.client),
          refused('PT403', 'not_authorized'),
        );
      },
    );

    test('history can be bounded by date for the monthly view', () async {
      await record({a1Id(): 'PRESENT'}, on: daysAgo(40));
      await record({a1Id(): 'PRESENT'}, on: daysAgo(5));
      final rows = await discipler().rpc<List<dynamic>>(
        'get_meeting_history',
        params: {
          'p_membership_id': a1Id(),
          'p_from': daysAgo(10).toIso8601String(),
          'p_to': DateTime.now().toUtc().toIso8601String(),
        },
      );
      expect(rows, hasLength(1));
    });

    test('My Disciples lists each assigned Disciple with factual figures; a '
        'lesson awaiting confirmation is not counted as completed', () async {
      await record({a1Id(): 'PRESENT', a2Id(): 'ABSENT'}, on: daysAgo(4));
      final absentOn = daysAgo(2);
      await record({a1Id(): 'PRESENT', a2Id(): 'ABSENT'}, on: absentOn);
      await setProgress(a1Id(), lessons().first, 'READY_FOR_COMPLETION');

      final rows = await discipler().rpc<List<dynamic>>(
        'list_disciple_progress',
      );
      final byId = {
        for (final r in rows.cast<Map<String, dynamic>>())
          r['church_membership_id']: r,
      };
      expect(byId.keys.toSet(), {a1Id(), a2Id()});

      final first = byId[a1Id()]!;
      expect(first['lessons_total'], 10);
      expect(first['lessons_completed'], 0);
      expect(first['current_lesson_number'], 1);
      expect(first['current_status'], 'READY_FOR_COMPLETION');
      expect(first['credited_count'], 2);

      // The latest recorded meeting counts even when the outcome was Absent.
      final second = byId[a2Id()]!;
      expect(second['recorded_absences'], 2);
      expect(
        DateTime.parse(second['last_recorded_meeting_at'] as String),
        absentOn,
      );
      expect(second['credited_count'], 0);
    });

    test('My Disciples is empty for anyone who disciples nobody', () async {
      for (final client in [a1.disciple.user.client, g1.leader.user.client]) {
        expect(
          await client.rpc<List<dynamic>>('list_disciple_progress'),
          isEmpty,
        );
      }
    });

    test('recording options list the Discipler\'s Disciples with their '
        'current lesson, the opened person first', () async {
      await setProgress(a1Id(), lessons().first, 'COMPLETED');
      final rows = (await discipler().rpc<List<dynamic>>(
        'get_recording_options',
        params: {'p_membership_id': a2Id()},
      )).cast<Map<String, dynamic>>();
      expect(
        [for (final r in rows) r['church_membership_id']],
        [a2Id(), a1Id()],
      );
      expect(rows.first['is_target'], isTrue);
      expect(rows.first['lesson_number'], 1);
      expect(rows.last['lesson_number'], 2);
      expect(rows.first['discipler_d_group_membership_id'], a1.disciplerDgmId);
    });

    test('recording options are refused to anyone who cannot record for the '
        'person', () async {
      for (final client in [
        a1.disciple.user.client,
        b1.discipler.user.client,
        otherChurch.approver.client,
      ]) {
        await expectLater(
          client.rpc<List<dynamic>>(
            'get_recording_options',
            params: {'p_membership_id': a1Id()},
          ),
          refused('PT403', 'not_authorized'),
        );
      }
    });

    test(
      'the Disciple detail header names the person, group and Discipler',
      () async {
        final row = await rpcRow(discipler(), 'get_disciple_context', {
          'p_membership_id': a1Id(),
        });
        expect(row['full_name'], 'Disciple dm-a-de');
        expect(row['discipler_name'], 'Discipler dm-a');
        expect(row['is_paired'], isTrue);
      },
    );
  });

  group('journey and Home reads', () {
    Future<Map<String, dynamic>> summary(
      String membershipId, [
      SupabaseClient? as,
    ]) => rpcRow(as ?? discipler(), 'get_disciple_meeting_summary', {
      'p_membership_id': membershipId,
    });

    test('the meeting summary is counts and dates only; the latest recorded '
        'meeting counts whatever the outcome', () async {
      await record({a1Id(): 'PRESENT'}, on: daysAgo(6));
      await record({a1Id(): 'ABSENT'}, on: daysAgo(5));
      await record({a1Id(): 'EXCUSED'}, on: daysAgo(4));
      await record({a1Id(): 'ABSENT'}, on: daysAgo(3));
      final last = daysAgo(2);
      await record({a1Id(): 'ABSENT'}, on: last);

      final s = await summary(a1Id());
      expect(s.keys.toSet(), {
        'meetings_attended',
        'recorded_absences',
        'excused',
        'last_recorded_meeting_at',
        'consecutive_recorded_absences',
      });
      expect(s['meetings_attended'], 1);
      expect(s['recorded_absences'], 3);
      expect(s['excused'], 1);
      expect(DateTime.parse(s['last_recorded_meeting_at'] as String), last);
      // Stops at the Excused meeting: Excused is never an absence.
      expect(s['consecutive_recorded_absences'], 2);
    });

    test('with nothing recorded the summary is zeros and no date', () async {
      final s = await summary(a1Id());
      expect(s['meetings_attended'], 0);
      expect(s['consecutive_recorded_absences'], 0);
      expect(s['last_recorded_meeting_at'], isNull);
    });

    test('the Disciple reads their own summary; another Discipler cannot '
        '(N7)', () async {
      await record({a1Id(): 'PRESENT'});
      expect(
        (await summary(a1Id(), a1.disciple.user.client))['meetings_attended'],
        1,
      );
      await expectLater(
        summary(a1Id(), b1.discipler.user.client),
        refused('PT403', 'not_authorized'),
      );
    });

    test('the progress summary gives active discipleships to the Coordinator '
        'only', () async {
      final leader = await rpcRow(
        g1.leader.user.client,
        'get_progress_summary',
      );
      expect(leader.keys, ['active_discipleships']);
      expect(leader['active_discipleships'], isNull);
      expect(
        (await rpcRow(
          discipler(),
          'get_progress_summary',
        ))['active_discipleships'],
        isNull,
      );
      // A1, A2, B1 and the Coordinator, who is also a paired Disciple.
      final coordinator = await rpcRow(
        church.approver.client,
        'get_progress_summary',
      );
      expect(coordinator['active_discipleships'], 4);
    });
  });
}
