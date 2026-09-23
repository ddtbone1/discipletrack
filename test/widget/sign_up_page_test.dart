import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:discipletrack/features/auth/presentation/sign_up_page.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls instead of reaching Supabase. No mocking package needed for a
/// surface this small.
class _RecordingAuthRepository implements AuthRepository {
  final calls = <({String email, String password, String fullName})>[];

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    calls.add((email: email, password: password, fullName: fullName));
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  String? get currentUserId => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> pumpSignUp(WidgetTester tester, AuthRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.light(), home: const SignUpPage()),
    ),
  );
}

void main() {
  group('SignUpPage validation', () {
    testWidgets('blocks submission when every field is empty', (tester) async {
      final repo = _RecordingAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(repo.calls, isEmpty, reason: 'nothing should reach the backend');
    });

    testWidgets('rejects a blank full name', (tester) async {
      final repo = _RecordingAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.enterText(find.byType(TextField).at(0), '   ');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.test');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('rejects a malformed email', (tester) async {
      final repo = _RecordingAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.enterText(find.byType(TextField).at(0), 'Juan');
      await tester.enterText(find.byType(TextField).at(1), 'not-an-email');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('rejects a password under 6 characters', (tester) async {
      final repo = _RecordingAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.enterText(find.byType(TextField).at(0), 'Juan');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.test');
      await tester.enterText(find.byType(TextField).at(2), '12345');
      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('submits a valid form and passes the trimmed full name', (
      tester,
    ) async {
      final repo = _RecordingAuthRepository();
      await pumpSignUp(tester, repo);

      await tester.enterText(
        find.byType(TextField).at(0),
        '  Juan dela Cruz  ',
      );
      await tester.enterText(find.byType(TextField).at(1), 'juan@example.test');
      await tester.enterText(find.byType(TextField).at(2), 'password123');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(1));
      // The repository trims before sending it to auth metadata, which is what
      // the handle_new_user trigger reads.
      expect(repo.calls.single.fullName, '  Juan dela Cruz  ');
      expect(repo.calls.single.email, 'juan@example.test');
    });
  });
}
