import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Drives registration, sign-in and sign-out.
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

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => _run(
    () => ref
        .read(authRepositoryProvider)
        .signUp(email: email, password: password, fullName: fullName),
  );

  Future<bool> signIn({required String email, required String password}) =>
      _run(
        () => ref
            .read(authRepositoryProvider)
            .signIn(email: email, password: password),
      );

  Future<bool> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());

  /// Returns true on success. Failures surface through [state] so forms can
  /// show them inline without discarding what the person typed.
  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      return true;
    } on AuthFailure catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
