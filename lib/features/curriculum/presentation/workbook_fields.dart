import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_pill.dart';
import '../domain/workbook.dart';

/// A blank or writing field the Disciple types into, inline in the text.
/// It grows with what is written, from a short line up to the width
/// available, and saves to the device workbook as they type (ADR-021).
class BlankField extends StatefulWidget {
  const BlankField({
    required this.workbook,
    required this.blockId,
    required this.place,
    required this.style,
    this.label = 'blank',
    super.key,
  });

  final Workbook workbook;
  final String blockId;
  final String place;
  final TextStyle? style;
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

  double _width(BoxConstraints c) {
    final painter = TextPainter(
      text: TextSpan(text: _controller.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final max = c.maxWidth.isFinite ? c.maxWidth : 260.0;
    return (painter.width + 14).clamp(80.0, max);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = pillColors(context, PillTone.brand).$2;
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        width: _width(c),
        child: TextField(
          controller: _controller,
          style: widget.style?.copyWith(color: fg, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          onChanged: (v) {
            setState(() {});
            widget.workbook.write(widget.blockId, widget.place, v.trim());
          },
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            hintText: null,
            semanticCounterText: '',
            labelText: null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: p.textPrimary, width: 1.2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: p.textPrimary, width: 1.2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: fg, width: 2),
            ),
          ),
        ),
      ),
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
