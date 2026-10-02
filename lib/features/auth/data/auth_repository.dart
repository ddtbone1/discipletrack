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

/// A new account was created but no session was issued: a verification code
/// has been emailed to [email].
final class SignUpVerificationRequired extends SignUpOutcome {
  const SignUpVerificationRequired(this.email);
  final String email;
}

/// An account already uses [email], verified or not. Registration stops here.
///
/// For an unverified account GoTrue still emails a fresh code and keeps the
/// original password and name, so continuing to verification would hand the
/// account to whoever registered first. The owner completes an abandoned
/// registration by signing in with the original password instead, which
/// routes to verification through `email_not_confirmed`.
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
  /// session and emails a code. Three responses mean the address is taken,
  /// and all are reported as [SignUpAlreadyRegistered]:
  ///
  /// - `user_already_exists` / `email_exists` for a verified account;
  /// - an obfuscated user with no identities, from a hosted project with
  ///   enumeration protection;
  /// - the existing unverified user, recognised by [isRepeatSignUp].
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
        final user = res.user;
        final identities = user?.identities;
        if (identities != null && identities.isEmpty) {
          return SignUpAlreadyRegistered(trimmed);
        }
        if (user != null &&
            isRepeatSignUp(
              createdAt: user.createdAt,
              confirmationSentAt: user.confirmationSentAt,
            )) {
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

  /// How far apart the account's creation and the code just sent must be for
  /// the sign-up to count as a repeat. A new account has them milliseconds
  /// apart, because GoTrue creates the user and sends the code in one request.
  static const repeatSignUpGap = Duration(seconds: 10);

  /// Whether a session-less sign-up response describes an account that
  /// existed before this request.
  ///
  /// Both timestamps are written by the server, so the device clock plays no
  /// part. A missing or unparseable timestamp is treated as a new account:
  /// the verification screen is the safe default when nothing can be told.
  static bool isRepeatSignUp({
    required String createdAt,
    required String? confirmationSentAt,
  }) {
    final created = DateTime.tryParse(createdAt);
    final sent = confirmationSentAt == null
        ? null
        : DateTime.tryParse(confirmationSentAt);
    if (created == null || sent == null) return false;
    return sent.difference(created) > repeatSignUpGap;
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

  /// gotrue removes the local session before it tells the server, so the
  /// person is signed out on this device even when that call cannot get
  /// through. Only that transport failure is ignored; an offline sign-out
  /// must not surface as an error on the sign-in screen.
  Future<void> signOut() async {
    try {
      await _guard(() => _client.auth.signOut());
    } on AuthFailure catch (e) {
      if (e.code != AuthFailureCode.network) rethrow;
    }
  }

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
