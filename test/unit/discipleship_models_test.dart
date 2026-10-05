import 'package:discipletrack/app/router.dart';
import 'package:discipletrack/app/routes.dart';
import 'package:discipletrack/features/discipleship/data/discipleship_repository.dart';
import 'package:discipletrack/features/discipleship/domain/attendance_outcome.dart';
import 'package:discipletrack/features/discipleship/domain/disciple_progress_summary.dart';
import 'package:discipletrack/features/discipleship/domain/journey.dart';
import 'package:discipletrack/features/discipleship/domain/meeting_draft.dart';
import 'package:discipletrack/features/discipleship/domain/meeting_history_entry.dart';
import 'package:discipletrack/features/session/application/session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _lesson(
  int n, {
  String status = 'NOT_STARTED',
  bool current = false,
  bool locked = false,
  int credited = 0,
  int? recommended,
}) => {
  'lesson_id': 'l$n',
  'lesson_number': n,
  'title': 'Lesson $n',
  'status': status,
  'credited_count': credited,
  'submission_minimum': 1,
  'recommended_meetings': recommended,
  'started_at': null,
  'ready_at': null,
  'submitted_by_name': null,
  'completed_at': null,
  'confirmed_by_name': null,
  'is_current': current,
  'is_locked': locked,
  'can_record': current,
};

