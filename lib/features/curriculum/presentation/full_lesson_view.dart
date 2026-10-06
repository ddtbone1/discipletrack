import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_pill.dart';
import '../domain/lesson_content.dart';
import '../domain/workbook.dart';
import 'workbook_fields.dart';

/// The faithful lesson (ADR-019 decisions 12 and 13): every block in
/// source order, laid out for a phone. Wording is shown exactly as
/// published; only the layout differs from the printed page.
///
/// The same blocks give two presentations. A Disciple's read carries no
/// answers, so each blank shows as an empty line; a Discipler's read
/// carries them, and each blank shows its answer, marked as an answer.
/// Which one appears is decided by the database, never here. When a
/// Disciple reads their own lesson, a [workbook] makes blanks, fields,
/// verse lines and ratings fillable, saved on the device only (ADR-021).
class FullLessonView extends StatelessWidget {
  const FullLessonView({required this.lesson, this.workbook, super.key});

  final LessonContent lesson;

  /// The Disciple's own answers, when they read their own lesson: blanks,
  /// fields, verses and ratings become fillable (ADR-021). Null otherwise.
  final Workbook? workbook;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final b in lesson.blocks) {
      if (b.type == BlockType.lessonTheme ||
          b.type == BlockType.topicList ||
          b.type == BlockType.unknown) {
        continue; // The header above the lesson shows the theme and topics.
      }
      final w = _block(context, b);
      if (w == null) continue;
      children.add(
        Padding(
          padding: EdgeInsets.only(top: _spaceBefore(b.type)),
          child: w,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  static double _spaceBefore(BlockType t) => switch (t) {
    BlockType.sectionHeading ||
    BlockType.moduleHeading ||
    BlockType.heading => AppSpacing.xl,
    _ => AppSpacing.md,
  };

  Widget? _block(BuildContext context, ContentBlock b) {
    final p = context.palette;
    final body = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(color: p.textPrimary, height: 1.5);
    switch (b.type) {
      case BlockType.sectionHeading:
        return _SectionTitle(
          label: b.sectionLabel == null ? null : 'Section ${b.sectionLabel}',
          title: b.title,
        );
      case BlockType.heading:
        return _SectionTitle(title: b.title, subtitle: b.subtitle);
      case BlockType.moduleHeading:
        return _ModuleTitle(block: b);
      case BlockType.keyObjective:
        return AppCard(
          fill: AppCardFill.pastel,
          child: Text(
            b.text ?? '',
            style: body?.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      case BlockType.paragraph:
      case BlockType.fillIn:
      case BlockType.disciplerNote:
        return _RichBlanks(block: b, workbook: workbook, style: body);
      case BlockType.point:
        return _Point(block: b, workbook: workbook, style: body);
      case BlockType.banner:
        return _Callout(text: b.text ?? '');
      case BlockType.figure:
        return _Figure(block: b);
      case BlockType.discussionPrompts:
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, q) in b.items.indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The book lists them without numbers.
                      SizedBox(width: 18, child: Text('•', style: body)),
                      Expanded(child: Text(q, style: body)),
                    ],
                  ),
                ),
            ],
          ),
        );
      case BlockType.scenario:
        return AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.forum_outlined, color: p.muted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RichBlanks(block: b, workbook: workbook, style: body),
              ),
            ],
          ),
        );
      case BlockType.verseWriting:
        return _VerseWriting(block: b, workbook: workbook, style: body);
      case BlockType.selfCheck:
        return _SelfCheck(block: b, workbook: workbook, style: body);
      case BlockType.signOff:
        return _RichBlanks(
          block: b,
          workbook: workbook,
          style: context.supportingStyle,
        );
      case BlockType.assignment:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${b.body['number']}.',
                style: body?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: _RichBlanks(block: b, workbook: workbook, style: body),
            ),
          ],
        );
      case BlockType.list:
        return Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in b.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Text(item, style: body),
                ),
            ],
          ),
        );
      case BlockType.scriptureReferences:
      case BlockType.assignments:
      case BlockType.lessonTheme:
      case BlockType.topicList:
      case BlockType.unknown:
        return null;
    }
  }
}

/// Text with its blanks: an empty line each for the Disciple, the answer
/// for the Discipler. Paragraph breaks ("\n\n") are kept.
class _RichBlanks extends StatelessWidget {
  const _RichBlanks({required this.block, required this.style, this.workbook});

  final Workbook? workbook;

  final ContentBlock block;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final source = block.text ?? '';
    final answers = block.answerList;
    final paragraphs = source.split('\n\n');
    var blank = 0;
    var field = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, para) in paragraphs.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  for (final (j, part) in para.split(blankToken).indexed) ...[
                    if (j > 0) _blank(context, answers, blank++),
                    for (final (k, piece)
                        in part.split(fieldToken).indexed) ...[
                      if (k > 0) _field(context, field++),
                      TextSpan(text: piece),
                    ],
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  InlineSpan _blank(BuildContext context, List<String> answers, int i) {
    if (i < answers.length) {
      final fg = pillColors(context, PillTone.brand).$2;
      return TextSpan(
        text: answers[i].isEmpty ? '      ' : answers[i],
        semanticsLabel: 'answer: ${answers[i]}',
        style: style?.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
          decoration: TextDecoration.underline,
          decorationColor: fg,
        ),
      );
    }
    final wb = workbook;
    if (wb != null) return _fillable(wb, 'b$i', 'blank');
    return _line(context, 'blank');
  }

  /// A writing field (date, signature): never answered by the source;
  /// fillable by the Disciple in their own lesson.
  InlineSpan _field(BuildContext context, int i) {
    final wb = workbook;
    if (wb != null) return _fillable(wb, 'f$i', 'writing space');
    return _line(context, 'writing space');
  }

  InlineSpan _fillable(Workbook wb, String place, String label) => WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: BlankField(
      workbook: wb,
      blockId: block.blockId,
      place: place,
      style: style,
      label: label,
    ),
  );

  /// An empty line to write on: a blank, or a field the source never
  /// answers (a date, a signature).
  InlineSpan _line(BuildContext context, String label) {
    final p = context.palette;
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Semantics(
        label: label,
        child: Container(
          width: 72,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: p.textPrimary, width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

/// The blank marker the converter writes into text.
const blankToken = '[_]';

/// A writing field (date, signature, day, time, place): always empty.
const fieldToken = '[~]';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({this.label, this.title, this.subtitle});

  final String? label;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(
              label!.toUpperCase(),
              style: context.captionStyle.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: pillColors(context, PillTone.brand).$2,
              ),
            ),
          if (title != null)
            Text(
              title!,
              style: AppTypography.sectionTitle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: context.supportingStyle),
          ],
        ],
      ),
    );
  }
}

