import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership/domain/church_membership.dart';
import '../../platform/application/platform_providers.dart';
import '../../profile/application/profile_providers.dart';

/// Where the person stands right now, as one value the router can switch on.
///
/// Combining auth, profile, membership, the church's status and the platform
/// role here keeps the redirect logic a pure function of a single enum, which
/// makes it directly unit-testable and keeps the router free of async
/// handling.
///
/// Email verification is deliberately not a state here. Supabase issues no
/// session until the email is confirmed, so an unverified person is
/// [signedOut]; the verification screen is a sign-out-side flow reached from
/// sign-up or sign-in.
enum SessionState {
  /// Still resolving. The router shows the splash and **never** the sign-in
  /// screen, which is what prevents a wrong-screen flash during restoration.
  unknown,

  signedOut,

  /// Authenticated but has not joined a church. MVP_SPEC section 11: enter the
  /// join code, confirm the church, request membership.
  noMembership,

  /// A platform Super Admin with no church membership (ADR-022 decision 16):
  /// the Platform area, never Join Church or the welcome.
  platform,

  /// RBAC section 1a: onboarding state only.
  pending,

  /// ACTIVE for the first time and the one-time welcome has not been
  /// completed. `church_memberships.onboarding_completed_at` is null.
  activeFirstEntry,

  /// RBAC section 1a: normal access.
  active,

  /// A PENDING or ACTIVE membership in a church that is SUSPENDED or ARCHIVED
  /// (ADR-022 decision 14): one screen naming the church; the profile and
  /// account stay available, nothing of the church does.
  churchUnavailable,

  /// INACTIVE, TRANSFERRED or ARCHIVED. RBAC section 1a: no protected church
  /// access. Historical records remain, but the app is not open to them.
  noAccess,
}

/// Resolves [SessionState] from its inputs.
///
/// Pure and separate from Riverpod so the redirect rules can be tested without
/// a container or a network. [churchStatus] is the status of the church the
/// membership belongs to; it matters only for a PENDING or ACTIVE membership.
SessionState resolveSessionState({
  required bool hasSession,
  required bool isLoading,
  required bool hasError,
  required MembershipStatus? membershipStatus,
  bool onboardingCompleted = false,
  bool isSuperAdmin = false,
  ChurchStatus churchStatus = ChurchStatus.active,
}) {
  if (!hasSession) return SessionState.signedOut;

  // An error resolving profile or membership must not masquerade as "signed
  // out", which would bounce a signed-in person to the sign-in screen.
  if (isLoading || hasError) return SessionState.unknown;

  final churchAvailable = churchStatus == ChurchStatus.active;
  return switch (membershipStatus) {
    null => isSuperAdmin ? SessionState.platform : SessionState.noMembership,
    MembershipStatus.pending when !churchAvailable =>
      SessionState.churchUnavailable,
    MembershipStatus.active when !churchAvailable =>
      SessionState.churchUnavailable,
    MembershipStatus.pending => SessionState.pending,
    MembershipStatus.active =>
      onboardingCompleted ? SessionState.active : SessionState.activeFirstEntry,
    MembershipStatus.inactive ||
    MembershipStatus.transferred ||
    MembershipStatus.archived => SessionState.noAccess,
  };
}

final sessionStateProvider = Provider<SessionState>((ref) {
  final hasSession = ref.watch(currentSessionProvider) != null;
  if (!hasSession) return SessionState.signedOut;

  final userId = ref.watch(currentUserIdProvider);
  final profile = ref.watch(myProfileProvider);
  final membership = ref.watch(myMembershipProvider);
  final platform = ref.watch(myPlatformAccessProvider);

  // A refresh that already has a value (a retry after reconnecting, a saved
  // edit) keeps the session resolved, so the router never flashes the
  // splash while data reloads in the background. A reload after signing in
  // is different: the value it still holds belongs to the signed-out period
  // (null) or to another user, and reading it would route this person on
  // someone else's state, for example to Join Church for a moment.
  bool pending(AsyncValue<Object?> v, {required String? Function() owner}) =>
      v.isLoading && (!v.hasValue || owner() != userId);
  bool failed(AsyncValue<Object?> v) => v.hasError && !v.hasValue;

  // The church is read once the membership is known, and only matters for a
  // PENDING or ACTIVE one. Its status decides between the app and the
  // unavailable screen, so the app waits for it: no protected screen is
  // entered before the church is known to be ACTIVE.
  final m = membership.value;
  final needsChurch =
      m != null &&
      m.userId == userId &&
      (m.status == MembershipStatus.pending ||
          m.status == MembershipStatus.active);
  final church = needsChurch ? ref.watch(myChurchProvider) : null;
  // In flight, or still holding another church's row (a reload after the
  // membership changed).
  final churchPending =
      church != null &&
      church.isLoading &&
      (!church.hasValue || church.value?.id != m!.churchId);

  return resolveSessionState(
    hasSession: true,
    isLoading:
        pending(profile, owner: () => profile.value?.id) ||
        pending(membership, owner: () => membership.value?.userId) ||
        pending(platform, owner: () => platform.value?.userId) ||
        churchPending,
    hasError:
        failed(profile) ||
        failed(membership) ||
        failed(platform) ||
        (church != null && failed(church)),
    membershipStatus: m?.status,
    onboardingCompleted: m?.onboardingCompletedAt != null,
    isSuperAdmin: platform.value?.isSuperAdmin ?? false,
    churchStatus: church?.value?.status ?? ChurchStatus.active,
  );
});
