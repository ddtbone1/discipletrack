import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/core/widgets/status_pill.dart';
import 'package:discipletrack/core/widgets/step_list.dart';
import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:discipletrack/features/home/presentation/home_page.dart';
import 'package:discipletrack/features/membership/application/membership_providers.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/membership/presentation/membership_status_pill.dart';
import 'package:discipletrack/features/onboarding/presentation/join_church_page.dart';
import 'package:discipletrack/features/onboarding/presentation/pending_approval_page.dart';
import 'package:discipletrack/features/profile/application/profile_providers.dart';
import 'package:discipletrack/features/profile/domain/profile.dart';
import 'package:discipletrack/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts sign-out calls instead of reaching Supabase.
class _SignOutRecorder implements AuthRepository {
  int signOuts = 0;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _profile = Profile(
  id: '11111111-1111-1111-1111-111111111111',
  fullName: 'James Mercado',
  createdAt: DateTime.utc(2026, 3, 14, 12),
  updatedAt: DateTime.utc(2026, 9, 20, 12),
);

ChurchMembership _membership(MembershipStatus status, {DateTime? joinedAt}) =>
    ChurchMembership(
      id: '33333333-3333-3333-3333-333333333333',
      churchId: '44444444-4444-4444-4444-444444444444',
      userId: _profile.id,
      status: status,
      joinedAt: joinedAt,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  AuthRepository? auth,
  ChurchMembership? membership,
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myProfileProvider.overrideWith((ref) async => _profile),
        myMembershipProvider.overrideWith((ref) async => membership),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
      StatusTone toneOf(MembershipStatus? s) {
        final pill = tester.widget<StatusPill>(find.byType(StatusPill));
        return pill.tone;
      }

      Future<void> show(MembershipStatus? s) =>
          tester.pumpWidget(MaterialApp(home: MembershipStatusPill(status: s)));

      await show(MembershipStatus.active);
      expect(toneOf(MembershipStatus.active), StatusTone.positive);
      await show(MembershipStatus.pending);
      expect(toneOf(MembershipStatus.pending), StatusTone.waiting);
      await show(MembershipStatus.archived);
      expect(toneOf(MembershipStatus.archived), StatusTone.neutral);
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
      await _pump(tester, const ProfilePage());
      expect(find.text('Joined church'), findsNothing);
      expect(find.text('Account created'), findsOneWidget);
      expect(find.text('Not in a church yet'), findsWidgets);
    });

    testWidgets('shows the church join date separately from account creation', (
      tester,
    ) async {
      await _pump(
        tester,
        const ProfilePage(),
        membership: _membership(
          MembershipStatus.active,
          joinedAt: DateTime.utc(2026, 3, 20, 12),
        ),
      );
      expect(find.text('Joined church'), findsOneWidget);
      expect(find.text('March 20, 2026'), findsOneWidget);
      expect(find.text('March 14, 2026'), findsOneWidget);
    });

    testWidgets('keeps the Edit profile action', (tester) async {
      await _pump(tester, const ProfilePage());
      expect(find.text('Edit profile'), findsOneWidget);
    });
  });

  group('Sign out and profile entry survive the redesign', () {
    final pages = <String, Widget>{
      'JoinChurchPage': const JoinChurchPage(),
      'PendingApprovalPage': const PendingApprovalPage(),
      'HomePage': const HomePage(),
    };

    for (final entry in pages.entries) {
      testWidgets('${entry.key}: Sign out calls the repository', (
        tester,
      ) async {
        final auth = _SignOutRecorder();
        await _pump(tester, entry.value, auth: auth);

        await tester.ensureVisible(find.text('Sign out'));
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(auth.signOuts, 1);
      });

      testWidgets('${entry.key}: avatar opens the profile', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, entry.value);
        expect(find.bySemanticsLabel(RegExp('^Open profile')), findsOneWidget);
        handle.dispose();
      });

      testWidgets('${entry.key}: renders in dark mode without errors', (
        tester,
      ) async {
        await _pump(tester, entry.value, mode: ThemeMode.dark);
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
      HomePage(),
      ProfilePage(),
    ]) {
      await _pump(
        tester,
        page,
        membership: _membership(
          MembershipStatus.active,
          joinedAt: DateTime.utc(2026, 3, 20, 12),
        ),
      );
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
    }
  });

  testWidgets('JoinChurchPage keeps join by code disabled', (tester) async {
    await _pump(tester, const JoinChurchPage());
    expect(find.text('Enter join code'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Enter join code')),
      isNot(matchesSemantics(isEnabled: true)),
    );
  });
}
