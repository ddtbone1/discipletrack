import 'package:discipletrack/features/curriculum/domain/lesson_content.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(
  String id,
  int ordinal,
  String type, {
  String tier = 'DISCIPLE',
  String? section,
  Map<String, dynamic> body = const {},
  List<dynamic>? answers,
}) => {
  'block_id': id,
  'lesson_id': 'l1',
  'ordinal': ordinal,
  'section_label': section,
  'block_type': type,
  'tier': tier,
  'body': body,
  'answers': answers,
};

void main() {
  group('ContentBlock', () {
    test('parses a database row', () {
      final b = ContentBlock.fromMap(
        _row(
          'b1',
          3,
          'SCRIPTURE_REFERENCES',
          section: 'A',
          body: {
            'refs': ['John 3:16'],
          },
        ),
      );
      expect(b.type, BlockType.scriptureReferences);
      expect(b.tier, ContentTier.disciple);
      expect(b.sectionLabel, 'A');
      expect(b.refs, ['John 3:16']);
      expect(b.answers, isNull);
    });

    test('an unknown block type becomes unknown instead of failing', () {
      final b = ContentBlock.fromMap(_row('b1', 1, 'SOMETHING_NEW'));
      expect(b.type, BlockType.unknown);
    });

    test('an unknown tier is rejected: tiers are never guessed', () {
      expect(
        () => ContentBlock.fromMap(_row('b1', 1, 'PARAGRAPH', tier: 'X')),
        throwsArgumentError,
      );
    });

    test('lesson id falls back to the one asked for', () {
      final row = _row('b1', 1, 'PARAGRAPH')..remove('lesson_id');
      expect(ContentBlock.fromMap(row, lessonId: 'l9').lessonId, 'l9');
    });
  });

  group('LessonContent', () {
    final lesson = LessonContent(
      lessonId: 'l1',
      blocks: [
        for (final r in [
          _row('t', 1, 'LESSON_THEME', body: {'text': 'Salvation'}),
          _row(
            'tl',
            2,
            'TOPIC_LIST',
            body: {
              'items': ['One', 'Two'],
            },
          ),
          _row('ha', 3, 'SECTION_HEADING', section: 'A', body: {}),
          _row(
            'ra',
            4,
            'SCRIPTURE_REFERENCES',
            section: 'A',
            body: {
              'refs': ['Genesis 1:1'],
            },
          ),
          _row(
            'hb',
            5,
            'SECTION_HEADING',
            section: 'B',
            body: {'title': 'Second'},
          ),
          _row(
            'm',
            6,
            'MODULE_HEADING',
            tier: 'DISCIPLER',
            body: {'number': 1, 'title': 'Module'},
          ),
          _row('x', 7, 'SOMETHING_NEW', tier: 'DISCIPLER'),
        ])
          ContentBlock.fromMap(r),
      ],
    );

    test('theme and topics', () {
      expect(lesson.theme, 'Salvation');
      expect(lesson.topics, ['One', 'Two']);
    });

    test('sections keep publication order; untitled ones have no title', () {
      final s = lesson.sections;
      expect(s.map((e) => e.label), ['A', 'B']);
      expect(s[0].title, isNull);
      expect(s[0].scriptureRefs, ['Genesis 1:1']);
      expect(s[1].title, 'Second');
    });

    test('Discipler blocks exclude unknown types', () {
      expect(lesson.disciplerBlocks.map((b) => b.blockId), ['m']);
      expect(lesson.hasDisciplerTier, isTrue);
    });

    test('a Disciple-tier read has no Discipler group', () {
      final disciple = LessonContent(
        lessonId: 'l1',
        blocks: [
          for (final b in lesson.blocks)
            if (b.tier == ContentTier.disciple) b,
        ],
      );
      expect(disciple.hasDisciplerTier, isFalse);
    });
  });

  group('ReadableContent', () {
    final copy = ReadableContent(
      userId: 'u1',
      savedAt: DateTime.utc(2026, 10, 6, 8),
      lessons: const [
        LessonAccess(
          lessonId: 'l1',
          number: 1,
          title: 'Salvation',
          theme: 'Salvation',
          discipleTier: true,
          disciplerTier: false,
        ),
      ],
      blocks: [
        ContentBlock.fromMap(_row('b2', 2, 'PARAGRAPH', body: {'text': 'x'})),
        ContentBlock.fromMap(
          _row('b1', 1, 'LESSON_THEME', body: {'text': 't'}),
        ),
      ],
    );

    test('survives a JSON round trip', () {
      final back = ReadableContent.fromJson(copy.toJson())!;
      expect(back.userId, 'u1');
      expect(back.savedAt, copy.savedAt);
      expect(back.lessons, copy.lessons);
      expect(back.blocks.map((b) => b.blockId), ['b2', 'b1']);
    });

    test('a lesson is served in ordinal order; unsynced lessons are null', () {
      expect(copy.lesson('l1')!.blocks.map((b) => b.blockId), ['b1', 'b2']);
      expect(copy.lesson('l2'), isNull);
    });

    test('a copy of another version or a damaged copy is ignored', () {
      expect(
        ReadableContent.fromJson({...copy.toJson(), 'version': 99}),
        isNull,
      );
      expect(ReadableContent.fromJson({'version': 1}), isNull);
    });
  });
}
