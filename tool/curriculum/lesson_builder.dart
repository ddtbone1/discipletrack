/// Builds a lesson's canonical block sequence from its source pages and
/// hints. See `lesson_source.dart` for how the text layer is read.
library;

import 'lesson_source.dart';

/// What the text layer cannot say, for one lesson. Every entry is a
/// placement or a transcription of image-only text, never a rewording.
class LessonHints {
  LessonHints.fromJson(Map<String, dynamic> json)
    : inserts = [
        for (final i in (json['inserts'] as List? ?? const []))
          (i as Map).cast<String, dynamic>(),
      ],
      callouts = [
        for (final c in (json['callouts'] as List? ?? const []))
          (c as Map).cast<String, dynamic>(),
      ],
      moves = [
        for (final m in (json['moves'] as List? ?? const []))
          (m as Map).cast<String, dynamic>(),
      ],
      breakBefore = [
        for (final b in (json['breakBefore'] as List? ?? const [])) '$b',
      ],
      assignmentPages = {
        for (final p in (json['assignmentPages'] as List? ?? const []))
          p as int,
      },
      disciplerFromPage = json['disciplerFromPage'] as int?,
      firstPage = json['firstPage'] as int? ?? 1,
      answerSplits = {
        for (final e in ((json['answerSplits'] as Map?) ?? const {}).entries)
          '${e.key}': [for (final a in e.value as List) '$a'],
      };

  /// Blocks the text layer lacks (image-only banners, the module heading,
  /// figures), each with "page" and an optional "before"/"after" anchor.
  final List<Map<String, dynamic>> inserts;

  /// Callout lines, with "page", "lines" and an optional anchor.
  final List<Map<String, dynamic>> callouts;

  /// Reading-order corrections: "page", "from", "count", "before"/"after".
  final List<Map<String, dynamic>> moves;

  /// Line starts that begin a new top-level paragraph after a bullet.
  final List<String> breakBefore;
  final Set<int> assignmentPages;
  final int? disciplerFromPage;

  /// Pages before this are not part of the lesson (Lesson 1's guide).
  final int firstPage;

  /// For an answered line whose words do not divide evenly over its
  /// blanks: the answer line, and its answers in blank order.
  final Map<String, List<String>> answerSplits;

  Map<int, Set<String>> get calloutLines {
    final out = <int, Set<String>>{};
    for (final c in callouts) {
      out.putIfAbsent(c['page'] as int, () => {}).addAll([
        for (final l in c['lines'] as List) '$l',
      ]);
    }
    return out;
  }
}

/// An item of the lesson stream: a source line, or a block from hints.
class _Item {
  _Item.line(this.page, this.text) : block = null;
  _Item.block(this.page, this.block) : text = null;

  final SourcePage page;
  final String? text;
  final Map<String, dynamic>? block;
}

class BuildResult {
  BuildResult(this.blocks, this.warnings, [this.unanswered = const []]);

  final List<Map<String, dynamic>> blocks;
  final List<String> warnings;

  /// Blank lines the Discipler's Copy leaves unanswered (reported, not
  /// errors: the book has them).
  final List<String> unanswered;
}

final _bullet = RegExp(r'^[••]\s*');
final _numbered = RegExp(r'^(\d+)\.\s+(.*)$');
final _reflectStart = RegExp(r'^What are the main points of this section\?');
final _waterCooler = RegExp(r'''^Here[’']s a [“"]water cooler[”"] scenario:''');
final _verseWriting = RegExp(
  r"^(?:Write (.+?) in the space below|Let[’']s practice on (.+?)$)",
);
const _explainVerse = 'How would you explain that verse?';

