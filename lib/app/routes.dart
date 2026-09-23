/// Route paths, in one place so no string is typed twice.
abstract final class Routes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const joinChurch = '/onboarding/join';
  static const pendingApproval = '/onboarding/pending';
  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';

  /// Reachable from every authenticated state.
  ///
  /// RBAC section 3 grants "User -> own profile" without gating it on
  /// membership, and section 1a lets a PENDING member see their own onboarding
  /// state, so the profile screens are not restricted to ACTIVE members.
  static const alwaysAllowedWhenAuthenticated = {profile, editProfile};
}
