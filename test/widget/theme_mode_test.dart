import 'package:discipletrack/core/supabase/supabase_providers.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/appearance/application/theme_mode_provider.dart';
import 'package:discipletrack/features/appearance/presentation/theme_mode_toggle.dart';
import 'package:discipletrack/features/membership/application/membership_providers.dart';
import 'package:discipletrack/features/membership/data/membership_repository.dart';
import 'package:discipletrack/features/onboarding/presentation/join_church_page.dart';
import 'package:discipletrack/features/profile/application/profile_providers.dart';
import 'package:discipletrack/features/session/application/session_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Lets a test move the session between states.
class _FakeSession extends Notifier<SessionState> {
  @override
  SessionState build() => SessionState.noMembership;

  void set(SessionState value) => state = value;
}

final _fakeSession = NotifierProvider<_FakeSession, SessionState>(
  _FakeSession.new,
);

/// Mirrors how DiscipleTrackApp wires the theme, without the router or
/// Supabase.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(themeModeProvider),
    home: const JoinChurchPage(),
  );
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(JoinChurchPage))).brightness;

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => ref.watch(_fakeSession)),
        currentUserIdProvider.overrideWithValue(sampleUserId),
        myProfileProvider.overrideWith((ref) async => sampleProfile),
        myMembershipProvider.overrideWithBuild((ref, notifier) async => null),
        membershipRepositoryProvider.overrideWithValue(
          FakeMembershipRepository(),
        ),
        myChurchProvider.overrideWith((ref) async => null),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _App()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('light is the default, regardless of the device setting', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pump(tester);
    expect(_brightness(tester), Brightness.light);
  });

  testWidgets('the toggle beside the avatar switches to dark and back', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(ThemeModeToggle), findsOneWidget);

    await tester.tap(find.byType(ThemeModeToggle));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.dark);
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);

    await tester.tap(find.byType(ThemeModeToggle));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.light);
  });

  test('signing out returns the app to light mode', () {
    // Keep the provider alive so its session listener is active.
    final sub = container.listen(themeModeProvider, (_, _) {});
    container.read(themeModeProvider.notifier).toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark);

    container.read(_fakeSession.notifier).set(SessionState.signedOut);
    container.read(sessionStateProvider);
    expect(container.read(themeModeProvider), ThemeMode.light);
    sub.close();
  });
}
