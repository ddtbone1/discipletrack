import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership/domain/church_membership.dart';
import '../../profile/application/profile_providers.dart';

/// Where the person stands right now, as one value the router can switch on.
///
/// Combining auth, profile and membership here keeps the redirect logic a pure
/// function of a single enum, which makes it directly unit-testable and keeps
/// the router free of async handling.
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

  /// RBAC section 1a: onboarding state only.
  pending,

  /// ACTIVE for the first time and the one-time welcome has not been
  /// completed. `church_memberships.onboarding_completed_at` is null.
  activeFirstEntry,

  /// RBAC section 1a: normal access.
  active,

  /// INACTIVE, TRANSFERRED or ARCHIVED. RBAC section 1a: no protected church
  /// access. Historical records remain, but the app is not open to them.
  noAccess,
}

/// Resolves [SessionState] from its inputs.
///
/// Pure and separate from Riverpod so the redirect rules can be tested without
/// a container or a network.
SessionState resolveSessionState({
  required bool hasSession,
  required bool isLoading,
  required bool hasError,
  required MembershipStatus? membershipStatus,
  bool onboardingCompleted = false,
}) {
  if (!hasSession) return SessionState.signedOut;

  // An error resolving profile or membership must not masquerade as "signed
  // out", which would bounce a signed-in person to the sign-in screen.
  if (isLoading || hasError) return SessionState.unknown;

  return switch (membershipStatus) {
    null => SessionState.noMembership,
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

  final profile = ref.watch(myProfileProvider);
  final membership = ref.watch(myMembershipProvider);

  return resolveSessionState(
    hasSession: true,
    isLoading: profile.isLoading || membership.isLoading,
    hasError: profile.hasError || membership.hasError,
    membershipStatus: membership.value?.status,
    onboardingCompleted: membership.value?.onboardingCompletedAt != null,
  );
});
