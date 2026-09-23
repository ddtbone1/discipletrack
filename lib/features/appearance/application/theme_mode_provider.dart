import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/application/session_state.dart';

/// The app's light or dark choice. Light is the default.
///
/// Dark mode is chosen explicitly by a signed-in person through
/// [ThemeModeToggle], never inherited from the device setting. Signing out
/// returns the app to light, so the sign-in screens are always light and the
/// next person on the device starts from the default.
///
/// Held in memory only: the choice lasts for the running session and resets on
/// restart. Persisting it needs a storage dependency, which has not been added.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    ref.listen(sessionStateProvider, (_, next) {
      if (next == SessionState.signedOut) state = ThemeMode.light;
    });
    return ThemeMode.light;
  }

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
