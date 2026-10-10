import 'package:flutter/foundation.dart';

import '../../../core/format/app_format.dart';

/// Where one lesson stands for one person.
///
/// [submitted] is READY_FOR_COMPLETION, which no operation enters since
/// ADR-015 (the Discipler marks a lesson completed in one step). It is kept
/// only so an unexpected row still reads sensibly, and is never counted as
/// completed.
enum LessonState { locked, notStarted, inProgress, submitted, completed }

/// "5 counted meetings": the lesson's Present and Late meetings, a fact,
/// never a fraction of a target. Absent, Excused and voided records are
/// not counted, so the line says "counted" rather than "recorded". Meeting
/// count does not determine completion (ADR-017).
String meetingCountLine(int count) => switch (count) {
  0 => 'No counted meetings yet',
  1 => '1 counted meeting',
  _ => '$count counted meetings',
};

/// One row of `get_disciple_journey()`.
@immutable
class JourneyLesson {
  const JourneyLesson({
    required this.lessonId,
    required this.number,
    required this.title,
    required this.state,
    required this.creditedCount,
    required this.isCurrent,
    this.startedAt,
    this.readyAt,
    this.submittedByName,
    this.completedAt,
    this.confirmedByName,
    this.canRecord = false,
    this.canComplete = false,
    this.canUndo = false,
  });

  factory JourneyLesson.fromMap(Map<String, dynamic> map) {
    final status = map['status'] as String;
    final locked = map['is_locked'] as bool;
    return JourneyLesson(
      lessonId: map['lesson_id'] as String,
      number: map['lesson_number'] as int,
      title: map['title'] as String,
      state: locked
          ? LessonState.locked
          : switch (status) {
              'NOT_STARTED' => LessonState.notStarted,
              'IN_PROGRESS' => LessonState.inProgress,
              'READY_FOR_COMPLETION' => LessonState.submitted,
              'COMPLETED' => LessonState.completed,
              _ => throw ArgumentError('Unknown lesson status: $status'),
            },
      creditedCount: map['credited_count'] as int,
      isCurrent: map['is_current'] as bool,
      startedAt: _date(map['started_at']),
      readyAt: _date(map['ready_at']),
      submittedByName: map['submitted_by_name'] as String?,
      completedAt: _date(map['completed_at']),
      confirmedByName: map['confirmed_by_name'] as String?,
      canRecord: map['can_record'] as bool? ?? false,
      canComplete: map['can_complete'] as bool? ?? false,
      canUndo: map['can_undo'] as bool? ?? false,
    );
  }

  final String lessonId;
  final int number;
  final String title;
  final LessonState state;

  /// Credited meetings for this lesson. A fact; it decides nothing.
  final int creditedCount;
  final bool isCurrent;
  final DateTime? startedAt;
  final DateTime? readyAt;
  final String? submittedByName;
  final DateTime? completedAt;

  /// Who marked the lesson completed (ADR-015).
  final String? confirmedByName;

  /// The viewer may record a meeting for this lesson now. A courtesy for
  /// presentation; the database decides again on every write.
  final bool canRecord;

  /// The viewer may mark this lesson completed now (ADR-015). Courtesy only.
  final bool canComplete;

  /// The viewer may undo this lesson's completion: it is the latest
  /// completed lesson and nothing is recorded on the next one yet.
  final bool canUndo;

  String get countLine => meetingCountLine(creditedCount);

  /// Where the lesson stands, in words (plan section F2). [ownJourney] is
  /// the Disciple's own wording on My Journey.
  String statusLine({bool ownJourney = false}) {
    String date(DateTime d) => AppFormat.shortDate(d);
    return switch (state) {
      LessonState.locked => 'Opens after Lesson ${number - 1} is completed.',
      LessonState.notStarted =>
        ownJourney
            ? 'Not started yet. It starts with your first counted meeting.'
            : 'Not started. It starts with the first counted meeting.',
      LessonState.inProgress =>
        startedAt == null
            ? 'In progress'
            : 'In progress since ${date(startedAt!)}',
      LessonState.submitted =>
        ownJourney
            ? 'Finished. Your Leader will confirm it.'
            : [
                'Marked finished',
                if (submittedByName != null) 'by $submittedByName',
                if (readyAt != null) 'on ${date(readyAt!)}',
                '· Awaiting Leader confirmation',
              ].join(' '),
      LessonState.completed => [
        completedAt == null ? 'Completed' : 'Completed ${date(completedAt!)}',
        if (!ownJourney && confirmedByName != null) '· by $confirmedByName',
      ].join(' '),
    };
  }
}

/// A person's journey through the ACTIVE curriculum.
@immutable
class DiscipleJourney {
  const DiscipleJourney(this.lessons);

  final List<JourneyLesson> lessons;

