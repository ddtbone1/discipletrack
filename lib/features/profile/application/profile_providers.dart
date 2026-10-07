import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../offline/application/offline_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// The signed-in user's profile.
///
/// Watches only the user id, so it refetches on sign-in and sign-out but not
/// on every unrelated auth event such as a token refresh.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return liveOrSaved(
    ref,
    live: () => repo.fetchMyProfile(userId),
    saved: (s) => s.profile,
  );
});

/// The avatars of the person's church, by church membership id
/// (Migration 021). Empty when they cannot be read, so initials show.
final churchAvatarsProvider = FutureProvider<Map<String, String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  try {
    return await ref.watch(profileRepositoryProvider).fetchChurchAvatars();
  } on ProfileFailure {
    return const {};
  }
});

/// Sets the person's avatar and refreshes everything that shows it.
class AvatarController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> choose(String? avatar) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    state = const AsyncValue.loading();
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateAvatar(userId: userId, avatar: avatar);
      ref
        ..invalidate(myProfileProvider)
        ..invalidate(churchAvatarsProvider);
      state = const AsyncValue.data(null);
      return true;
    } on ProfileFailure catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final avatarControllerProvider =
    NotifierProvider<AvatarController, AsyncValue<void>>(AvatarController.new);

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
