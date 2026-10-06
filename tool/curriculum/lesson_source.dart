/// Converts one lesson of the source PDF's text layer into the canonical
/// block sequence (ADR-019 decisions 12 to 14).
///
/// The input is `pdftotext -raw -enc UTF-8` output. In that text layer
/// each page holds, in order: the page's body, the page marker
/// ("Lesson n page m"), then the handwritten answers of the Discipler's
/// Copy, one line per answered line of the page. Nothing here rewrites
/// wording: lines are only joined, split at questions, and classified.
/// What the text layer cannot say (image-only banners, callout placement,
/// a few reading-order corrections) comes from a per-lesson hints file.
library;

/// A blank in a block's text.
const blankToken = '[_]';

final _blankRun = RegExp(r'_{2,}');
final _blankOnly = RegExp(r'^_+$');
final _pageMarker = RegExp(
  r'^(?:For more resources visit www\.TheJourneyForum\.com\s+)?'
  r'Lesson\s+\d+\s+page\s+\d+$',
);
final _sectionLine = RegExp(r'^SECTION\s+([A-Z])$');
const _furniture = {'For more resources visit www.TheJourneyForum.com'};

/// Private-use glyphs (checkbox dingbats) carry no wording.
final _privateUse = RegExp(r'[\uE000-\uF8FF\x00-\x08\x0B\x0E-\x1F]');

String _clean(String s) => s.replaceAll(_privateUse, '').trim();

/// A writing field (a date, a signature): a line to write on, never a
/// blank with an answer.
const fieldToken = '[~]';

final _field = RegExp(
  r'((?:Date(?: completed)?|signature\)?|Day|Time|Place)\s*:?\s*)_{2,}',
);

String normalizeBlanks(String line) => line
    .replaceAllMapped(_field, (m) => '${m.group(1)}$fieldToken')
    .replaceAll(_blankRun, blankToken)
    .replaceAll(_privateUse, '')
    .replaceAll(RegExp(r' {2,}'), ' ')
    .trim();

int blankCount(String text) => blankToken.allMatches(text).length;

bool isBlankOnly(String line) => _blankOnly.hasMatch(line.trim());

/// One page of the text layer, split into body and answers.
class SourcePage {
  SourcePage({
    required this.number,
    required this.body,
    required this.answers,
    this.section,
    this.owned = const {},
    this.ownedFills = const {},
  });

  /// 1-based page index in the PDF.
  final int number;
  final List<String> body;

  /// Answer lines not tied to one printed line (written verses, chart
  /// labels), in order.
  final List<String> answers;
  final String? section;

  /// The answer lines printed in each body line's blanks, by line.
  final Map<String, List<String>> owned;

  /// The letters printed in that line's filled blanks, read two ways (see
  /// [fillReadings]).
  final Map<String, List<List<String>>> ownedFills;
}

/// A line reduced for matching between the raw and layout text layers:
/// spaces collapsed, and any token holding a blank (with or without answer
/// letters printed in it) reduced to "_".
String layoutKey(String line) => [
  for (final t in _clean(line).split(RegExp(r'\s+')))
    if (t.isNotEmpty) t.contains('_') ? '_' : t,
].join(' ').replaceAll(RegExp(r'_( _)+'), '_');

/// Whether two layout keys are the same printed line, allowing for text
/// printed beside it (a callout in the margin).
bool sameLine(String a, String b) {
  if (a == b) return true;
  final n = a.length < b.length ? a.length : b.length;
  if (n >= 20 && a.substring(0, n) == b.substring(0, n)) return true;
  // A word glued to a blank changes the key ("the _" against "_"): then
  // the first six words outside blanks decide.
  // List numbers and bullets may sit apart in one text layer.
  List<String> words(String s) => [
    for (final w in s.split(' '))
      if (w != '_' && w != '•' && !RegExp(r'^\d+\.$').hasMatch(w)) w,
  ];
  final wa = words(a), wb = words(b);
  if (wa.length < 6 || wb.length < 6) return false;
  for (var i = 0; i < 6; i++) {
    if (wa[i] != wb[i]) return false;
  }
  return true;
}

String _squash(String s) => s.replaceAll(RegExp(r'[\s_]'), '');

