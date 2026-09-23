import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/core/widgets/status_pill.dart';
import 'package:discipletrack/core/widgets/step_list.dart';
import 'package:discipletrack/features/home/presentation/home_page.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/membership/presentation/membership_status_pill.dart';
import 'package:discipletrack/features/onboarding/presentation/join_church_page.dart';
import 'package:discipletrack/features/onboarding/presentation/no_access_page.dart';
import 'package:discipletrack/features/onboarding/presentation/pending_approval_page.dart';
import 'package:discipletrack/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group('MembershipStatusPill', () {
    testWidgets('names every membership state in words', (tester) async {
      for (final status in [null, ...MembershipStatus.values]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: MembershipStatusPill(status: status),
          ),
        );
        expect(find.text(membershipStatusLabel(status)), findsOneWidget);
      }
    });

    testWidgets('maps tones to their meaning', (tester) async {
      StatusTone toneOf() {
        final pill = tester.widget<StatusPill>(find.byType(StatusPill));
        return pill.tone;
      }

      Future<void> show(MembershipStatus? s) =>
          tester.pumpWidget(MaterialApp(home: MembershipStatusPill(status: s)));

      await show(MembershipStatus.active);
      expect(toneOf(), StatusTone.positive);
      await show(MembershipStatus.pending);
      expect(toneOf(), StatusTone.waiting);
      await show(MembershipStatus.archived);
      expect(toneOf(), StatusTone.neutral);
    });
  });

  testWidgets('StepList announces position and state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: StepList(
            steps: [
              StepItem(title: 'Account created', state: StepProgress.done),
              StepItem(title: 'Review', state: StepProgress.current),
              StepItem(title: 'Access', state: StepProgress.upcoming),
            ],
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Step 1 of 3, Account created, completed'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Step 2 of 3, Review, current step'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Step 3 of 3, Access, not started'),
      findsOneWidget,
    );
    handle.dispose();
  });

  group('ProfilePage', () {
    testWidgets('hides "Joined church" when there is no join date', (
      tester,
    ) async {
      await pumpPage(tester, const ProfilePage(), church: null);
      await tester.pumpAndSettle();
      expect(find.text('Joined church'), findsNothing);
      expect(find.text('Account created'), findsOneWidget);
      expect(find.text('Not in a church yet'), findsWidgets);
    });

    testWidgets('shows the church join date separately from account creation', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const ProfilePage(),
        membership: sampleMembership(
          MembershipStatus.active,
          joinedAt: DateTime.utc(2026, 3, 20, 12),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Joined church'), findsOneWidget);
      expect(find.text('March 20, 2026'), findsOneWidget);
      expect(find.text('March 14, 2026'), findsOneWidget);
    });

    testWidgets('keeps the Edit profile action', (tester) async {
      await pumpPage(tester, const ProfilePage());
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
    });
  });

  group('Sign out and profile entry on every onboarding page', () {
    final pages = <String, (Widget, MembershipStatus?)>{
      'JoinChurchPage': (const JoinChurchPage(), null),
      'PendingApprovalPage': (
        const PendingApprovalPage(),
        MembershipStatus.pending,
      ),
      'NoAccessPage': (const NoAccessPage(), MembershipStatus.archived),
      'HomePage': (const HomePage(), MembershipStatus.active),
    };

    for (final entry in pages.entries) {
      final (page, status) = entry.value;
      final membership = status == null
          ? null
          : sampleMembership(
              status,
              onboardingCompletedAt: DateTime.utc(2026, 9, 26),
            );

      testWidgets('${entry.key}: Sign out calls the repository', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        await pumpPage(tester, page, auth: auth, membership: membership);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Sign out'));
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(auth.signOuts, 1);
      });

      testWidgets('${entry.key}: avatar opens the profile', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpPage(tester, page, membership: membership);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('^Open profile')), findsOneWidget);
        handle.dispose();
      });

      testWidgets('${entry.key}: renders in dark mode without errors', (
        tester,
      ) async {
        await pumpPage(
          tester,
          page,
          membership: membership,
          mode: ThemeMode.dark,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('pages lay out on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final page in const [
      JoinChurchPage(),
      PendingApprovalPage(),
      NoAccessPage(),
      HomePage(),
      ProfilePage(),
    ]) {
      await pumpPage(
        tester,
        page,
        membership: sampleMembership(
          MembershipStatus.active,
          joinedAt: DateTime.utc(2026, 3, 20, 12),
          onboardingCompletedAt: DateTime.utc(2026, 9, 26),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
    }
  });
}
