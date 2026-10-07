import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_pill.dart';
import '../domain/workbook.dart';

/// A blank or writing field the Disciple types into, inline in the text.
/// It grows with what is written, from a short line up to the width
/// available, and saves to the device workbook as they type (ADR-021).
/// After a check ([blank] given), its line turns green or red, and a wrong
/// blank shows the book's answer under it.
class BlankField extends StatefulWidget {
  const BlankField({
    required this.workbook,
    required this.blockId,
    required this.place,
    required this.style,
    this.blank,
    this.label = 'blank',
    super.key,
  });

  final Workbook workbook;
  final String blockId;
  final String place;
  final TextStyle? style;

  /// The blank's index in its block, for checking; null for a writing
  /// field, which has no answer.
  final int? blank;
  final String label;

  @override
  State<BlankField> createState() => _BlankFieldState();
}

class _BlankFieldState extends State<BlankField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.workbook.valueOf(widget.blockId, widget.place),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _width(BoxConstraints c, String extra) {
    double measure(String t) {
      final painter = TextPainter(
        text: TextSpan(text: t, style: widget.style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    final max = c.maxWidth.isFinite ? c.maxWidth : 260.0;
    final w = [
      measure(_controller.text),
      measure(extra),
    ].reduce((a, b) => a > b ? a : b);
    return (w + 14).clamp(80.0, max);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = pillColors(context, PillTone.brand).$2;
    final bad = pillColors(context, PillTone.error).$2;
    return ListenableBuilder(
      listenable: widget.workbook,
      builder: (context, _) {
        final result = widget.blank == null
            ? null
            : widget.workbook.resultOf(widget.blockId, widget.blank!);
        final line = result == null
            ? p.textPrimary
            : result.correct
            ? fg
            : bad;
        final shown = result != null && !result.correct ? result.answer : '';
        return LayoutBuilder(
          builder: (context, c) => SizedBox(
            width: _width(c, shown),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: widget.label,
                  textField: true,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    style: widget.style?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (v) {
                      setState(() {});
                      widget.workbook.write(
                        widget.blockId,
                        widget.place,
                        v.trim(),
                      );
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: line, width: 1.2),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: line,
                          width: result == null ? 1.2 : 2,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: fg, width: 2),
                      ),
                    ),
                  ),
                ),
                if (shown.isNotEmpty)
                  Text(
                    shown,
                    textAlign: TextAlign.center,
                    semanticsLabel: 'answer: $shown',
                    style: widget.style?.copyWith(
                      fontSize: (widget.style?.fontSize ?? 16) * 0.8,
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lines to write a verse on: one multi-line field the size of the
/// printed lines.
class VerseField extends StatefulWidget {
  const VerseField({
    required this.workbook,
    required this.blockId,
    required this.lines,
    required this.style,
    super.key,
  });

  final Workbook workbook;
  final String blockId;
  final int lines;
  final TextStyle? style;

  @override
  State<VerseField> createState() => _VerseFieldState();
}

class _VerseFieldState extends State<VerseField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.workbook.valueOf(widget.blockId, 'v'),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: _controller,
      minLines: widget.lines < 2 ? 2 : widget.lines,
      maxLines: null,
      style: widget.style,
      onChanged: (v) => widget.workbook.write(widget.blockId, 'v', v.trim()),
      decoration: InputDecoration(
        hintText: 'Write it here',
        filled: true,
        fillColor: neutralFill(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.brand, width: 2),
        ),
      ),
    );
  }
}

/// A written answer under a question: one field that grows as they write.
class AnswerBox extends StatefulWidget {
  const AnswerBox({
    required this.workbook,
    required this.blockId,
    required this.place,
    required this.style,
    this.hint = 'Your answer',
    this.minLines = 2,
    super.key,
  });

  final Workbook workbook;
  final String blockId;
  final String place;
  final TextStyle? style;
  final String hint;
  final int minLines;

  @override
  State<AnswerBox> createState() => _AnswerBoxState();
}

class _AnswerBoxState extends State<AnswerBox> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.workbook.valueOf(widget.blockId, widget.place),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _controller,
        minLines: widget.minLines,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: widget.style,
        onChanged: (v) =>
            widget.workbook.write(widget.blockId, widget.place, v.trim()),
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          filled: true,
          fillColor: neutralFill(context),
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: p.brand, width: 2),
          ),
        ),
      ),
    );
  }
}

/// One answer picked among [options] (a choice, or True / False), saved
/// as the option's text.
class PickOne extends StatelessWidget {
  const PickOne({
    required this.workbook,
    required this.blockId,
    required this.place,
    required this.options,
    required this.style,
    this.labels,
    super.key,
  });

  final Workbook workbook;
  final String blockId;
  final String place;
  final List<String> options;

  /// Shown before each option ("a."), when the book labels them.
  final List<String?>? labels;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = pillColors(context, PillTone.brand).$2;
    return ListenableBuilder(
      listenable: workbook,
      builder: (context, _) {
        final chosen = workbook.valueOf(blockId, place);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, o) in options.indexed)
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: chosen == o,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      workbook.write(blockId, place, chosen == o ? '' : o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          chosen == o
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 22,
                          color: chosen == o ? fg : p.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            [labels?[i], o].nonNulls.join(' '),
                            style: style,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A task to do ("Read ...", "Memorize ..."), ticked when done.
class TaskCheck extends StatelessWidget {
  const TaskCheck({
    required this.workbook,
    required this.blockId,
    this.place = 'd',
    super.key,
  });

  final Workbook workbook;
  final String blockId;
  final String place;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = pillColors(context, PillTone.brand).$2;
    return ListenableBuilder(
      listenable: workbook,
      builder: (context, _) {
        final done = workbook.valueOf(blockId, place) == 'done';
        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => workbook.write(blockId, place, done ? '' : 'done'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: done ? fg : p.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    done ? 'Done' : 'Mark as done',
                    style: TextStyle(
                      color: done ? fg : p.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
