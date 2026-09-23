import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Drives registration, sign-in, email verification and sign-out.
///
/// Holds no session state of its own. The session lives in Supabase and is
/// observed through `authStateChangesProvider`, so there is one source of
/// truth rather than a copy that can drift.
/// State is `AsyncValue<void>` held by a plain [Notifier] rather than an
/// [AsyncNotifier]. An AsyncNotifier begins in `AsyncLoading` until its
/// `build()` future resolves, which would render the submit button as a
/// spinner before the person has done anything. There is no initial async work
/// here, so the controller starts in a data state.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Null on failure; the failure is exposed through [state].
  Future<SignUpOutcome?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => _run(
    () => ref
        .read(authRepositoryProvider)
        .signUp(email: email, password: password, fullName: fullName),
  );

  Future<bool> signIn({required String email, required String password}) =>
      _succeeds(
        () => ref
            .read(authRepositoryProvider)
            .signIn(email: email, password: password),
      );

  Future<bool> verifyEmailCode({required String email, required String code}) =>
      _succeeds(
        () => ref
            .read(authRepositoryProvider)
            .verifyEmailCode(email: email, code: code),
      );

  Future<bool> resendVerificationCode(String email) => _succeeds(
    () => ref.read(authRepositoryProvider).resendVerificationCode(email),
  );

  Future<bool> signOut() =>
      _succeeds(() => ref.read(authRepositoryProvider).signOut());

  /// Clears a shown failure, for example when the person edits the form.
  void clearError() {
    if (state.hasError) state = const AsyncValue.data(null);
  }

  Future<bool> _succeeds(Future<void> Function() action) async =>
      await _run(() async {
        await action();
        return true;
      }) ??
      false;

  /// Failures surface through [state] so forms can show them inline without
  /// discarding what the person typed.
  Future<T?> _run<T>(Future<T> Function() action) async {
    state = const AsyncValue.loading();
    try {
      final result = await action();
      state = const AsyncValue.data(null);
      return result;
    } on AuthFailure catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

/// The email address awaiting verification, or null.
///
/// Set by sign-up when no session is issued, and by a sign-in that fails with
/// `email_not_confirmed`. In-memory only: an unverified account has no
/// session, so after a cold start the person simply signs in again and is
/// routed back here with the address they typed.
class PendingVerification extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String email) => state = email.trim();

  void clear() => state = null;
}

final pendingVerificationProvider =
    NotifierProvider<PendingVerification, String?>(PendingVerification.new);
