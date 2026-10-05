import 'package:flutter/material.dart';

import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_pill.dart';
import '../domain/attendance_outcome.dart';
import '../domain/journey.dart';
import '../domain/meeting_history_entry.dart';

/// The first thing on a journey page: where the person is now.
///
/// A ring shows lessons completed out of the curriculum (no percentage is
/// printed); beside it the current lesson, its title and the Discipler.
/// Below, the current lesson's meetings as steps, one marker per recorded
/// meeting in date order, coloured by outcome. There is no "remaining"
/// marker, because a lesson has no fixed number of meetings (ADR-011).
/// Pills carry the lesson's state, the outcome counts and the last recorded
/// meeting. [footer] holds the actions the viewer may take.
class CurrentLessonCard extends StatelessWidget {
  const CurrentLessonCard({
    required this.journey,
    required this.history,
    this.disciplerName,
    this.lastRecordedMeetingAt,
    this.ownJourney = false,
    this.footer,
    super.key,
  });

  final DiscipleJourney journey;

  /// The person's meeting history, newest first.
  final List<MeetingHistoryEntry> history;
  final String? disciplerName;

  /// The latest recorded meeting, whatever the outcome (decision S6).
  final DateTime? lastRecordedMeetingAt;
  final bool ownJourney;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final lesson = journey.currentLesson;
    final meetings = lesson == null
        ? const <MeetingHistoryEntry>[]
        : [
            for (final e in history.reversed)
              if (e.lessonNumber == lesson.number && !e.isVoided) e,
          ];
    // Placeholder titles repeat the number ("Lesson 3"); show a title only
    // when it says something more.
    final showTitle =
        lesson != null && lesson.title.trim() != 'Lesson ${lesson.number}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LessonRing(
                total: journey.lessonsTotal,
                completed: journey.lessonsCompleted,
                currentNumber: lesson?.number,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson == null ? 'JOURNEY' : 'CURRENT LESSON',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson == null
                          ? 'All lessons completed'
                          : 'Lesson ${lesson.number}',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showTitle)
                      Text(
                        lesson.title,
                        style: text.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (disciplerName != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Discipler: $disciplerName',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (lesson != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _statePill(lesson),
                if (lastRecordedMeetingAt != null)
                  AppPill(
                    icon: Icons.event_available_rounded,
                    label:
                        'Last recorded meeting '
                        '${AppFormat.shortDate(lastRecordedMeetingAt!)}',
                  )
                else
                  const AppPill(
                    icon: Icons.event_busy_rounded,
                    label: 'No meeting recorded yet',
                  ),
              ],
            ),
            const Divider(height: AppSpacing.lg * 1.5),
            Text(
              lesson.countLine,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            MeetingSteps(meetings: meetings),
            if (meetings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              OutcomePills(meetings: meetings),
            ],
          ],
          ?footer,
        ],
      ),
    );
  }

  Widget _statePill(JourneyLesson lesson) => switch (lesson.state) {
    LessonState.inProgress => AppPill(
      tone: PillTone.brand,
      icon: Icons.play_circle_outline_rounded,
      label: lesson.startedAt == null
          ? 'In progress'
          : 'In progress since ${AppFormat.shortDate(lesson.startedAt!)}',
    ),
    LessonState.notStarted => const AppPill(
      tone: PillTone.warning,
      icon: Icons.hourglass_empty_rounded,
      label: 'Not started',
    ),
    LessonState.submitted => const AppPill(
      tone: PillTone.warning,
      label: 'Marked finished',
    ),
    LessonState.completed => const AppPill(
      tone: PillTone.brand,
      icon: Icons.check_circle_outline_rounded,
      label: 'Completed',
    ),
    LessonState.locked => const AppPill(label: 'Upcoming'),
  };
}

/// "2 Present", "1 Absent" and so on, as pills in a fixed order.
class OutcomePills extends StatelessWidget {
  const OutcomePills({required this.meetings, super.key});

  final List<MeetingHistoryEntry> meetings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in AttendanceOutcome.values)
          if (meetings.any((m) => m.outcome == o))
            AppPill(
              label:
                  '${meetings.where((m) => m.outcome == o).length} ${o.label}',
            ),
      ],
    );
  }
}

/// "2 Present · 1 Late · 1 Excused", in a fixed outcome order.
String outcomeBreakdown(List<MeetingHistoryEntry> meetings) => [
  for (final o in AttendanceOutcome.values)
    if (meetings.any((m) => m.outcome == o))
      '${meetings.where((m) => m.outcome == o).length} ${o.label}',
].join(' · ');

