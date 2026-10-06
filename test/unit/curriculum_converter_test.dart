// The lesson converter (tool/curriculum/), on a made-up text layer shaped
// like the source's: the real lesson text never enters the repository
// (ADR-019 decision 15).
import 'package:flutter_test/flutter_test.dart';

import '../../tool/curriculum/lesson_builder.dart';
import '../../tool/curriculum/lesson_source.dart';

const _layer =
    'cover art only\f'
    'An opening paragraph that is long enough to wrap onto the next line of\n'
    'the page and then ends here.\n'
    '• Genesis 1:1\n'
    'In the beginning God created the ____________.\n'
    '• Read John 3:16 and believe.\n'
    'A callout line\n'
    'SECTION A\n'
    'Lesson 9 page 2\n'
    'heavens\n'
    'For more resources visit www.TheJourneyForum.com\f'
    'Write John 11:35 in the space below - going down a line.\n'
    '______________________________\n'
    '______________________________\n'
    'How would you explain that verse?\n'
    'Date completed : ____________ Discipler signature: ________\n'
    'Lesson 9 page 3\n'
    'Jesus wept.\f'
    '• A module point about ____________ and ______________.\n'
    'Lesson 9 page 4\n'
    'one two\n';

void main() {
  final hints = LessonHints.fromJson({
    'firstPage': 2,
    'disciplerFromPage': 4,
    'callouts': [
      {
        'page': 2,
        'before': '• Read John',
        'lines': ['A callout line'],
      },
    ],
  });

  group('splitPages', () {
    final pages = splitPages(_layer, calloutLines: hints.calloutLines);

    test('drops the footer and the marker, and keeps answers apart', () {
      final p2 = pages.firstWhere((p) => p.number == 2);
      expect(p2.section, 'A');
      expect(p2.answers, ['heavens']);
      expect(p2.body, isNot(contains('A callout line')));
      expect(p2.body.any((l) => l.contains('TheJourneyForum')), isFalse);
    });
  });

  group('reading a line', () {
    test('a leading scripture reference is split from the text', () {
      expect(splitReference('1st John 3:8 Remember this.'), (
        reference: '1st John 3:8',
        text: 'Remember this.',
      ));
      expect(
        splitReference(
          'Romans 14:10, 1st Corinthians 3:13-15 and 2nd '
          'Corinthians 5:10',
        ).reference,
        'Romans 14:10, 1st Corinthians 3:13-15 and 2nd Corinthians 5:10',
      );
      expect(splitReference('Read John 14:2-3.').reference, isNull);
    });

    test('blanks become [_]; one answer line divides over its blanks', () {
      expect(normalizeBlanks('a ____ b ______.'), 'a [_] b [_].');
      expect(splitAnswer("God's Word", 2), ["God's", 'Word']);
      expect(splitAnswer('Anti-Christ', 1), ['Anti-Christ']);
      expect(splitAnswer('one two three', 2), isNull);
    });

    test('questions are split at question marks, words untouched', () {
      expect(splitQuestions('Who is in you? Who is greater?'), [
        'Who is in you?',
        'Who is greater?',
      ]);
    });
  });

  group('buildLesson', () {
    final result = buildLesson(
      splitPages(_layer, calloutLines: hints.calloutLines),
      hints,
    );
    final blocks = result.blocks;

    test('converts cleanly', () => expect(result.warnings, isEmpty));

    test('keeps the wording, joining wrapped lines only', () {
      expect(
        blocks.first['body']['text'],
        'An opening paragraph that is long enough to wrap onto the next line '
        'of the page and then ends here.',
      );
    });

    test('a point carries its reference, its blanks and their answers', () {
      final point = blocks.firstWhere(
        (b) => b['body']['reference'] == 'Genesis 1:1',
      );
      expect(point['body']['text'], 'In the beginning God created the [_].');
      expect(point['answers'], ['heavens']);
      expect(point['body']['blanks'], 1);
    });

    test('a callout is placed where the hints say', () {
      final i = blocks.indexWhere((b) => b['type'] == 'BANNER');
      expect(blocks[i + 1]['body']['text'], 'Read John 3:16 and believe.');
    });

    test('verse writing takes the page\'s remaining answers as its lines', () {
      final verse = blocks.firstWhere((b) => b['type'] == 'VERSE_WRITING');
      expect(verse['body']['reference'], 'John 11:35');
      expect(verse['body']['lines'], 2);
      expect(verse['body']['followUp'], 'How would you explain that verse?');
      expect(verse['answers'], ['Jesus wept.']);
    });

    test('a sign-off keeps its lines and takes no answers', () {
      final sign = blocks.firstWhere((b) => b['type'] == 'SIGN_OFF');
      expect(
        sign['body']['text'],
        'Date completed : [~] Discipler signature: [~]',
      );
      expect(sign['answers'], isNull);
    });

    test('module pages are Discipler tier', () {
      expect(blocks.last['tier'], 'DISCIPLER');
      expect(blocks.last['answers'], ['one', 'two']);
      expect(blocks.where((b) => b['tier'] == 'DISCIPLER'), hasLength(1));
    });
  });
}
