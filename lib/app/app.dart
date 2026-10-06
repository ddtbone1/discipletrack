import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/connection_status.dart';
import '../core/theme/app_theme.dart';
import '../features/appearance/application/theme_mode_provider.dart';
import '../features/discipleship/application/discipleship_providers.dart';
import '../features/membership/application/membership_providers.dart';
import '../features/ministry/application/ministry_providers.dart';
import '../features/offline/application/offline_providers.dart';
import 'router.dart';

/// The root widget.
///
/// Watches only [routerProvider] and [themeModeProvider]. Auth, profile and
/// membership changes rebuild the affected screens rather than the whole
/// application; a theme switch necessarily rebuilds everything.
///
/// Stateful to own an [AppLifecycleListener] and the offline retry timer.
/// Returning to the app re-reads the membership, so an approval granted while
/// the app was in the background is noticed without a restart or a re-login.
///
/// While offline (Slice 4), the server is tried again every
/// [_offlineRetryEvery], on resume, and from the banner's Try again.
class DiscipleTrackApp extends ConsumerStatefulWidget {
  const DiscipleTrackApp({super.key});

  @override
  ConsumerState<DiscipleTrackApp> createState() => _DiscipleTrackAppState();
}

class _DiscipleTrackAppState extends ConsumerState<DiscipleTrackApp> {
  late final AppLifecycleListener _lifecycle;
  Timer? _retryTimer;

  static const _offlineRetryEvery = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    ref.listenManual(isOfflineProvider, (_, offline) {
      _retryTimer?.cancel();
      _retryTimer = offline
          ? Timer.periodic(_offlineRetryEvery, (_) => retryConnection(ref))
          : null;
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(isOfflineProvider)) {
          retryConnection(ref);
          return;
        }
        ref.read(myMembershipProvider.notifier).refresh();
        // Being added to a group or set up, a pairing made, or a meeting
        // recorded by someone else, while the app was in the background.
        ref
          ..invalidate(myMinistryContextProvider)
          ..invalidate(myDisciplesProvider)
          ..invalidate(discipleJourneyProvider)
          ..invalidate(meetingHistoryProvider)
          ..invalidate(meetingSummaryProvider)
          ..invalidate(progressSummaryProvider);
      },
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Saves the offline snapshot whenever fresh data arrives.
    ref.watch(offlineSnapshotSyncProvider);
    final offline = ref.watch(isOfflineProvider);

    return MaterialApp.router(
      title: 'DiscipleTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Light by default; dark only when chosen via ThemeModeToggle. The
      // device setting is deliberately not followed.
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ConnectionScope(
        offline: offline,
        onRetry: () => retryConnection(ref),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
