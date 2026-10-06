// Writes a lesson's hints file from its banners file and the source PDF.
//
//   dart run tool/curriculum/suggest_hints.dart 2
//
// Input: supabase/curriculum/full/lesson-NN.banners.json, the text of the
// lesson's image-only banners, transcribed from the extracted images:
//   { "firstPage": 2,
//     "sections": [ { "label": "A", "title": "...", "objective": "..." } ],
//     "assignments": "Assignments for Lesson Two",
//     "modules": [ { "page": 14, "number": 1, "subtitle": "..." } ] }
// Output: lesson-NN.hints.json. Everything else is derived, the same way for
// every lesson:
//   - the book's standard page banners, placed by the text they head;
//   - callouts: lines the text layer gives at the end of a page but the
//     printed page shows higher up (pdftotext -layout), placed before the
//     line they visually precede;
//   - the review page's reading order (its text layer lists the sign-off
//     and the online-resources paragraph out of place);
//   - assignment and module pages, and a figure for an assignment chart.
import 'dart:convert';
import 'dart:io';

import 'convert_lesson.dart'
    show fullDir, hintsPath, readLayout, readTextLayer, sourcePdf;
import 'lesson_source.dart';

String bannersPath(int n) =>
    '$fullDir/lesson-${n.toString().padLeft(2, '0')}.banners.json';

const _reflectSubtitle =
    'Take a moment to understand and learn so that you can share it.';

/// A line reduced for matching between the raw and layout text layers:
/// any token with a blank (with or without answer letters) becomes "_".
String key(String line) {
  final tokens = [
    for (final t in line.trim().split(RegExp(r'\s+')))
      if (t.isNotEmpty) t.contains('_') ? '_' : t,
  ];
  return tokens.join(' ');
}

String _prefix(String s) => s.length > 30 ? s.substring(0, 30) : s;

/// Whether a line can be a callout: a short pull-quote line.
bool _calloutLike(String l) =>
    !isBlankOnly(l) && l.length <= 60 && !l.startsWith('•');

Future<List<String>> layoutPage(int n, int page) async {
  final r = await Process.run('pdftotext', [
    '-layout',
    '-enc',
    'UTF-8',
    '-f',
    '$page',
    '-l',
    '$page',
    sourcePdf(n),
    '-',
  ], stdoutEncoding: utf8);
  return [
    for (final l in (r.stdout as String).split(RegExp(r'\r?\n')))
      if (l.trim().isNotEmpty) key(l.replaceAll(RegExp(r' {2,}'), ' ')),
  ];
}

