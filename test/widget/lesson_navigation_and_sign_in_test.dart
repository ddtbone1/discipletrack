import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/auth/data/remembered_email_store.dart';
import 'package:discipletrack/features/auth/presentation/sign_in_page.dart';
import 'package:discipletrack/features/curriculum/application/curriculum_providers.dart';
import 'package:discipletrack/features/curriculum/domain/lesson_content.dart';
import 'package:discipletrack/features/curriculum/presentation/lessons_nav_card.dart';
import 'package:discipletrack/features/curriculum/presentation/lesson_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

/// Hosts [child] in a router with a stand-in lesson page, and the lesson
/// access the database would answer.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required List<LessonAccess> access,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => Scaffold(body: SingleChildScrollView(child: child)),
      ),
      GoRoute(
        path: '/lessons',
        builder: (c, s) => Text('Lessons for ${s.uri.queryParameters['for']}'),
      ),
      GoRoute(
        path: '/lessons/:lessonId',
        builder: (c, s) => Text(
          'Reader ${s.pathParameters['lessonId']} '
          'for ${s.uri.queryParameters['for']}',
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lessonAccessProvider.overrideWith((ref, forId) async => access),
        lessonCoversProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Lessons nav card', () {
    final journey = sampleJourney(total: 10, completed: 1);

    testWidgets('shows the current lesson and opens the list of all ten in '
        "the Disciple's context", (tester) async {
      await _pump(
        tester,
        LessonsNavCard(journey: journey, forMembershipId: 'cm-d'),
        access: sampleLessonAccess(open: 2),
      );

      expect(find.text('Lessons'), findsOneWidget);
      await tester.tap(find.byType(LessonsNavCard));
      await tester.pumpAndSettle();
      expect(find.text('Lessons for cm-d'), findsOneWidget);
    });
  });

  group('Lesson carousel', () {
    final journey = sampleJourney(total: 10, completed: 1);

    testWidgets('starts on the current lesson; a reached lesson opens, a '
        'locked one does not', (tester) async {
      await _pump(
        tester,
        LessonCarousel(journey: journey),
        access: sampleLessonAccess(open: 2),
      );

      expect(find.text('Lesson 2 · Now'), findsOneWidget);
      await tester.tap(find.text('Lesson title 2'));
      await tester.pumpAndSettle();
      expect(find.text('Reader lesson-2 for null'), findsOneWidget);
    });

    testWidgets('a locked lesson shows a lock and does nothing', (
      tester,
    ) async {
      await _pump(
        tester,
        LessonCarousel(journey: journey),
        access: sampleLessonAccess(open: 2),
      );
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
      await tester.tap(find.text('Lesson title 3'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reader'), findsNothing);
    });
  });

  group('remembered sign-in', () {
    testWidgets('the last email on this device is filled in', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth.last_email': 'diana@example.com',
      });
      final store = RememberedEmailStore();
      await pumpPage(
        tester,
        const SignInPage(),
        auth: FakeAuthRepository(),
        rememberedEmail: store,
      );
      await tester.pumpAndSettle();

      expect(find.text('diana@example.com'), findsOneWidget);
      expect(find.textContaining('Not you'), findsNothing);
      expect(await store.read(), 'diana@example.com');
    });

    testWidgets('a successful sign-in remembers the email', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = RememberedEmailStore();
      final auth = FakeAuthRepository();
      await pumpPage(
        tester,
        const SignInPage(),
        auth: auth,
        rememberedEmail: store,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'lea@example.com');
      await tester.enterText(find.byType(TextField).last, 'secret-123');
      await tester.tap(find.text('Login').last);
      await tester.pumpAndSettle();

      expect(auth.signIns.single.email, 'lea@example.com');
      expect(await store.read(), 'lea@example.com');
    });
  });
}