  /// From the curriculum, never a literal (BR-036).
  int get lessonsTotal => lessons.length;

  /// The lessons this journey has reached: every completed lesson and the
  /// current one (DATABASE_CONSTRAINTS section 11, Reached Lessons). My
  /// Journey opens only these, whatever else the reader may read elsewhere
  /// (ADR-023 decision 10).
  Set<String> get reachedLessonIds => {
    for (final l in lessons)
      if (l.state == LessonState.completed || l.isCurrent) l.lessonId,
  };

  /// Confirmed COMPLETED only; a submitted lesson is not completed.
  int get lessonsCompleted =>
      lessons.where((l) => l.state == LessonState.completed).length;

  /// The lesson being worked on, or null when every lesson is completed.
  JourneyLesson? get currentLesson {
    for (final l in lessons) {
      if (l.isCurrent) return l;
    }
    return null;
  }

  bool get canRecord => currentLesson?.canRecord ?? false;

  /// The latest completed lesson, when the viewer may still undo it.
  JourneyLesson? get undoableLesson {
    for (final l in lessons) {
      if (l.canUndo) return l;
    }
    return null;
  }

  /// "Lesson 4 of 12 · 3 lessons completed · Lesson 4 current", or
  /// "awaiting confirmation" once it is submitted. No percentage.
  String get summaryLine {
    final current = currentLesson;
    if (current == null) {
      return '$lessonsCompleted of $lessonsTotal lessons completed';
    }
    final completed = lessonsCompleted == 1
        ? '1 lesson completed'
        : '$lessonsCompleted lessons completed';
    final state = current.state == LessonState.submitted
        ? 'awaiting confirmation'
        : 'current';
    return 'Lesson ${current.number} of $lessonsTotal · $completed · '
        'Lesson ${current.number} $state';
  }
}

/// `get_disciple_context()`: who the person is, for the detail header.
@immutable
class DiscipleContext {
  const DiscipleContext({
    required this.membershipId,
    required this.fullName,
    required this.isPaired,
    this.dGroupName,
    this.disciplerName,
  });

  factory DiscipleContext.fromMap(Map<String, dynamic> map) => DiscipleContext(
    membershipId: map['church_membership_id'] as String,
    fullName: map['full_name'] as String,
    dGroupName: map['d_group_name'] as String?,
    disciplerName: map['discipler_name'] as String?,
    isPaired: map['is_paired'] as bool,
  );

  final String membershipId;
  final String fullName;
  final String? dGroupName;
  final String? disciplerName;
  final bool isPaired;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// `get_disciple_meeting_summary()`: meeting facts as counts and dates
/// (DC section 11). No ratio, no percentage, no condition.
@immutable
class MeetingSummary {
  const MeetingSummary({
    required this.meetingsAttended,
    required this.recordedAbsences,
    required this.excused,
    required this.consecutiveRecordedAbsences,
    this.lastRecordedMeetingAt,
  });

  factory MeetingSummary.fromMap(Map<String, dynamic> map) => MeetingSummary(
    meetingsAttended: map['meetings_attended'] as int,
    recordedAbsences: map['recorded_absences'] as int,
    excused: map['excused'] as int,
    consecutiveRecordedAbsences: map['consecutive_recorded_absences'] as int,
    lastRecordedMeetingAt: _date(map['last_recorded_meeting_at']),
  );

  final int meetingsAttended;
  final int recordedAbsences;
  final int excused;
  final int consecutiveRecordedAbsences;

  /// The latest recorded meeting, whatever the outcome (decision S6).
  final DateTime? lastRecordedMeetingAt;

  /// "3 meetings attended · 1 recorded absence · Last recorded meeting
  /// Sep 28". With [includeConsecutive], a run of two or more recorded
  /// absences is stated too, as a fact (oversight views only).
  String factsLine({bool includeConsecutive = false}) {
    return [
      meetingsAttended == 1
          ? '1 meeting attended'
          : '$meetingsAttended meetings attended',
      recordedAbsences == 1
          ? '1 recorded absence'
          : '$recordedAbsences recorded absences',
      if (includeConsecutive && consecutiveRecordedAbsences >= 2)
        '$consecutiveRecordedAbsences consecutive recorded absences',
      if (lastRecordedMeetingAt == null)
        'No meeting recorded yet'
      else
        'Last recorded meeting ${AppFormat.shortDate(lastRecordedMeetingAt!)}',
    ].join(' · ');
  }
}

/// `get_progress_summary()`: figures for Home within the caller's scope.
@immutable
class ProgressSummary {
  const ProgressSummary({this.activeDiscipleships});

  factory ProgressSummary.fromMap(Map<String, dynamic> map) =>
      ProgressSummary(activeDiscipleships: map['active_discipleships'] as int?);

  /// Church-wide, for the Coordinator only; null for everyone else.
  final int? activeDiscipleships;
}
