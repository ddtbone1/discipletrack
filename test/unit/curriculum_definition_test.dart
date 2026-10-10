import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/curriculum_seed.dart';

/// The committed curriculum definition stays within ADR-019 decision 2,
/// and the generated seed matches it.
void main() {
  final json = File(curriculumDefinitionPath).readAsStringSync();
  final definition = jsonDecode(json) as Map<String, dynamic>;
  final lessons = (definition['lessons'] as List).cast<Map<String, dynamic>>();

  const metadataTypes = {
    'LESSON_THEME',
    'TOPIC_LIST',
    'SECTION_HEADING',
    'SCRIPTURE_REFERENCES',
    'MODULE_HEADING',
  };

  test('ten lessons, numbered in order, with titles', () {
    expect(lessons, hasLength(10));
    for (var i = 0; i < lessons.length; i++) {
      expect(lessons[i]['number'], i + 1);
      expect((lessons[i]['title'] as String).trim(), isNotEmpty);
    }
  });

  test('cover titles are canonical; contents wording is the theme', () {
    String theme(int n) =>
        ((lessons[n - 1]['blocks'] as List).firstWhere(
                  (b) => b['type'] == 'LESSON_THEME',
                )['body']
                as Map)['text']
            as String;
    expect(lessons[6]['title'], 'Spiritual Formation');
    expect(theme(7), 'Spiritual Growth');
    expect(lessons[8]['title'], 'Conversation');
    expect(theme(9), 'Words');
  });

  test('identifying metadata only: no substantive block, no answers', () {
    for (final lesson in lessons) {
      for (final block in (lesson['blocks'] as List).cast<Map>()) {
        expect(metadataTypes, contains(block['type']), reason: '$block');
        expect(block.containsKey('answers'), isFalse);
        expect(['DISCIPLE', 'DISCIPLER'], contains(block['tier']));
        if (block['type'] == 'MODULE_HEADING') {
          expect(block['tier'], 'DISCIPLER');
        }
      }
    }
  });

  test('Training Modules 1 to 7 sit in Lessons 5 to 9', () {
    final modules = <int, int>{
      for (final lesson in lessons)
        for (final b in (lesson['blocks'] as List).cast<Map>())
          if (b['type'] == 'MODULE_HEADING')
            (b['body'] as Map)['number'] as int: lesson['number'] as int,
    };
    expect(modules, {1: 5, 2: 6, 3: 7, 4: 7, 5: 8, 6: 8, 7: 9});
  });

  // Compared with LF line endings: a Windows checkout (core.autocrlf) holds
  // the committed LF file as CRLF. Any other difference still fails.
  test('the generated seed matches the definition', () {
    expect(
      normalizeLineEndings(File(curriculumSeedPath).readAsStringSync()),
      curriculumSeedSql(json),
      reason: 'run: dart run tool/generate_curriculum_seed.dart',
    );
  });
}
