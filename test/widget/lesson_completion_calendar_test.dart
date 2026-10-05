import 'package:discipletrack/core/supabase/postgrest_failure.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/discipleship/data/discipleship_repository.dart';
import 'package:discipletrack/features/discipleship/domain/attendance_outcome.dart';
import 'package:discipletrack/features/discipleship/domain/journey.dart';
import 'package:discipletrack/features/discipleship/domain/meeting_history_entry.dart';
import 'package:discipletrack/features/discipleship/presentation/disciple_detail_page.dart';
import 'package:discipletrack/features/discipleship/presentation/meeting_calendar.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

MeetingHistoryEntry _entry(
  DateTime day,
  AttendanceOutcome outcome, {
  int? ordinal,
}) => MeetingHistoryEntry(
  meetingId: 'm-${day.day}',
  participantId: 'p-${day.day}',
  occurredAt: day,
  lessonNumber: 2,
  lessonTitle: 'Lesson title 2',
  outcome: outcome,
  isCredited: outcome.countsTowardLesson,
  isVoided: false,
  ordinal: ordinal,
  recordedByName: 'Mark Reyes',
);

void main() {
  group('MeetingCalendar', () {
    // Newest first, as the read returns them.
    final entries = [
      _entry(DateTime.utc(2026, 10, 2, 4), AttendanceOutcome.absent),
      _entry(
        DateTime.utc(2026, 9, 21, 4),
        AttendanceOutcome.present,
        ordinal: 2,
      ),
      _entry(DateTime.utc(2026, 9, 14, 4), AttendanceOutcome.late, ordinal: 1),
    ];

    Future<void> pump(WidgetTester tester, List<MeetingHistoryEntry> list) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: MeetingCalendar(
                  entries: list,
                  emptyMessage: 'No meetings recorded yet.',
                  clock: () => DateTime(2026, 10, 5, 9),
                ),
              ),
            ),
          ),
        );

    testWidgets('opens on the latest meeting\'s month with that day selected', (
      tester,
    ) async {
      await pump(tester, entries);
      expect(find.text('October 2026'), findsOneWidget);
      expect(
        find.text('Absent · Not counted · Recorded absence'),
        findsOneWidget,
      );
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Recorded absence'), findsOneWidget);
      expect(find.text('View full history · 3 meetings'), findsOneWidget);
    });

    testWidgets('moves between months, never past the current month or before '
        'the first meeting', (tester) async {
      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );
      await pump(tester, entries);
      expect(button('Next month').onPressed, isNull);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();
      expect(find.text('September 2026'), findsOneWidget);
      expect(button('Previous month').onPressed, isNull);
    });

    testWidgets('a date reads its outcome to a screen reader and opens that '
        'meeting when tapped', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, entries);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();

      final day = find.bySemanticsLabel(
        RegExp(r'September 21, 2026, Meeting 2 · Present · Counted'),
      );
      expect(day, findsOneWidget);
      await tester.tap(day);
      await tester.pump();
      expect(find.text('Meeting 2 · Present · Counted'), findsOneWidget);

      // A blank date is plain, with no warning wording.
      await tester.tap(find.bySemanticsLabel(RegExp(r'September 15, 2026')));
      await tester.pump();
      expect(find.text('No meeting recorded on this date.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('See all lists every meeting in a sheet', (tester) async {
      await pump(tester, entries);
      await tester.tap(find.text('View full history · 3 meetings'));
      await tester.pumpAndSettle();
      expect(find.text('Meeting history'), findsOneWidget);
      expect(find.text('Meeting 1 · Late · Counted'), findsOneWidget);
      expect(find.text('Meeting 2 · Present · Counted'), findsOneWidget);
    });

    testWidgets('with nothing recorded it shows the empty message', (
      tester,
    ) async {
      await pump(tester, const []);
      expect(find.text('No meetings recorded yet.'), findsOneWidget);
      expect(find.byTooltip('Previous month'), findsNothing);
    });
  });

  group('lesson completion on Disciple detail (ADR-015)', () {
    final active = sampleMembership(
      MembershipStatus.active,
      joinedAt: DateTime.utc(2026, 3, 1),
      onboardingCompletedAt: DateTime.utc(2026, 3, 1),
    );
    const diana = DiscipleContext(
      membershipId: 'cm-diana',
      fullName: 'Diana Cruz',
      isPaired: true,
      disciplerName: 'Mark Reyes',
    );

    Future<FakeDiscipleshipRepository> pump(
      WidgetTester tester, {
      bool canComplete = false,
      bool canUndo = false,
      DiscipleshipFailure? failure,
    }) async {
      final repo = FakeDiscipleshipRepository()
        ..contexts = {'cm-diana': diana}
        ..journeys = {
          'cm-diana': sampleJourney(
            canComplete: canComplete,
            canUndoPrevious: canUndo,
          ),
        }
        ..progressFailure = failure;
      await pumpPage(
        tester,
        const DiscipleDetailPage(membershipId: 'cm-diana'),
        membership: active,
        discipleshipRepo: repo,
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('marking a lesson completed asks first, stating the meetings '
        'and the undo window, then offers Undo', (tester) async {
      final repo = await pump(tester, canComplete: true);
      final button = find.text('Mark Lesson 4 completed');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Mark Lesson 4 completed?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('2 meetings recorded'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Lesson 5 becomes the current lesson'),
        findsOneWidget,
      );
      expect(
        find.textContaining('only the Coordinator can reopen'),
        findsOneWidget,
      );

      // Cancel sends nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.completed, isEmpty);

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark completed'));
      await tester.pump();
      expect(repo.completed, ['lesson-4']);
      expect(
        find.text('Lesson 4 completed. Lesson 5 is now current.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(repo.undone, ['lesson-4']);
    });

    testWidgets('the latest completion can be undone from the page', (
      tester,
    ) async {
      final repo = await pump(tester, canUndo: true);
      final link = find.text('Undo Lesson 3 completion');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pump();
      expect(repo.undone, ['lesson-3']);
      expect(find.text('Lesson 3 is in progress again.'), findsOneWidget);
    });

    testWidgets('the calendar offers Record a meeting today, or on an earlier '
        'empty date once that date is selected', (tester) async {
      final repo = FakeDiscipleshipRepository()
        ..contexts = {'cm-diana': diana}
        ..journeys = {'cm-diana': sampleJourney(canRecord: true)}
        ..histories = {
          'cm-diana': [
            _entry(DateTime.utc(2026, 9, 20, 4), AttendanceOutcome.present),
          ],
        };
      await pumpPage(
        tester,
        const DiscipleDetailPage(membershipId: 'cm-diana'),
        membership: active,
        discipleshipRepo: repo,
      );
      await tester.pumpAndSettle();
      expect(find.text('Record a meeting today'), findsOneWidget);

      final day = find.bySemanticsLabel(RegExp(r'September 15, 2026'));
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pump();
      expect(find.text('Record a meeting on Sep 15'), findsOneWidget);
    });

    testWidgets('no action without the courtesy flags', (tester) async {
      await pump(tester);
      expect(find.text('CURRENT LESSON'), findsOneWidget);
      expect(find.text('Mark Lesson 4 completed'), findsNothing);
      expect(find.textContaining('Undo Lesson'), findsNothing);
    });

    testWidgets('a refusal is shown in words', (tester) async {
      await pump(
        tester,
        canComplete: true,
        failure: const DiscipleshipFailure(
          'A meeting is already recorded on the next lesson.',
          code: DbFailureCode.conflict,
          reason: 'next_lesson_started',
        ),
      );
      final button = find.text('Mark Lesson 4 completed');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();
      expect(
        find.text('A meeting is already recorded on the next lesson.'),
        findsOneWidget,
      );
    });

    testWidgets('completed lessons name who marked them', (tester) async {
      await pump(tester);
      expect(
        sampleJourney().lessons.first.statusLine(),
        'Completed Sep 12 · by Mark Reyes',
      );
      expect(sampleJourney().lessons.first.state, LessonState.completed);
    });
  });
}
