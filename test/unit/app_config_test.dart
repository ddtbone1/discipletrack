import 'package:discipletrack/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('accepts complete configuration', () {
      final config = AppConfig.from(
        url: 'http://127.0.0.1:54321',
        publishableKey: 'sb_publishable_abc',
      );

      expect(config.supabaseUrl, 'http://127.0.0.1:54321');
      expect(config.supabasePublishableKey, 'sb_publishable_abc');
    });

    test('throws when the URL is missing, rather than defaulting', () {
      expect(
        () => AppConfig.from(url: '', publishableKey: 'sb_publishable_abc'),
        throwsA(
          isA<MissingConfigError>().having((e) => e.key, 'key', 'SUPABASE_URL'),
        ),
      );
    });

    test('throws when the publishable key is missing', () {
      expect(
        () => AppConfig.from(url: 'http://127.0.0.1:54321', publishableKey: ''),
        throwsA(
          isA<MissingConfigError>().having(
            (e) => e.key,
            'key',
            'SUPABASE_PUBLISHABLE_KEY',
          ),
        ),
      );
    });

    test('treats whitespace-only values as missing', () {
      expect(
        () => AppConfig.from(url: '   ', publishableKey: '   '),
        throwsA(isA<MissingConfigError>()),
      );
    });

    test('the error names the file to pass', () {
      final error = MissingConfigError('SUPABASE_URL');
      expect(error.toString(), contains('config/dev.json'));
    });
  });
}