/// Splits the text layer into pages, dropping the repeated footer, the
/// page marker and the section label, and separating the handwritten
/// answers from the lesson's own lines.
///
/// With [layout] (each page of `pdftotext -layout`), a line is an answer
/// when the printed page shows it only inside blanks: its letters occur in
/// a line where they are interleaved with the blank's underscores, and the
/// line is not printed on its own. Lines of the lesson found after the
/// page marker are put back where the page shows them. Without [layout],
/// everything after the page marker is taken as answers.
/// [calloutLines] are removed (they become callouts).
List<SourcePage> splitPages(
  String raw, {
  Map<int, Set<String>> calloutLines = const {},
  List<String>? layout,
}) {
  final pages = <SourcePage>[];
  final chunks = raw.split('\f');
  for (var i = 0; i < chunks.length; i++) {
    final number = i + 1;
    final callouts = calloutLines[number] ?? const <String>{};
    final lines = [
      for (final l in chunks[i].split(RegExp(r'\r?\n')))
        if (l.trim().isNotEmpty) l.trimRight(),
    ];
    final marker = lines.indexWhere((l) => _pageMarker.hasMatch(l.trim()));
    if (marker < 0 && layout == null) {
      if (lines.isEmpty) continue;
      pages.add(SourcePage(number: number, body: lines, answers: const []));
      continue;
    }
    String? section;
    final kept = <(String, bool)>[]; // line, after the marker
    for (var k = 0; k < lines.length; k++) {
      if (k == marker) continue;
      final t = lines[k].trim();
      final s = _sectionLine.firstMatch(t);
      if (s != null) {
        section = s.group(1);
        continue;
      }
      if (_furniture.contains(t) || callouts.contains(_clean(t))) continue;
      kept.add((t, marker >= 0 && k > marker));
    }
    if (kept.isEmpty && marker < 0) continue;

    final body = <String>[];
    final answers = <String>[];
    final owned = <String, List<String>>{};
    final ownedFills = <String, List<List<String>>>{};
    if (layout == null || i >= layout.length) {
      for (final (t, after) in kept) {
        (after ? answers : body).add(t);
      }
    } else {
      final printed = [
        for (final l in layout[i].split(RegExp(r'\r?\n')))
          if (l.trim().isNotEmpty) l,
      ];
      final keys = [for (final l in printed) layoutKey(l)];
      // The letters printed inside blanks: tokens holding underscores.
      final filled = [
        for (final l in printed)
          for (final t in l.trim().split(RegExp(r'\s+')))
            if (t.contains('_') && RegExp(r'[A-Za-z0-9]').hasMatch(t))
              _squash(t),
      ].join('|');
      bool isAnswer(String t) {
        if (t.contains('_') || keys.contains(layoutKey(t))) return false;
        // Its words in order, mostly found inside blanks: one answer line
        // may fill several blanks with lesson text between them, and a
        // written verse may end just past its line.
        var from = 0;
        var found = 0;
        var total = 0;
        for (final w in t.split(RegExp(r'\s+'))) {
          final s = _squash(w);
          if (s.isEmpty) continue;
          total += s.length;
          final at = filled.indexOf(s, from);
          if (at < 0) continue;
          found += s.length;
          from = at + s.length;
        }
        return total > 0 && found >= total * 0.8;
      }

      int position(String t) {
        final k = layoutKey(t);
        final exact = keys.indexOf(k);
        if (exact >= 0) return exact;
        final p = k.length > 30 ? k.substring(0, 30) : k;
        return keys.indexWhere((x) => x.startsWith(p));
      }

      final late = <String>[];
      // After the marker, the answers form one trailing run: from the
      // first answer-like line on, every line without a blank is an
      // answer (a written verse line may stand on its own).
      var answering = false;
      for (final (t, after) in kept) {
        if (after && !answering && isAnswer(t)) answering = true;
        if ((answering && !t.contains('_')) || (!after && isAnswer(t))) {
          answers.add(t);
        } else if (after) {
          late.add(t);
        } else {
          body.add(t);
        }
      }
      // Lines of the lesson given after the marker go where the page
      // shows them.
      for (final t in late) {
        final at = position(t);
        var insert = body.length;
        if (at >= 0) {
          for (var b = 0; b < body.length; b++) {
            final pb = position(body[b]);
            if (pb > at) {
              insert = b;
              break;
            }
          }
        }
        body.insert(insert, t);
      }

      // Tie each answer line to the printed line whose blanks hold it,
      // and so to its body line. A blank the Discipler's Copy leaves empty
      // then stays empty instead of taking the next line's answer.
      // An answer belongs to a printed line when its letters are exactly
      // the letters of one or more consecutive filled blanks there.
      final tokensOf = [
        for (final l in printed)
          [
            for (final t in l.trim().split(RegExp(r'\s+')))
              if (t.contains('_') && RegExp(r'[A-Za-z0-9]').hasMatch(t))
                _letters(t),
          ],
      ];
      bool fills(int j, String answer) {
        final a = _letters(answer);
        if (a.isEmpty) return false;
        final t = tokensOf[j];
        for (var i = 0; i < t.length; i++) {
          var spelled = '';
          for (var k = i; k < t.length && spelled.length < a.length; k++) {
            spelled += t[k];
            if (spelled == a) return true;
          }
        }
        return false;
      }

      final candidates = [
        for (final b in body)
          if (b.contains('_') && !isBlankOnly(b)) b,
      ];

      /// The body line printed as layout line [j]: exact before prefix,
      /// and one without an answer before one that has one (printed lines
      /// can begin alike).
      String? bodyLineOf(int j) {
        for (final pass in [
          (exact: true, free: true),
          (exact: true, free: false),
          (exact: false, free: true),
          (exact: false, free: false),
        ]) {
          for (final b in candidates) {
            final k = layoutKey(b);
            final match = pass.exact ? k == keys[j] : sameLine(k, keys[j]);
            if (match && (!pass.free || !owned.containsKey(b))) return b;
          }
        }
        return null;
      }

      /// Like [fills], but a printed blank may carry a whole word of the
      /// line glued to its edge ("theN_e_w", "N_e_w__Testament",
      /// "They_r_i_s_k_e_d"); such words are taken off before comparing.
      bool fillsGlued(int j, String answer, String line) {
        final a = _letters(answer);
        if (a.isEmpty) return false;
        final words = {
          for (final w in line.split(RegExp(r'[\s_]+')))
            if (_letters(w).length > 1) _letters(w),
        };
        String unglue(String t) {
          for (final w in words) {
            if (t.length > w.length && t.startsWith(w)) {
              t = t.substring(w.length);
              break;
            }
          }
          for (final w in words) {
            if (t.length > w.length && t.endsWith(w)) {
              t = t.substring(0, t.length - w.length);
              break;
            }
          }
          return t;
        }

        final t = [for (final x in tokensOf[j]) unglue(x)];
        for (var i = 0; i < t.length; i++) {
          var spelled = '';
          for (var k = i; k < t.length && spelled.length < a.length; k++) {
            spelled += t[k];
            if (spelled == a) return true;
          }
        }
        return false;
      }

      /// An answer printed on a line of its own, just above the empty
      /// blank it answers (the Discipler's Copy sometimes sets it there).
      int? floatingOwner(String answer) {
        final at = printed.indexWhere((l) => l.trim() == answer.trim());
        if (at < 0) return null;
        for (var j = at + 1; j < printed.length && j <= at + 4; j++) {
          final hasEmptyBlank = printed[j]
              .trim()
              .split(RegExp(r'\s+'))
              .any((t) => RegExp(r'^_{3,}[.,;:]?$').hasMatch(t));
          if (hasEmptyBlank) return j;
        }
        return null;
      }

      var lastPrinted = 0;
      final loose = <String>[];
      for (final a in answers) {
        final order = [
          for (var k = lastPrinted; k < printed.length; k++) k,
          for (var k = 0; k < lastPrinted; k++) k,
        ];
        int? owner;
        String? line;
        // Exactly the letters of its blanks first; then a blank with a
        // word of the line glued to it.
        // A line whose blanks have no answer yet before one that has: one
        // answer's letters can recur inside another's ("good" in "very
        // good").
        for (final pass in [
          (glued: false, answered: false),
          (glued: false, answered: true),
          (glued: true, answered: false),
          (glued: true, answered: true),
        ]) {
          for (final j in order) {
            if (!pass.glued && !fills(j, a)) continue;
            final b = bodyLineOf(j);
            if (b == null) continue;
            if (!pass.answered && owned.containsKey(b)) continue;
            if (pass.glued && !fillsGlued(j, a, b)) continue;
            owner = j;
            line = b;
            break;
          }
          if (line != null) break;
        }
        if (line == null) {
          final j = floatingOwner(a);
          final b = j == null ? null : bodyLineOf(j);
          if (j != null && b != null && !owned.containsKey(b)) {
            owner = j;
            line = b;
          }
        }
        if (line == null || owner == null) {
          loose.add(a);
        } else {
          lastPrinted = owner;
          (owned[line] ??= []).add(a);
          ownedFills[line] ??= fillReadings(printed[owner]);
        }
      }
      answers
        ..clear()
        ..addAll(loose);
    }
    pages.add(
      SourcePage(
        number: number,
        body: body,
        answers: answers,
        section: section,
        owned: owned,
        ownedFills: ownedFills,
      ),
    );
  }
  return pages;
}

