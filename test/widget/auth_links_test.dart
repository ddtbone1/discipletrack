import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/core/widgets/app_text_link.dart';
import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:discipletrack/features/auth/presentation/sign_in_page.dart';
import 'package:discipletrack/features/auth/presentation/sign_up_page.dart';
import 'package:discipletrack/features/auth/presentation/verify_email_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: page),
    ),
  );
}

void main() {
  testWidgets('sign-in links to sign-up with a text link', (tester) async {
    await _pump(tester, const SignInPage());
    expect(
      find.widgetWithText(AppTextLink, 'Create an account'),
      findsOneWidget,
    );
    expect(find.text('New here?'), findsOneWidget);
  });

  testWidgets('sign-up links to sign-in with a text link', (tester) async {
    await _pump(tester, const SignUpPage());
    expect(find.widgetWithText(AppTextLink, 'Sign in'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
  });

  testWidgets('verify-email uses text links for its secondary actions', (
    tester,
  ) async {
    await _pump(tester, const VerifyEmailPage());
    expect(
      find.widgetWithText(AppTextLink, 'Use a different email'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppTextLink, 'Sign in'), findsOneWidget);
  });

  testWidgets('a disabled link does not respond', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              AppTextLink(label: 'Live', onTap: () => taps++),
              const AppTextLink(label: 'Off', onTap: null),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Off'));
    await tester.tap(find.text('Live'));
    expect(taps, 1);
  });
}
