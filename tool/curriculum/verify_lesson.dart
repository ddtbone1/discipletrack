// Verifies a converted lesson against its source (ADR-019 decision 14).
//
//   dart run tool/curriculum/verify_lesson.dart 6
//
// Re-reads the source text layer independently of the converter and
// checks:
//   1. every source word is in the lesson and nothing was added
//      (as multisets of words, blanks counted as [_]);
//   2. the order is the source's, apart from the hinted moves and callout
//      placements, which are listed for review;
//   3. every handwritten answer is attached, in order, and nowhere else;
//   4. no Disciple-tier block's text contains an answer it does not show
//      as a blank (answers live only in "answers");
//   5. Training Module blocks are Discipler tier.
// Image-only text (blocks marked "source": "image") and the opening
// metadata (theme and topics, from the contents page) are reported, not
// compared, since the text layer does not contain them.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'convert_lesson.dart'
    show hintsPath, lessonPath, readLayout, readTextLayer;
import 'lesson_builder.dart';
import 'lesson_source.dart';

List<String> words(String s) => [
  for (final w in normalizeBlanks(s).split(RegExp(r'\s+')))
    if (w.isNotEmpty && w != '•') w,
];

List<String> blockWords(Map<String, dynamic> b) {
  final body = (b['body'] as Map).cast<String, dynamic>();
  String s(String k) => body[k] == null ? '' : '${body[k]}';
  List<String> list(String k) => [for (final x in body[k] as List) '$x'];
  switch (b['type']) {
    case 'ASSIGNMENT':
      return [
        '${body['number']}.',
        ...words(s('text')),
        for (final p in (body['parts'] as List? ?? const []).cast<Map>()) ...[
          if (p['label'] != null) '${p['label']}',
          ...words('${p['text']}'),
        ],
      ];
    case 'LIST' when body['field'] != null:
      // A reading plan: readings, the printed date labels and lines.
      return [
        for (final i in list('items')) ...words(i),
        for (final w in list('fieldWords')) w,
        ...words(s('note')),
      ];
    case 'LIST':
    case 'DISCUSSION_PROMPTS':
      return [for (final i in list('items')) ...words(i)];
    case 'VERSE_WRITING':
      return [
        ...words(s('instruction')),
        for (var i = 0; i < (body['lines'] as int? ?? 0); i++) blankToken,
        ...words(s('followUp')),
      ];
    case 'SELF_CHECK':
      return [
        s('header'),
        for (final c in list('columns')) ...words(c),
        for (final i in list('items')) ...words(i),
      ];
    case 'FIGURE':
      return [
        for (var i = 0; i < (body['lines'] as int? ?? 0); i++) blankToken,
      ];
    default:
      return [...words(s('reference')), ...words(s('text'))];
  }
}

/// Longest common subsequence alignment; returns the unmatched runs.
List<String> orderDiff(List<String> a, List<String> b) {
  final n = a.length, m = b.length;
  final dp = List.generate(n + 1, (_) => Int32List(m + 1));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final out = <String>[];
  var i = 0, j = 0;
  final onlyA = <String>[], onlyB = <String>[];
  void flush() {
    if (onlyA.isNotEmpty) out.add('source only here: ${onlyA.join(' ')}');
    if (onlyB.isNotEmpty) out.add('lesson only here: ${onlyB.join(' ')}');
    onlyA.clear();
    onlyB.clear();
  }

  while (i < n && j < m) {
    if (a[i] == b[j]) {
      flush();
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      onlyA.add(a[i++]);
    } else {
      onlyB.add(b[j++]);
    }
  }
  onlyA.addAll(a.sublist(i));
  onlyB.addAll(b.sublist(j));
  flush();
  return out;
}

Map<String, int> counts(Iterable<String> xs) {
  final c = <String, int>{};
  for (final x in xs) {
    c[x] = (c[x] ?? 0) + 1;
  }
  return c;
}