/// A scripture reference list such as "1st John 2:28 and 1st John 3:2-3"
/// or "2nd Thessalonians 1:7-9, 2:8-12".
final _book = r'(?:[1-3](?:st|nd|rd)\s)?[A-Z][a-z]+(?:\sof\s[A-Z][a-z]+)?';
final _verse = r'\d+:\d+(?:-\d+)?(?:,\s?\d+(?::\d+)?(?:-\d+)?)*';
final _refList = RegExp(
  '^($_book\\s$_verse(?:(?:,\\s|\\sand\\s)$_book\\s$_verse)*)(?=\\s|\$)',
);

/// Splits a bullet's line into a leading reference and the rest.
({String? reference, String text}) splitReference(String line) {
  final m = _refList.firstMatch(line);
  if (m == null) return (reference: null, text: line);
  return (reference: m.group(1), text: line.substring(m.end).trim());
}

/// Splits a line of questions into its questions, at each question mark.
List<String> splitQuestions(String line) => [
  for (final q in line.split(RegExp(r'(?<=\?)\s+')))
    if (q.trim().isNotEmpty) q.trim(),
];

/// The answers for one answered line with [blanks] blanks.
List<String>? splitAnswer(String answer, int blanks) {
  if (blanks == 1) return [answer];
  final words = answer.split(RegExp(r'\s+'));
  if (words.length == blanks) return words;
  return null;
}

