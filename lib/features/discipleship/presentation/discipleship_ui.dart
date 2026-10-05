import 'package:flutter/material.dart';

import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_text_link.dart';
import '../domain/attendance_outcome.dart';
import '../domain/disciple_progress_summary.dart';
import '../domain/journey.dart';
import '../domain/meeting_history_entry.dart';

/// Factual journey progress as one continuous bar: the share of the ACTIVE
/// curriculum's lessons that are COMPLETED. Not a stepper (user decision of
/// 2026-10-05): steps are kept for the meetings of the current lesson, in
/// [CurrentLessonCard].
///
/// No percentage is printed and nothing is compared. The full form adds the
/// factual line beneath; the compact form is the bar alone, for rows that
/// print their own lines.
class JourneyProgressBar extends StatelessWidget {
  const JourneyProgressBar({
    required this.total,
    required this.completed,
    required this.currentNumber,
    this.submitted = false,
    this.line,
    this.compact = false,
    super.key,
  });

  final int total;
  final int completed;

  /// Null when every lesson is completed.
  final int? currentNumber;
  final bool submitted;

  /// The factual line shown under the full form.
  final String? line;
  final bool compact;

  String get _semantics {
    final done = completed == 1
        ? '1 lesson completed'
        : '$completed lessons completed';
    if (currentNumber == null) return '$completed of $total lessons completed';
    final state = submitted ? 'awaiting confirmation' : 'current';
    return 'Lesson $currentNumber of $total. $done. '
        'Lesson $currentNumber $state.';
  }

  @override
  Widget build(BuildContext context) {
    final segments = ClipRRect(
      borderRadius: AppRadius.pill,
      child: LinearProgressIndicator(
        value: total == 0 ? 0 : completed / total,
        minHeight: compact ? 6 : 8,
        color: progressColor(context),
        backgroundColor: neutralFill(context),
      ),
    );

    return Semantics(
      label: _semantics,
      container: true,
      child: ExcludeSemantics(
        child: compact
            ? segments
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  segments,
                  if (line != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(line!, style: context.supportingStyle),
                  ],
                ],
              ),
      ),
    );
  }
}

/// One Disciple in My Disciples and on Home: an avatar, the name and the
/// lesson they are on, a stepper over the curriculum's lessons, and pills
/// for the lesson's state and the last recorded meeting. The meeting count
/// stays on Disciple detail.
class DiscipleProgressRow extends StatelessWidget {
  const DiscipleProgressRow({required this.disciple, this.onTap, super.key});

