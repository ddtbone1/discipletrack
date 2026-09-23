import 'package:discipletrack/app/routes.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/auth/application/auth_providers.dart';
import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:discipletrack/features/auth/presentation/sign_in_page.dart';
import 'package:discipletrack/features/auth/presentation/sign_up_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

Future<void> pumpSignUp(WidgetTester tester, FakeAuthRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.light(), home: const SignUpPage()),
    ),
  );
}

/// A tiny router so `context.go(Routes.verifyEmail)` has somewhere to go.
/// The verification page itself is stubbed; its behaviour has its own test.
Future<ProviderContainer> pumpWithRouter(
  WidgetTester tester,
  FakeAuthRepository repo, {
  required String initialLocation,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: Routes.signUp, builder: (c, s) => const SignUpPage()),
      GoRoute(path: Routes.signIn, builder: (c, s) => const SignInPage()),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (c, s) => const Scaffold(body: Text('VERIFY PAGE')),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  return container;
}

void main() {
  group('SignUpPage validation', () {
    testWidgets('blocks submission when every field is empty', (tester) async {
      final repo = FakeAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(repo.signUps, isEmpty, reason: 'nothing should reach the backend');
    });

    testWidgets('rejects a blank full name', (tester) async {
      final repo = FakeAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.enterText(find.byType(TextField).at(0), '   ');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.test');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(repo.signUps, isEmpty);
    });

    testWidgets('rejects a malformed email', (tester) async {
      final repo = FakeAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.enterText(find.byType(TextField).at(0), 'Juan');
      await tester.enterText(find.byType(TextField).at(1), 'not-an-email');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(repo.signUps, isEmpty);
    });

    testWidgets('rejects a password under 6 characters', (tester) async {
      final repo = FakeAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.enterText(find.byType(TextField).at(0), 'Juan');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.test');
      await tester.enterText(find.byType(TextField).at(2), '12345');
      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(repo.signUps, isEmpty);
    });
  });

  group('SignUpPage outcomes', () {
    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(
        find.byType(TextField).at(0),
        '  Juan dela Cruz  ',
      );
      await tester.enterText(find.byType(TextField).at(1), 'juan@example.test');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
    }

    testWidgets('verification required: remembers the email and opens the '
        'verification screen', (tester) async {
      final repo = FakeAuthRepository()
        ..signUpOutcome = const SignUpVerificationRequired('juan@example.test');
      final container = await pumpWithRouter(
        tester,
        repo,
        initialLocation: Routes.signUp,
      );

      await fill(tester);

      expect(repo.signUps, hasLength(1));
      // The repository trims before sending it to auth metadata, which is
      // what the handle_new_user trigger reads.
      expect(repo.signUps.single.fullName, '  Juan dela Cruz  ');
      expect(repo.signUps.single.email, 'juan@example.test');
      expect(container.read(pendingVerificationProvider), 'juan@example.test');
      expect(find.text('VERIFY PAGE'), findsOneWidget);
    });

    testWidgets('already registered: explains and stays on the form', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..signUpOutcome = const SignUpAlreadyRegistered('juan@example.test');
      await pumpSignUp(tester, repo);

      await fill(tester);

      expect(find.textContaining('already exists'), findsOneWidget);
      expect(find.byType(SignUpPage), findsOneWidget);
    });

    testWidgets('a failure is shown inline without clearing the form', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..signUpFailure = const AuthFailure(
          'Please enter a valid email address.',
          code: AuthFailureCode.invalidEmail,
        );
      await pumpSignUp(tester, repo);

      await fill(tester);

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'juan@example.test',
      );
    });
  });

  group('SignInPage', () {
    testWidgets(
      'an unconfirmed email routes to verification with the address',
      (tester) async {
        final repo = FakeAuthRepository()
          ..signInFailure = const AuthFailure(
            'Please verify your email before signing in.',
            code: AuthFailureCode.emailNotConfirmed,
          );
        final container = await pumpWithRouter(
          tester,
          repo,
          initialLocation: Routes.signIn,
        );

        await tester.enterText(
          find.byType(TextField).at(0),
          'juan@example.test',
        );
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();

        expect(
          container.read(pendingVerificationProvider),
          'juan@example.test',
        );
        expect(find.text('VERIFY PAGE'), findsOneWidget);
      },
    );

    testWidgets('wrong credentials stay on sign-in with the message', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..signInFailure = const AuthFailure(
          'That email or password is not correct.',
          code: AuthFailureCode.invalidCredentials,
        );
      await pumpWithRouter(tester, repo, initialLocation: Routes.signIn);

      await tester.enterText(find.byType(TextField).at(0), 'juan@example.test');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('That email or password is not correct.'),
        findsOneWidget,
      );
      expect(find.byType(SignInPage), findsOneWidget);
    });
  });
}
