import 'package:discipletrack/features/discipleship/domain/journey.dart';
import 'package:discipletrack/features/discipleship/domain/journey_views.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:discipletrack/features/profile/presentation/ministry_summary.dart';
import 'package:flutter_test/flutter_test.dart';

MinistryContext _ctx(Set<DGroupResponsibility> mine, {int disciples = 0}) =>
    MinistryContext(
      dGroupId: 'g',
      dGroupName: 'G',
      roster: [
        for (final r in mine)
          RosterEntry(
            dGroupMembershipId: 'me-${r.name}',
            churchMembershipId: 'me',
            fullName: 'Me',
            responsibility: r,
            isMe: true,
          ),
        for (var i = 0; i < disciples; i++)
          RosterEntry(
            dGroupMembershipId: 'd$i',
            churchMembershipId: 'cm$i',
            fullName: 'Disciple $i',
            responsibility: DGroupResponsibility.disciple,
            isMyDisciple: true,
          ),
      ],
    );

const _disciple = DGroupResponsibility.disciple;
const _discipler = DGroupResponsibility.discipler;
const _leader = DGroupResponsibility.leader;

void main() {
  group('JourneyViews (decision 20)', () {
    test('Disciple only: My Journey, no tabs, no note', () {
      final v = JourneyViews.of(_ctx({_disciple}));
      expect(v.isOffered, isTrue);
      expect(v.showsMyJourneyOnly, isTrue);
      expect(v.showsTabs, isFalse);
      expect(v.showsAppointedNote, isFalse);
    });

    test('Disciple and appointed, nobody paired: My Journey with the note', () {
      final v = JourneyViews.of(_ctx({_disciple, _discipler}));
      expect(v.showsMyJourneyOnly, isTrue);
      expect(v.showsAppointedNote, isTrue);
    });

    test('Disciple with Disciples: two tabs', () {
      final v = JourneyViews.of(_ctx({_disciple, _discipler}, disciples: 1));
      expect(v.showsTabs, isTrue);
      expect(v.showsMyJourneyOnly, isFalse);
      expect(v.showsMyDisciplesOnly, isFalse);
    });

    test('Discipler with Disciples and no own journey: My Disciples only', () {
      final v = JourneyViews.of(_ctx({_discipler}, disciples: 2));
      expect(v.showsMyDisciplesOnly, isTrue);
      expect(v.showsTabs, isFalse);
    });

    test('Discipler with neither: the My Disciples empty state', () {
      final v = JourneyViews.of(_ctx({_discipler}));
      expect(v.isOffered, isTrue);
      expect(v.showsMyDisciplesOnly, isTrue);
    });

    test('a Leader who also disciples is offered Journey; a Leader alone and '
        'an unplaced member are not', () {
      expect(JourneyViews.of(_ctx({_leader, _discipler})).isOffered, isTrue);
      expect(JourneyViews.of(_ctx({_leader})).isOffered, isFalse);
      expect(JourneyViews.of(null).isOffered, isFalse);
    });
  });

  group('lesson status wording', () {
    JourneyLesson lesson(LessonState state, {int number = 4}) => JourneyLesson(
      lessonId: 'l',
      number: number,
      title: 'T',
      state: state,
      creditedCount: 2,
      isCurrent: state != LessonState.locked && state != LessonState.completed,
      startedAt: DateTime.utc(2026, 9, 3, 12),
      readyAt: DateTime.utc(2026, 9, 30, 12),
      submittedByName: 'Mark Reyes',
      completedAt: DateTime.utc(2026, 9, 12, 12),
      confirmedByName: 'Lea Santos',
    );

    test('oversight and own wording per state', () {
      expect(
        lesson(LessonState.locked, number: 5).statusLine(),
        'Opens after Lesson 4 is completed.',
      );
      expect(
        lesson(LessonState.inProgress).statusLine(),
        'In progress since Sep 3',
      );
      expect(
        lesson(LessonState.submitted).statusLine(),
        'Marked finished by Mark Reyes on Sep 30 · Awaiting Leader '
        'confirmation',
      );
      expect(
        lesson(LessonState.submitted).statusLine(ownJourney: true),
        'Finished. Your Leader will confirm it.',
      );
      expect(
        lesson(LessonState.completed).statusLine(),
        'Completed Sep 12 · by Lea Santos',
      );
      expect(
        lesson(LessonState.completed).statusLine(ownJourney: true),
        'Completed Sep 12',
      );
    });
  });

  group('MeetingSummary', () {
    test('facts only; a run of absences is stated only in oversight views', () {
      final s = MeetingSummary(
        meetingsAttended: 1,
        recordedAbsences: 3,
        excused: 1,
        consecutiveRecordedAbsences: 3,
        lastRecordedMeetingAt: DateTime.utc(2026, 9, 28, 12),
      );
      expect(
        s.factsLine(),
        '1 meeting attended · 3 recorded absences · Last recorded meeting '
        'Sep 28',
      );
      expect(
        s.factsLine(includeConsecutive: true),
        contains('3 consecutive recorded absences'),
      );
      const none = MeetingSummary(
        meetingsAttended: 0,
        recordedAbsences: 0,
        excused: 0,
        consecutiveRecordedAbsences: 0,
      );
      expect(none.factsLine(), endsWith('No meeting recorded yet'));
      expect(none.factsLine().toLowerCase(), isNot(contains('missed')));
    });
  });

  group('profile lines', () {
    test('every responsibility held, and names up to two', () {
      expect(
        responsibilityLine(_ctx({_discipler, _disciple})),
        'Disciple · Discipler',
      );
      expect(
        responsibilityLine(_ctx({_leader, _discipler})),
        'Leader · Discipler',
      );
      expect(discipleNames(['Anna Cruz']), 'Anna Cruz');
      expect(discipleNames(['Anna Cruz', 'Ben Lim']), 'Anna Cruz and Ben Lim');
      expect(discipleNames(['A', 'B', 'C']), '3 people');
    });
  });
}