void main() {
  group('meeting count line', () {
    test(
      'a count, never a fraction; typical only when the policy gives one',
      () {
        expect(meetingCountLine(0), 'No meetings recorded yet');
        expect(meetingCountLine(1), '1 meeting recorded');
        expect(meetingCountLine(5), '5 meetings recorded');
        expect(
          meetingCountLine(5, recommended: 4),
          '5 meetings recorded · Typical: 4',
        );
        expect(meetingCountLine(5, recommended: 4), isNot(contains('/')));
      },
    );
  });

  group('AttendanceOutcome', () {
    test('Present and Late count toward the lesson; Absent and Excused do '
        'not', () {
      expect(
        {for (final o in AttendanceOutcome.values) o: o.countsTowardLesson},
        {
          AttendanceOutcome.present: true,
          AttendanceOutcome.late: true,
          AttendanceOutcome.absent: false,
          AttendanceOutcome.excused: false,
        },
      );
      expect(AttendanceOutcome.fromDb('LATE'), AttendanceOutcome.late);
      expect(() => AttendanceOutcome.fromDb('MAYBE'), throwsArgumentError);
    });
  });

  group('DiscipleJourney', () {
    DiscipleJourney journey(List<Map<String, dynamic>> rows) =>
        DiscipleJourney([for (final r in rows) JourneyLesson.fromMap(r)]);

    test('completed counts confirmed COMPLETED only; a submitted lesson is '
        'the current one, awaiting confirmation', () {
      final j = journey([
        _lesson(1, status: 'COMPLETED'),
        _lesson(2, status: 'READY_FOR_COMPLETION', current: true, credited: 6),
        _lesson(3, locked: true),
      ]);
      expect(j.lessonsTotal, 3);
      expect(j.lessonsCompleted, 1);
      expect(j.currentLesson!.number, 2);
      expect(j.currentLesson!.state, LessonState.submitted);
      expect(
        j.summaryLine,
        'Lesson 2 of 3 · 1 lesson completed · Lesson 2 awaiting confirmation',
      );
      expect(j.lessons[2].state, LessonState.locked);
    });

    test('the total comes from the curriculum rows, not a literal', () {
      final j = journey([
        for (var n = 1; n <= 10; n++)
          _lesson(n, current: n == 1, locked: n > 1),
      ]);
      expect(j.lessonsTotal, 10);
      expect(
        j.summaryLine,
        'Lesson 1 of 10 · 0 lessons completed · Lesson 1 current',
      );
      expect(j.summaryLine, isNot(contains('%')));
    });

    test('with every lesson completed there is no current lesson', () {
      final j = journey([
        _lesson(1, status: 'COMPLETED'),
        _lesson(2, status: 'COMPLETED'),
      ]);
      expect(j.currentLesson, isNull);
      expect(j.canRecord, isFalse);
      expect(j.summaryLine, '2 of 2 lessons completed');
    });

    test('canRecord follows the current lesson\'s courtesy flag', () {
      expect(journey([_lesson(1, current: true)]).canRecord, isTrue);
    });
  });

  group('MeetingHistoryEntry', () {
    MeetingHistoryEntry entry(
      String outcome, {
      bool credited = false,
      int? ordinal,
      String meetingStatus = 'RECORDED',
    }) => MeetingHistoryEntry.fromMap({
      'meeting_id': 'm',
      'participant_id': 'p',
      'occurred_at': '2026-09-20T12:00:00Z',
      'lesson_number': 2,
      'lesson_title': 'Lesson 2',
      'meeting_status': meetingStatus,
      'participant_status': 'RECORDED',
      'attendance_status': outcome,
      'is_credited': credited,
      'ordinal': ordinal,
      'recorded_by_name': 'Mark Reyes',
      'notes': null,
      'voided_at': null,
      'voided_by_name': null,
    });

    test('each outcome reads as a fact, with no missed label', () {
      expect(
        entry('PRESENT', credited: true, ordinal: 3).outcomeLine,
        'Meeting 3 · Present · Counted',
      );
      expect(
        entry('ABSENT').outcomeLine,
        'Absent · Not counted · Recorded absence',
      );
      expect(entry('EXCUSED').outcomeLine, 'Excused · Not counted');
      expect(
        entry('PRESENT', meetingStatus: 'VOIDED').outcomeLine,
        'Present · Voided',
      );
      for (final o in ['PRESENT', 'LATE', 'ABSENT', 'EXCUSED']) {
        expect(entry(o).outcomeLine.toLowerCase(), isNot(contains('missed')));
      }
    });
  });

  group('DiscipleProgressSummary', () {
    DiscipleProgressSummary row(
      String name, {
      DateTime? last,
      String status = 'IN_PROGRESS',
      int? lesson = 8,
    }) => DiscipleProgressSummary.fromMap({
      'church_membership_id': name,
      'full_name': name,
      'current_lesson_number': lesson,
      'current_lesson_title': 'Lesson',
      'current_status': status,
      'credited_count': 2,
      'lessons_total': 12,
      'lessons_completed': 7,
      'last_recorded_meeting_at': last?.toIso8601String(),
      'recorded_absences': 1,
    });

    test('lines are factual', () {
      final r = row('Ana', last: DateTime.utc(2026, 10, 1, 12));
      expect(r.lessonLine, 'Lesson 8 of 12');
      expect(r.stateLine, '7 completed · Lesson 8 current');
      expect(r.lastMeetingLine, 'Last recorded meeting Oct 1');
      expect(
        row('Ben', status: 'READY_FOR_COMPLETION').stateLine,
        '7 completed · Lesson 8 awaiting confirmation',
      );
      expect(row('Cy').lastMeetingLine, 'No meeting recorded yet');
    });

    test('ordered longest since the last recorded meeting first', () {
      final rows = [
        row('Recent', last: DateTime.utc(2026, 10, 2)),
        row('Never'),
        row('Older', last: DateTime.utc(2026, 9, 1)),
      ]..sort(DiscipleProgressSummary.byLongestSinceLastMeeting);
      expect([for (final r in rows) r.fullName], ['Never', 'Older', 'Recent']);
    });
  });

  group('MeetingDraft', () {
    final now = DateTime(2026, 10, 5, 18, 30);
    MeetingDraft draft(
      Map<String, AttendanceOutcome> outcomes, {
      DateTime? on,
    }) => MeetingDraft(
      lessonId: 'l4',
      lessonNumber: 4,
      disciplerDGroupMembershipId: 'dgm',
      occurredOn: on ?? DateTime(2026, 10, 1),
      outcomes: outcomes,
      names: const {'d': 'Diana Cruz', 'e': 'Eli Santos'},
    );

    test('today is recorded as now; an earlier day at noon, never in the '
        'future', () {
      expect(
        draft(const {
          'd': AttendanceOutcome.present,
        }, on: DateTime(2026, 10, 5)).occurredAt(now),
        now,
      );
      expect(
        draft(const {'d': AttendanceOutcome.present}).occurredAt(now),
        DateTime(2026, 10, 1, 12),
      );
    });

    test('the form refuses no participant and a future date', () {
      expect(draft(const {}).problem(now), contains('at least one Disciple'));
      expect(
        draft(const {
          'd': AttendanceOutcome.present,
        }, on: DateTime(2026, 10, 6)).problem(now),
        contains('in the future'),
      );
      expect(draft(const {'d': AttendanceOutcome.late}).problem(now), isNull);
    });

    test('the review line says who counts and who does not', () {
      expect(
        draft(const {'d': AttendanceOutcome.present}).reviewLine,
        'Records a Lesson 4 meeting on Oct 1 · counts for Diana',
      );
      expect(
        draft(const {
          'd': AttendanceOutcome.absent,
          'e': AttendanceOutcome.excused,
        }).reviewLine,
        'Records a Lesson 4 meeting on Oct 1 · Diana: Absent, doesn\'t count'
        ' · Eli: Excused, doesn\'t count',
      );
    });
  });

  group('failure mapping', () {
    DiscipleshipFailure map(
      String reason, {
      String code = 'PT409',
      Object? details,
    }) => DiscipleshipRepository.failureFrom(
      PostgrestException(message: reason, code: code, details: details),
      'fallback',
      names: const {'cm-1': 'Diana Cruz'},
    );

    test('every recording and completion reason has its own sentence, never '
        'the fallback', () {
      for (final reason in [
        'participants_required',
        'duplicate_participant',
        'invalid_attendance_status',
        'occurred_at_required',
        'occurred_at_in_future',
        'discipler_not_active_at_occurred_at',
        'participant_not_assigned_at_occurred_at',
        'lesson_not_eligible',
        'lesson_not_in_active_curriculum',
        'member_not_active',
        'cannot_record_own_meeting',
        'not_authorized',
        'lesson_not_found',
        'lesson_not_in_progress',
        'below_submission_minimum',
        'lesson_not_completed',
        'later_lesson_completed',
        'next_lesson_started',
        'cannot_act_on_own_lesson',
      ]) {
        final f = map(reason);
        expect(f.message, isNot('fallback'), reason: reason);
        expect(f.reason, reason);
      }
    });

    test('a refusal about one person names them from the error detail', () {
      expect(
        map(
          'lesson_not_eligible',
          details: '{"church_membership_id": "cm-1", "lesson_number": 3}',
        ).message,
        'Diana Cruz is on Lesson 3. Lessons are recorded in order, one at a '
        'time.',
      );
      expect(
        map(
          'participant_not_assigned_at_occurred_at',
          details: '{"church_membership_id": "cm-1"}',
        ).message,
        startsWith("Diana Cruz wasn't paired"),
      );
    });
  });

  group('routes', () {
    test('discipleship routes are allowed only in the active state', () {
      for (final pattern in Routes.discipleshipRoutes) {
        expect(redirectFor(SessionState.active, pattern), isNull);
        for (final state in [
          SessionState.pending,
          SessionState.noMembership,
          SessionState.activeFirstEntry,
          SessionState.noAccess,
        ]) {
          expect(
            redirectFor(state, pattern),
            destinationFor(state),
            reason: '$state $pattern',
          );
        }
      }
      expect(Routes.discipleDetailFor('x'), '/disciples/x');
      expect(Routes.recordMeetingFor('x'), '/disciples/x/record');
    });
  });
}
