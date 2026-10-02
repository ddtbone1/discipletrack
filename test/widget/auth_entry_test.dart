import 'package:discipletrack/app/routes.dart';
import 'package:discipletrack/app/transitions.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/auth/application/intro_state.dart';
import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:discipletrack/features/auth/presentation/auth_form_layout.dart';
import 'package:discipletrack/features/auth/presentation/sign_in_page.dart';
import 'package:discipletrack/features/auth/presentation/sign_up_page.dart';
import 'package:discipletrack/features/auth/presentation/splash_page.dart';
import 'package:discipletrack/features/auth/presentation/start_page.dart';
import 'package:discipletrack/features/membership/application/membership_providers.dart';
import 'package:discipletrack/features/profile/application/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

void main() {
  group('SplashPage', () {
    Future<ProviderContainer> pumpSplash(
      WidgetTester tester, {
      bool reduceMotion = false,
    }) async {
      final container = ProviderContainer(
        overrides: [
          myProfileProvider.overrideWith((ref) async => null),
          myMembershipProvider.overrideWithBuild((ref, n) async => null),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            // Reduced motion on top of the real screen metrics.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: const SplashPage(),
          ),
        ),
      );
      return container;
    }

    testWidgets('the wordmark writes itself in, letter by letter, then the '
        'intro completes', (tester) async {
      final c = await pumpSplash(tester);

      double opacityOf(String letter) => tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text(letter), matching: find.byType(Opacity))
                .first,
          )
          .opacity;

      // Well into the animation: the first letter is in, the last is not.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(opacityOf('D'), greaterThan(opacityOf('k')));
      expect(c.read(introCompleteProvider), isFalse);

      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(opacityOf('D'), 1);
      expect(opacityOf('k'), 1);
      expect(c.read(introCompleteProvider), isTrue);
    });

    testWidgets('with reduced motion the intro completes at once', (
      tester,
    ) async {
      final c = await pumpSplash(tester, reduceMotion: true);
      await tester.pump();
      expect(c.read(introCompleteProvider), isTrue);
    });
  });

  group('StartPage', () {
    Future<void> pumpStart(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: Routes.start,
        routes: [
          GoRoute(
            path: Routes.start,
            builder: (c, s) => const StartPage(),
            routes: [
              GoRoute(
                path: 'sign-in',
                pageBuilder: (c, s) =>
                    buildPage(state: s, child: const SignInPage()),
              ),
              GoRoute(
                path: 'sign-up',
                pageBuilder: (c, s) =>
                    buildPage(state: s, child: const SignUpPage()),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the illustration, the hero line and both actions', (
      tester,
    ) async {
      await pumpStart(tester);
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('Discipleship'), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
    });

    testWidgets('Log in opens the full-screen login page, and back returns '
        'to the welcome page', (tester) async {
      await pumpStart(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthFormLayout), findsOneWidget);
      expect(find.byType(StartPage), findsNothing, reason: 'full screen');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(StartPage), findsOneWidget);
    });

    testWidgets('the welcome page fits a small phone without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpStart(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sign up opens the sign-up page', (tester) async {
      await pumpStart(tester);
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpPage), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });
  });
}
