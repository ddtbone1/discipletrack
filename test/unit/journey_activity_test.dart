import 'package:discipletrack/features/discipleship/domain/attendance_outcome.dart';
import 'package:discipletrack/features/discipleship/domain/journey.dart';
import 'package:discipletrack/features/discipleship/domain/journey_activity.dart';
import 'package:discipletrack/features/discipleship/domain/meeting_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

JourneyLesson _lesson(
  int n,
  LessonState state, {
  DateTime? started,
  DateTime? completed,
  String? by,
}) => JourneyLesson(
  lessonId: 'l$n',
  number: n,
  title: 'L$n',
  state: state,
  creditedCount: 0,
  isCurrent: state == LessonState.inProgress,
  startedAt: started,
  completedAt: completed,
  confirmedByName: by,
);

MeetingHistoryEntry _meeting(
  DateTime at,
  int lesson,
  AttendanceOutcome outcome, {
  DateTime? voidedAt,
}) => MeetingHistoryEntry(
  meetingId: 'm${at.day}',
  participantId: 'p${at.day}',
  occurredAt: at,
  lessonNumber: lesson,
  lessonTitle: 'L$lesson',
  outcome: outcome,
  isCredited: outcome.countsTowardLesson && voidedAt == null,
  isVoided: voidedAt != null,
  voidedAt: voidedAt,
  voidedByName: voidedAt == null ? null : 'Lea Santos',
);

void main() {
  final sep1 = DateTime.utc(2026, 9, 1, 10);
  final sep8 = DateTime.utc(2026, 9, 8, 10);
  final sep9 = DateTime.utc(2026, 9, 9, 10);
  final sep10 = DateTime.utc(2026, 9, 10, 10);
  final sep15 = DateTime.utc(2026, 9, 15, 10);
  final sep20 = DateTime.utc(2026, 9, 20, 10);

  final journey = DiscipleJourney([
    _lesson(
      1,
      LessonState.completed,
      started: sep1,
      completed: sep10,
      by: 'Dino Reyes',
    ),
    _lesson(2, LessonState.inProgress, started: sep15),
    _lesson(3, LessonState.locked),
  ]);
  final history = [
    _meeting(sep20, 2, AttendanceOutcome.absent),
    _meeting(sep15, 2, AttendanceOutcome.present),
    _meeting(sep8, 1, AttendanceOutcome.late, voidedAt: sep9),
    _meeting(sep1, 1, AttendanceOutcome.present),
  ];

  test('events are factual and newest first; a lesson start follows the '
      'meeting that started it', () {
    final events = journeyActivity(journey, history);
    expect(
      [for (final e in events) e.title],
      [
        'Meeting recorded',
        'Meeting recorded',
        'Lesson 2 started',
        'Lesson 1 completed',
        'Meeting voided',
        'Meeting recorded',
        'Meeting recorded',
        'Lesson 1 started',
      ],
    );
    expect(events.first.detail, 'Lesson 2 · Absent');
    expect(events[3].detail, 'by Dino Reyes');
    expect(events[4].detail, 'Lesson 1 · by Lea Santos');
  });

  test('nothing is inferred: no missed meetings or inactivity', () {
    final events = journeyActivity(journey, history);
    for (final e in events) {
      final words = '${e.title} ${e.detail ?? ''}'.toLowerCase();
      expect(words, isNot(contains('missed')));
      expect(words, isNot(contains('inactive')));
    }
    // A locked lesson with no dates contributes nothing.
    expect(events.where((e) => e.title.contains('Lesson 3')), isEmpty);
  });

  test('a voided record says so and carries no outcome colour', () {
    final events = journeyActivity(journey, history);
    final voidedRecord = events.firstWhere(
      (e) => e.kind == ActivityKind.meeting && e.at == sep8,
    );
    expect(voidedRecord.detail, 'Lesson 1 · Late · Voided');
    expect(voidedRecord.outcome, isNull);
    // A record that stands keeps its outcome.
    expect(events.first.outcome, AttendanceOutcome.absent);
  });

  test(
    'a person removed from a meeting is not told the meeting was voided',
    () {
      final removed = MeetingHistoryEntry(
        meetingId: 'm21',
        participantId: 'p21',
        occurredAt: DateTime.utc(2026, 9, 21, 4),
        lessonNumber: 1,
        lessonTitle: 'L1',
        outcome: AttendanceOutcome.present,
        isCredited: false,
        isVoided: true,
        isRemoved: true,
        voidedAt: DateTime.utc(2026, 10, 6, 4),
        voidedByName: 'Dino Reyes',
      );
      final events = journeyActivity(
        DiscipleJourney([_lesson(1, LessonState.notStarted)]),
        [removed],
      );
      expect(
        [for (final e in events) e.title],
        ['Removed from meeting', 'Meeting recorded'],
      );
      expect(events.first.detail, 'Lesson 1 · by Dino Reyes');
      expect(events.last.detail, 'Lesson 1 · Present · Voided');
      expect(events.last.outcome, isNull);
    },
  );

  test('isRemoved is set only when the person\'s row, not the meeting, was '
      'voided', () {
    Map<String, dynamic> row(String meeting, String participant) => {
      'meeting_id': 'm',
      'participant_id': 'p',
      'occurred_at': '2026-09-21T04:00:00Z',
      'lesson_number': 1,
      'lesson_title': 'L1',
      'meeting_status': meeting,
      'participant_status': participant,
      'attendance_status': 'PRESENT',
      'is_credited': false,
    };
    expect(
      MeetingHistoryEntry.fromMap(row('RECORDED', 'VOIDED')).isRemoved,
      isTrue,
    );
    expect(
      MeetingHistoryEntry.fromMap(row('VOIDED', 'RECORDED')).isRemoved,
      isFalse,
    );
    expect(
      MeetingHistoryEntry.fromMap(row('RECORDED', 'RECORDED')).isRemoved,
      isFalse,
    );
  });

  test('on the person\'s own journey, who marked a lesson is left out', () {
    final events = journeyActivity(journey, history, ownJourney: true);
    final completed = events.firstWhere(
      (e) => e.kind == ActivityKind.lessonCompleted,
    );
    expect(completed.detail, isNull);
  });
}
