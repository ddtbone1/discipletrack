import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// The signed-in user's profile.
///
/// Watches only the user id, so it refetches on sign-in and sign-out but not
/// on every unrelated auth event such as a token refresh.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchMyProfile(userId);
});

/// Saves profile edits and refreshes [myProfileProvider] on success.
///
/// Starts in a data state for the same reason as `AuthController`: an
/// [AsyncNotifier] would begin loading and show the save button as a spinner
/// before anything had been submitted.
class ProfileEditController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Returns true when the save succeeded. On failure the error is exposed
  /// through [state] so the form can show it without losing what was typed.
  Future<bool> save({required String fullName, String? phone}) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;

    state = const AsyncValue.loading();
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateMyProfile(userId: userId, fullName: fullName, phone: phone);
      ref.invalidate(myProfileProvider);
      state = const AsyncValue.data(null);
      return true;
    } on ProfileFailure catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final profileEditControllerProvider =
    NotifierProvider<ProfileEditController, AsyncValue<void>>(
      ProfileEditController.new,
    );
