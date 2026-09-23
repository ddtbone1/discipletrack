/// Build-time configuration, injected with `--dart-define-from-file`.
///
/// Networking differs by execution environment. The app on an Android emulator
/// reaches the host through `10.0.2.2`, while host-side integration tests reach
/// it through `127.0.0.1`. Neither value is hard-coded anywhere else in the
/// application; everything reads it from here.
///
/// See `config/README.md`.
library;

/// Thrown when a required build-time value was not supplied.
class MissingConfigError extends Error {
  MissingConfigError(this.key);

  final String key;

  @override
  String toString() =>
      'Missing build configuration "$key". Pass it with '
      '--dart-define-from-file=config/dev.json (or config/test.json for tests).';
}

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  /// Reads configuration from the values compiled into this build.
  ///
  /// Throws [MissingConfigError] rather than falling back to a default, so a
  /// misconfigured build fails at launch instead of silently pointing at the
  /// wrong backend.
  factory AppConfig.fromEnvironment() =>
      AppConfig.from(url: _urlFromEnv, publishableKey: _keyFromEnv);

  /// Validates explicit values. Exists so the validation rules can be tested
  /// deterministically, without depending on which defines a test run carries.
  factory AppConfig.from({
    required String url,
    required String publishableKey,
  }) {
    return AppConfig(
      supabaseUrl: _require(url, 'SUPABASE_URL'),
      supabasePublishableKey: _require(
        publishableKey,
        'SUPABASE_PUBLISHABLE_KEY',
      ),
    );
  }

  final String supabaseUrl;

  /// The publishable key, which replaced the legacy anon key. It maps to the
  /// `anon` Postgres role, so RLS still governs everything it can reach.
  final String supabasePublishableKey;

  // const-constructed so the compiler can inline them; empty means absent.
  static const String _urlFromEnv = String.fromEnvironment('SUPABASE_URL');
  static const String _keyFromEnv = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static String _require(String value, String key) {
    if (value.trim().isEmpty) throw MissingConfigError(key);
    return value;
  }
}
