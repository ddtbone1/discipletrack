import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/discipleship/domain/journey_activity.dart';
import 'package:discipletrack/features/discipleship/presentation/activity_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<ActivityEvent> _events(int n) => [
  for (var i = 0; i < n; i++)
    ActivityEvent(
      at: DateTime.utc(2026, 9, 28 - i, 10),
      kind: ActivityKind.meeting,
      title: 'Event $i',
      detail: 'Lesson 2 · Present',
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
  testWidgets('shows the five most recent events, then a link to the full '
      'history', (tester) async {
    await _pump(tester, _events(8));
    expect(find.text('Journey activity'), findsOneWidget);
    expect(find.text('Event 0'), findsOneWidget);
    expect(find.text('Event 4'), findsOneWidget);
    expect(find.text('Event 5'), findsNothing);
    expect(find.text('View journey history · 8 events'), findsOneWidget);

    await tester.tap(find.text('View journey history · 8 events'));
    await tester.pumpAndSettle();
    expect(find.text('Journey history'), findsOneWidget);
    expect(find.text('Event 7'), findsOneWidget);
  });

  testWidgets('a short history needs no link, and each event reads in words', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _events(2));
    expect(find.textContaining('View journey history'), findsNothing);
    expect(
      find.bySemanticsLabel('Event 0. Sep 28 · Lesson 2 · Present'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('with no events the section is not shown', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Journey activity'), findsNothing);
  });
}
