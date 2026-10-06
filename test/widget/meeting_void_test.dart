import 'package:discipletrack/core/connectivity/connection_status.dart';
import 'package:discipletrack/features/discipleship/data/discipleship_repository.dart';
import 'package:discipletrack/features/discipleship/domain/attendance_outcome.dart';
import 'package:discipletrack/features/discipleship/domain/journey.dart';
import 'package:discipletrack/features/discipleship/domain/meeting_history_entry.dart';
import 'package:discipletrack/features/discipleship/presentation/disciple_detail_page.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Slice 5 step 6: the selected meeting's ⋮ menu on Disciple detail. The
/// actions come only from the server's courtesy flags; each asks first.
void main() {
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

  MeetingHistoryEntry meeting({
    bool canVoidMeeting = false,
    bool canVoidParticipant = false,
  }) => MeetingHistoryEntry(
    meetingId: 'm-20',
    participantId: 'p-20',
    occurredAt: DateTime.utc(2026, 9, 20, 4),
    lessonNumber: 2,
    lessonTitle: 'Lesson title 2',
    outcome: AttendanceOutcome.present,
    isCredited: true,
    isVoided: false,
    ordinal: 1,
    recordedByName: 'Mark Reyes',
    canVoidMeeting: canVoidMeeting,
    canVoidParticipant: canVoidParticipant,
  );

  Future<FakeDiscipleshipRepository> pump(
    WidgetTester tester,
    MeetingHistoryEntry entry, {
    bool offline = false,
    DiscipleshipFailure? failure,
  }) async {
    final repo = FakeDiscipleshipRepository()
      ..contexts = {'cm-diana': diana}
      ..journeys = {'cm-diana': sampleJourney()}
      ..histories = {
        'cm-diana': [entry],
      }
      ..voidFailure = failure;
    await pumpPage(
      tester,
      ConnectionScope(
        offline: offline,
        onRetry: () {},
        child: const DiscipleDetailPage(membershipId: 'cm-diana'),
      ),
      membership: active,
      discipleshipRepo: repo,
    );
    await tester.pumpAndSettle();
    // Select the meeting's day to show its details.
    final day = find.bySemanticsLabel(RegExp(r'September 20, 2026'));
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('Meeting actions'));
    await tester.tap(find.byTooltip('Meeting actions'));
    await tester.pumpAndSettle();
  }

  testWidgets('no menu without a permission from the server', (tester) async {
    await pump(tester, meeting());
    expect(find.text('Meeting 1 · Present · Counted'), findsOneWidget);
    expect(find.byTooltip('Meeting actions'), findsNothing);
  });

  testWidgets('Void meeting asks first; Cancel sends nothing; confirming '
      'voids and says so', (tester) async {
    final repo = await pump(tester, meeting(canVoidMeeting: true));
    await openMenu(tester);
    expect(find.text('Void meeting'), findsOneWidget);
    // A single-person meeting offers no removal.
    expect(find.textContaining('Remove'), findsNothing);

    await tester.tap(find.text('Void meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Void this meeting?'), findsOneWidget);
    expect(
      find.text(
        "It will no longer count toward Lesson 2. This can't be undone; "
        'record it again if needed.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.voidedMeetings, isEmpty);

    await openMenu(tester);
    await tester.tap(find.text('Void meeting'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Void meeting'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.voidedMeetings, ['m-20']);
    expect(find.text('Meeting voided'), findsOneWidget);
  });

  testWidgets('a meeting with others in it offers removing just this person', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      meeting(canVoidMeeting: true, canVoidParticipant: true),
    );
    await openMenu(tester);
    await tester.tap(find.text('Remove Diana from this meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Diana from this meeting?'), findsOneWidget);
    expect(
      find.text(
        "Diana's outcome will no longer count. The meeting stays as recorded "
        "for everyone else. This can't be undone.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repo.voidedParticipants, ['p-20']);
    expect(repo.voidedMeetings, isEmpty);
    expect(find.text('Diana removed from the meeting'), findsOneWidget);
  });

  testWidgets(
    'voiding the whole of a shared meeting says it affects everyone',
    (tester) async {
      await pump(
        tester,
        meeting(canVoidMeeting: true, canVoidParticipant: true),
      );
      await openMenu(tester);
      await tester.tap(find.text('Void meeting'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('It is voided for everyone in the meeting.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a refusal is shown in words', (tester) async {
    await pump(
      tester,
      meeting(canVoidMeeting: true),
      failure: const DiscipleshipFailure(
        "This can't be voided because Diana Cruz's Lesson 2 is completed.",
      ),
    );
    await openMenu(tester);
    await tester.tap(find.text('Void meeting'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Void meeting'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        "This can't be voided because Diana Cruz's Lesson 2 is completed.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('offline, choosing an action explains itself and asks nothing', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      meeting(canVoidMeeting: true),
      offline: true,
    );
    await openMenu(tester);
    await tester.tap(find.text('Void meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Void this meeting?'), findsNothing);
    expect(
      find.text("You're offline. Connect to void this meeting."),
      findsOneWidget,
    );
    expect(repo.voidedMeetings, isEmpty);
  });
}
