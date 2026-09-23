import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// A failure that already carries a message fit to show a person.
///
/// ARCHITECTURE section 29: user-facing errors must be understandable without
/// exposing internal detail.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
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
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _guard(() async {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
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

  Future<void> signOut() => _guard(() => _client.auth.signOut());

  /// Translates transport and auth errors into messages worth showing.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthApiException catch (e) {
      throw AuthFailure(_friendly(e));
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    } catch (_) {
      throw const AuthFailure(
        'Could not reach DiscipleTrack. Check your connection and try again.',
      );
    }
  }

  String _friendly(AuthException e) {
    final raw = e.message.toLowerCase();

    // The database trigger raises this when full_name metadata is absent or
    // blank. It should be unreachable from the app, which always sends a
    // validated name, but a clear message beats a raw Postgres string.
    if (raw.contains('full_name')) {
      return 'Please enter your full name.';
    }
    if (raw.contains('invalid login credentials')) {
      return 'That email or password is not correct.';
    }
    if (raw.contains('already registered') || raw.contains('already exists')) {
      return 'An account with that email already exists.';
    }
    if (raw.contains('password')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('email')) {
      return 'Please enter a valid email address.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
