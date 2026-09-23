import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase/supabase_providers.dart';
import '../core/theme/app_theme.dart';
import '../features/appearance/application/theme_mode_provider.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/presentation/verify_email_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/membership/application/membership_providers.dart';
import '../features/membership/domain/church_membership.dart';
import '../features/membership_review/application/membership_review_providers.dart';
import '../features/membership_review/domain/membership_request.dart';
import '../features/membership_review/presentation/pending_members_page.dart';
import '../features/onboarding/presentation/join_church_page.dart';
import '../features/onboarding/presentation/no_access_page.dart';
import '../features/onboarding/presentation/pending_approval_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import '../features/profile/application/profile_providers.dart';
import '../features/profile/domain/profile.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/profile_page.dart';

/// Previews of every screen in the Auth + Profile and Church Join slices.
///
/// Run with: flutter widget-preview start
///
/// Riverpod providers are overridden with fixed sample data, so these render
/// without Supabase, without a network and without an emulator. Navigation
/// callbacks are inert because there is no GoRouter here; these are for
/// inspecting layout, spacing, type and colour, not for clicking through.

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _profile = Profile(
  id: '11111111-1111-1111-1111-111111111111',
  fullName: 'James Mercado',
  phone: '+63 917 555 0142',
  createdAt: DateTime(2026, 3, 14),
  updatedAt: DateTime(2026, 9, 20),
);

final _longNameProfile = Profile(
  id: '22222222-2222-2222-2222-222222222222',
  fullName: 'Maria Cristina Villanueva-Santos',
  createdAt: DateTime(2026, 1, 8),
  updatedAt: DateTime(2026, 9, 21),
);

const _church = ChurchSummary(
  id: '44444444-4444-4444-4444-444444444444',
  name: 'Bankal Seventh-day Adventist Church',
);

ChurchMembership _membership(
  MembershipStatus status, {
  bool onboardingCompleted = true,
}) => ChurchMembership(
  id: '33333333-3333-3333-3333-333333333333',
  churchId: _church.id,
  userId: _profile.id,
  status: status,
  joinedAt: DateTime(2026, 3, 20),
  requestedAt: DateTime(2026, 3, 18),
  onboardingCompletedAt: onboardingCompleted ? DateTime(2026, 3, 20) : null,
);

final _requests = [
  MembershipRequest(
    membershipId: 'r1',
    fullName: 'Juan Dela Cruz',
    requestedAt: DateTime(2026, 9, 25),
  ),
  MembershipRequest(
    membershipId: 'r2',
    fullName: 'Maria Cristina Villanueva-Santos',
    requestedAt: DateTime(2026, 9, 26),
  ),
];

/// A known address, so the verification preview shows the normal copy.
class _PreviewPendingVerification extends PendingVerification {
  @override
  String? build() => 'james@example.com';
}

/// Holds the toggle in its dark state so dark previews show the right icon.
class _PreviewDarkMode extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.dark;
}

/// Wraps a page with sample data, in light or dark mode. Must be top-level to be usable from an
/// annotation.
Widget _wrap(
  Widget page, {
  Profile? profile,
  ChurchMembership? membership,
  Set<ChurchRole> roles = const {},
  List<MembershipRequest> requests = const [],
  bool dark = false,
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(profile?.id),
      myProfileProvider.overrideWith((ref) async => profile),
      myMembershipProvider.overrideWithBuild(
        (ref, notifier) async => membership,
      ),
      myChurchProvider.overrideWith(
        (ref) async => membership == null ? null : _church,
      ),
      myChurchRolesProvider.overrideWith((ref) async => roles),
      pendingMembershipRequestsProvider.overrideWith((ref) async => requests),
      pendingVerificationProvider.overrideWith(_PreviewPendingVerification.new),
      if (dark) themeModeProvider.overrideWith(_PreviewDarkMode.new),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: page,
    ),
  );
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

@Preview(name: '1. Splash', group: 'Auth flow', size: Size(390, 844))
Widget splash() => _wrap(const SplashPage());

@Preview(name: '2. Sign in', group: 'Auth flow', size: Size(390, 844))
Widget signIn() => _wrap(const SignInPage());

@Preview(name: '3. Sign up', group: 'Auth flow', size: Size(390, 844))
Widget signUp() => _wrap(const SignUpPage());

@Preview(name: '3b. Verify email', group: 'Auth flow', size: Size(390, 844))
Widget verifyEmail() => _wrap(const VerifyEmailPage());

// ---------------------------------------------------------------------------
// Onboarding and home, one per membership state
// ---------------------------------------------------------------------------

@Preview(name: '4. No membership', group: 'Onboarding', size: Size(390, 844))
Widget joinChurch() => _wrap(const JoinChurchPage(), profile: _profile);

@Preview(name: '5. Pending approval', group: 'Onboarding', size: Size(390, 844))
Widget pendingApproval() => _wrap(
  const PendingApprovalPage(),
  profile: _profile,
  membership: _membership(MembershipStatus.pending),
);