  final DiscipleProgressSummary disciple;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = disciple;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: d.fullName),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.fullName,
                  style: AppTypography.body.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(d.lessonLine, style: context.supportingStyle),
                const SizedBox(height: AppSpacing.xs),
                LessonStepper(
                  total: d.lessonsTotal,
                  completed: d.lessonsCompleted,
                  currentNumber: d.currentLessonNumber,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (d.currentLessonNumber == null)
                      const AppPill(
                        tone: PillTone.brand,
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Every lesson completed',
                      )
                    else if (d.currentState == LessonState.inProgress)
                      AppPill(
                        tone: PillTone.brand,
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Lesson ${d.currentLessonNumber} in progress',
                      )
                    else
                      AppPill(
                        tone: PillTone.warning,
                        icon: Icons.hourglass_empty_rounded,
                        label: 'Lesson ${d.currentLessonNumber} not started',
                      ),
                    AppPill(
                      icon: d.lastRecordedMeetingAt == null
                          ? Icons.event_busy_rounded
                          : Icons.event_available_rounded,
                      label: d.lastMeetingLine,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
    );
    return MergeSemantics(
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}

/// One segment per lesson of the curriculum: completed lessons filled, the
/// current one outlined, the rest empty. Used where several people are
/// listed, so their positions in the curriculum compare at a glance
/// without any percentage.
class LessonStepper extends StatelessWidget {
  const LessonStepper({
    required this.total,
    required this.completed,
    required this.currentNumber,
    super.key,
  });

  final int total;
  final int completed;

  /// Null when every lesson is completed.
  final int? currentNumber;

  @override
  Widget build(BuildContext context) {
    final track = neutralFill(context);
    final label = currentNumber == null
        ? '$completed of $total lessons completed'
        : 'Lesson $currentNumber of $total. '
              '${completed == 1 ? '1 lesson' : '$completed lessons'} completed.';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        children: [
          for (var n = 1; n <= total; n++) ...[
            if (n > 1) const SizedBox(width: 3),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: n <= completed
                      ? progressColor(context)
                      : n == currentNumber
                      ? progressColor(context).withValues(alpha: 0.35)
                      : track,
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One recorded outcome in a person's meeting history. Voided rows stay,
/// greyed, with who voided them. Shared notes open on request.
class MeetingHistoryRow extends StatefulWidget {
  const MeetingHistoryRow({required this.entry, super.key});

  final MeetingHistoryEntry entry;

  @override
  State<MeetingHistoryRow> createState() => _MeetingHistoryRowState();
}

class _MeetingHistoryRowState extends State<MeetingHistoryRow> {
  bool _showNotes = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = widget.entry;
    final faded = e.isVoided ? p.muted : p.textPrimary;
    final recorder = e.isVoided
        ? 'Voided${e.voidedByName == null ? '' : ' by ${e.voidedByName}'}'
        : e.recordedByName == null
        ? null
        : 'Recorded by ${e.recordedByName}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppFormat.shortDate(e.occurredAt)} · Lesson ${e.lessonNumber}',
                  style: AppTypography.body.copyWith(
                    color: faded,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.outcomeLine,
                  style: AppTypography.supporting.copyWith(color: faded),
                ),
                if (recorder != null)
                  Text(recorder, style: context.captionStyle),
              ],
            ),
          ),
          if (e.notes != null) ...[
            AppTextLink(
              label: _showNotes ? 'Hide notes' : 'Show notes',
              onTap: () => setState(() => _showNotes = !_showNotes),
            ),
            if (_showNotes) Text(e.notes!, style: context.supportingStyle),
          ],
        ],
      ),
    );
  }
}

/// The four outcomes for one Disciple, as four large choices, each with
/// its own icon and colour: Present in lime, Late in amber, Absent in red,
/// Excused in grey. Nothing is preselected unless the form sets it, because
/// every outcome is stated explicitly (ADR-009).
class OutcomeSelector extends StatelessWidget {
  const OutcomeSelector({
    required this.value,
    required this.onChanged,
    required this.personName,
    super.key,
  });

  final AttendanceOutcome? value;
  final ValueChanged<AttendanceOutcome> onChanged;
  final String personName;

  static PillTone toneOf(AttendanceOutcome o) => switch (o) {
    AttendanceOutcome.present => PillTone.brand,
    AttendanceOutcome.late => PillTone.warning,
    AttendanceOutcome.absent => PillTone.error,
    AttendanceOutcome.excused => PillTone.neutral,
  };

  static IconData iconOf(AttendanceOutcome o) => switch (o) {
    AttendanceOutcome.present => Icons.check_rounded,
    AttendanceOutcome.late => Icons.schedule_rounded,
    AttendanceOutcome.absent => Icons.close_rounded,
    AttendanceOutcome.excused => Icons.remove_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (final o in AttendanceOutcome.values) ...[
          if (o != AttendanceOutcome.values.first) const SizedBox(width: 6),
          Expanded(child: _choice(context, p, o)),
        ],
      ],
    );
  }

  Widget _choice(BuildContext context, AppPalette p, AttendanceOutcome o) {
    final selected = value == o;
    final (bg, fg) = pillColors(context, toneOf(o));
    return Semantics(
      label: '$personName: ${o.label}',
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: selected ? bg : neutralFill(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(o),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconOf(o), size: 20, color: selected ? fg : p.muted),
                const SizedBox(height: 2),
                Text(
                  o.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? fg : p.muted,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
