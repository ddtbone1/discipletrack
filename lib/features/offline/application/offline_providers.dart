import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../../ministry/application/ministry_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../data/offline_snapshot.dart';

/// Runs [live]; when the server cannot be reached, answers from the saved
/// snapshot instead.
///
/// - Already offline, with a snapshot: answers from it at once, rather than
///   waiting out another failed request. Finding the connection again is
///   [retryConnection]'s job.
/// - Success marks the app online.
/// - A network failure marks it offline and returns [saved] from the
///   person's own snapshot. With no snapshot the failure is rethrown, which
///   is how a first launch offline ends on the splash's offline message.
/// - Any other failure is rethrown untouched: a refusal from the database is
///   a real answer and is never papered over with stale data.
///
/// A live attempt that takes longer than [liveTimeout] counts as
/// unreachable. Offline, the Supabase client keeps retrying an expired
/// token's refresh before the request itself fails, which otherwise holds
/// the splash for a quarter of a minute.
const liveTimeout = Duration(seconds: 8);

Future<T> liveOrSaved<T>(
  Ref ref, {
  required Future<T> Function() live,
  required T Function(OfflineSnapshot snapshot) saved,
}) async {
  final userId = ref.read(currentUserIdProvider);
  final store = ref.read(offlineSnapshotStoreProvider);
  if (ref.read(isOfflineProvider) && userId != null) {
    final snapshot = await store.read(userId);
    if (snapshot != null) return saved(snapshot);
  }
  try {
    final value = await live().timeout(liveTimeout);
    ref.read(isOfflineProvider.notifier).markOnline();
    return value;
  } catch (error, stack) {
    if (!isNetworkFailure(error) && error is! TimeoutException) rethrow;
    ref.read(isOfflineProvider.notifier).markOffline();
    final snapshot = userId == null ? null : await store.read(userId);
    if (snapshot == null) Error.throwWithStackTrace(error, stack);
    return saved(snapshot);
  }
}

/// Saves the snapshot whenever every part has a fresh live value.
///
/// Watched once by the app root. Nothing is written while offline, because
/// the values on screen then came from the snapshot itself.
final offlineSnapshotSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || ref.watch(isOfflineProvider)) return;

  final profile = ref.watch(myProfileProvider);
  final membership = ref.watch(myMembershipProvider);
  final church = ref.watch(myChurchProvider);
  final roles = ref.watch(myChurchRolesProvider);
  final ministry = ref.watch(myMinistryContextProvider);

  final parts = <AsyncValue<Object?>>[
    profile,
    membership,
    church,
    roles,
    ministry,
  ];
  if (parts.any((p) => p.isLoading || p.hasError || !p.hasValue)) return;

  ref
      .read(offlineSnapshotStoreProvider)
      .write(
        OfflineSnapshot(
          userId: userId,
          savedAt: DateTime.now().toUtc(),
          profile: profile.value,
          membership: membership.value,
          church: church.value,
          roles: roles.value ?? const {},
          ministry: ministry.value,
        ),
      );
});

/// Probes the server with one membership read. When it answers, the app is
/// online again: everything the snapshot covers is re-read live, and the
/// sync above saves a fresh snapshot.
///
/// The membership is re-read in place rather than invalidated, so the
/// session never drops back to the splash while this runs.
Future<void> retryConnection(WidgetRef ref) async {
  final online = await ref.read(myMembershipProvider.notifier).refresh();
  if (!online) return;
  ref
    ..invalidate(myProfileProvider)
    ..invalidate(myChurchProvider)
    ..invalidate(myChurchRolesProvider)
    ..invalidate(myMinistryContextProvider)
    ..invalidate(myPendingInvitationProvider);
}
