import 'package:flutter/material.dart';

import '../../../core/format/app_format.dart';
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
/// Below, one coloured line with the lesson's state and the last recorded
/// meeting, then the current lesson's meetings as steps, one marker per
/// recorded meeting in date order, coloured by outcome. There is no
/// "remaining" marker, because a lesson has no fixed number of meetings
/// (ADR-011). [footer] holds the actions the viewer may take.
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
            const SizedBox(height: AppSpacing.md),
            // One line: where the lesson stands and when they last met.
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _stateText(lesson),
                    style: TextStyle(
                      color: pillColors(context, _stateTone(lesson)).$2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (lastRecordedMeetingAt != null)
                    TextSpan(
                      text:
                          '  ·  Last met '
                          '${AppFormat.shortDate(lastRecordedMeetingAt!)}',
                    ),
                ],
              ),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (meetings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              MeetingSteps(meetings: meetings),
            ],
          ],
          ?footer,
        ],
      ),
    );
  }

  static String _stateText(JourneyLesson lesson) => switch (lesson.state) {
    LessonState.inProgress =>
      lesson.startedAt == null
          ? 'In progress'
          : 'In progress since ${AppFormat.shortDate(lesson.startedAt!)}',
    LessonState.notStarted => 'Not started',
    LessonState.submitted => 'Marked finished',
    LessonState.completed => 'Completed',
    LessonState.locked => 'Upcoming',
  };

  static PillTone _stateTone(JourneyLesson lesson) => switch (lesson.state) {
    LessonState.inProgress || LessonState.completed => PillTone.brand,
    LessonState.notStarted || LessonState.submitted => PillTone.warning,
    LessonState.locked => PillTone.neutral,
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
              strokeWidth: size * 0.1,
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
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Text(
                    'of $total',
                    style: text.labelSmall?.copyWith(
                      fontSize: size * 0.14,
                      height: 1.1,
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