/// Whether a paragraph ends after [line] (as printed, blanks included),
/// given the page's line width in characters and the [next] line: the
/// line ends a sentence, and the next line's first word would have fitted
/// after it, so the line was broken on purpose rather than wrapped.
bool endsParagraph(String line, int width, {String? next}) {
  final t = line.trimRight();
  if (t.isEmpty) return true;
  final last = t[t.length - 1];
  const enders = '.?!:”"\')';
  if (!enders.contains(last)) return false;
  if (next == null) return true;
  final firstWord = next.trim().split(RegExp(r'\s+')).first;
  return t.length + 1 + firstWord.length <= width * 0.95;
}

/// Divides an answer line over [fills], the letters printed in each of its
/// blanks: words are taken in order until they spell each blank's letters.
List<String>? splitByFills(String answer, List<String> fills) {
  final words = answer.split(RegExp(r'\s+'));
  final out = <String>[];
  var w = 0;
  for (final fill in fills) {
    final taken = <String>[];
    var spelled = '';
    while (w < words.length && spelled.length < _letters(fill).length) {
      taken.add(words[w]);
      spelled += _letters(words[w]);
      w++;
    }
    if (spelled != _letters(fill)) return null;
    out.add(taken.join(' '));
  }
  return w == words.length ? out : null;
}

/// The letters printed in a line's filled blanks, read two ways: one entry
/// per printed token, and one per run of adjacent tokens (an answer with a
/// space in it spans tokens of one blank). The caller takes whichever has
/// as many entries as the line has blanks.
List<List<String>> fillReadings(String printed) {
  final tokens = printed.trim().split(RegExp(r'\s+'));
  final perToken = [
    for (final t in tokens)
      if (t.contains('_') && RegExp(r'[A-Za-z0-9]').hasMatch(t)) _squash(t),
  ];
  final grouped = <String>[];
  var run = '';
  for (final t in tokens) {
    if (t.contains('_')) {
      run += _squash(t);
    } else if (run.isNotEmpty) {
      grouped.add(run);
      run = '';
    }
  }
  if (run.isNotEmpty) grouped.add(run);
  return [perToken, grouped];
}

String _letters(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
