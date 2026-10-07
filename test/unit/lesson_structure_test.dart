// The answer each question asks for, decided from the book's own wording
// (tool/curriculum/lesson_structure.dart). Synthetic text, no source.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/curriculum/lesson_structure.dart';

Map<String, dynamic> _block(String type, Map<String, dynamic> body) => {
  'type': type,
  'tier': 'DISCIPLE',
  'body': body,
};

void main() {
  group('respondKind', () {
    test('questions and written tasks ask for a written answer', () {
      expect(respondKind('Why should you pray?'), 'write');
      expect(respondKind('Explain what the verse teaches.'), 'write');
      expect(respondKind('Write a verse about the Bible.'), 'write');
      expect(
        respondKind('Read Acts 19:10 and explain how it happened.'),
        'write',
      );
    });

    test('True or False, tasks and instructions', () {
      expect(respondKind('(True or False) Baptism saves.'), 'truefalse');
      expect(respondKind('Read the verses below.'), 'task');
      expect(respondKind('Memorize the steps.'), 'task');
      expect(respondKind('Write your answers to all the scenarios.'), 'task');
      expect(
        respondKind('Answer the questions for Lesson 3 below on paper:'),
        isNull,
      );
      expect(respondKind('A disciple is in the Word every day.'), isNull);
    });
  });

  group('structureLesson', () {
    test('an assignment takes the lines under it, with lettered questions '
        'as parts', () {
      final blocks = [
        _block('ASSIGNMENT', {'number': 4, 'text': ''}),
        _block('LIST', {
          'items': [
            'Answer the questions for Lesson 3 below on a separate piece',
            'of paper:',
            'A.',
            'What do we know about God?',
            'B. Why should you pray?',
          ],
        }),
      ];
      structureLesson(blocks);

      expect(blocks, hasLength(1));
      final body = blocks.single['body'] as Map;
      expect(
        body['text'],
        'Answer the questions for Lesson 3 below on a separate piece of paper:',
      );
      expect(body['respond'], isNull);
      expect(body['parts'], [
        {
          'label': 'A.',
          'text': 'What do we know about God?',
          'respond': 'write',
        },
        {'label': 'B.', 'text': 'Why should you pray?', 'respond': 'write'},
      ]);
    });

    test('lettered statements under "Which ...?" are choices', () {
      final blocks = [
        _block('ASSIGNMENT', {'number': 1, 'text': 'Which statement is true?'}),
        _block('LIST', {
          'items': ['a. First', 'b. Second'],
        }),
      ];
      structureLesson(blocks);
      final body = blocks.single['body'] as Map;
      expect(body['respond'], 'choice');
      expect(
        [for (final p in body['parts'] as List) p['respond']],
        [null, null],
      );
    });

    test('labels printed on one line split into parts, commas kept', () {
      final blocks = [
        _block('ASSIGNMENT', {
          'number': 8,
          'text': 'Look up the verses and jot down what He does:',
        }),
        _block('LIST', {
          'items': ['a. John 14:26, b. Acts 13:2.'],
        }),
      ];
      structureLesson(blocks);
      final parts = (blocks.single['body'] as Map)['parts'] as List;
      expect([for (final p in parts) p['text']], ['John 14:26,', 'Acts 13:2.']);
      expect([for (final p in parts) p['respond']], ['write', 'write']);
    });

    test('answers of the merged lines stay in reading order', () {
      final blocks = [
        {
          ..._block('ASSIGNMENT', {'number': 1, 'text': 'One [_] here'}),
          'answers': ['a'],
        },
        {
          ..._block('LIST', {
            'items': ['and [_] there.'],
          }),
          'answers': ['b'],
        },
      ];
      structureLesson(blocks);
      expect(blocks.single['answers'], ['a', 'b']);
    });

    test('a reading plan becomes one row per reading, in reading order', () {
      final blocks = [
        _block('PARAGRAPH', {
          'text':
              'Date Date Mark 1:1-4 Mark 3:1-2 Mark 1:5-8 Mark 3:3-4 '
              'Mark 2:1-3 Mark 4:1 Mark 2:4-5 Mark 4:2 Mark 2:6 Mark 4:3 '
              'See a note',
        }),
      ];
      structureLesson(blocks);
      final body = blocks.single['body'] as Map;
      expect(blocks.single['type'], 'LIST');
      expect(body['field'], 'Date');
      expect((body['items'] as List).take(4), [
        'Mark 1:1-4',
        'Mark 1:5-8',
        'Mark 2:1-3',
        'Mark 2:4-5',
      ]);
      expect(body['fieldWords'], ['Date', 'Date']);
      expect(body['note'], 'See a note');
    });
  });
}
