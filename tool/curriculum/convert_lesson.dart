// Converts one lesson of the source PDFs into its canonical block sequence
// (ADR-019 decisions 12 to 14).
//
//   dart run tool/curriculum/convert_lesson.dart 6
//
// Reads docs/curriculum/source/ (git-ignored) with pdftotext and the
// lesson's hints from supabase/curriculum/full/lesson-NN.hints.json, and
// writes supabase/curriculum/full/lesson-NN.json. Prints
// every warning and exits non-zero if there is one: a lesson is accepted
// only when it converts cleanly and tool/curriculum/verify_lesson.dart
// passes.
import 'dart:convert';
import 'dart:io';

import 'lesson_builder.dart';
import 'lesson_source.dart';

const fullDir = 'supabase/curriculum/full';
const metadataPath = 'supabase/curriculum/journey-metadata.json';

String sourcePdf(int n) => n == 1
    ? 'docs/curriculum/source/Journey - Lesson 1 with How to.pdf'
    : 'docs/curriculum/source/Journey - Lesson $n.pdf';

String lessonPath(int n) =>
    '$fullDir/lesson-${n.toString().padLeft(2, '0')}.json';
String hintsPath(int n) =>
    '$fullDir/lesson-${n.toString().padLeft(2, '0')}.hints.json';

/// The printed layout of each page (pdftotext -layout), for telling
/// answers from lesson lines.
Future<List<String>> readLayout(int n) async {
  final result = await Process.run('pdftotext', [
    '-layout',
    '-enc',
    'UTF-8',
    sourcePdf(n),
    '-',
  ], stdoutEncoding: utf8);
  if (result.exitCode != 0) {
    throw StateError('pdftotext failed: ${result.stderr}');
  }
  return (result.stdout as String).split('\f');
}

Future<String> readTextLayer(int n) async {
  final result = await Process.run('pdftotext', [
    '-raw',
    '-enc',
    'UTF-8',
    sourcePdf(n),
    '-',
  ], stdoutEncoding: utf8);
  if (result.exitCode != 0) {
    throw StateError('pdftotext failed: ${result.stderr}');
  }
  return result.stdout as String;
}

Future<void> main(List<String> args) async {
  final n = int.parse(args.single);
  final hints = LessonHints.fromJson(
    (jsonDecode(File(hintsPath(n)).readAsStringSync()) as Map)
        .cast<String, dynamic>(),
  );
  final pages = splitPages(
    await readTextLayer(n),
    calloutLines: hints.calloutLines,
    layout: await readLayout(n),
  );
  final result = buildLesson(pages, hints);

  final metadata = (jsonDecode(File(metadataPath).readAsStringSync()) as Map)
      .cast<String, dynamic>();
  final meta = (metadata['lessons'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((l) => l['number'] == n);

  // The lesson opens with its identifying metadata (theme and topics,
  // from the book's contents page), then the converted lesson.
  final opening = [
    for (final b in (meta['blocks'] as List).cast<Map<String, dynamic>>())
      if (b['type'] == 'LESSON_THEME' || b['type'] == 'TOPIC_LIST') b,
  ];
  final lesson = {
    'number': n,
    'title': meta['title'],
    'blocks': [...opening, ...result.blocks],
  };
  File(lessonPath(n))
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lesson));

  stdout.writeln(
    'Lesson $n: ${result.blocks.length} blocks, '
    '${result.blocks.where((b) => b['answers'] != null).length} with answers '
    '-> ${lessonPath(n)}',
  );
  for (final u in result.unanswered) {
    stdout.writeln('  unanswered in the source: $u');
  }
  for (final w in result.warnings) {
    stderr.writeln('WARNING $w');
  }
  if (result.warnings.isNotEmpty) exitCode = 1;
}
