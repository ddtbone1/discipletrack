import 'package:flutter/foundation.dart';

import '../../../core/format/app_format.dart';
import 'journey.dart';

/// One row of `list_disciple_progress()`: a Disciple as their Discipler sees
/// them in My Disciples. Factual figures only; no ranking and no ratio.
@immutable
class DiscipleProgressSummary {
  const DiscipleProgressSummary({
    required this.membershipId,
    required this.fullName,
    required this.lessonsTotal,
    required this.lessonsCompleted,
    required this.creditedCount,
    required this.recordedAbsences,
    this.currentLessonNumber,
    this.currentLessonTitle,
    this.currentState,
    this.lastRecordedMeetingAt,
  });

  factory DiscipleProgressSummary.fromMap(Map<String, dynamic> map) =>
      DiscipleProgressSummary(
        membershipId: map['church_membership_id'] as String,
        fullName: map['full_name'] as String,
        currentLessonNumber: map['current_lesson_number'] as int?,
        currentLessonTitle: map['current_lesson_title'] as String?,
        currentState: switch (map['current_status'] as String?) {
          'IN_PROGRESS' => LessonState.inProgress,
          'READY_FOR_COMPLETION' => LessonState.submitted,
          'NOT_STARTED' => LessonState.notStarted,
          _ => null,
        },
        creditedCount: map['credited_count'] as int,
        lessonsTotal: map['lessons_total'] as int,
        lessonsCompleted: map['lessons_completed'] as int,
        lastRecordedMeetingAt: map['last_recorded_meeting_at'] == null
            ? null
            : DateTime.parse(map['last_recorded_meeting_at'] as String),
        recordedAbsences: map['recorded_absences'] as int,
      );

  final String membershipId;
  final String fullName;

  /// Null when every lesson is completed.
  final int? currentLessonNumber;
  final String? currentLessonTitle;
  final LessonState? currentState;
  final int creditedCount;
  final int lessonsTotal;
  final int lessonsCompleted;
  final DateTime? lastRecordedMeetingAt;
  final int recordedAbsences;

  /// "Lesson 8 of 12".
  String get lessonLine => currentLessonNumber == null
      ? '$lessonsCompleted of $lessonsTotal lessons completed'
      : 'Lesson $currentLessonNumber of $lessonsTotal';

  /// "7 completed · Lesson 8 current", or "awaiting confirmation".
  String get stateLine {
    if (currentLessonNumber == null) return 'Every lesson completed';
    final state = currentState == LessonState.submitted
        ? 'awaiting confirmation'
        : 'current';
    return '$lessonsCompleted completed · Lesson $currentLessonNumber $state';
  }

  /// "Last recorded meeting Oct 1": the latest recorded meeting, whatever
  /// the outcome (decision S6), or "No meeting recorded yet".
  String get lastMeetingLine => lastRecordedMeetingAt == null
      ? 'No meeting recorded yet'
      : 'Last recorded meeting ${AppFormat.shortDate(lastRecordedMeetingAt!)}';

  /// Longest since the last recorded meeting first; never-recorded first of
  /// all. An order, not a ranking (plan section F1, item 12).
  static int byLongestSinceLastMeeting(
    DiscipleProgressSummary a,
    DiscipleProgressSummary b,
  ) {
    final x = a.lastRecordedMeetingAt;
    final y = b.lastRecordedMeetingAt;
    if (x == null && y == null) return a.fullName.compareTo(b.fullName);
    if (x == null) return -1;
    if (y == null) return 1;
    final c = x.compareTo(y);
    return c != 0 ? c : a.fullName.compareTo(b.fullName);
  }
}
