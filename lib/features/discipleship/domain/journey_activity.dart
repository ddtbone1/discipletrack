import 'package:flutter/foundation.dart';

import 'attendance_outcome.dart';
import 'journey.dart';
import 'meeting_history_entry.dart';

/// What kind of factual event an activity is.
enum ActivityKind { lessonStarted, lessonCompleted, meeting, meetingVoided }

/// One factual event in a person's journey, as plain words.
///
/// Built only from recorded facts: lesson start and completion dates, and
/// recorded or voided meetings. Nothing is inferred: no "missed meeting",
/// no inactivity, no "falling behind" (ADR-014).
@immutable
class ActivityEvent {
  const ActivityEvent({
    required this.at,
    required this.kind,
    required this.title,
    this.detail,
    this.outcome,
  });

  final DateTime at;
  final ActivityKind kind;

  /// "Lesson 3 completed", "Meeting recorded".
  final String title;

  /// "Lesson 3 · Present", "by Dino Reyes".
  final String? detail;

  /// For a recorded meeting, its outcome.
  final AttendanceOutcome? outcome;
}

/// The journey's factual events, newest first.
///
/// [ownJourney] leaves out who marked a lesson completed, as on the
/// person's own journey elsewhere. At the same moment, a lesson's start is
/// placed after the meeting that started it, so the story reads naturally
/// newest first.
List<ActivityEvent> journeyActivity(
  DiscipleJourney journey,
  List<MeetingHistoryEntry> history, {
  bool ownJourney = false,
}) {
  final events = <(ActivityEvent, int)>[];

  for (final l in journey.lessons) {
    if (l.startedAt != null) {
      events.add((
        ActivityEvent(
          at: l.startedAt!,
          kind: ActivityKind.lessonStarted,
          title: 'Lesson ${l.number} started',
        ),
        0,
      ));
    }
    if (l.state == LessonState.completed && l.completedAt != null) {
      events.add((
        ActivityEvent(
          at: l.completedAt!,
          kind: ActivityKind.lessonCompleted,
          title: 'Lesson ${l.number} completed',
          detail: ownJourney || l.confirmedByName == null
              ? null
              : 'by ${l.confirmedByName}',
        ),
        2,
      ));
    }
  }

  for (final m in history) {
    // A voided record stays in the story, but never reads as a counted
    // meeting: no outcome (it would read as attendance), no outcome colour,
    // and it says it does not count.
    events.add((
      ActivityEvent(
        at: m.occurredAt,
        kind: ActivityKind.meeting,
        title: !m.isVoided
            ? 'Meeting recorded'
            : m.isRemoved
            ? 'Listed in a meeting'
            : 'Meeting recorded',
        detail: [
          'Lesson ${m.lessonNumber}',
          if (!m.isVoided) m.outcome.label else 'Not counted',
        ].join(' · '),
        outcome: m.isVoided ? null : m.outcome,
      ),
      1,
    ));
    if (m.isVoided && m.voidedAt != null) {
      events.add((
        ActivityEvent(
          at: m.voidedAt!,
          kind: ActivityKind.meetingVoided,
          // Removing one person is not voiding the meeting.
          title: m.isRemoved ? 'Removed from meeting' : 'Meeting voided',
          detail: [
            'Lesson ${m.lessonNumber}',
            if (m.voidedByName != null) 'by ${m.voidedByName}',
          ].join(' · '),
        ),
        3,
      ));
    }
  }

  events.sort((a, b) {
    final byTime = b.$1.at.compareTo(a.$1.at);
    return byTime != 0 ? byTime : b.$2.compareTo(a.$2);
  });
  return [for (final e in events) e.$1];
}
