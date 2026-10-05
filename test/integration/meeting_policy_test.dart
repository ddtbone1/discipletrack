/// The two policy points of Slice 5 and the derivations they apply to.
///
/// lesson_meeting_policy() is a PLACEHOLDER until N1 (minimum meetings) is
/// decided. These tests pin the floor every model shares and that nothing
/// depends on required_meetings. They do not encode a choice of model A, B
/// or C: when N1 is decided, the model-specific cases are added here and
/// the floor cases stay.
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

  Future<List<List<String>>> policy(String lessonId) => sqlRows(
    'select submission_minimum, recommended_meetings '
    "from private.lesson_meeting_policy('$lessonId')",
  );

  group('lesson_meeting_policy (placeholder until N1)', () {
    test('every lesson gets the shared floor: submission minimum 1, no '
        'recommended number', () async {
      for (final lesson in curriculum.lessonIds) {
        expect(await policy(lesson), [
          ['1', ''],
        ]);
      }
    });

    test('required_meetings does not drive the policy', () async {
      final lesson = curriculum.lessonIds.first;
      for (final n in [1, 9]) {
        await service
            .from('curriculum_lessons')
            .update({'required_meetings': n})
            .eq('id', lesson);
        expect(await policy(lesson), [
          ['1', ''],
        ], reason: 'required_meetings = $n');
      }
    });

    test('an unknown lesson has no policy', () async {
      expect(await policy('00000000-0000-4000-8000-000000000000'), isEmpty);
    });

    test('no database function reads required_meetings; only bootstrap '
        'seeds and asserts it', () async {
      final rows = await sqlRows('''
        select p.proname
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'private')
          and p.prosrc ilike '%required_meetings%'
        order by 1''');
      expect(
        [for (final r in rows) r.single],
        ['assert_bootstrap_postconditions', 'bootstrap_church'],
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

  test('policy points and derivations are not callable by clients', () async {
    for (final call in [
      "private.lesson_meeting_policy('${curriculum.lessonIds.first}')",
      'private.discipler_eligibility_lesson()',
      "private.credited_count('${pair.disciple.membershipId}', "
          "'${curriculum.lessonIds.first}')",
      "private.eligible_lesson('${pair.disciple.membershipId}')",
    ]) {
      final error = await sqlError('set role authenticated; select $call');
      expect(error, contains('permission denied'), reason: call);
    }
  });

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
