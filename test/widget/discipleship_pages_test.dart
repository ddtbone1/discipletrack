import 'package:discipletrack/core/connectivity/connection_status.dart';
import 'package:discipletrack/core/supabase/postgrest_failure.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/discipleship/data/discipleship_repository.dart';
import 'package:discipletrack/features/discipleship/domain/attendance_outcome.dart';
import 'package:discipletrack/features/discipleship/domain/disciple_progress_summary.dart';
import 'package:discipletrack/features/discipleship/domain/journey.dart';
import 'package:discipletrack/features/discipleship/domain/meeting_history_entry.dart';
import 'package:discipletrack/features/discipleship/presentation/disciple_detail_page.dart';
import 'package:discipletrack/features/discipleship/presentation/discipleship_ui.dart';
import 'package:discipletrack/features/discipleship/presentation/journey_page.dart';
import 'package:discipletrack/features/discipleship/presentation/record_meeting_page.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

final _active = sampleMembership(
  MembershipStatus.active,
  joinedAt: DateTime.utc(2026, 3, 1),
  onboardingCompletedAt: DateTime.utc(2026, 3, 1),
);

RosterEntry _entry(
  String id,
  String name,
  DGroupResponsibility r, {
  bool me = false,
  bool myDisciple = false,
}) => RosterEntry(
  dGroupMembershipId: 'dgm-$id',
  churchMembershipId: 'cm-$id',
  fullName: name,
  responsibility: r,
  isMe: me,
  isMyDisciple: myDisciple,
);

/// The caller is a Discipler with Diana as their Disciple.
MinistryContext _disciplerContext() => MinistryContext(
  dGroupId: 'g1',
  dGroupName: 'Young Adults A',
  roster: [
    _entry('me', 'James Mercado', DGroupResponsibility.discipler, me: true),
    _entry(
      'diana',
      'Diana Cruz',
      DGroupResponsibility.disciple,
      myDisciple: true,
    ),
  ],
);

/// The caller leads the group; Diana is Mark's Disciple.
MinistryContext _leaderContext() => MinistryContext(
  dGroupId: 'g1',
  dGroupName: 'Young Adults A',
  roster: [
    _entry('me', 'James Mercado', DGroupResponsibility.leader, me: true),
    _entry('diana', 'Diana Cruz', DGroupResponsibility.disciple),
  ],
);

DiscipleProgressSummary _summary(String id, String name, {DateTime? last}) =>
    DiscipleProgressSummary(
      membershipId: id,
      fullName: name,
      lessonsTotal: 12,
      lessonsCompleted: 7,
      creditedCount: 2,
      recordedAbsences: 0,
      currentLessonNumber: 8,
      currentLessonTitle: 'Lesson title 8',
      currentState: LessonState.inProgress,
      lastRecordedMeetingAt: last,
    );

const _diana = DiscipleContext(
  membershipId: 'cm-diana',
  fullName: 'Diana Cruz',
  isPaired: true,
  dGroupName: 'Young Adults A',
  disciplerName: 'Mark Reyes',
);

MeetingHistoryEntry _history(
  AttendanceOutcome outcome, {
  int? ordinal,
  bool voided = false,
}) => MeetingHistoryEntry(
  meetingId: 'm-${outcome.db}',
  participantId: 'p-${outcome.db}',
  occurredAt: DateTime.utc(2026, 9, 20, 12),
  lessonNumber: 4,
  lessonTitle: 'Lesson title 4',
  outcome: outcome,
  isCredited: outcome.countsTowardLesson && !voided,
  isVoided: voided,
  ordinal: ordinal,
  recordedByName: 'Mark Reyes',
  notes: 'Prayed together',
  voidedByName: voided ? 'Lea Santos' : null,
);

