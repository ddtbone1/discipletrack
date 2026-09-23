import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  AuthFailure map(String message, {String? code}) =>
      AuthRepository.failureFrom(AuthApiException(message, code: code));

  test('branches on the GoTrue error code before message text', () {
    // "Email not confirmed" contains the word "email"; the substring fallback
    // would have called it an invalid address.
    expect(
      map('Email not confirmed', code: 'email_not_confirmed').code,
      AuthFailureCode.emailNotConfirmed,
    );
    expect(
      map('Invalid login credentials', code: 'invalid_credentials').code,
      AuthFailureCode.invalidCredentials,
    );
    expect(
      map('Token has expired or is invalid', code: 'otp_expired').code,
      AuthFailureCode.invalidOrExpiredCode,
    );
    expect(
      map(
        'For security purposes, you can only request this after 0 seconds.',
        code: 'over_email_send_rate_limit',
      ).code,
      AuthFailureCode.resendTooSoon,
    );
  });

  test('falls back to message text when no code is present', () {
    expect(
      map('Invalid login credentials').code,
      AuthFailureCode.invalidCredentials,
    );
    expect(
      map('full_name is required in user metadata').code,
      AuthFailureCode.missingName,
    );
    expect(
      map('Password should be at least 6 characters').code,
      AuthFailureCode.weakPassword,
    );
    expect(
      map('Unable to validate email address').code,
      AuthFailureCode.invalidEmail,
    );
    expect(map('Some other failure').code, AuthFailureCode.unknown);
  });

  test('every mapped failure carries a message fit to show', () {
    for (final code in [
      'email_not_confirmed',
      'invalid_credentials',
      'otp_expired',
      'over_email_send_rate_limit',
      'weak_password',
      'validation_failed',
      null,
    ]) {
      final f = map('x', code: code);
      expect(f.message, isNotEmpty);
      expect(f.message, isNot(contains('Exception')));
    }
  });
}
