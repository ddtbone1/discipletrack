import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/appearance/application/theme_mode_provider.dart';
import 'router.dart';

/// The root widget.
///
/// Watches only [routerProvider] and [themeModeProvider]. Auth, profile and
/// membership changes rebuild the affected screens rather than the whole
/// application; a theme switch necessarily rebuilds everything.
class DiscipleTrackApp extends ConsumerWidget {
  const DiscipleTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
