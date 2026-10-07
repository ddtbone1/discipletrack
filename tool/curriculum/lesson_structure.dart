// Gives a converted lesson's questions and assignments their structure and
// the input each one needs in the app (user decision 2026-10-07: nothing is
// answered on a separate piece of paper; no wording is changed).
//
// Works on the blocks lesson_builder.dart produced, before they are written:
//   - a numbered assignment and the LIST lines that follow it become one
//     ASSIGNMENT: its text (the printed lines reflowed), and its parts
//     (lettered questions "A.", choices "a.", or one line each, such as a
//     verse to explain);
//   - each assignment and part gets a "respond" kind, decided from the
//     book's own wording:
//       write     a question or a written task ("What ...?", "Explain ...")
//       choice    a statement to pick among lettered choices
//       truefalse "(True or False) ..."
//       task      something to do ("Read ...", "Memorize ...")
//       (none)    teaching text and instructions
//     Blanks ("[_]") stay inline as fill-in items whatever the kind;
//   - a reading plan (references with a "Date" to fill in) becomes a LIST
//     with "field": one reading per row, each with a date to write.
// Every word of the source is kept; verify_lesson.dart checks it.
import 'lesson_source.dart';

const _write =
    r'^(What|Why|How|Who|Whom|Where|When|Which|Does|Do you|Did|Can|Could|'
    r'Is|Are|Would|Will|Have|Has|Should|Explain|Write|Give|List|Describe|'
    r'Name|Jot|Look up|From these|From verse|According to|Answer this|'
    r'Pick \d+|Support)\b';
const _task =
    r'^(Read|Get|Pray|Find|Do this|Review|Begin|With your Discipler|'
    r'Download|Complete|Go to|Check|Memorize|Draw|Bring|Share|Meet|Pray)\b';
final _writeRe = RegExp(_write);
final _taskRe = RegExp(_task);
final _label = RegExp(r'^([A-Za-z])\.(?:\s+(.*))?$');
final _stepLine = RegExp(r'^Step #\d+');
final _reference = RegExp(
  r'^(?:\d(?:st|nd|rd|th)?\s)?[A-Z][a-z]+\.?\s\d+(?::\s?\d+(?:[-,]\s?\d+)*)?'
  r'(?:\s*(?:,|and)?\s*\d*\s?[A-Z]?[a-z]*\.?\s?\d+:\s?\d+(?:[-,]\s?\d+)*)*$',
);
final _readingRef = RegExp(
  // "[\s:]": the book prints one reading as "Mark:16:7-8".
  r'(?:\d(?:st|nd|rd|th)?\s)?[A-Z][a-z]+[\s:]\d+:\s?\d+(?:-\d+)?',
);

final _asksWriting = RegExp(
  r'\b(explain|describe|write down|jot down|write your|write them|'
  r'write the|write a)\b',
  caseSensitive: false,
);

/// The kind of answer a sentence asks for, from its own wording. [part]:
/// a lettered or listed part, where any question asks for an answer; in a
/// long instruction a question may be rhetorical.
String? respondKind(String text, {bool part = false}) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (t.startsWith('(True or False)')) return 'truefalse';
  if (t.startsWith('Answer the questions for Lesson')) return null;
  if (t.startsWith('Write your answers to')) return 'task';
  if (_writeRe.hasMatch(t) || t.endsWith('?')) return 'write';
  if (_asksWriting.hasMatch(t)) return 'write';
  if (_taskRe.hasMatch(t)) return 'task';
  if ((part || t.length < 400) && t.contains('?')) return 'write';
  return null;
}

/// "a. John 14:26, b. Acts 13:2" printed on one line: one part each.
List<String> _splitLabels(String line) => [
  for (final s in line.split(RegExp(r'\s+(?=[a-z]\.\s)')))
    if (s.trim().isNotEmpty) s.trim(),
];

/// Printed lines joined into paragraphs: a short line ending a sentence
/// ends its paragraph; the rest run on.
String reflow(List<String> lines) {
  final width = lines.fold<int>(0, (w, l) => l.length > w ? l.length : w);
  final out = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].trim();
    if (l.isEmpty) continue;
    if (out.isNotEmpty) {
      final prev = lines[i - 1].trim();
      final ends = RegExp(r'[.:?!”"]$').hasMatch(prev);
      out.write(ends && prev.length < width * 0.8 ? '\n\n' : ' ');
    }
    out.write(l);
  }
  return out.toString();
}

