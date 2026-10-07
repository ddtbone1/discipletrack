/// Slice 7.1 against the real local stack: curriculum content publishing
/// and progression-gated, tiered reads (ADR-019). Every negative is a
/// refusal by PostgreSQL itself, not by the client.
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
  late TestGroup g;
  late TestGroup g2;
  late PairedDisciple p;
  late TestMember plain;
  late TestMember adminOnly;
  final cleanup = <String>[];

  /// A test definition: per lesson a theme, scripture references, a
  /// FILL_IN block with answers and a Discipler-tier module heading.
  Map<String, dynamic> definition({String marker = 'v1'}) => {
    'lessons': [
      for (var n = 1; n <= 10; n++)
        {
          'number': n,
          'title': 'Lesson $n title',
          'blocks': [
            {
              'type': 'LESSON_THEME',
              'tier': 'DISCIPLE',
              'body': {'text': 'Theme $n $marker'},
            },
            {
              'type': 'SCRIPTURE_REFERENCES',
              'tier': 'DISCIPLE',
              'section': 'A',
              'body': {
                'refs': ['John 3:16'],
              },
            },
            {
              'type': 'FILL_IN',
              'tier': 'DISCIPLE',
              'section': 'A',
              'body': {'text': 'God ___ the world.'},
              'answers': [
                ['loves', 'loved'],
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

  Future<void> publish(
    Map<String, dynamic> def, {
    String level = 'FULL',
    String? licence = 'TEST-LICENCE-1',
  }) => service.rpc<List<dynamic>>(
    'publish_curriculum',
    params: {
      'p_church_id': church.churchId,
      'p_definition': def,
      'p_content_level': level,
      'p_licence_reference': licence,
      'p_published_by': church.approver.userId,
    },
  );

  setUpAll(() async {
    church = await seedChurch(name: 'Curriculum Content Church');
    otherChurch = await seedChurch(name: 'Other Curriculum Church');
    curriculum = await seedCurriculum(church.churchId);
    g = await createGroupWithLeader(church, tag: 'cc-lead');
    g2 = await createGroupWithLeader(church, tag: 'cc-lead2');
    p = await placePairedDisciple(
      church,
      g,
      since: DateTime.now().subtract(const Duration(days: 30)),
      tag: 'cc',
    );
    plain = await createActiveMember(
      church.churchId,
      fullName: 'CC Plain',
      tag: 'cc-plain',
    );
    adminOnly = await createActiveMember(
      church.churchId,
      fullName: 'CC Admin',
      tag: 'cc-admin',
    );
    await service.from('church_role_assignments').insert({
      'church_membership_id': adminOnly.membershipId,
      'role': 'ADMIN',
      'assigned_by': church.approver.userId,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    });
    await publish(definition());
    cleanup.addAll([
      g.leader.user.userId,
      g2.leader.user.userId,
      p.disciple.user.userId,
      p.discipler.user.userId,
      plain.user.userId,
      adminOnly.user.userId,
    ]);
  });

  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final id in cleanup) {
      await deleteUser(id);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  String lesson(int n) => curriculum.lessonIds[n - 1];

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

  group('the Disciple', () {
    test('reads the Disciple tier of their current lesson, never answers or '
        'the Discipler tier, and nothing ahead', () async {
      final rows = await content(p.disciple.user.client, 1);
      expect(tiers(rows), {'DISCIPLE'});
      expect(hasAnswers(rows), isFalse);
      expect(
        rows.map((r) => r['block_type']),
        isNot(contains('MODULE_HEADING')),
      );

      await expectLater(content(p.disciple.user.client, 2), refused());
    });

    test(
      'completing a lesson opens the next; undoing it closes it again',
      () async {
        await rpcRow(p.discipler.user.client, 'complete_lesson', {
          'p_membership_id': p.disciple.membershipId,
          'p_lesson_id': lesson(1),
        });
        expect(tiers(await content(p.disciple.user.client, 2)), {'DISCIPLE'});
        expect(tiers(await content(p.disciple.user.client, 1)), {
          'DISCIPLE',
        }, reason: 'completed lessons stay readable');

        await rpcRow(p.discipler.user.client, 'undo_lesson_completion', {
          'p_membership_id': p.disciple.membershipId,
          'p_lesson_id': lesson(1),
        });
        await expectLater(content(p.disciple.user.client, 2), refused());
      },
    );

    test('the lesson list shows what is open', () async {
      final rows = (await p.disciple.user.client.rpc<List<dynamic>>(
        'list_lesson_access',
      )).cast<Map<String, dynamic>>();
      expect(rows, hasLength(10));
      expect(rows.first['disciple_tier'], isTrue);
      expect(rows.first['discipler_tier'], isFalse);
      expect(rows.first['theme'], 'Theme 1 v1');
      expect(rows[1]['disciple_tier'], isFalse);
      expect(rows[1]['theme'], isNull, reason: 'nothing of a closed lesson');
    });
  });

  group('the assigned Discipler', () {
    test('reads both tiers, with answers, of every lesson in their '
        'Disciple\'s context, ahead of the journey too', () async {
      final rows = await content(
        p.discipler.user.client,
        1,
        forId: p.disciple.membershipId,
      );
      expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'});
      expect(hasAnswers(rows), isTrue);

      final ahead = await content(
        p.discipler.user.client,
        3,
        forId: p.disciple.membershipId,
      );
      expect(tiers(ahead), {'DISCIPLE', 'DISCIPLER'});
      expect(hasAnswers(ahead), isTrue);
    });

    test(
      'with no journey of their own, reads every lesson for themselves',
      () async {
        expect(tiers(await content(p.discipler.user.client, 10)), {
          'DISCIPLE',
          'DISCIPLER',
        });
      },
    );
  });

  group('the Leader', () {
    test(
      'holds the Discipler role (ADR-020), so reads both tiers with answers',
      () async {
        final rows = await content(
          g.leader.user.client,
          1,
          forId: p.disciple.membershipId,
        );
        expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'});
        expect(hasAnswers(rows), isTrue);
      },
    );

    test('of another group reads the curriculum but may not ask about the '
        'person', () async {
      // Content carries nothing of the person; as a Discipler they read it.
      expect(
        await content(g2.leader.user.client, 1, forId: p.disciple.membershipId),
        isNotEmpty,
      );
      await expectLater(
        g2.leader.user.client.rpc<List<dynamic>>(
          'list_lesson_access',
          params: {'p_for_membership_id': p.disciple.membershipId},
        ),
        refused(),
      );
    });
  });

  group('the Coordinator', () {
    test('reads both tiers of any lesson', () async {
      final rows = await content(church.approver.client, 10);
      expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'});
      expect(hasAnswers(rows), isTrue);
    });
  });

  group('no access', () {
    test('a member with no journey, an Admin-only user, another church and '
        'anon read nothing', () async {
      for (final c in [
        plain.user.client,
        adminOnly.user.client,
        otherChurch.approver.client,
      ]) {
        await expectLater(content(c, 1), refused());
      }
      final rows = (await plain.user.client.rpc<List<dynamic>>(
        'list_lesson_access',
      )).cast<Map<String, dynamic>>();
      expect(rows.every((r) => r['disciple_tier'] == false), isTrue);
      await expectLater(
        anonClient().rpc<List<dynamic>>(
          'get_lesson_content',
          params: {'p_lesson_id': lesson(1)},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('an unknown lesson is refused like a forbidden one', () async {
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'get_lesson_content',
          params: {'p_lesson_id': '00000000-0000-4000-8000-0000000000cc'},
        ),
        refused(),
      );
    });

    test('the tables are not readable or writable directly', () async {
      for (final table in [
        'curriculum_publications',
        'lesson_content_blocks',
        'lesson_block_answers',
      ]) {
        await expectLater(
          church.approver.client.from(table).select('id'),
          throwsPostgrestCode('42501'),
          reason: table,
        );
      }
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'publish_curriculum',
          params: {
            'p_church_id': church.churchId,
            'p_definition': definition(),
            'p_content_level': 'METADATA',
            'p_licence_reference': null,
            'p_published_by': church.approver.userId,
          },
        ),
        throwsA(isA<PostgrestException>()),
        reason: 'publishing is trusted tooling only',
      );
    });
  });

  group('checking blanks (Migration 020)', () {
    Future<List<Map<String, dynamic>>> check(
      SupabaseClient c,
      Map<String, dynamic> responses,
    ) async => (await c.rpc<List<dynamic>>(
      'check_lesson_answers',
      params: {'p_lesson_id': lesson(1), 'p_responses': responses},
    )).cast<Map<String, dynamic>>();

    test('the Disciple learns right or wrong and the answer, only for what '
        'they wrote; nobody outside the lesson may ask', () async {
      final fill = (await content(
        p.disciple.user.client,
        1,
      )).firstWhere((r) => r['block_type'] == 'FILL_IN');
      final id = fill['block_id'] as String;
      expect(fill['answers'], isNull, reason: 'the read itself has no key');

      final right = await check(p.disciple.user.client, {
        id: ['  Loved! '],
      });
      expect(right.single['correct'], isTrue, reason: 'any accepted answer');
      expect(right.single['answer'], 'loves');

      final wrong = await check(p.disciple.user.client, {
        id: ['hates'],
      });
      expect(wrong.single['correct'], isFalse);

      expect(
        await check(p.disciple.user.client, {
          id: [''],
        }),
        isEmpty,
        reason: 'an empty blank reveals nothing',
      );

      await expectLater(
        check(plain.user.client, {
          id: ['loves'],
        }),
        refused(),
      );
    });
  });

  group('lesson covers', () {
    test('every active member of the church reads them, locked lessons '
        'included; nobody else, and never directly', () async {
      await service.rpc<void>(
        'set_lesson_cover',
        params: {'p_lesson_id': lesson(5), 'p_image': 'AAAA'},
      );
      Future<List<Map<String, dynamic>>> covers(SupabaseClient c) async =>
          (await c.rpc<List<dynamic>>('get_lesson_covers'))
              .cast<Map<String, dynamic>>();

      for (final c in [p.disciple.user.client, plain.user.client]) {
        expect(
          (await covers(c)).where((r) => r['lesson_id'] == lesson(5)),
          hasLength(1),
        );
      }
      expect(
        (await covers(otherChurch.approver.client))
            .where((r) => r['lesson_id'] == lesson(5)),
        isEmpty,
      );
      await expectLater(
        church.approver.client.rpc<void>(
          'set_lesson_cover',
          params: {'p_lesson_id': lesson(5), 'p_image': 'BBBB'},
        ),
        throwsA(isA<PostgrestException>()),
        reason: 'covers are written by trusted tooling only',
      );
      await expectLater(
        church.approver.client.from('lesson_covers').select('lesson_id'),
        throwsPostgrestCode('42501'),
      );
    });
  });

  group('the device copy', () {
    test('holds only what each person may read', () async {
      final disciple = (await p.disciple.user.client.rpc<List<dynamic>>(
        'get_my_readable_content',
      )).cast<Map<String, dynamic>>();
      expect({for (final r in disciple) r['lesson_id']}, {lesson(1)});
      expect(tiers(disciple), {'DISCIPLE'});
      expect(hasAnswers(disciple), isFalse);

      final discipler = (await p.discipler.user.client.rpc<List<dynamic>>(
        'get_my_readable_content',
      )).cast<Map<String, dynamic>>();
      expect({for (final r in discipler) r['lesson_id']}, hasLength(10));
      expect(tiers(discipler), {'DISCIPLE', 'DISCIPLER'});
      expect(hasAnswers(discipler), isTrue);

      final leader = (await g.leader.user.client.rpc<List<dynamic>>(
        'get_my_readable_content',
      )).cast<Map<String, dynamic>>();
      expect(tiers(leader), {'DISCIPLE', 'DISCIPLER'});
      expect(hasAnswers(leader), isTrue);

      expect(
        await plain.user.client.rpc<List<dynamic>>('get_my_readable_content'),
        isEmpty,
      );
    });
  });

  group('publishing', () {
    test('a full publication needs a recorded licence reference', () async {
      await expectLater(
        publish(definition(), licence: null),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'a metadata publication refuses substantive blocks and answers',
      () async {
        await expectLater(
          publish(definition(), level: 'METADATA', licence: null),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test('republishing supersedes and keeps history; published rows never '
        'change', () async {
      await publish(definition(marker: 'v2'));
      final pubs = await service
          .from('curriculum_publications')
          .select('version, superseded_at')
          .eq('curriculum_id', curriculum.curriculumId)
          .order('version');
      expect(pubs.length, greaterThanOrEqualTo(2));
      expect(pubs.where((r) => r['superseded_at'] == null), hasLength(1));

      final rows = await content(church.approver.client, 1);
      expect(
        rows.firstWhere((r) => r['block_type'] == 'LESSON_THEME')['body'],
        {'text': 'Theme 1 v2'},
      );

      final block = await service
          .from('lesson_content_blocks')
          .select('id')
          .limit(1)
          .single();
      await expectLater(
        service
            .from('lesson_content_blocks')
            .update({'ordinal': 99})
            .eq('id', block['id'] as String),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
  group('faithful lessons (Migration 019)', () {
    // Synthetic content only: the real lesson text never enters the
    // repository (ADR-019 decision 15).
    Map<String, dynamic> faithful({List<dynamic>? pointAnswers}) {
      final def = definition(marker: 'v3');
      final lesson1 = (def['lessons'] as List).first as Map<String, dynamic>;
      lesson1['blocks'] = <dynamic>[
        ...lesson1['blocks'] as List,
        {
          'type': 'HEADING',
          'tier': 'DISCIPLE',
          'body': {'title': 'Reflect', 'subtitle': 'A banner'},
        },
        {
          'type': 'POINT',
          'tier': 'DISCIPLE',
          'section': 'A',
          'body': {
            'reference': 'John 1:1',
            'text': 'In the [_] was the [_].',
            'blanks': 2,
          },
          'answers': pointAnswers ?? ['beginning', 'Word'],
        },
        {
          'type': 'VERSE_WRITING',
          'tier': 'DISCIPLE',
          'body': {
            'reference': 'John 11:35',
            'instruction': 'Write John 11:35 below.',
            'lines': 2,
            'blanks': 1,
          },
          'answers': ['Jesus wept.'],
        },
        {
          'type': 'FIGURE',
          'tier': 'DISCIPLE',
          'body': {'caption': '', 'lines': 2, 'blanks': 2},
          'answers': ['Label one', 'Label two'],
        },
        {
          'type': 'SELF_CHECK',
          'tier': 'DISCIPLE',
          'body': {
            'header': 'Question',
            'columns': ['Low', 'High'],
            'items': ['How are you?'],
          },
        },
        {
          'type': 'ASSIGNMENT',
          'tier': 'DISCIPLE',
          'body': {'number': 1, 'text': 'Do this.'},
        },
        {
          'type': 'LIST',
          'tier': 'DISCIPLE',
          'body': {
            'items': ['John 3:16'],
          },
        },
        {
          'type': 'SIGN_OFF',
          'tier': 'DISCIPLE',
          'body': {'text': 'Date completed : [_]'},
        },
        {
          'type': 'POINT',
          'tier': 'DISCIPLER',
          'body': {'text': 'A module point with [_].', 'blanks': 1},
          'answers': ['an answer'],
        },
      ];
      return def;
    }

    test('the Disciple reads every block of the Disciple tier, with blanks '
        'and without a single answer', () async {
      await publish(faithful());
      final rows = await content(p.disciple.user.client, 1);
      final point = rows.firstWhere((r) => r['block_type'] == 'POINT');
      expect(point['body']['text'], 'In the [_] was the [_].');
      expect(point['answers'], isNull);
      expect(hasAnswers(rows), isFalse);
      expect(tiers(rows), {'DISCIPLE'});
      expect(
        rows.map((r) => r['block_type']),
        containsAll([
          'HEADING',
          'VERSE_WRITING',
          'FIGURE',
          'SELF_CHECK',
          'ASSIGNMENT',
          'LIST',
          'SIGN_OFF',
        ]),
      );
    });

    test('the assigned Discipler reads the same lesson with every answer '
        'and the Discipler-only blocks', () async {
      final rows = await content(
        p.discipler.user.client,
        1,
        forId: p.disciple.membershipId,
      );
      final point = rows.firstWhere(
        (r) => r['block_type'] == 'POINT' && r['tier'] == 'DISCIPLE',
      );
      expect(point['answers'], ['beginning', 'Word']);
      expect(
        rows.firstWhere((r) => r['block_type'] == 'VERSE_WRITING')['answers'],
        ['Jesus wept.'],
      );
      expect(
        rows.where((r) => r['tier'] == 'DISCIPLER').map((r) => r['answers']),
        anyElement(equals(['an answer'])),
      );
    });

    test('the Leader, a Discipler too, reads every answer', () async {
      final rows = await content(
        g.leader.user.client,
        1,
        forId: p.disciple.membershipId,
      );
      expect(tiers(rows), {'DISCIPLE', 'DISCIPLER'});
      expect(hasAnswers(rows), isTrue);
    });

    test('a block needs exactly one answer per blank', () async {
      await expectLater(
        publish(faithful(pointAnswers: ['only one'])),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
