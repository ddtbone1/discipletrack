/// Discipleship fixtures for Slice 5: a curriculum for a test church and a
/// Disciple paired with a Discipler, backdated so meetings can be recorded
/// in the past.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'ministry_fixture.dart';
import 'test_env.dart';

typedef TestCurriculum = ({String curriculumId, List<String> lessonIds});

/// An ACTIVE curriculum of [lessons] lessons for [churchId], as bootstrap
/// creates for a real church. Test churches are seeded without bootstrap,
/// so they have none. Lesson ids are in lesson-number order.
Future<TestCurriculum> seedCurriculum(
  String churchId, {
  int lessons = 10,
}) async {
  final curriculum = await service
      .from('curricula')
      .insert({
        'church_id': churchId,
        'name': 'Test Curriculum',
        'status': 'ACTIVE',
      })
      .select('id')
      .single();
  final curriculumId = curriculum['id'] as String;
  final rows = await service
      .from('curriculum_lessons')
      .insert([
        for (var n = 1; n <= lessons; n++)
          {'curriculum_id': curriculumId, 'lesson_number': n, 'title': 'L$n'},
      ])
      .select('id, lesson_number');
  rows.sort(
    (a, b) => (a['lesson_number'] as int).compareTo(b['lesson_number'] as int),
  );
  return (
    curriculumId: curriculumId,
    lessonIds: [for (final r in rows) r['id'] as String],
  );
}

typedef PairedDisciple = ({
  TestMember disciple,
  String discipleDgmId,
  TestMember discipler,
  String disciplerDgmId,
});

/// A new Disciple and Discipler in [group], placed and paired through the
/// real operations, then backdated through the service role so both
/// D Group rows and the assignment started at [since].
Future<PairedDisciple> placePairedDisciple(
  TestChurch church,
  TestGroup group, {
  required DateTime since,
  String tag = 'pair',
}) async {
  final discipler = await createActiveMember(
    church.churchId,
    fullName: 'Discipler $tag',
    tag: '$tag-dr',
  );
  final disciplerDgmId = await place(
    group.leader.user.client,
    group.groupId,
    discipler,
    'DISCIPLER',
  );
  await service
      .from('d_group_memberships')
      .update({'started_at': since.toUtc().toIso8601String()})
      .eq('id', disciplerDgmId);

  final added = await addDisciple(
    church,
    group,
    disciplerDgmId,
    since: since,
    tag: '$tag-de',
  );
  return (
    disciple: added.disciple,
    discipleDgmId: added.discipleDgmId,
    discipler: discipler,
    disciplerDgmId: disciplerDgmId,
  );
}

/// Another Disciple for the Discipler row [disciplerDgmId] in [group],
/// placed and paired through the real operations, then backdated so the
/// DISCIPLE row and the assignment started at [since]. One Discipler may
/// have several Disciples.
Future<({TestMember disciple, String discipleDgmId})> addDisciple(
  TestChurch church,
  TestGroup group,
  String disciplerDgmId, {
  required DateTime since,
  String tag = 'disc',
}) async {
  final disciple = await createActiveMember(
    church.churchId,
    fullName: 'Disciple $tag',
    tag: tag,
  );
  final leader = group.leader.user.client;
  final discipleDgmId = await place(
    leader,
    group.groupId,
    disciple,
    'DISCIPLE',
  );
  await setDiscipler(leader, discipleDgmId, disciplerDgmId);

  final started = since.toUtc().toIso8601String();
  await service
      .from('d_group_memberships')
      .update({'started_at': started})
      .eq('id', discipleDgmId);
  await service
      .from('discipler_assignments')
      .update({'started_at': started})
      .eq('disciple_d_group_membership_id', discipleDgmId)
      .isFilter('ended_at', null);
  return (disciple: disciple, discipleDgmId: discipleDgmId);
}

/// `record_discipleship_meeting()` as [caller], returning the meeting id.
/// [outcomes] maps church membership ids to attendance outcomes.
Future<String> recordMeeting(
  SupabaseClient caller, {
  required String disciplerDgmId,
  required String lessonId,
  required Map<String, String> outcomes,
  DateTime? occurredAt,
  String? notes,
}) async {
  final row = await rpcRow(caller, 'record_discipleship_meeting', {
    'p_discipler_d_group_membership_id': disciplerDgmId,
    'p_lesson_id': lessonId,
    'p_occurred_at': (occurredAt ?? DateTime.now().toUtc())
        .toUtc()
        .toIso8601String(),
    'p_participants': [
      for (final e in outcomes.entries)
        {'church_membership_id': e.key, 'attendance_status': e.value},
    ],
    'p_notes': notes,
  });
  return row['meeting_id'] as String;
}

/// The person's progress row for [lessonId], or null.
Future<Map<String, dynamic>?> progressRow(
  String membershipId,
  String lessonId,
) => service
    .from('disciple_lesson_progress')
    .select()
    .eq('church_membership_id', membershipId)
    .eq('lesson_id', lessonId)
    .maybeSingle();
