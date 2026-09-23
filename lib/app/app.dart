import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/appearance/application/theme_mode_provider.dart';
import '../features/membership/application/membership_providers.dart';
import 'router.dart';

/// The root widget.
///
/// Watches only [routerProvider] and [themeModeProvider]. Auth, profile and
/// membership changes rebuild the affected screens rather than the whole
/// application; a theme switch necessarily rebuilds everything.
///
/// Stateful only to own an [AppLifecycleListener]: returning to the app
/// re-reads the membership, so an approval granted while the app was in the
/// background is noticed without a restart or a re-login.
class DiscipleTrackApp extends ConsumerStatefulWidget {
  const DiscipleTrackApp({super.key});

  @override
  ConsumerState<DiscipleTrackApp> createState() => _DiscipleTrackAppState();
}

class _DiscipleTrackAppState extends ConsumerState<DiscipleTrackApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(myMembershipProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DiscipleTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Light by default; dark only when chosen via ThemeModeToggle. The
      // device setting is deliberately not followed.
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
