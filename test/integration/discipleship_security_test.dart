/// Slice 5 security: grants on the curriculum, meeting, progress, condition
/// and follow-up tables, the gathering lock-down (ADR-014), and the
/// read-only RLS policies, decided for each pair (caller, person viewed).
///
/// Rows are written through the service role here, because the recording
/// operations arrive in later steps; what is tested is who may read them.
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

  // In g1: Discipler A with Disciples A1 and A2; Discipler B with B1.
  // In g2: Discipler C with C1.
  late PairedDisciple a1;
  late ({TestMember disciple, String discipleDgmId}) a2;
  late PairedDisciple b1;
  late PairedDisciple c1;

  late TestMember plain;
  late TestMember adminOnly;
  late TestUser pending;

  late String meetingA;
  late String meetingB;
  late String meetingC;
  late String otherChurchLesson;

  final people = <String>[];
  final since = DateTime.now().toUtc().subtract(const Duration(days: 60));
  String daysAgo(int d) =>
      DateTime.now().toUtc().subtract(Duration(days: d)).toIso8601String();

  Future<String> insertMeeting(
    TestGroup group,
    String disciplerDgmId,
    String recorderId,
    Map<String, String> outcomes,
  ) async {
    final m = await service
        .from('discipleship_meetings')
        .insert({
          'd_group_id': group.groupId,
          'discipler_d_group_membership_id': disciplerDgmId,
          'lesson_id': curriculum.lessonIds.first,
          'occurred_at': daysAgo(10),
          'recorded_by': recorderId,
        })
        .select('id')
        .single();
    final id = m['id'] as String;
    await service.from('discipleship_meeting_participants').insert([
      for (final e in outcomes.entries)
        {
          'meeting_id': id,
          'church_membership_id': e.key,
          'attendance_status': e.value,
        },
    ]);
    return id;
  }

  Future<void> insertProgress(String membershipId) =>
      service.from('disciple_lesson_progress').insert({
        'church_membership_id': membershipId,
        'lesson_id': curriculum.lessonIds.first,
        'status': 'IN_PROGRESS',
        'started_at': daysAgo(10),
      });

  setUpAll(() async {
    church = await seedChurch(name: 'Discipleship Security Church');
    otherChurch = await seedChurch(name: 'Other Discipleship Security');
    curriculum = await seedCurriculum(church.churchId);
    otherCurriculum = await seedCurriculum(otherChurch.churchId, lessons: 2);
    otherChurchLesson = otherCurriculum.lessonIds.first;
    g1 = await createGroupWithLeader(church, tag: 'ds-g1');
    g2 = await createGroupWithLeader(church, tag: 'ds-g2');

    a1 = await placePairedDisciple(church, g1, since: since, tag: 'ds-a');
    a2 = await addDisciple(
      church,
      g1,
      a1.disciplerDgmId,
      since: since,
      tag: 'ds-a2',
    );
    b1 = await placePairedDisciple(church, g1, since: since, tag: 'ds-b');
    c1 = await placePairedDisciple(church, g2, since: since, tag: 'ds-c');

    plain = await createActiveMember(church.churchId, fullName: 'Plain');
    adminOnly = await createActiveMember(church.churchId, fullName: 'Admin');
    // A former Admin: the role is retired and its rows ended (ADR-022).
    await service
        .from('church_role_assignments')
        .insert(formerAdminRow(adminOnly.membershipId, church.approver.userId));
    pending = await createUser(fullName: 'Pending Person', tag: 'ds-pend');
    await seedMembership(church.churchId, pending.userId, 'PENDING');

    people.addAll([
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
        plain,
        adminOnly,
      ])
        m.user.userId,
      pending.userId,
    ]);

    meetingA = await insertMeeting(
      g1,
      a1.disciplerDgmId,
      a1.discipler.user.userId,
      {a1.disciple.membershipId: 'PRESENT', a2.disciple.membershipId: 'ABSENT'},
    );
    meetingB = await insertMeeting(
      g1,
      b1.disciplerDgmId,
      b1.discipler.user.userId,
      {b1.disciple.membershipId: 'PRESENT'},
    );
    meetingC = await insertMeeting(
      g2,
      c1.disciplerDgmId,
      c1.discipler.user.userId,
      {c1.disciple.membershipId: 'LATE'},
    );
    for (final m in [a1.disciple, a2.disciple, b1.disciple, c1.disciple]) {
      await insertProgress(m.membershipId);
    }
  });
  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final id in people) {
      await deleteUser(id);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  final denied = throwsPostgrestCode('42501');

  group('grants', () {
    const writeOnly = [
      'curricula',
      'curriculum_lessons',
      'discipleship_meetings',
      'discipleship_meeting_participants',
      'disciple_lesson_progress',
      'attention_conditions',
      'follow_ups',
      'follow_up_actions',
    ];

    test('authenticated callers cannot write the Slice 5 tables directly, '
        'even a Coordinator', () async {
      final client = church.approver.client;
      for (final table in writeOnly) {
        await expectLater(
          client.from(table).insert({'id': curriculum.curriculumId}),
          denied,
          reason: 'insert $table',
        );
        await expectLater(
          client
              .from(table)
              .update({'created_at': DateTime.now().toIso8601String()})
              .eq('id', curriculum.curriculumId),
          denied,
          reason: 'update $table',
        );
        await expectLater(
          client.from(table).delete().eq('id', curriculum.curriculumId),
          denied,
          reason: 'delete $table',
        );
      }
    });

    test('anon has no access to the Slice 5 tables', () async {
      final anon = anonClient();
      for (final table in writeOnly) {
        await expectLater(
          anon.from(table).select('id'),
          denied,
          reason: 'select $table',
        );
      }
    });

    test('gathering tables are locked: neither anon nor authenticated can '
        'read or write them (ADR-014)', () async {
      for (final client in [church.approver.client, anonClient()]) {
        for (final table in ['d_group_gatherings', 'gathering_attendance']) {
          await expectLater(
            client.from(table).select('id'),
            denied,
            reason: 'select $table',
          );
          await expectLater(
            client.from(table).insert({'id': curriculum.curriculumId}),
            denied,
            reason: 'insert $table',
          );
        }
      }
    });

    test(
      'nobody reads monitoring or follow-up rows: no policy exists',
      () async {
        for (final table in [
          'attention_conditions',
          'follow_ups',
          'follow_up_actions',
        ]) {
          expect(
            await church.approver.client.from(table).select('id'),
            isEmpty,
            reason: table,
          );
        }
      },
    );
  });

  group('curriculum', () {
    Future<int> lessonsVisible(
      SupabaseClient client,
      String curriculumId,
    ) async =>
        (await client
                .from('curriculum_lessons')
                .select('id')
                .eq('curriculum_id', curriculumId))
            .length;

    test('every ACTIVE member reads their church\'s curriculum, whatever '
        'their role', () async {
      for (final m in [plain, adminOnly, a1.disciple, g1.leader]) {
        final client = m.user.client;
        expect(await client.from('curricula').select('id'), [
          {'id': curriculum.curriculumId},
        ]);
        expect(await lessonsVisible(client, curriculum.curriculumId), 10);
      }
    });

    test(
      'another church\'s curriculum is not visible, even to a Coordinator',
      () async {
        final client = church.approver.client;
        expect(await lessonsVisible(client, otherCurriculum.curriculumId), 0);
        expect(
          await client
              .from('curriculum_lessons')
              .select('id')
              .eq('id', otherChurchLesson),
          isEmpty,
        );
      },
    );

    test('a PENDING member reads no curriculum', () async {
      expect(await pending.client.from('curricula').select('id'), isEmpty);
      expect(await lessonsVisible(pending.client, curriculum.curriculumId), 0);
    });
  });

  group('discipleship_meetings', () {
    Future<Set<String>> visible(SupabaseClient client) async => {
      for (final r
          in await client.from('discipleship_meetings').select('id').inFilter(
            'id',
            [meetingA, meetingB, meetingC],
          ))
        r['id'] as String,
    };

    test('the Coordinator reads every meeting in the church; another '
        'church\'s Coordinator none', () async {
      expect(await visible(church.approver.client), {
        meetingA,
        meetingB,
        meetingC,
      });
      expect(await visible(otherChurch.approver.client), isEmpty);
    });

    test('a Leader reads the meetings of their own group only', () async {
      expect(await visible(g1.leader.user.client), {meetingA, meetingB});
      expect(await visible(g2.leader.user.client), {meetingC});
    });

    test('a Discipler reads only meetings under their own row, not other '
        'Disciplers\' in the group (O1)', () async {
      expect(await visible(a1.discipler.user.client), {meetingA});
      expect(await visible(b1.discipler.user.client), {meetingB});
    });

    test('a Disciple reads meetings they are in, including one where they '
        'were recorded absent', () async {
      expect(await visible(a1.disciple.user.client), {meetingA});
      expect(await visible(a2.disciple.user.client), {meetingA});
      expect(await visible(b1.disciple.user.client), {meetingB});
    });

    test('a member without a D Group, an Admin who is not Coordinator and a '
        'PENDING member read none', () async {
      for (final client in [
        plain.user.client,
        adminOnly.user.client,
        pending.client,
      ]) {
        expect(await visible(client), isEmpty);
      }
    });
  });

  group('discipleship_meeting_participants', () {
    Future<Set<String>> visible(
      SupabaseClient client,
      String meetingId,
    ) async => {
      for (final r
          in await client
              .from('discipleship_meeting_participants')
              .select('church_membership_id')
              .eq('meeting_id', meetingId))
        r['church_membership_id'] as String,
    };

    test(
      'a Disciple sees only their own row, not a co-participant\'s',
      () async {
        expect(await visible(a1.disciple.user.client, meetingA), {
          a1.disciple.membershipId,
        });
        expect(await visible(a2.disciple.user.client, meetingA), {
          a2.disciple.membershipId,
        });
      },
    );

    test('the meeting\'s Discipler, the Leader and the Coordinator see every '
        'row', () async {
      final all = {a1.disciple.membershipId, a2.disciple.membershipId};
      for (final client in [
        a1.discipler.user.client,
        g1.leader.user.client,
        church.approver.client,
      ]) {
        expect(await visible(client, meetingA), all);
      }
    });

    test('nobody outside the meeting context sees its rows', () async {
      for (final client in [
        b1.discipler.user.client,
        b1.disciple.user.client,
        g2.leader.user.client,
        adminOnly.user.client,
        otherChurch.approver.client,
      ]) {
        expect(await visible(client, meetingA), isEmpty);
      }
    });
  });

  group('disciple_lesson_progress', () {
    Future<Set<String>> visible(SupabaseClient client) async => {
      for (final r
          in await client
              .from('disciple_lesson_progress')
              .select('church_membership_id')
              .inFilter('church_membership_id', [
                a1.disciple.membershipId,
                a2.disciple.membershipId,
                b1.disciple.membershipId,
                c1.disciple.membershipId,
              ]))
        r['church_membership_id'] as String,
    };

    test(
      'the Coordinator reads every Disciple\'s progress in the church',
      () async {
        expect(await visible(church.approver.client), {
          a1.disciple.membershipId,
          a2.disciple.membershipId,
          b1.disciple.membershipId,
          c1.disciple.membershipId,
        });
        expect(await visible(otherChurch.approver.client), isEmpty);
      },
    );

    test(
      'a Leader reads the progress of Disciples currently in their group',
      () async {
        expect(await visible(g1.leader.user.client), {
          a1.disciple.membershipId,
          a2.disciple.membershipId,
          b1.disciple.membershipId,
        });
        expect(await visible(g2.leader.user.client), {
          c1.disciple.membershipId,
        });
      },
    );

    test('a Discipler reads only their own assigned Disciples, not another '
        'Disciple in the same group (N7)', () async {
      expect(await visible(a1.discipler.user.client), {
        a1.disciple.membershipId,
        a2.disciple.membershipId,
      });
      expect(await visible(b1.discipler.user.client), {
        b1.disciple.membershipId,
      });
    });

    test('a Disciple reads only their own progress', () async {
      expect(await visible(a1.disciple.user.client), {
        a1.disciple.membershipId,
      });
    });

    test('a member without a D Group, an Admin who is not Coordinator and a '
        'PENDING member read none', () async {
      for (final client in [
        plain.user.client,
        adminOnly.user.client,
        pending.client,
      ]) {
        expect(await visible(client), isEmpty);
      }
    });
  });

  group('relationship changes', () {
    test('when the assignment ends, the Discipler loses the progress read but '
        'keeps the meetings recorded under their own row', () async {
      final a3 = await addDisciple(
        church,
        g1,
        a1.disciplerDgmId,
        since: since,
        tag: 'ds-a3',
      );
      addTearDown(() => deleteUser(a3.disciple.user.userId));
      final meeting = await insertMeeting(
        g1,
        a1.disciplerDgmId,
        a1.discipler.user.userId,
        {a3.disciple.membershipId: 'PRESENT'},
      );
      await insertProgress(a3.disciple.membershipId);

      Future<List<dynamic>> progress(SupabaseClient client) => client
          .from('disciple_lesson_progress')
          .select('id')
          .eq('church_membership_id', a3.disciple.membershipId);

      final discipler = a1.discipler.user.client;
      expect(await progress(discipler), hasLength(1));

      await setDiscipler(g1.leader.user.client, a3.discipleDgmId, null);

      expect(await progress(discipler), isEmpty);
      expect(await progress(g1.leader.user.client), hasLength(1));
      expect(
        await discipler
            .from('discipleship_meetings')
            .select('id')
            .eq('id', meeting),
        hasLength(1),
      );
    });

    test('an INACTIVE member reads nothing: no curriculum, no meetings, no '
        'own progress', () async {
      final a4 = await addDisciple(
        church,
        g1,
        a1.disciplerDgmId,
        since: since,
        tag: 'ds-a4',
      );
      addTearDown(() => deleteUser(a4.disciple.user.userId));
      final meeting = await insertMeeting(
        g1,
        a1.disciplerDgmId,
        a1.discipler.user.userId,
        {a4.disciple.membershipId: 'PRESENT'},
      );
      await insertProgress(a4.disciple.membershipId);
      final client = a4.disciple.user.client;
      expect(await client.from('discipleship_meetings').select('id'), [
        {'id': meeting},
      ]);

      await service
          .from('church_memberships')
          .update({'status': 'INACTIVE'})
          .eq('id', a4.disciple.membershipId);

      expect(await client.from('curricula').select('id'), isEmpty);
      expect(await client.from('discipleship_meetings').select('id'), isEmpty);
      expect(
        await client.from('discipleship_meeting_participants').select('id'),
        isEmpty,
      );
      expect(
        await client.from('disciple_lesson_progress').select('id'),
        isEmpty,
      );
    });
  });
}