/// The person's overall meeting facts as pills, shown with the meeting
/// history rather than in the current lesson card. A run of two or more
/// recorded absences is stated only in oversight views ([includeConsecutive]).
class MeetingFactPills extends StatelessWidget {
  const MeetingFactPills({
    required this.summary,
    this.includeConsecutive = false,
    super.key,
  });

  final MeetingSummary summary;
  final bool includeConsecutive;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        AppPill(
          icon: Icons.check_rounded,
          label: s.meetingsAttended == 1
              ? '1 meeting attended'
              : '${s.meetingsAttended} meetings attended',
        ),
        AppPill(
          icon: Icons.close_rounded,
          label: s.recordedAbsences == 1
              ? '1 recorded absence'
              : '${s.recordedAbsences} recorded absences',
        ),
        if (s.excused > 0)
          AppPill(icon: Icons.remove_rounded, label: '${s.excused} excused'),
        if (includeConsecutive && s.consecutiveRecordedAbsences >= 2)
          AppPill(
            tone: PillTone.warning,
            icon: Icons.warning_amber_rounded,
            label:
                '${s.consecutiveRecordedAbsences} recorded absences in a row',
          ),
      ],
    );
  }
}

/// Lessons completed out of the curriculum, as a ring with the current
/// lesson number in the middle. Read aloud in words; no percentage.
class LessonRing extends StatelessWidget {
  const LessonRing({
    required this.total,
    required this.completed,
    required this.currentNumber,
    this.size = 76,
    super.key,
  });

  final int total;
  final int completed;
  final int? currentNumber;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = completed == 1
        ? '1 lesson completed'
        : '$completed lessons completed';
    final label = currentNumber == null
        ? '$completed of $total lessons completed'
        : 'Lesson $currentNumber of $total. $done.';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: progressColor(context),
              backgroundColor: neutralFill(context),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentNumber ?? completed}',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Text(
                    'of $total',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One step per recorded meeting of the current lesson, oldest first:
/// a check for Present, a clock for Late, a cross for a recorded absence,
/// a dash for Excused.
class MeetingSteps extends StatelessWidget {
  const MeetingSteps({required this.meetings, super.key});

  final List<MeetingHistoryEntry> meetings;

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return Text(
        'No meeting recorded on this lesson yet.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in meetings)
          Tooltip(
            message: m.outcomeLine,
            child: Semantics(
              label: m.outcomeLine,
              excludeSemantics: true,
              child: _Step(meeting: m),
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.meeting});

  final MeetingHistoryEntry meeting;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (meeting.outcome) {
      AttendanceOutcome.present => pillColors(context, PillTone.brand),
      AttendanceOutcome.late => pillColors(context, PillTone.warning),
      AttendanceOutcome.absent => pillColors(context, PillTone.error),
      AttendanceOutcome.excused => pillColors(context, PillTone.neutral),
    };
    final icon = switch (meeting.outcome) {
      AttendanceOutcome.present => Icons.check_rounded,
      AttendanceOutcome.late => Icons.schedule_rounded,
      AttendanceOutcome.absent => Icons.close_rounded,
      AttendanceOutcome.excused => Icons.remove_rounded,
    };
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

/// Every lesson of the curriculum, collapsed by default: completed ones
/// with their date, the current one, and the rest as upcoming.
class AllLessonsList extends StatelessWidget {
  const AllLessonsList({
    required this.journey,
    this.ownJourney = false,
    super.key,
  });

  final DiscipleJourney journey;
  final bool ownJourney;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card.filled(
      color: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        title: const Text('All lessons'),
        subtitle: Text(journey.summaryLine),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          for (final l in journey.lessons)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ListTile(
                dense: true,
                tileColor: neutralFill(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(
                  switch (l.state) {
                    LessonState.completed => Icons.check_circle_rounded,
                    LessonState.locked => Icons.lock_outline_rounded,
                    _ => Icons.radio_button_checked_rounded,
                  },
                  color: switch (l.state) {
                    LessonState.completed => p.textPrimary,
                    LessonState.locked => p.disabled,
                    _ => p.warning,
                  },
                ),
                title: Text('Lesson ${l.number} · ${l.title}'),
                subtitle: Text(l.statusLine(ownJourney: ownJourney)),
              ),
            ),
        ],
      ),
    );
  }
}
