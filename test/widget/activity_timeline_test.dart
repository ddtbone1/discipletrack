import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/discipleship/domain/attendance_outcome.dart';
import 'package:discipletrack/features/discipleship/domain/journey_activity.dart';
import 'package:discipletrack/features/discipleship/presentation/activity_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<ActivityEvent> _events(int n) => [
  for (var i = 0; i < n; i++)
    ActivityEvent(
      at: DateTime.utc(2026, 9, 28 - i, 10),
      kind: ActivityKind.lessonStarted,
      title: 'Lesson ${i + 1} started',
      lessonNumber: i + 1,
      lessonTitle: 'Title ${i + 1}',
    ),
];

Future<void> _pump(WidgetTester tester, List<ActivityEvent> events) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: JourneyActivitySection(
              title: 'Journey activity',
              events: events,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows the five most recent events, each with its lesson, then '
      'View all opening the full history', (tester) async {
    await _pump(tester, _events(8));
    expect(find.text('Journey activity'), findsOneWidget);
    expect(find.text('Lesson 1'), findsOneWidget);
    expect(find.text('Lesson 5'), findsOneWidget);
    expect(find.text('Lesson 6'), findsNothing);
    expect(find.text('Sep 28'), findsOneWidget);

    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.text('Journey history'), findsOneWidget);
    expect(find.text('Title 8', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the history page filters by tab and by month', (tester) async {
    final events = [
      ActivityEvent(
        at: DateTime.utc(2026, 9, 28, 10),
        kind: ActivityKind.meeting,
        title: 'Meeting recorded',
        outcome: AttendanceOutcome.absent,
        lessonNumber: 2,
        lessonTitle: 'Absent one',
      ),
      ActivityEvent(
        at: DateTime.utc(2026, 8, 20, 10),
        kind: ActivityKind.lessonStarted,
        title: 'Lesson 2 started',
        lessonNumber: 2,
        lessonTitle: 'Started one',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: JourneyHistoryPage(events: events),
      ),
    );

    expect(find.text('Absent one'), findsOneWidget);
    expect(find.text('Started one'), findsOneWidget);

    await tester.tap(find.text('Absent'));
    await tester.pump();
    expect(find.text('Started one'), findsNothing);
    expect(find.text('Absent one'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.byTooltip('Filter by month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('August 2026').last);
    await tester.pumpAndSettle();
    expect(find.text('Absent one'), findsNothing);
    expect(find.text('Started one'), findsOneWidget);
  });

  testWidgets('a short history needs no link, and each event reads in words', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [
      ActivityEvent(
        at: DateTime.utc(2026, 9, 28, 10),
        kind: ActivityKind.meeting,
        title: 'Meeting recorded',
        outcome: AttendanceOutcome.present,
        lessonNumber: 2,
      ),
    ]);
    expect(find.textContaining('View all'), findsNothing);
    expect(
      find.bySemanticsLabel('Sep 28. Meeting · Present, Lesson 2'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('with no events the section is not shown', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Journey activity'), findsNothing);
  });
}
