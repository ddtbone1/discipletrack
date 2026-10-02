import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the light or dark choice is kept on the device.
///
/// One value for the device, not per person, so the welcome page and the
/// sign-in screens open in the mode last used, and the choice survives
/// signing out and back in.
class ThemeModeStore {
  const ThemeModeStore();

  static const _key = 'theme_mode';

  /// The saved choice, or light when nothing was saved or storage fails.
  Future<ThemeMode> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } on Object {
      return ThemeMode.light;
    }
  }

  Future<void> write(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
    } on Object {
      // Not being able to remember the choice must never break the app.
    }
  }
}

final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => const ThemeModeStore(),
);

/// The mode read from the device before the first frame, by `main`, so the
/// app never flashes the wrong mode. Light when not overridden.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.light);

/// The app's light or dark choice. Light by default.
///
/// Chosen explicitly with [ThemeModeToggle], never inherited from the device
/// setting, and remembered on the device: it stays across restarts, signing
/// out and signing back in.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    ref.read(themeModeStoreProvider).write(state);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