void structureLesson(List<Map<String, dynamic>> blocks) {
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    if (b['type'] == 'PARAGRAPH' && _readingPlan(b)) continue;
    if (b['type'] == 'SCENARIO') {
      (b['body'] as Map)['respond'] = 'write';
      continue;
    }
    if (b['type'] == 'DISCUSSION_PROMPTS') {
      (b['body'] as Map)['respond'] = 'write';
      continue;
    }
    if (b['type'] != 'ASSIGNMENT') continue;

    // The assignment's own line and the lines under it, with answers in
    // reading order.
    final body = (b['body'] as Map).cast<String, dynamic>();
    final lines = <String>[
      if ('${body['text'] ?? ''}'.trim().isNotEmpty) '${body['text']}',
    ];
    final answers = <dynamic>[...?b['answers'] as List?];
    while (i + 1 < blocks.length &&
        blocks[i + 1]['type'] == 'LIST' &&
        blocks[i + 1]['tier'] == b['tier']) {
      final list = blocks.removeAt(i + 1);
      lines.addAll([for (final x in list['body']['items'] as List) '$x']);
      answers.addAll(list['answers'] as List? ?? const []);
    }

    // Split into the instruction and its parts.
    final head = <String>[];
    final parts = <Map<String, dynamic>>[];
    String? pendingLabel;
    for (final raw in [
      for (final x in lines)
        if (_label.hasMatch(x.trim())) ..._splitLabels(x.trim()) else x,
    ]) {
      final l = raw.trim();
      if (l.isEmpty) continue;
      final m = _label.firstMatch(l);
      if (m != null) {
        if (m.group(2) == null || m.group(2)!.isEmpty) {
          pendingLabel = '${m.group(1)}.';
          continue;
        }
        parts.add({
          'label': '${m.group(1)}.',
          'lines': [m.group(2)!],
        });
        continue;
      }
      if (pendingLabel != null) {
        parts.add({
          'label': pendingLabel,
          'lines': [l],
        });
        pendingLabel = null;
        continue;
      }
      if (_stepLine.hasMatch(l) ||
          (_reference.hasMatch(l) && head.isNotEmpty)) {
        parts.add({
          'lines': [l],
        });
        continue;
      }
      if (parts.isNotEmpty) {
        (parts.last['lines'] as List<String>).add(l);
      } else {
        head.add(l);
      }
    }
    if (pendingLabel != null) parts.add({'label': pendingLabel, 'lines': []});

    final text = reflow(head);
    body['text'] = text;
    final lettered = parts.isNotEmpty && parts.every((p) => p['label'] != null);
    // Choices are statements to pick from, under "Which ...?"; other
    // lettered parts are questions of their own.
    final choices =
        lettered &&
        RegExp(r'^Which\b').hasMatch(text) &&
        parts.every((p) => RegExp('^[a-z]').hasMatch(p['label'] as String));
    final mainKind = respondKind(text);
    if (parts.isNotEmpty) {
      body['parts'] = [
        for (final p in parts)
          {
            'label': ?p['label'],
            'text': reflow(p['lines'] as List<String>),
            // Choices are picked, steps are read; a verse or question part
            // under a written instruction is answered one by one.
            if (!choices && !_stepLine.hasMatch((p['lines'] as List).first))
              'respond':
                  ?(respondKind(
                    reflow(p['lines'] as List<String>),
                    part: true,
                  ) ??
                  (mainKind == 'write' || _asksWriting.hasMatch(text)
                      ? 'write'
                      : null)),
          },
      ];
    } else {
      body.remove('parts');
    }
    final parted = body['parts'] as List?;
    final partsAnswer =
        parted != null && parted.any((p) => (p as Map)['respond'] != null);
    final kind = choices
        ? 'choice'
        // An instruction that only introduces its parts ("Pick 5 of the
        // verses below and explain ...") is answered in the parts.
        : partsAnswer &&
              RegExp(r'^(Pick|Look up|From these|Answer the)').hasMatch(text)
        ? null
        : mainKind;
    if (kind != null) {
      body['respond'] = kind;
    } else {
      body.remove('respond');
    }
    if (answers.isNotEmpty) b['answers'] = answers;
  }
}

/// A reading plan: references, each with a "Date" to write. Kept as a
/// LIST whose rows are the readings, in reading order, with the date field.
bool _readingPlan(Map<String, dynamic> b) {
  final text = '${(b['body'] as Map)['text'] ?? ''}';
  final refs = _readingRef.allMatches(text).toList();
  if (refs.length < 10 || !text.contains('Date')) return false;
  final rest = text.replaceAll(_readingRef, ' ');
  final leftover = [
    for (final w in rest.split(RegExp(r'\s+')))
      if (w.isNotEmpty) w,
  ];
  final dates = leftover.where((w) => w == 'Date' || w == 'Date:').toList();
  final fields = leftover.where((w) => w == fieldToken).length;
  final note = [
    for (final w in leftover)
      if (w != 'Date' && w != 'Date:' && w != fieldToken) w,
  ];
  int chapter(String r) =>
      int.parse(RegExp(r'(\d+):').firstMatch(r)!.group(1)!);
  int verse(String r) =>
      int.parse(RegExp(r'\d+:\s?(\d+)').firstMatch(r)!.group(1)!);
  final readings = [for (final r in refs) r.group(0)!]
    ..sort((a, c) {
      final x = chapter(a).compareTo(chapter(c));
      return x != 0 ? x : verse(a).compareTo(verse(c));
    });
  b['type'] = 'LIST';
  b['body'] = {
    'items': readings,
    'field': dates.first.replaceAll(':', ''),
    // The printed labels and lines, kept for the word check.
    'fieldWords': [...dates, for (var k = 0; k < fields; k++) fieldToken],
    if (note.isNotEmpty) 'note': note.join(' '),
  };
  return true;
}
