import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/appearance/application/theme_mode_provider.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();

  // Awaited before runApp deliberately. Supabase.initialize restores any
  // persisted session, so by the first frame the app already knows whether
  // someone is signed in. Initialising after runApp would render a signed-out
  // frame first and flash the sign-in screen on every launch.
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );

  // Read before the first frame, so the welcome page and every screen
  // after it open in the mode last chosen.
  final themeMode = await const ThemeModeStore().read();

  runApp(
    ProviderScope(
      overrides: [initialThemeModeProvider.overrideWithValue(themeMode)],
      child: const DiscipleTrackApp(),
    ),
  );
}