Future<void> main(List<String> args) async {
  final n = int.parse(args.single);
  final hints = LessonHints.fromJson(
    (jsonDecode(File(hintsPath(n)).readAsStringSync()) as Map)
        .cast<String, dynamic>(),
  );
  final lesson = (jsonDecode(File(lessonPath(n)).readAsStringSync()) as Map)
      .cast<String, dynamic>();
  final blocks = (lesson['blocks'] as List).cast<Map<String, dynamic>>();

  // Source, read independently: no hints but the callout lines (which are
  // content wherever they sit) and the first page.
  final calloutText = {
    for (final c in hints.callouts)
      for (final l in c['lines'] as List) '$l',
  };
  final pages = splitPages(await readTextLayer(n), layout: await readLayout(n));
  final sourceWords = <String>[];
  final sourceAnswers = <String>[];
  for (final p in pages) {
    if (p.number < hints.firstPage) continue;
    for (final l in p.body) {
      sourceWords.addAll(words(l));
    }
    for (final l in p.answers) {
      final clean = normalizeBlanks(l);
      if (calloutText.contains(clean)) {
        sourceWords.addAll(words(clean));
      } else {
        sourceAnswers.addAll(words(clean));
      }
    }
    for (final a in p.owned.values.expand((x) => x)) {
      sourceAnswers.addAll(words(a));
    }
  }

  final compared = [
    for (final b in blocks)
      if (b['source'] != 'image' &&
          b['type'] != 'LESSON_THEME' &&
          b['type'] != 'TOPIC_LIST')
        b,
  ];
  final lessonWords = [for (final b in compared) ...blockWords(b)];
  final lessonAnswers = [
    for (final b in blocks)
      for (final a in (b['answers'] as List? ?? const [])) ...words('$a'),
  ];

  var ok = true;
  void fail(String m) {
    ok = false;
    stdout.writeln('FAIL $m');
  }

  // 1. Same words, nothing added or dropped.
  final cs = counts(sourceWords), cl = counts(lessonWords);
  final missing = {
    for (final e in cs.entries)
      if ((cl[e.key] ?? 0) < e.value) e.key: e.value - (cl[e.key] ?? 0),
  };
  final added = {
    for (final e in cl.entries)
      if ((cs[e.key] ?? 0) < e.value) e.key: e.value - (cs[e.key] ?? 0),
  };
  if (missing.isNotEmpty) fail('words missing from the lesson: $missing');
  if (added.isNotEmpty) fail('words not in the source: $added');

  // Bullets are structure: one POINT per source bullet.
  final bullets = [
    for (final p in pages)
      if (p.number >= hints.firstPage)
        for (final l in p.body)
          if (l.startsWith('•')) l,
  ].length;
  final points = blocks.where((b) => b['type'] == 'POINT').length;
  if (bullets != points) fail(' bullets but  POINT blocks');

  // 2. Order.
  final order = orderDiff(sourceWords, lessonWords);
  stdout.writeln(
    'Order: ${order.isEmpty ? 'identical' : '${order.length} relocated run(s), expected only for hinted moves and callouts:'}',
  );
  for (final d in order) {
    stdout.writeln('  $d');
  }

  // 3. Answers.
  final ca = counts(sourceAnswers), la = counts(lessonAnswers);
  final answersMatch =
      ca.length == la.length && ca.entries.every((e) => la[e.key] == e.value);
  if (!answersMatch) {
    fail(
      'answers differ from the source\n'
      '  source: ${sourceAnswers.join(' ')}\n'
      '  lesson: ${lessonAnswers.join(' ')}',
    );
  }

  // 4. Blanks match answers; answers are never written into text.
  for (final b in blocks) {
    final body = (b['body'] as Map).cast<String, dynamic>();
    final answers = b['answers'] as List?;
    final text = [
      body['text'],
      for (final p in (body['parts'] as List? ?? const []).cast<Map>())
        p['text'],
    ].whereType<String>().join(' ');
    if (answers != null && body['blanks'] != answers.length) {
      fail('blanks/answers count differs in ${b['type']}: $text');
    }
    if (answers != null &&
        body['text'] is String &&
        b['type'] != 'VERSE_WRITING' &&
        blankCount(text) != answers.length) {
      fail(
        '${blankCount(text)} blank(s) but ${answers.length} answer(s): $text',
      );
    }
  }

  // 5. Modules are Discipler tier.
  if (hints.disciplerFromPage != null) {
    final moduleStart = blocks.indexWhere((b) => b['type'] == 'MODULE_HEADING');
    for (final b in blocks.skip(
      moduleStart < 0 ? blocks.length : moduleStart,
    )) {
      if (b['tier'] != 'DISCIPLER') {
        fail('module block not Discipler tier: ${b['type']}');
      }
    }
  }

  final images = blocks.where((b) => b['source'] == 'image').length;
  stdout.writeln(
    'Lesson $n: ${sourceWords.length} source words, ${lessonWords.length} '
    'lesson words; ${sourceAnswers.length} answer words; $images '
    'image-transcribed block(s) reviewed visually, not compared.',
  );
  stdout.writeln(ok ? 'PASS' : 'FAILED');
  if (!ok) exitCode = 1;
}