@Preview(name: '5b. Not approved', group: 'Onboarding', size: Size(390, 844))
Widget noAccess() => _wrap(
  const NoAccessPage(),
  profile: _profile,
  membership: _membership(MembershipStatus.archived),
);

@Preview(
  name: '5c. Welcome (first entry)',
  group: 'Onboarding',
  size: Size(390, 844),
)
Widget welcome() => _wrap(
  const WelcomePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active, onboardingCompleted: false),
);

@Preview(name: '6. Home (active)', group: 'Onboarding', size: Size(390, 844))
Widget home() => _wrap(
  const HomePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
);

@Preview(name: '6b. Home (approver)', group: 'Onboarding', size: Size(390, 844))
Widget homeApprover() => _wrap(
  const HomePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  roles: const {ChurchRole.admin, ChurchRole.coordinator},
  requests: _requests,
);

@Preview(
  name: '6c. Membership requests',
  group: 'Onboarding',
  size: Size(390, 844),
)
Widget pendingMembers() => _wrap(
  const PendingMembersPage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  roles: const {ChurchRole.coordinator},
  requests: _requests,
);

@Preview(
  name: '6d. Membership requests, empty',
  group: 'Onboarding',
  size: Size(390, 844),
)
Widget pendingMembersEmpty() => _wrap(
  const PendingMembersPage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  roles: const {ChurchRole.coordinator},
);

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

@Preview(name: '7. Profile, active', group: 'Profile', size: Size(390, 844))
Widget profileActive() => _wrap(
  const ProfilePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
);

@Preview(name: '8. Profile, no church', group: 'Profile', size: Size(390, 844))
Widget profileNoChurch() => _wrap(const ProfilePage(), profile: _profile);

@Preview(name: '9. Profile, pending', group: 'Profile', size: Size(390, 844))
Widget profilePending() => _wrap(
  const ProfilePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.pending),
);

@Preview(
  name: '10. Profile, long name + no phone',
  group: 'Profile',
  size: Size(390, 844),
)
Widget profileLongName() => _wrap(
  const ProfilePage(),
  profile: _longNameProfile,
  membership: _membership(MembershipStatus.active),
);

@Preview(name: '11. Edit profile', group: 'Profile', size: Size(390, 844))
Widget editProfile() => _wrap(
  const EditProfilePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
);

// ---------------------------------------------------------------------------
// Stress cases
// ---------------------------------------------------------------------------

@Preview(
  name: 'Sign up, large text',
  group: 'Stress',
  size: Size(390, 844),
  textScaleFactor: 1.5,
)
Widget signUpLargeText() => _wrap(const SignUpPage());

@Preview(name: 'Sign in, small screen', group: 'Stress', size: Size(320, 568))
Widget signInSmallScreen() => _wrap(const SignInPage());

@Preview(name: 'Home, small screen', group: 'Stress', size: Size(320, 568))
Widget homeSmallScreen() => _wrap(
  const HomePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
);

// ---------------------------------------------------------------------------
// Dark mode
// ---------------------------------------------------------------------------

@Preview(name: 'Sign in, dark', group: 'Dark', size: Size(390, 844))
Widget signInDark() => _wrap(const SignInPage(), dark: true);

@Preview(name: 'Sign up, dark', group: 'Dark', size: Size(390, 844))
Widget signUpDark() => _wrap(const SignUpPage(), dark: true);

@Preview(name: 'Splash, dark', group: 'Dark', size: Size(390, 844))
Widget splashDark() => _wrap(const SplashPage(), dark: true);

@Preview(name: 'No membership, dark', group: 'Dark', size: Size(390, 844))
Widget joinChurchDark() =>
    _wrap(const JoinChurchPage(), profile: _profile, dark: true);

@Preview(name: 'Pending approval, dark', group: 'Dark', size: Size(390, 844))
Widget pendingApprovalDark() => _wrap(
  const PendingApprovalPage(),
  profile: _profile,
  membership: _membership(MembershipStatus.pending),
  dark: true,
);

@Preview(name: 'Home, dark', group: 'Dark', size: Size(390, 844))
Widget homeDark() => _wrap(
  const HomePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  dark: true,
);

@Preview(name: 'Profile, dark', group: 'Dark', size: Size(390, 844))
Widget profileDark() => _wrap(
  const ProfilePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  dark: true,
);

@Preview(name: 'Edit profile, dark', group: 'Dark', size: Size(390, 844))
Widget editProfileDark() => _wrap(
  const EditProfilePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  dark: true,
);

@Preview(
  name: 'Join church, small screen',
  group: 'Stress',
  size: Size(320, 568),
)
Widget joinChurchSmallScreen() =>
    _wrap(const JoinChurchPage(), profile: _profile);

@Preview(
  name: 'Profile, large text',
  group: 'Stress',
  size: Size(390, 844),
  textScaleFactor: 1.5,
)
Widget profileLargeText() => _wrap(
  const ProfilePage(),
  profile: _longNameProfile,
  membership: _membership(MembershipStatus.active),
);
