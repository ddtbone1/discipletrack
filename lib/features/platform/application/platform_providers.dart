import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../offline/application/offline_providers.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';

/// The signed-in person's platform roles (ADR-022), or null when signed out.
///
/// Read from `platform_roles` (own rows only); offline, from the saved
/// snapshot, so a Super Admin opens the Platform area without a connection
/// and sees its "needs a connection" state rather than Join Church.
final myPlatformAccessProvider = FutureProvider<PlatformAccess?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final repo = ref.watch(platformRepositoryProvider);
  final roles = await liveOrSaved(
    ref,
    live: () => repo.fetchMyRoles(userId),
    saved: (s) => s.isSuperAdmin ? {PlatformRole.superAdmin} : <PlatformRole>{},
  );
  return PlatformAccess(userId: userId, roles: roles);
});

/// Whether to offer the Platform area. Presentation only: every platform
/// operation checks the role in the database.
final isSuperAdminProvider = Provider<bool>((ref) {
  final access = ref.watch(myPlatformAccessProvider).value;
  return access != null &&
      access.userId == ref.watch(currentUserIdProvider) &&
      access.isSuperAdmin;
});

/// Every church on the platform, with its counts and Coordinators.
final platformChurchesProvider = FutureProvider<List<PlatformChurch>>((
  ref,
) async {
  if (!ref.watch(isSuperAdminProvider)) return const [];
  return ref.watch(platformRepositoryProvider).listChurches();
});

/// One church from the list, or null when it is not there.
final platformChurchProvider =
    Provider.family<AsyncValue<PlatformChurch?>, String>(
      (ref, churchId) => ref
          .watch(platformChurchesProvider)
          .whenData((all) => all.where((c) => c.id == churchId).firstOrNull),
    );

/// A church's platform activity, newest first.
final platformEventsProvider =
    FutureProvider.family<List<PlatformEvent>, String>((ref, churchId) async {
      if (!ref.watch(isSuperAdminProvider)) return const [];
      return ref
          .watch(platformRepositoryProvider)
          .listEvents(churchId: churchId);
    });
