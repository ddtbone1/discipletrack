/// Route paths, in one place so no string is typed twice.
abstract final class Routes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';

  /// Reached from sign-up (no session is issued until the email is confirmed)
  /// or from a sign-in that failed with `email_not_confirmed`.
  static const verifyEmail = '/verify-email';

  static const joinChurch = '/onboarding/join';
  static const pendingApproval = '/onboarding/pending';

  /// INACTIVE, TRANSFERRED or ARCHIVED, including a rejected request.
  static const noAccess = '/onboarding/no-access';

  /// The one-time first-entry welcome.
  static const welcome = '/welcome';

  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';

  /// Membership-request review for Admins and Coordinators.
  static const pendingMembers = '/members/pending';

  /// Reachable from every authenticated state that has resolved a membership.
  ///
  /// RBAC section 3 grants "User -> own profile" without gating it on
  /// membership, and section 1a lets a PENDING member see their own onboarding
  /// state, so the profile screens are not restricted to ACTIVE members.
  static const profileRoutes = {profile, editProfile};
}
