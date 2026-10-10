/// Slice 8 against the real local stack: curriculum access follows the
/// relationship (ADR-023, superseding ADR-019 decision 16), and a Discipler,
/// every Leader included, reads the whole book in their own context
/// (ADR-024, amending ADR-023 decisions 2 and 3). Covers the cases
/// that exist in the ministry: a Disciple who is also a Discipler (Rosa in
/// the seed), a Leader who disciples, re-pairing, the Coordinator's full
/// access, and that reading never changes progression.
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
  late TestCurriculum curriculum;
  late TestGroup g;
  late PairedDisciple rosa; // will be a Disciple and an appointed Discipler
  late String rosaDisciplerDgm;
  late TestMember paired; // a Disciple paired with Rosa
  late String pairedDgm;
  late TestMember leaders; // a Disciple paired with the group's Leader
  late String leaderDisciplerDgm;
  final cleanup = <String>[];

  Map<String, dynamic> definition() => {
    'lessons': [
      for (var n = 1; n <= 10; n++)
        {
          'number': n,
          'title': 'Lesson $n',
          'blocks': [
            {
              'type': 'FILL_IN',
              'tier': 'DISCIPLE',
              'section': 'A',
              'body': {'text': 'God ___ the world.'},
              'answers': [
                ['loves'],
              ],
            },
            {
              'type': 'MODULE_HEADING',
              'tier': 'DISCIPLER',
              'body': {'number': n, 'title': 'Module $n'},
            },
          ],
        },
    ],
  };

  String lesson(int n) => curriculum.lessonIds[n - 1];

  setUpAll(() async {
    church = await seedChurch(name: 'Relationship Curriculum Church');
    curriculum = await seedCurriculum(church.churchId);
    await service.rpc<List<dynamic>>(
      'publish_curriculum',
      params: {
        'p_church_id': church.churchId,
        'p_definition': definition(),
        'p_content_level': 'FULL',
        'p_licence_reference': 'TEST-LICENCE-RC',
        'p_published_by': church.approver.userId,
      },
    );
    g = await createGroupWithLeader(church, tag: 'rc-lead');
    rosa = await placePairedDisciple(
      church,
      g,
      since: DateTime.now().subtract(const Duration(days: 60)),
      tag: 'rc-rosa',
    );
    // Lessons 1 to 5 completed by her Discipler, then appointed.
    for (var n = 1; n <= 5; n++) {
      await rpcRow(rosa.discipler.user.client, 'complete_lesson', {
        'p_membership_id': rosa.disciple.membershipId,
        'p_lesson_id': lesson(n),
      });
    }
    await rpcRow(church.approver.client, 'appoint_discipler', {
      'p_membership_id': rosa.disciple.membershipId,
    });
    rosaDisciplerDgm =
        (await service
                .from('d_group_memberships')
                .select('id')
                .eq('church_membership_id', rosa.disciple.membershipId)
                .eq('responsibility', 'DISCIPLER')
                .isFilter('ended_at', null)
                .single())['id']
            as String;

    paired = await createActiveMember(
      church.churchId,
      fullName: 'RC Paired',
      tag: 'rc-paired',
    );
    pairedDgm = await place(
      g.leader.user.client,
      g.groupId,
      paired,
      'DISCIPLE',
    );
    await setDiscipler(g.leader.user.client, pairedDgm, rosaDisciplerDgm);

    leaderDisciplerDgm =
        (await service
                .from('d_group_memberships')
                .select('id')
                .eq('church_membership_id', g.leader.membershipId)
                .eq('responsibility', 'DISCIPLER')
                .isFilter('ended_at', null)
                .single())['id']
            as String;
    leaders = await createActiveMember(
      church.churchId,
      fullName: 'RC Leader Disciple',
      tag: 'rc-ld',
    );
    final leadersDgm = await place(
      g.leader.user.client,
      g.groupId,
      leaders,
      'DISCIPLE',
    );
    await setDiscipler(g.leader.user.client, leadersDgm, leaderDisciplerDgm);

    cleanup.addAll([
      g.leader.user.userId,
      rosa.disciple.user.userId,
      rosa.discipler.user.userId,
      paired.user.userId,
      leaders.user.userId,
    ]);
  });

  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final id in cleanup) {
      await deleteUser(id);
    }
    await deleteUser(church.approver.userId);
  });

  Future<List<Map<String, dynamic>>> content(
    SupabaseClient c,
    int n, {
    String? forId,
  }) async => (await c.rpc<List<dynamic>>(
    'get_lesson_content',
    params: {'p_lesson_id': lesson(n), 'p_for_membership_id': forId},
  )).cast<Map<String, dynamic>>();

  Set<String> tiers(List<Map<String, dynamic>> rows) => {
    for (final r in rows) r['tier'] as String,
  };

  bool hasAnswers(List<Map<String, dynamic>> rows) =>
      rows.any((r) => r['answers'] != null);

  Matcher refused() => throwsPostgrestCode('PT403');

  group('a Disciple who is also a Discipler (Rosa)', () {
    test('in her own context, as a Discipler, reads all ten lessons, both '
        'tiers (ADR-024); reading ahead records nothing', () async {
      final c = rosa.disciple.user.client;
      for (final n in [1, 6, 7, 10]) {
        final rows = await content(c, n);
        expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'}, reason: 'Lesson $n');
        expect(hasAnswers(rows), isTrue, reason: 'Lesson $n');
      }
      final own = (await c.rpc<List<dynamic>>('list_lesson_access'))
          .cast<Map<String, dynamic>>();
      expect(own, hasLength(10));
      expect(
        own.every(
          (r) => r['disciple_tier'] == true && r['discipler_tier'] == true,
        ),
        isTrue,
      );
      // Her progression is her Discipler's to record: five completed, still.
      final done = await service
          .from('disciple_lesson_progress')
          .select('lesson_id')
          .eq('church_membership_id', rosa.disciple.membershipId)
          .eq('status', 'COMPLETED');
      expect(done, hasLength(5));
    });

    test('in her paired Disciple\'s context reads all ten lessons, both tiers, '
        'with answers', () async {
      final c = rosa.disciple.user.client;
      for (final n in [1, 6, 10]) {
        final rows = await content(c, n, forId: paired.membershipId);
        expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'}, reason: 'Lesson $n');
        expect(hasAnswers(rows), isTrue, reason: 'Lesson $n');
      }
      final access = (await c.rpc<List<dynamic>>(
        'list_lesson_access',
        params: {'p_for_membership_id': paired.membershipId},
      )).cast<Map<String, dynamic>>();
      expect(access.every((r) => r['discipler_tier'] == true), isTrue);
    });

    test('her device copy holds the whole book, both tiers, for her own '
        'context and her Disciple\'s', () async {
      final rows = (await rosa.disciple.user.client.rpc<List<dynamic>>(
        'get_my_readable_content',
      )).cast<Map<String, dynamic>>();
      expect({for (final r in rows) r['lesson_id']}, hasLength(10));
      expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'});
    });
  });

  group('the Leader', () {
    test(
      'as the assigned Discipler of a Disciple reads all ten lessons, both '
      'tiers, in that Disciple\'s context and in their own (ADR-024)',
      () async {
        final c = g.leader.user.client;
        for (final forId in [leaders.membershipId, null]) {
          final rows = await content(c, 10, forId: forId);
          expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'}, reason: '$forId');
          expect(hasAnswers(rows), isTrue, reason: '$forId');
        }
      },
    );

    test('with a Disciple paired with someone else reads that Disciple\'s '
        'reached lessons, Disciple tier only', () async {
      final c = g.leader.user.client;
      final rows = await content(c, 6, forId: rosa.disciple.membershipId);
      expect(tiers(rows), {'DISCIPLE'});
      expect(hasAnswers(rows), isFalse);
      await expectLater(
        content(c, 7, forId: rosa.disciple.membershipId),
        refused(),
      );
    });
  });

  group('a Disciple who is not a Discipler', () {
    test('reads only their own journey in their own context: the current '
        'lesson, Disciple tier, no answers', () async {
      final c = paired.user.client;
      final rows = await content(c, 1);
      expect(tiers(rows), {'DISCIPLE'});
      expect(hasAnswers(rows), isFalse);
      await expectLater(content(c, 2), refused());
      final own = (await c.rpc<List<dynamic>>('list_lesson_access'))
          .cast<Map<String, dynamic>>();
      expect(
        [for (final r in own) r['disciple_tier']],
        [true, false, false, false, false, false, false, false, false, false],
      );
      expect(own.every((r) => r['discipler_tier'] == false), isTrue);
    });
  });

  group('re-pairing', () {
    test('ends the former Discipler\'s access at once', () async {
      final c = rosa.disciple.user.client;
      expect(await content(c, 10, forId: paired.membershipId), isNotEmpty);

      await setDiscipler(g.leader.user.client, pairedDgm, leaderDisciplerDgm);
      try {
        await expectLater(
          content(c, 10, forId: paired.membershipId),
          refused(),
        );
        await expectLater(
          c.rpc<List<dynamic>>(
            'list_lesson_access',
            params: {'p_for_membership_id': paired.membershipId},
          ),
          refused(),
        );
      } finally {
        await setDiscipler(g.leader.user.client, pairedDgm, rosaDisciplerDgm);
      }
    });
  });

  group('the Coordinator', () {
    test('reads every lesson, both tiers, in their own context and in any '
        'member\'s', () async {
      final c = church.approver.client;
      for (final forId in [
        null,
        rosa.disciple.membershipId,
        paired.membershipId,
      ]) {
        final rows = await content(c, 10, forId: forId);
        expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'}, reason: '$forId');
        expect(hasAnswers(rows), isTrue);
      }
    });
  });

  group('reading never affects progression (ADR-023 decision 11)', () {
    test('reading every open lesson in every context changes no progress, '
        'journey or audit row', () async {
      Future<String> state() async {
        final progress = await service
            .from('disciple_lesson_progress')
            .select('church_membership_id, lesson_id, status, completed_at')
            .inFilter('church_membership_id', [
              rosa.disciple.membershipId,
              paired.membershipId,
              leaders.membershipId,
            ])
            .order('church_membership_id')
            .order('lesson_id');
        final journeys = [
          for (final m in [
            rosa.disciple.membershipId,
            paired.membershipId,
            leaders.membershipId,
          ])
            await church.approver.client.rpc<dynamic>(
              'get_disciple_journey',
              params: {'p_membership_id': m},
            ),
        ];
        final audit = await service
            .from('audit_events')
            .select('id')
            .eq('church_id', church.churchId);
        final meetings = await service
            .from('discipleship_meetings')
            .select('id')
            .eq('d_group_id', g.groupId);
        return jsonEncode([progress, journeys, audit.length, meetings.length]);
      }

      final before = await state();
      final readers = <(SupabaseClient, String?)>[
        (rosa.disciple.user.client, null),
        (rosa.disciple.user.client, paired.membershipId),
        (g.leader.user.client, leaders.membershipId),
        (g.leader.user.client, rosa.disciple.membershipId),
        (church.approver.client, null),
        (church.approver.client, paired.membershipId),
      ];
      for (final (c, forId) in readers) {
        for (var n = 1; n <= 10; n++) {
          await content(c, n, forId: forId).then((_) {}, onError: (_) {});
        }
        await c.rpc<dynamic>(
          'list_lesson_access',
          params: {'p_for_membership_id': forId},
        );
        await c.rpc<dynamic>('get_my_readable_content');
      }
      expect(await state(), before);
    });
  });
}
