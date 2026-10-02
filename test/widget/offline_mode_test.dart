import 'package:discipletrack/core/connectivity/connection_status.dart';
import 'package:discipletrack/core/supabase/supabase_providers.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/core/widgets/app_button.dart';
import 'package:discipletrack/core/widgets/app_scaffold.dart';
import 'package:discipletrack/core/widgets/app_text_link.dart';
import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:discipletrack/features/auth/presentation/splash_page.dart';
import 'package:discipletrack/features/home/presentation/home_page.dart';
import 'package:discipletrack/features/membership/application/membership_providers.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/profile/application/profile_providers.dart';
import 'package:discipletrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Hosts [child] as the app root does: inside a [ConnectionScope].
Widget _host(Widget child, {required bool offline, VoidCallback? onRetry}) =>
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, c) => ConnectionScope(
        offline: offline,
        onRetry: onRetry ?? () {},
        child: c!,
      ),
      home: child,
    );

void main() {
  group('offline banner', () {
    testWidgets('every page shows it while offline, and Try again retries', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          const AppScaffold(title: 'Home', child: Text('content')),
          offline: true,
          onRetry: () => retries++,
        ),
      );

      expect(find.text("You're offline"), findsOneWidget);
      expect(find.textContaining('Changes are off'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('no banner while online', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppScaffold(title: 'Home', child: Text('content')),
          offline: false,
        ),
      );
      expect(find.text("You're offline"), findsNothing);
    });
  });

  group('actions while offline', () {
    final taps = <String>[];
    Widget actions() => Scaffold(
      body: Column(
        children: [
          AppButton(
            label: 'Save changes',
            requiresConnection: true,
            onPressed: () => taps.add('save'),
          ),
          AppButton(label: 'Sign out', onPressed: () => taps.add('out')),
          AppTextLink(
            label: 'Pair',
            requiresConnection: true,
            onTap: () => taps.add('pair'),
          ),
        ],
      ),
    );

    Future<void> tapAll(WidgetTester tester) async {
      for (final label in ['Save changes', 'Sign out', 'Pair']) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
    }

    setUp(taps.clear);

    testWidgets('changes are disabled; sign-out is not', (tester) async {
      await tester.pumpWidget(_host(actions(), offline: true));
      await tapAll(tester);
      expect(taps, ['out']);
    });

    testWidgets('the same actions work online', (tester) async {
      await tester.pumpWidget(_host(actions(), offline: false));
      await tapAll(tester);
      expect(taps, ['save', 'out', 'pair']);
    });
  });

  testWidgets('a first launch offline, with nothing saved, says to connect', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          currentUserIdProvider.overrideWithValue(sampleUserId),
          myProfileProvider.overrideWith(
            (ref) async => throw const ProfileFailure(
              'Could not load your profile.',
              isNetwork: true,
            ),
          ),
          myMembershipProvider.overrideWithBuild((ref, notifier) async => null),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SplashPage()),
      ),
    );
    // Past the launch animation; the message shows once it has played.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining('Connect to sign in'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('Home for an unplaced member', () {
    final active = sampleMembership(
      MembershipStatus.active,
      onboardingCompletedAt: DateTime.utc(2026, 9, 26),
    );

    testWidgets('an ordinary member sees the not-placed card', (tester) async {
      await pumpPage(tester, const HomePage(), membership: active);
      await tester.pumpAndSettle();
      expect(find.text('Not placed in a D Group yet'), findsOneWidget);
    });

    testWidgets('an Admin or Coordinator does not', (tester) async {
      for (final role in ChurchRole.values) {
        await pumpPage(
          tester,
          const HomePage(),
          membership: active,
          roles: {role},
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Not placed in a D Group yet'),
          findsNothing,
          reason: '$role',
        );
      }
    });
  });
}