class _ModuleTitle extends StatelessWidget {
  const _ModuleTitle({required this.block});

  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = pillColors(context, PillTone.info);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_rounded, color: fg, size: 30),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For the Discipler',
                  style: context.captionStyle.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  block.title ?? '',
                  style: AppTypography.sectionTitle.copyWith(
                    fontSize: 20,
                    color: p.textPrimary,
                  ),
                ),
                if (block.subtitle != null)
                  Text(block.subtitle!, style: context.supportingStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bulleted item: its scripture reference (when it leads the bullet) in
/// bold text, then its text.
class _Point extends StatelessWidget {
  const _Point({required this.block, required this.style, this.workbook});

  final Workbook? workbook;

  final ContentBlock block;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    // Green is kept for answers; references read as bold text and the
    // bullets stay quiet (user, 2026-10-07).
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9, right: AppSpacing.sm),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: p.muted, shape: BoxShape.circle),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.reference != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    block.reference!,
                    style: style?.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if ((block.text ?? '').isNotEmpty)
                _RichBlanks(block: block, workbook: workbook, style: style),
            ],
          ),
        ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: p.brand, width: 4)),
      ),
      child: Text(
        text,
        style: AppTypography.sectionTitle.copyWith(
          fontSize: 17,
          fontStyle: FontStyle.italic,
          color: p.textPrimary,
        ),
      ),
    );
  }
}

/// A chart or picture of the printed lesson. The image itself is not in
/// the app yet; its labels are, as blanks or (for the Discipler) answers.
class _Figure extends StatelessWidget {
  const _Figure({required this.block});

  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final answers = block.answerList;
    final blanks = block.body['blanks'] as int? ?? 0;
    final caption = block.body['caption'] as String? ?? '';
    final labels = [
      for (final l in block.body['labels'] as List? ?? const []) '$l',
    ];
    return AppCard(
      fill: AppCardFill.pastel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insert_chart_outlined_rounded, color: p.muted),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  caption.isEmpty ? 'Chart in your printed lesson' : caption,
                  style: context.supportingStyle,
                ),
              ),
            ],
          ),
          if (answers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in answers)
                  AppPill(label: a, tone: PillTone.brand),
              ],
            ),
          ] else if (labels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final l in labels) AppPill(label: l)],
            ),
          ] else if (blanks > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('$blanks labels to write in', style: context.captionStyle),
          ],
        ],
      ),
    );
  }
}

class _VerseWriting extends StatelessWidget {
  const _VerseWriting({
    required this.block,
    required this.style,
    this.workbook,
  });

  final Workbook? workbook;

  final ContentBlock block;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final answers = block.answerList;
    final lines = block.body['lines'] as int? ?? 0;
    final fg = pillColors(context, PillTone.brand).$2;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            block.body['instruction'] as String? ?? '',
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (answers.isNotEmpty)
            for (final line in answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: style?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
          else if (workbook != null)
            VerseField(
              workbook: workbook!,
              blockId: block.blockId,
              lines: lines,
              style: style,
            )
          else
            for (var i = 0; i < lines; i++)
              Container(
                height: 30,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.border)),
                ),
              ),
          if (block.body['followUp'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(block.body['followUp'] as String, style: style),
          ],
        ],
      ),
    );
  }
}

/// The self-rating table, as a list: each question with the four ratings.
class _SelfCheck extends StatelessWidget {
  const _SelfCheck({required this.block, required this.style, this.workbook});

  final Workbook? workbook;

  final ContentBlock block;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final columns = [
      for (final c in (block.body['columns'] as List? ?? const [])) '$c',
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${block.body['header'] ?? ''}',
            style: context.captionStyle.copyWith(fontWeight: FontWeight.w700),
          ),
          for (final (i, q) in block.items.indexed) ...[
            const Divider(height: AppSpacing.lg),
            Text(q, style: style),
            const SizedBox(height: AppSpacing.xs),
            ListenableBuilder(
              listenable: workbook ?? const AlwaysStoppedAnimation(0),
              builder: (context, _) {
                final chosen = workbook?.valueOf(block.blockId, 's$i');
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    for (final c in columns)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: workbook == null
                            ? null
                            : () => workbook!.write(
                                block.blockId,
                                's$i',
                                chosen == c ? '' : c,
                              ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                chosen == c
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: chosen == c
                                    ? pillColors(context, PillTone.brand).$2
                                    : p.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(c, style: context.captionStyle),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