BuildResult buildLesson(List<SourcePage> pages, LessonHints hints) {
  final warnings = <String>[];
  final unanswered = <String>[];
  final items = <_Item>[];

  for (final page in pages) {
    if (page.number < hints.firstPage) continue;
    final lines = [...page.body];

    for (final m in hints.moves.where((m) => m['page'] == page.number)) {
      final from = lines.indexWhere((l) => l.startsWith('${m['from']}'));
      final count = m['count'] as int? ?? 1;
      if (from < 0) {
        warnings.add(
          'page ${page.number}: move source "${m['from']}" not found',
        );
        continue;
      }
      final moved = lines.sublist(from, from + count);
      lines.removeRange(from, from + count);
      final anchor = (m['before'] ?? m['after']) as String;
      var at = lines.indexWhere((l) => l.startsWith(anchor));
      if (at < 0) {
        warnings.add('page ${page.number}: move anchor "$anchor" not found');
        lines.insertAll(from, moved);
        continue;
      }
      if (m.containsKey('after')) at++;
      lines.insertAll(at, moved);
    }

    final pageItems = [for (final l in lines) _Item.line(page, l)];

    void place(
      Map<String, dynamic> block,
      Map<String, dynamic> hint, {
      required bool atEnd,
    }) {
      final item = _Item.block(page, block);
      final before = hint['before'] as String?;
      final after = hint['after'] as String?;
      if (before == null && after == null) {
        atEnd ? pageItems.add(item) : pageItems.insert(0, item);
        return;
      }
      final i = pageItems.indexWhere(
        (x) => x.text != null && x.text!.startsWith(before ?? after!),
      );
      if (i < 0) {
        warnings.add(
          'page ${page.number}: anchor "${before ?? after}" not found',
        );
        pageItems.add(item);
        return;
      }
      pageItems.insert(after != null ? i + 1 : i, item);
    }

    // Inserts go in hint order, each at its anchor or the page start;
    // the reversed loop keeps several unanchored inserts in hint order.
    final pageInserts = [
      for (final h in hints.inserts)
        if (h['page'] == page.number) h,
    ];
    for (final h in pageInserts.where(
      (h) => h['before'] != null || h['after'] != null,
    )) {
      place((h['block'] as Map).cast<String, dynamic>(), h, atEnd: false);
    }
    for (final h in pageInserts.reversed.where(
      (h) => h['before'] == null && h['after'] == null,
    )) {
      place((h['block'] as Map).cast<String, dynamic>(), h, atEnd: false);
    }
    for (final c in hints.callouts.where((c) => c['page'] == page.number)) {
      place(
        {
          'type': 'BANNER',
          'body': {
            'text': [for (final l in c['lines'] as List) '$l'].join(' '),
          },
        },
        c,
        atEnd: true,
      );
    }
    items.addAll(pageItems);
  }

  final blocks = <Map<String, dynamic>>[];
  final answersLeft = {
    for (final p in pages) p.number: [...p.answers],
  };
  final width = {
    for (final p in pages)
      p.number: p.body.fold<int>(0, (w, l) => l.length > w ? l.length : w),
  };

  Map<String, dynamic>? open; // the block lines currently flow into
  List<String> para = []; // the paragraph being built inside [open]
  List<String> paras = []; // finished paragraphs of [open]
  SourcePage? openPage;

  String tierOf(SourcePage p) =>
      hints.disciplerFromPage != null && p.number >= hints.disciplerFromPage!
      ? 'DISCIPLER'
      : 'DISCIPLE';

  Map<String, dynamic> start(
    String type,
    SourcePage page,
    Map<String, dynamic> body,
  ) {
    final b = <String, dynamic>{
      'type': type,
      'tier': tierOf(page),
      'section': ?page.section,
      'body': body,
      '_page': page.number,
    };
    blocks.add(b);
    return b;
  }

  void closeParagraph() {
    if (para.isNotEmpty) paras.add(para.join(' '));
    para = [];
  }

  void close() {
    closeParagraph();
    final b = open;
    if (b != null &&
        (b['type'] == 'PARAGRAPH' ||
            b['type'] == 'POINT' ||
            b['type'] == 'SCENARIO')) {
      final text = paras.join('\n\n');
      (b['body'] as Map)['text'] = text;
    }
    open = null;
    paras = [];
    openPage = null;
  }

  /// Gives [block] the answers of [line]'s blanks. [source] is the line as
  /// the page gives it, by which its answers are known. A blank the source
  /// leaves unanswered gets an empty answer, so answers stay one per blank.
  void takeAnswers(
    Map<String, dynamic> block,
    SourcePage page,
    String line, {
    required String source,
  }) {
    final n = blankCount(line);
    if (n == 0) return;
    final List<String> split;
    final mine = page.owned[source];
    if (mine != null && mine.isNotEmpty) {
      final answer = mine.join(' ');
      mine.clear();
      final fills = page.ownedFills[source];
      final s =
          hints.answerSplits[answer] ??
          [
            for (final reading in fills ?? const <List<String>>[])
              if (reading.length == n) splitByFills(answer, reading),
          ].nonNulls.firstOrNull ??
          splitAnswer(answer, n);
      if (s == null || s.length != n) {
        warnings.add(
          'page ${page.number}: answer "$answer" does not divide over $n blanks',
        );
        split = List.filled(n, '');
      } else {
        split = s;
      }
    } else if (page.owned.isEmpty && answersLeft[page.number]!.isNotEmpty) {
      // No layout to tie answers to lines: take them in order.
      final answer = answersLeft[page.number]!.removeAt(0);
      final s = hints.answerSplits[answer] ?? splitAnswer(answer, n);
      if (s == null || s.length != n) {
        warnings.add(
          'page ${page.number}: answer "$answer" does not divide over $n blanks',
        );
        split = List.filled(n, '');
      } else {
        split = s;
      }
    } else {
      unanswered.add('page ${page.number}: $line');
      split = List.filled(n, '');
    }
    (block['answers'] ??= <String>[]).addAll(split);
  }

  void addTextLine(
    Map<String, dynamic> block,
    SourcePage page,
    String raw, {
    String? next,
    String? source,
  }) {
    final line = normalizeBlanks(raw);
    takeAnswers(block, page, line, source: source ?? raw);
    para.add(line);
    if (_privateUseIn(raw) ||
        endsParagraph(raw, width[page.number]!, next: next)) {
      closeParagraph();
    }
  }

  // The next source line on the same page, or null at a page or block
  // boundary (where a paragraph always ends).
  String? nextLine(int i) {
    if (i + 1 >= items.length) return null;
    final n = items[i + 1];
    return n.text != null && n.page == items[i].page ? n.text : null;
  }

  final verseByPage = <int, Map<String, dynamic>>{};
  final figureLinesByPage = <int, int>{};

  // Items already taken by an earlier block (a table header set apart).
  final skip = <int>{};

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (skip.contains(i)) continue;
    final page = item.page;
    if (item.block != null) {
      close();
      final b = item.block!;
      final block = start(
        b['type'] as String,
        page,
        (b['body'] as Map).cast<String, dynamic>(),
      );
      if (b['tier'] != null) block['tier'] = b['tier'];
      if (b['section'] != null) block['section'] = b['section'];
      if (b['source'] != null) block['source'] = b['source'];
      continue;
    }
    final raw = item.text!;
    final text = raw.trim();

    if (isBlankOnly(text)) {
      final b = open;
      if (b != null && b['type'] == 'VERSE_WRITING') {
        final body = b['body'] as Map;
        body['lines'] = (body['lines'] as int? ?? 0) + 1;
      } else {
        close();
        figureLinesByPage[page.number] =
            (figureLinesByPage[page.number] ?? 0) + 1;
      }
      continue;
    }

    if (text == _explainVerse && open?['type'] == 'VERSE_WRITING') {
      (open!['body'] as Map)['followUp'] = text;
      close();
      continue;
    }

    if (_bullet.hasMatch(text)) {
      close();
      final rest = text.replaceFirst(_bullet, '');
      final split = splitReference(rest);
      open = start('POINT', page, {'reference': ?split.reference});
      openPage = page;
      if (split.text.isNotEmpty) {
        addTextLine(open!, page, split.text, next: nextLine(i), source: text);
      }
      continue;
    }

    if (_reflectStart.hasMatch(text)) {
      close();
      final questions = <String>[];
      var j = i;
      for (; j < items.length; j++) {
        final t = items[j].text?.trim();
        if (t == null ||
            _waterCooler.hasMatch(t) ||
            _verseWriting.hasMatch(t)) {
          break;
        }
        questions.addAll(splitQuestions(t));
      }
      start('DISCUSSION_PROMPTS', page, {'items': questions});
      i = j - 1;
      continue;
    }

    if (_waterCooler.hasMatch(text)) {
      close();
      open = start('SCENARIO', page, {});
      openPage = page;
      addTextLine(open!, page, text, next: nextLine(i));
      continue;
    }

    final verse = _verseWriting.firstMatch(text);
    if (verse != null) {
      close();
      open = start('VERSE_WRITING', page, {
        'reference': verse.group(1) ?? verse.group(2),
        'instruction': text,
      });
      verseByPage[page.number] = open!;
      continue;
    }

    if (text.startsWith('Date completed')) {
      close();
      start('SIGN_OFF', page, {'text': normalizeBlanks(text)});
      continue;
    }

    if (text.startsWith('Question Struggling')) {
      close();
      // The header runs over up to three lines, which the text layer may
      // set elsewhere on the page: take them from wherever they are.
      final header = <String>[...text.split(RegExp(r'\s+'))];
      for (var k = i + 1; k < items.length && !header.contains('Well'); k++) {
        final t = items[k].text?.trim();
        if (items[k].page != page || t == null) continue;
        if (t.startsWith('Improvement') || t == 'Well') {
          header.addAll(t.split(RegExp(r'\s+')));
          skip.add(k);
        }
      }
      var j = i + 1;
      final columns = <String>[];
      for (var k = 1; k < header.length; k++) {
        final w = header[k];
        if ((w == 'Needs' || w == 'Doing') && k + 1 < header.length) {
          columns.add('$w ${header[++k]}');
        } else {
          columns.add(w);
        }
      }
      final questions = <String>[];
      while (j < items.length &&
          (skip.contains(j) ||
              (items[j].text != null && items[j].text!.trim().endsWith('?')))) {
        if (!skip.contains(j)) questions.add(items[j].text!.trim());
        j++;
      }
      start('SELF_CHECK', page, {
        'header': header.first,
        'columns': columns,
        'items': questions,
      });
      i = j - 1;
      continue;
    }

    if (hints.assignmentPages.contains(page.number)) {
      final n = _numbered.firstMatch(text);
      if (n != null) {
        close();
        final item = normalizeBlanks(n.group(2)!);
        final assignment = start('ASSIGNMENT', page, {
          'number': int.parse(n.group(1)!),
          'text': item,
        });
        takeAnswers(assignment, page, item, source: text);
        continue;
      }
      // Lines under an assignment are its list.
      final last = blocks.isEmpty ? null : blocks.last;
      if (open == null &&
          last != null &&
          (last['type'] == 'ASSIGNMENT' || last['type'] == 'LIST') &&
          last['_page'] == page.number) {
        final list = last['type'] == 'LIST'
            ? last
            : start('LIST', page, {'items': <String>[]});
        final item = normalizeBlanks(text);
        (list['body']['items'] as List).add(item);
        takeAnswers(list, page, item, source: text);
        continue;
      }
    }

    if (open != null && hints.breakBefore.any(text.startsWith)) close();

    if (open == null || openPage == null) {
      open = start('PARAGRAPH', page, {});
      openPage = page;
    } else if (open!['type'] == 'PARAGRAPH' &&
        para.isEmpty &&
        paras.isNotEmpty) {
      // A finished paragraph block; the next paragraph is its own block.
      close();
      open = start('PARAGRAPH', page, {});
      openPage = page;
    }
    addTextLine(open!, page, text, next: nextLine(i));
  }
  close();

  // Answers left on a page belong to its verse writing, or else to its
  // figure (a chart whose labels the Disciple writes in).
  for (final p in pages) {
    final left = answersLeft[p.number]!;
    if (left.isEmpty) continue;
    final verse = verseByPage[p.number];
    final figure = blocks
        .where((b) => b['_page'] == p.number && b['type'] == 'FIGURE')
        .firstOrNull;
    final target = verse ?? figure;
    if (target == null) {
      warnings.add(
        'page ${p.number}: ${left.length} answer line(s) unplaced: $left',
      );
      continue;
    }
    (target['answers'] ??= <String>[]).addAll(left);
    if (figure != null && verse == null) {
      (figure['body'] as Map)['lines'] = figureLinesByPage[p.number] ?? 0;
    }
    left.clear();
  }

  for (final b in blocks) {
    final answers = b['answers'] as List?;
    if (answers != null) (b['body'] as Map)['blanks'] = answers.length;
    final text = (b['body'] as Map)['text'];
    if (answers == null &&
        text is String &&
        blankCount(text) > 0 &&
        b['type'] != 'SIGN_OFF') {
      (b['body'] as Map)['blanks'] = 0;
      warnings.add('page ${b['_page']}: blanks without answers: "$text"');
    }
    b.remove('_page');
  }
  return BuildResult(blocks, warnings, unanswered);
}

bool _privateUseIn(String s) => RegExp(r'[-]').hasMatch(s);
