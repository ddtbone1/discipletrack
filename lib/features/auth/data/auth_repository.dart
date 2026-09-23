import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// Why an auth call failed, decided from the GoTrue error code where one
/// exists. Screens branch on this; they never parse message text.
enum AuthFailureCode {
  /// `email_not_confirmed`: the account exists but the email has not been
  /// verified. Sign-in routes to the verification screen.
  emailNotConfirmed,
  invalidCredentials,

  /// `otp_expired`: GoTrue uses this for a wrong code as well as a stale one.
  invalidOrExpiredCode,

  /// `over_email_send_rate_limit`: a resend inside `max_frequency`.
  resendTooSoon,
  weakPassword,
  invalidEmail,
  missingName,
  network,
  unknown,
}

/// A failure that already carries a message fit to show a person.
///
/// ARCHITECTURE section 29: user-facing errors must be understandable without
/// exposing internal detail.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code = AuthFailureCode.unknown});

  final String message;
  final AuthFailureCode code;

  @override
  String toString() => message;
}

/// What registration produced.
sealed class SignUpOutcome {
  const SignUpOutcome();
}

/// A session was issued immediately (only when email confirmation is off).
final class SignUpSignedIn extends SignUpOutcome {
  const SignUpSignedIn();
}

/// The account exists but no session was issued: a verification code has
/// been emailed to [email]. GoTrue also returns this for a repeat sign-up of
/// an unconfirmed address, and resends the code.
final class SignUpVerificationRequired extends SignUpOutcome {
  const SignUpVerificationRequired(this.email);
  final String email;
}

/// A confirmed account already uses [email]. Nothing was sent.
final class SignUpAlreadyRegistered extends SignUpOutcome {
  const SignUpAlreadyRegistered(this.email);
  final String email;
}

/// The only place the app talks to Supabase Auth.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Registers a user and passes `full_name` through auth metadata.
  ///
  /// The `handle_new_user` database trigger reads that metadata to create the
  /// profiles row. The client never inserts into `profiles` itself, and a
  /// missing or blank name is rejected by the database rather than here.
  /// Client-side validation exists only to give faster feedback.
  ///
  /// With `enable_confirmations` on, GoTrue returns the user without a
  /// session and emails a code. A hosted project with enumeration protection
  /// instead returns an obfuscated user with no identities for an address that
  /// is already registered; that is reported as [SignUpAlreadyRegistered].
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    final trimmed = email.trim();
    return _guard(() async {
      try {
        final res = await _client.auth.signUp(
          email: trimmed,
          password: password,
          data: {'full_name': fullName.trim()},
        );
        if (res.session != null) return const SignUpSignedIn();
        final identities = res.user?.identities;
        if (identities != null && identities.isEmpty) {
          return SignUpAlreadyRegistered(trimmed);
        }
        return SignUpVerificationRequired(trimmed);
      } on AuthApiException catch (e) {
        if (e.code == 'user_already_exists' || e.code == 'email_exists') {
          return SignUpAlreadyRegistered(trimmed);
        }
        rethrow;
      }
    });
  }

  Future<void> signIn({required String email, required String password}) {
    return _guard(() async {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  /// Confirms ownership of [email] with the 6-digit code from the signup
  /// confirmation email. On success Supabase issues the session.
  Future<void> verifyEmailCode({required String email, required String code}) {
    return _guard(() async {
      await _client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.signup,
      );
    });
  }

  /// Emails a fresh signup confirmation code.
  Future<void> resendVerificationCode(String email) {
    return _guard(() async {
      await _client.auth.resend(type: OtpType.signup, email: email.trim());
    });
  }

  Future<void> signOut() => _guard(() => _client.auth.signOut());

  /// Translates transport and auth errors into messages worth showing.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthApiException catch (e) {
      throw failureFrom(e);
    } on AuthException catch (e) {
      throw failureFrom(e);
    } catch (_) {
      throw const AuthFailure(
        'Could not reach DiscipleTrack. Check your connection and try again.',
        code: AuthFailureCode.network,
      );
    }
  }

  /// Error code first, message text only as a fallback. Exposed for tests.
  static AuthFailure failureFrom(AuthException e) {
    switch (e.code) {
      case 'email_not_confirmed':
        return const AuthFailure(
          'Please verify your email before signing in.',
          code: AuthFailureCode.emailNotConfirmed,
        );
      case 'invalid_credentials':
        return const AuthFailure(
          'That email or password is not correct.',
          code: AuthFailureCode.invalidCredentials,
        );
      case 'otp_expired':
        return const AuthFailure(
          'That code is not valid or has expired. Check it or request a new '
          'one.',
          code: AuthFailureCode.invalidOrExpiredCode,
        );
      case 'over_email_send_rate_limit':
        return const AuthFailure(
          'A code was sent a moment ago. Wait a little before asking again.',
          code: AuthFailureCode.resendTooSoon,
        );
      case 'weak_password':
        return const AuthFailure(
          'Password must be at least 6 characters.',
          code: AuthFailureCode.weakPassword,
        );
      case 'validation_failed':
        return const AuthFailure(
          'Please enter a valid email address.',
          code: AuthFailureCode.invalidEmail,
        );
    }

    final raw = e.message.toLowerCase();

    // The database trigger raises this when full_name metadata is absent or
    // blank. It should be unreachable from the app, which always sends a
    // validated name, but a clear message beats a raw Postgres string.
    if (raw.contains('full_name')) {
      return const AuthFailure(
        'Please enter your full name.',
        code: AuthFailureCode.missingName,
      );
    }
    if (raw.contains('invalid login credentials')) {
      return const AuthFailure(
        'That email or password is not correct.',
        code: AuthFailureCode.invalidCredentials,
      );
    }
    if (raw.contains('token has expired') || raw.contains('invalid')) {
      return const AuthFailure(
        'That code is not valid or has expired. Check it or request a new '
        'one.',
        code: AuthFailureCode.invalidOrExpiredCode,
      );
    }
    if (raw.contains('password')) {
      return const AuthFailure(
        'Password must be at least 6 characters.',
        code: AuthFailureCode.weakPassword,
      );
    }
    if (raw.contains('email')) {
      return const AuthFailure(
        'Please enter a valid email address.',
        code: AuthFailureCode.invalidEmail,
      );
    }
    return const AuthFailure('Something went wrong. Please try again.');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