void main() {
  group('JourneyProgressBar', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );

    testWidgets('one continuous bar over the curriculum, described in words, '
        'with no percentage', (tester) async {
      final handle = tester.ensureSemantics();
      final journey = sampleJourney(total: 10, completed: 3);
      await pump(
        tester,
        JourneyProgressBar(
          total: journey.lessonsTotal,
          completed: journey.lessonsCompleted,
          currentNumber: journey.currentLesson!.number,
          line: journey.summaryLine,
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Lesson 4 of 10. 3 lessons completed. Lesson 4 current.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('%'), findsNothing);
      // One continuous bar, not a stepper: 3 of 10 lessons completed.
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.3, 0.001));
      handle.dispose();
    });

    testWidgets('a submitted lesson is current, awaiting confirmation, not '
        'completed', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const JourneyProgressBar(
          total: 12,
          completed: 5,
          currentNumber: 6,
          submitted: true,
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Lesson 6 of 12. 5 lessons completed. Lesson 6 awaiting '
          'confirmation.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('Journey, My Disciples', () {
    testWidgets('lists each Disciple with factual lines and offers Record a '
        'meeting', (tester) async {
      final repo = FakeDiscipleshipRepository()
        ..disciples = [
          _summary('cm-a', 'Ana Lim', last: DateTime.utc(2026, 10, 1, 12)),
          _summary('cm-b', 'Ben Cruz'),
        ];
      await pumpPage(
        tester,
        const JourneyPage(),
        membership: _active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = _disciplerContext(),
        discipleshipRepo: repo,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Lim'), findsOneWidget);
      expect(find.text('Ben Cruz'), findsOneWidget);
      expect(find.text('Lesson 8 of 12'), findsNWidgets(2));
      expect(find.text('Last recorded meeting Oct 1'), findsOneWidget);
      expect(find.text('No meeting recorded yet'), findsOneWidget);
      expect(find.text('LONGEST SINCE LAST MEETING FIRST'), findsOneWidget);
      expect(find.text('Record a meeting'), findsOneWidget);
      // Never recorded is listed first.
      expect(
        tester.getTopLeft(find.text('Ben Cruz')).dy,
        lessThan(tester.getTopLeft(find.text('Ana Lim')).dy),
      );
    });

    testWidgets('explains an empty list', (tester) async {
      await pumpPage(
        tester,
        const JourneyPage(),
        membership: _active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = _disciplerContext(),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No Disciples are paired with you yet'),
        findsOneWidget,
      );
      expect(find.text('Record a meeting'), findsNothing);
    });

    testWidgets('is restricted for someone with neither relationship', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const JourneyPage(),
        membership: _active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = _leaderContext(),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Journey is for Disciples and Disciplers'),
        findsOneWidget,
      );
    });
  });

  group('Disciple detail', () {
    FakeDiscipleshipRepository repo({
      bool canRecord = true,
      List<MeetingHistoryEntry>? history,
    }) => FakeDiscipleshipRepository()
      ..contexts = {'cm-diana': _diana}
      ..journeys = {'cm-diana': sampleJourney(canRecord: canRecord)}
      ..histories = {'cm-diana': history ?? const []};

    Future<void> pump(
      WidgetTester tester,
      FakeDiscipleshipRepository r, {
      MinistryContext? ministry,
    }) async {
      await pumpPage(
        tester,
        const DiscipleDetailPage(membershipId: 'cm-diana'),
        membership: _active,
        ministryRepo: FakeMinistryRepository()
          ..ministryContext = ministry ?? _disciplerContext(),
        discipleshipRepo: r,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the journey, the current lesson with its count, and '
        'the history', (tester) async {
      await pump(
        tester,
        repo(
          history: [
            _history(AttendanceOutcome.present, ordinal: 2),
            _history(AttendanceOutcome.absent),
            _history(AttendanceOutcome.late, voided: true),
          ],
        ),
      );
      expect(find.text('Diana Cruz'), findsOneWidget);
      // The current lesson comes first: number, title, Discipler, count.
      expect(find.text('CURRENT LESSON'), findsOneWidget);
      expect(find.text('Lesson 4'), findsOneWidget);
      expect(find.text('Lesson title 4'), findsOneWidget);
      expect(find.text('Discipler: Mark Reyes'), findsOneWidget);
      expect(find.text('2 meetings recorded'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Lesson 4 of 12. 3 lessons completed.'),
        findsOneWidget,
      );
      expect(find.text('Meeting 2 · Present · Counted'), findsOneWidget);
      expect(
        find.text('Absent · Not counted · Recorded absence'),
        findsOneWidget,
      );
      expect(find.text('Late · Voided'), findsOneWidget);
      expect(find.text('Voided by Lea Santos'), findsOneWidget);
      // Notes stay closed until asked for.
      expect(find.text('Prayed together'), findsNothing);
      await tester.ensureVisible(find.text('Show notes').first);
      await tester.tap(find.text('Show notes').first);
      await tester.pump();
      expect(find.text('Prayed together'), findsOneWidget);
      // The assigned Discipler records, from the calendar.
      expect(find.text('Record a meeting today'), findsOneWidget);
      expect(find.textContaining('behalf'), findsNothing);
    });

    testWidgets('the Leader records on behalf of the Discipler', (
      tester,
    ) async {
      await pump(tester, repo(), ministry: _leaderContext());
      expect(find.text('Record a meeting today'), findsOneWidget);
      expect(find.text("On Mark Reyes's behalf"), findsOneWidget);
    });

    testWidgets('no recording action without the courtesy flag, and an empty '
        'history explains itself', (tester) async {
      await pump(tester, repo(canRecord: false));
      expect(find.textContaining('Record'), findsNothing);
      expect(find.text('No meetings recorded for Diana yet.'), findsOneWidget);
    });

    testWidgets('a refused deep link shows the restricted state without '
        'naming the person', (tester) async {
      await pump(
        tester,
        FakeDiscipleshipRepository()
          ..readFailure = const DiscipleshipFailure(
            'refused',
            code: DbFailureCode.forbidden,
            reason: 'not_authorized',
          ),
      );
      expect(find.text("This isn't available to you"), findsOneWidget);
      expect(find.textContaining('Diana'), findsNothing);
      expect(find.textContaining('refused'), findsNothing);
    });

    testWidgets('offline, the page says it needs a connection', (tester) async {
      await pump(
        tester,
        FakeDiscipleshipRepository()
          ..readFailure = const DiscipleshipFailure(
            'raw network text',
            code: DbFailureCode.network,
          ),
      );
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.textContaining('raw network text'), findsNothing);
    });
  });

  group('Record a meeting', () {
    FakeDiscipleshipRepository repo() => FakeDiscipleshipRepository()
      ..options = {
        'cm-diana': [
          sampleOption(),
          sampleOption(id: 'cm-eli', name: 'Eli Santos', isTarget: false),
          sampleOption(
            id: 'cm-fe',
            name: 'Fe Ramos',
            isTarget: false,
            lesson: 3,
          ),
        ],
      };

    Future<void> pump(
      WidgetTester tester,
      FakeDiscipleshipRepository r, {
      bool offline = false,
    }) async {
      await pumpPage(
        tester,
        ConnectionScope(
          offline: offline,
          onRetry: () {},
          child: const RecordMeetingPage(membershipId: 'cm-diana'),
        ),
        membership: _active,
        discipleshipRepo: r,
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapRecord(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Record meeting'));
      await tester.tap(find.text('Record meeting'));
      await tester.pumpAndSettle();
    }

    testWidgets('the lesson is shown, not chosen; the opened Disciple is '
        'preset Present; another lesson is listed but cannot be added', (
      tester,
    ) async {
      await pump(tester, repo());
      expect(find.text('LESSON 4'), findsOneWidget);
      expect(find.text('Lesson title 4'), findsOneWidget);
      expect(
        find.text('On Lesson 3. Record their meeting separately.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Records a Lesson 4 meeting on'),
        findsOneWidget,
      );
      expect(find.textContaining('counts for Diana'), findsOneWidget);
    });

    testWidgets('Nobody came sets every outcome to Absent, and the review '
        'line says it does not count', (tester) async {
      final r = repo();
      await pump(tester, r);
      await tester.tap(find.text('Nobody came'));
      await tester.pump();
      expect(
        find.textContaining("Diana: Absent, doesn't count"),
        findsOneWidget,
      );
      await tapRecord(tester);
      expect(r.recorded.single.outcomes, {
        'cm-diana': AttendanceOutcome.absent,
      });
      expect(r.recorded.single.lessonId, 'lesson-4');
      expect(r.recorded.single.disciplerDGroupMembershipId, 'dgm-mark');
      expect(find.text('Meeting recorded for Diana Cruz'), findsOneWidget);
    });

    testWidgets('an added Disciple needs an explicit outcome before sending', (
      tester,
    ) async {
      final r = repo();
      await pump(tester, r);
      await tester.ensureVisible(find.bySemanticsLabel('Include Eli Santos'));
      await tester.tap(find.bySemanticsLabel('Include Eli Santos'));
      await tester.pump();
      await tapRecord(tester);
      expect(r.recorded, isEmpty);
      expect(find.text('Choose an outcome for Eli Santos.'), findsOneWidget);

      await tester.ensureVisible(find.bySemanticsLabel('Eli Santos: Late'));
      await tester.tap(find.bySemanticsLabel('Eli Santos: Late'));
      await tester.pump();
      await tapRecord(tester);
      expect(r.recorded.single.outcomes, {
        'cm-diana': AttendanceOutcome.present,
        'cm-eli': AttendanceOutcome.late,
      });
    });

    testWidgets('a refusal is shown in words and the form is kept', (
      tester,
    ) async {
      final r = repo()
        ..recordFailure = const DiscipleshipFailure(
          'Diana Cruz is on Lesson 3. Lessons are recorded in order, one at a '
          'time.',
          code: DbFailureCode.conflict,
          reason: 'lesson_not_eligible',
        );
      await pump(tester, r);
      await tester.tap(find.text('Nobody came'));
      await tester.pump();
      await tapRecord(tester);
      expect(find.textContaining('Diana Cruz is on Lesson 3'), findsOneWidget);
      expect(
        find.textContaining("Diana: Absent, doesn't count"),
        findsOneWidget,
      );
    });

    testWidgets('offline, Record meeting explains itself instead of sending', (
      tester,
    ) async {
      final r = repo();
      await pump(tester, r, offline: true);
      await tapRecord(tester);
      expect(r.recorded, isEmpty);
      expect(
        find.text("You're offline. Connect to record this meeting."),
        findsOneWidget,
      );
    });

    testWidgets('someone who cannot record for the person sees why', (
      tester,
    ) async {
      await pump(
        tester,
        FakeDiscipleshipRepository()
          ..readFailure = const DiscipleshipFailure(
            'x',
            code: DbFailureCode.forbidden,
          ),
      );
      expect(find.text("You can't record for this person"), findsOneWidget);
      expect(find.text('Record meeting'), findsNothing);
    });
  });
}