Future<void> main(List<String> args) async {
  final n = int.parse(args.single);
  final banners = (jsonDecode(File(bannersPath(n)).readAsStringSync()) as Map)
      .cast<String, dynamic>();
  final firstPage = banners['firstPage'] as int? ?? 2;
  final pages = [
    for (final p in splitPages(
      await readTextLayer(n),
      layout: await readLayout(n),
    ))
      if (p.number >= firstPage) p,
  ];

  final inserts = <Map<String, dynamic>>[];
  final callouts = <Map<String, dynamic>>[];
  final moves = <Map<String, dynamic>>[];
  final notes = <String>[];

  Map<String, dynamic> heading(String title, [String? subtitle]) => {
    'type': 'HEADING',
    'source': 'image',
    'body': {'title': title, 'subtitle': ?subtitle},
  };

  String? lineOn(SourcePage p, String start) {
    for (final l in p.body) {
      if (l.startsWith(start)) return l;
    }
    return null;
  }

  // Sections: their banner on the first page of the section.
  for (final s in (banners['sections'] as List).cast<Map<String, dynamic>>()) {
    final label = s['label'] as String;
    final page =
        s['page'] as int? ?? pages.firstWhere((p) => p.section == label).number;
    inserts.add({
      'page': page,
      'block': {
        'type': 'SECTION_HEADING',
        'section': label,
        'source': 'image',
        'body': {'title': s['title']},
      },
    });
    if (s['objective'] != null) {
      inserts.add({
        'page': page,
        'block': {
          'type': 'KEY_OBJECTIVE',
          'section': label,
          'source': 'image',
          'body': {'text': s['objective']},
        },
      });
    }
  }

  final modules = (banners['modules'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
  final moduleStart = modules.isEmpty
      ? null
      : modules.map((m) => m['page'] as int).reduce((a, b) => a < b ? a : b);
  final assignmentPages = <int>[];
  final reviewPage = pages
      .where((p) => p.body.any((l) => l.startsWith('Question Struggling')))
      .firstOrNull
      ?.number;

  for (final p in pages) {
    // The book's standard page banners, by the text they head.
    const anchored = [
      (
        'What are the main points of this section?',
        'Reflect & Transfer',
        _reflectSubtitle,
      ),
      (
        'Your Discipler will now take a thorough look',
        'Daily in the Word',
        'Reading, Writing, Saying and Studying the Bible.',
      ),
      ('If you have a smart phone', 'Online Resources', 'TheJourneyForum.com'),
      ('Question Struggling', 'Reflect & Review', _reflectSubtitle),
    ];
    for (final (start, title, subtitle) in anchored) {
      if (lineOn(p, start) != null) {
        inserts.add({
          'page': p.number,
          'before': start,
          'block': heading(title, subtitle),
        });
      }
    }

    // The review page lists two parts out of reading order.
    final smart = p.body.indexWhere(
      (l) => l.startsWith('If you have a smart phone'),
    );
    final table = p.body.indexWhere((l) => l.startsWith('Question Struggling'));
    if (smart > table && table >= 0) {
      var count = 1;
      while (smart + count < p.body.length &&
          !p.body[smart + count].startsWith('Have any assignments')) {
        count++;
      }
      moves.add({
        'page': p.number,
        'from': 'If you have a smart phone',
        'count': count,
        'before': 'Question Struggling',
      });
    }
    final sign = p.body.indexWhere((l) => l.startsWith('Date completed'));
    final explain = p.body.indexWhere(
      (l) => l.startsWith('If yes, please explain'),
    );
    if (sign >= 0 && explain > sign) {
      moves.add({
        'page': p.number,
        'from': 'Date completed',
        'count': 1,
        'after': 'If yes, please explain:',
      });
    }

    // Assignment pages run from the first numbered assignment to the
    // modules.
    // A numbered list in the teaching is not the assignments: they come at
    // or after the review page.
    final numbered =
        (reviewPage == null || p.number >= reviewPage) &&
        p.body.any((l) => RegExp(r'^1\.\s').hasMatch(l));
    if (numbered ||
        (assignmentPages.isNotEmpty &&
            (moduleStart == null || p.number < moduleStart))) {
      if (assignmentPages.isEmpty && banners['assignments'] != null) {
        inserts.add({
          'page': p.number,
          'block': heading(banners['assignments'] as String),
        });
      }
      assignmentPages.add(p.number);
      // A chart to label: blank-only lines outside verse writing.
      final hasBlankLines = p.body.any(isBlankOnly);
      final verse = p.body.any(
        (l) =>
            (l.startsWith('Write ') && l.contains('in the space below')) ||
            RegExp(r"^Let[’']s practice on ").hasMatch(l),
      );
      if (hasBlankLines && !verse) {
        final chart = p.body.lastWhere(
          (l) =>
              RegExp(r'^\d+\.\s').hasMatch(l) &&
              RegExp(r'chart|label|draw', caseSensitive: false).hasMatch(l),
          orElse: () => '',
        );
        if (chart.isEmpty) {
          notes.add('page ${p.number}: blank lines but no chart assignment');
        } else {
          inserts.add({
            'page': p.number,
            'after': chart,
            'block': {
              'type': 'FIGURE',
              'body': {'caption': ''},
            },
          });
        }
      }
    }

    // Callouts: trailing lines that the printed page shows higher up.
    final layout = await layoutPage(n, p.number);
    int at(String l) {
      final k = key(l);
      final exact = layout.indexOf(k);
      if (exact >= 0) return exact;
      return layout.indexWhere((x) => _prefix(x) == _prefix(k));
    }

    final positions = [for (final l in p.body) at(l)];
    var end = p.body.length;
    var i = end - 1;
    while (i > 0) {
      final before = [for (var j = 0; j < i; j++) positions[j]]
          .where((x) => x >= 0);
      final maxBefore = before.isEmpty
          ? -1
          : before.reduce((a, b) => a > b ? a : b);
      if (positions[i] >= 0 &&
          positions[i] < maxBefore &&
          _calloutLike(p.body[i]) &&
          p.body.length - i <= 3) {
        i--;
      } else {
        break;
      }
    }
    // The review page has no callouts; its order is fixed by moves above.
    if (i + 1 < end && table < 0) {
      final lines = p.body.sublist(i + 1, end);
      final pos = positions[i + 1];
      String? anchor;
      for (var j = 0; j <= i; j++) {
        if (positions[j] > pos) {
          anchor = p.body[j];
          break;
        }
      }
      callouts.add({
        'page': p.number,
        'before': ?anchor?.substring(
          0,
          anchor.length < 40 ? anchor.length : 40,
        ),
        'lines': lines,
      });
    }

    // The video note of a module page, given among the answers.
    final tail = p.answers;
    final arrow = tail.indexWhere(
      (l) => l.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim() == '<<<',
    );
    if (arrow >= 0) {
      final lines = <String>['<<<'];
      var k = arrow + 1;
      while (k < tail.length) {
        lines.add(tail[k]);
        if (tail[k].trim().endsWith('.')) break;
        k++;
      }
      final first = p.body.isEmpty ? null : p.body.first;
      callouts.add({'page': p.number, 'after': ?first, 'lines': lines});
    }
  }

  for (final m in modules) {
    inserts.add({
      'page': m['page'],
      'before': ?m['before'],
      'block': {
        'type': 'MODULE_HEADING',
        'tier': 'DISCIPLER',
        'source': 'image',
        'body': {
          'number': m['number'],
          'title': 'Module ${m['number']}',
          'subtitle': ?m['subtitle'],
        },
      },
    });
  }

  // Lesson-specific extras (a figure within the text, say), as given.
  inserts.addAll([
    for (final i in (banners['inserts'] as List? ?? const []))
      (i as Map).cast<String, dynamic>(),
  ]);

  final hints = {
    '_about':
        'Generated by tool/curriculum/suggest_hints.dart from lesson-${n.toString().padLeft(2, '0')}.banners.json.',
    'firstPage': firstPage,
    'disciplerFromPage': ?moduleStart,
    'assignmentPages': assignmentPages,
    'inserts': inserts,
    'callouts': callouts,
    'moves': moves,
    'breakBefore': banners['breakBefore'] ?? const [],
    'answerSplits': banners['answerSplits'] ?? const {},
  };
  File(hintsPath(n))
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(hints));
  stdout.writeln(
    'Lesson $n hints: ${inserts.length} inserts, ${callouts.length} callouts, ${moves.length} moves, assignment pages $assignmentPages, modules from ${moduleStart ?? '-'}',
  );
  for (final note in notes) {
    stderr.writeln('NOTE $note');
  }
}
