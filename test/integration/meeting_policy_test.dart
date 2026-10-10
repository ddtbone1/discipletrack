/// The policy point of Slice 5 and the derivations.
///
/// N1 is closed (ADR-017): there is no meeting minimum, so the placeholder
/// lesson_meeting_policy() is gone. These tests pin that it stays gone and
/// that nothing depends on the legacy required_meetings column. The
/// Discipler eligibility lesson (D2) is the one remaining policy point.
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/discipleship_fixture.dart';
import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestCurriculum curriculum;
  late TestGroup dGroup;
  late PairedDisciple pair;

  setUpAll(() async {
    church = await seedChurch(name: 'Meeting Policy Church');
    curriculum = await seedCurriculum(church.churchId, lessons: 3);
    dGroup = await createGroupWithLeader(church, tag: 'mp');
    pair = await placePairedDisciple(
      church,
      dGroup,
      since: DateTime.now().toUtc().subtract(const Duration(days: 60)),
      tag: 'mp',
    );
  });
  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final p in [dGroup.leader, pair.disciple, pair.discipler]) {
      await deleteUser(p.user.userId);
    }
    await deleteUser(church.approver.userId);
  });

  group('no meeting minimum (ADR-017, N1 closed)', () {
    test(
      'the placeholder policy and the void protection no longer exist',
      () async {
        final rows = await sqlRows('''
        select p.proname
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'private')
          and p.proname in ('lesson_meeting_policy',
                            'assert_void_keeps_completed')''');
        expect(rows, isEmpty);
      },
    );

    test('no database function reads a meeting minimum', () async {
      final rows = await sqlRows('''
        select p.proname
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'private')
          and (p.prosrc ilike '%submission_minimum%'
               or p.prosrc ilike '%lesson_meeting_policy%')''');
      expect(rows, isEmpty);
    });

    test('no database function reads required_meetings; only bootstrap and '
        'create_church() (ADR-022) seed and assert it', () async {
      final rows = await sqlRows('''
        select p.proname
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'private')
          and p.prosrc ilike '%required_meetings%'
        order by 1''');
      expect(
        [for (final r in rows) r.single],
        [
          'assert_bootstrap_postconditions',
          'bootstrap_church',
          'create_church',
        ],
      );
    });

    test('clients cannot read required_meetings; the other lesson columns '
        'stay readable', () async {
      final client = pair.disciple.user.client;
      await expectLater(
        client.from('curriculum_lessons').select('required_meetings'),
        throwsPostgrestCode('42501'),
      );
      final lessons = await client
          .from('curriculum_lessons')
          .select('id, lesson_number, title')
          .eq('curriculum_id', curriculum.curriculumId);
      expect(lessons, hasLength(3));
    });
  });

  group('discipler_eligibility_lesson (D2)', () {
    test('is lesson 5, with no argument and no setting', () async {
      expect(await sqlRows('select private.discipler_eligibility_lesson()'), [
        ['5'],
      ]);
    });
  });

  test(
    'the policy point and derivations are not callable by clients',
    () async {
      for (final call in [
        'private.discipler_eligibility_lesson()',
        "private.credited_count('${pair.disciple.membershipId}', "
            "'${curriculum.lessonIds.first}')",
        "private.eligible_lesson('${pair.disciple.membershipId}')",
      ]) {
        final error = await sqlError('set role authenticated; select $call');
        expect(error, contains('permission denied'), reason: call);
      }
    },
  );

  group('derivations', () {
    tearDown(
      () => deleteDiscipleshipRows(membershipIds: [pair.disciple.membershipId]),
    );

    var day = 50;
    Future<String> meeting(String lessonId, String outcome) async {
      final m = await service
          .from('discipleship_meetings')
          .insert({
            'd_group_id': dGroup.groupId,
            'discipler_d_group_membership_id': pair.disciplerDgmId,
            'lesson_id': lessonId,
            'occurred_at': DateTime.now()
                .toUtc()
                .subtract(Duration(days: day--))
                .toIso8601String(),
            'recorded_by': pair.discipler.user.userId,
          })
          .select('id')
          .single();
      final id = m['id'] as String;
      await service.from('discipleship_meeting_participants').insert({
        'meeting_id': id,
        'church_membership_id': pair.disciple.membershipId,
        'attendance_status': outcome,
      });
      return id;
    }

    Future<int> credited(String lessonId) async {
      final rows = await sqlRows(
        "select private.credited_count('${pair.disciple.membershipId}', "
        "'$lessonId')",
      );
      return int.parse(rows.single.single);
    }

    Future<String?> eligible() async {
      final rows = await sqlRows(
        'select coalesce(private.eligible_lesson('
        "'${pair.disciple.membershipId}')::text, 'none')",
      );
      final id = rows.single.single;
      return id == 'none' ? null : id;
    }

    Map<String, dynamic> voided() => {
      'status': 'VOIDED',
      'voided_by': church.approver.userId,
      'voided_at': DateTime.now().toUtc().toIso8601String(),
    };

    test('credited means a RECORDED meeting, a RECORDED participation and '
        'PRESENT or LATE', () async {
      for (final outcome in ['PRESENT', 'LATE', 'ABSENT', 'EXCUSED']) {
        await meeting(curriculum.lessonIds[0], outcome);
      }
      expect(await credited(curriculum.lessonIds[0]), 2);

      final voidedMeeting = await meeting(curriculum.lessonIds[0], 'PRESENT');
      await service
          .from('discipleship_meetings')
          .update(voided())
          .eq('id', voidedMeeting);
      final voidedRow = await meeting(curriculum.lessonIds[0], 'PRESENT');
      await service
          .from('discipleship_meeting_participants')
          .update(voided())
          .eq('meeting_id', voidedRow);
      expect(await credited(curriculum.lessonIds[0]), 2);

      // Another lesson's meetings are not counted.
      await meeting(curriculum.lessonIds[1], 'PRESENT');
      expect(await credited(curriculum.lessonIds[0]), 2);
      expect(await credited(curriculum.lessonIds[1]), 1);
    });

    test('the eligible lesson is the lowest not COMPLETED; submitted does '
        'not count as completed', () async {
      expect(await eligible(), curriculum.lessonIds[0]);

      final at = DateTime.now().toUtc().toIso8601String();
      final by = church.approver.userId;
      Future<void> progress(String lessonId, Map<String, dynamic> f) =>
          service.from('disciple_lesson_progress').upsert({
            'church_membership_id': pair.disciple.membershipId,
            'lesson_id': lessonId,
            ...f,
          }, onConflict: 'church_membership_id, lesson_id');
      final submitted = {
        'status': 'READY_FOR_COMPLETION',
        'started_at': at,
        'ready_at': at,
        'submitted_by': by,
        'completed_at': null,
        'confirmed_by': null,
      };
      final completed = {
        ...submitted,
        'status': 'COMPLETED',
        'completed_at': at,
        'confirmed_by': by,
      };

      await progress(curriculum.lessonIds[0], submitted);
      expect(await eligible(), curriculum.lessonIds[0]);

      await progress(curriculum.lessonIds[0], completed);
      expect(await eligible(), curriculum.lessonIds[1]);

      await progress(curriculum.lessonIds[1], completed);
      await progress(curriculum.lessonIds[2], completed);
      expect(await eligible(), isNull);
    });
  });
}
