import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../membership/application/membership_providers.dart';
import '../../membership/data/membership_repository.dart';

/// Completes the one-time first-entry welcome.
///
/// Calls `complete_onboarding()` and then re-reads the membership, so the
/// session state moves from `activeFirstEntry` to `active` and the router
/// goes Home. The database keeps the timestamp, which is why a reinstall or a
/// second device does not see the welcome again.
class FirstEntryController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> complete() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(membershipRepositoryProvider).completeOnboarding();
      await ref.read(myMembershipProvider.notifier).refresh();
      state = const AsyncValue.data(null);
      return true;
    } on MembershipFailure catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final firstEntryControllerProvider =
    NotifierProvider<FirstEntryController, AsyncValue<void>>(
      FirstEntryController.new,
    );
