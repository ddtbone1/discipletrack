import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/auth/application/auth_providers.dart';
import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:discipletrack/features/auth/presentation/verify_email_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

class _KnownEmail extends PendingVerification {
  @override
  String? build() => 'juan@example.test';
}

Future<ProviderContainer> pump(
  WidgetTester tester,
  FakeAuthRepository repo, {
  bool knownEmail = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      if (knownEmail) pendingVerificationProvider.overrideWith(_KnownEmail.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const VerifyEmailPage(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('tells the person where the code went, provider-neutrally', (
    tester,
  ) async {
    await pump(tester, FakeAuthRepository());
    expect(find.textContaining('juan@example.test'), findsOneWidget);
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.textContaining('Gmail'), findsNothing);
  });

  testWidgets('requires a 6-digit code before calling the backend', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await pump(tester, repo);

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Verify'));
    await tester.pump();

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(repo.verifications, isEmpty);
  });

  testWidgets('verifies with the remembered email and clears it on success', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    final container = await pump(tester, repo);

    await tester.enterText(find.byType(TextField), '086791');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(repo.verifications, [(email: 'juan@example.test', code: '086791')]);
    expect(container.read(pendingVerificationProvider), isNull);
  });

  testWidgets('shows a wrong or expired code inline and keeps the email', (
    tester,
  ) async {
    final repo = FakeAuthRepository()
      ..verifyFailure = const AuthFailure(
        'That code is not valid or has expired. Check it or request a new one.',
        code: AuthFailureCode.invalidOrExpiredCode,
      );
    final container = await pump(tester, repo);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not valid or has expired'), findsOneWidget);
    expect(container.read(pendingVerificationProvider), 'juan@example.test');
  });

  testWidgets('resend calls the backend and starts a cooldown', (tester) async {
    final repo = FakeAuthRepository();
    await pump(tester, repo);

    await tester.tap(find.text('Resend code'));
    await tester.pump();
    await tester.pump();

    expect(repo.resends, ['juan@example.test']);
    expect(find.textContaining('A new code is on its way'), findsOneWidget);
    expect(
      find.text('Resend code (${VerifyEmailPage.resendCooldown}s)'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Resend code (${VerifyEmailPage.resendCooldown - 1}s)'),
      findsOneWidget,
    );

    // The countdown must not be tappable until it ends.
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.textContaining('Resend code')),
      isNot(matchesSemantics(isEnabled: true)),
    );
    handle.dispose();

    await tester.pump(Duration(seconds: VerifyEmailPage.resendCooldown));
    expect(find.text('Resend code'), findsOneWidget);
  });

  testWidgets('asks for the email after a cold start and uses what is typed', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await pump(tester, repo, knownEmail: false);

    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).at(0), 'maria@example.test');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(repo.verifications, [(email: 'maria@example.test', code: '123456')]);
  });
}
