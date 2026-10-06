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
import '../features/ministry/application/ministry_providers.dart';
import '../features/ministry/domain/d_group.dart';
import '../features/ministry/domain/d_group_detail.dart';
import '../features/ministry/domain/d_group_placement.dart';
import '../features/ministry/domain/d_group_member.dart';
import '../features/ministry/domain/discipler_assignment.dart';
import '../features/ministry/domain/member_option.dart';
import '../features/ministry/domain/ministry_context.dart';
import '../features/ministry/presentation/d_group_detail_page.dart';
import '../features/ministry/presentation/d_groups_page.dart';
import '../features/ministry/data/ministry_repository.dart';
import '../features/ministry/presentation/add_members_page.dart';
import '../features/ministry/presentation/my_group_page.dart';
import '../features/onboarding/presentation/join_church_page.dart';
import '../features/onboarding/presentation/no_access_page.dart';
import '../features/onboarding/presentation/pending_approval_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import '../features/profile/application/profile_providers.dart';
import '../features/profile/domain/profile.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/profile_page.dart';

/// Previews of every screen in the Auth + Profile, Church Join and Ministry
/// Structure slices.
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
  name: 'Liberty Bible Baptist Church - Gensan',
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

const _groupId = '55555555-5555-5555-5555-555555555555';

DGroupMember _dgm(
  String id,
  String name,
  DGroupResponsibility r, [
  String? phone,
]) => DGroupMember(
  dGroupMembershipId: id,
  churchMembershipId: 'cm-$id',
  fullName: name,
  responsibility: r,
  phone: phone,
  startedAt: DateTime(2026, 9, 1),
);

final _groupDetail = DGroupDetail(
  group: const DGroup(
    id: _groupId,
    name: 'Young Adults A',
    description: 'Thursday evenings at the fellowship hall.',
    status: DGroupStatus.active,
  ),
  placements: [
    for (final p in [
      ('lea', 'Lea Santos'),
      ('dino', 'Dino Reyes'),
      ('diana', 'Diana Cruz'),
      ('daniel', 'Daniel Bautista'),
      ('mara', 'Mara Villanueva'),
    ])
      DGroupPlacement(
        placementId: 'pl-${p.$1}',
        churchMembershipId: 'cm-${p.$1}',
        fullName: p.$2,
        startedAt: DateTime(2026, 9, 1),
      ),
  ],
  members: [
    _dgm('lea', 'Lea Santos', DGroupResponsibility.leader, '+63 917 555 0102'),
    _dgm(
      'dino',
      'Dino Reyes',
      DGroupResponsibility.discipler,
      '+63 917 555 0103',
    ),
    _dgm('diana', 'Diana Cruz', DGroupResponsibility.disciple),
    _dgm('daniel', 'Daniel Bautista', DGroupResponsibility.disciple),
  ],
  assignments: [
    DisciplerAssignment(
      id: 'a1',
      disciplerDGroupMembershipId: 'dino',
      discipleDGroupMembershipId: 'diana',
      startedAt: DateTime(2026, 9, 2),
    ),
  ],
);

RosterEntry _roster(
  String id,
  String name,
  DGroupResponsibility r, {
  String? phone,
  bool me = false,
  bool leader = false,
  bool discipler = false,
}) => RosterEntry(
  dGroupMembershipId: id,
  churchMembershipId: 'cm-$id',
  fullName: name,
  responsibility: r,
  phone: phone,
  isMe: me,
  isMyLeader: leader,
  isMyDiscipler: discipler,
);

final _discipleContext = MinistryContext(
  dGroupId: _groupId,
  dGroupName: 'Young Adults A',
  roster: [
    _roster(
      'lea',
      'Lea Santos',
      DGroupResponsibility.leader,
      phone: '+63 917 555 0102',
      leader: true,
    ),
    _roster(
      'dino',
      'Dino Reyes',
      DGroupResponsibility.discipler,
      phone: '+63 917 555 0103',
      discipler: true,
    ),
    _roster('me', 'James Mercado', DGroupResponsibility.disciple, me: true),
    _roster('daniel', 'Daniel Bautista', DGroupResponsibility.disciple),
  ],
);

final _leaderContext = MinistryContext(
  dGroupId: _groupId,
  dGroupName: 'Young Adults A',
  roster: [
    _roster('me', 'James Mercado', DGroupResponsibility.leader, me: true),
  ],
);

final _needsSetupContext = MinistryContext(
  dGroupId: _groupId,
  dGroupName: 'Young Adults A',
  roster: [
    _roster('lea', 'Lea Santos', DGroupResponsibility.leader, leader: true),
  ],
);

final _groups = [
  DGroupSummary(
    group: _groupDetail.group,
    leaderName: 'Lea Santos',
    disciplerCount: 1,
    discipleCount: 2,
  ),
  const DGroupSummary(
    group: DGroup(id: 'g2', name: 'Men of Faith', status: DGroupStatus.active),
    leaderName: 'Ramon Garcia',
    disciplerCount: 2,
    discipleCount: 5,
  ),
];

final _addable = [
  AddableMember(
    churchMembershipId: 'm1',
    fullName: 'Mara Villanueva',
    joinedAt: DateTime(2026, 9, 14),
  ),
  AddableMember(
    churchMembershipId: 'm2',
    fullName: 'Paolo Lim',
    joinedAt: DateTime(2026, 8, 30),
  ),
];

const _placeable = [
  MemberOption(churchMembershipId: 'm1', fullName: 'Mara Villanueva'),
  MemberOption(churchMembershipId: 'm2', fullName: 'Paolo Lim'),
  MemberOption(
    churchMembershipId: 'm3',
    fullName: 'Diana Cruz',
    currentDGroupId: _groupId,
    currentDGroupName: 'Young Adults A',
    currentResponsibilities: {DGroupResponsibility.disciple},
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
  MinistryContext? ministry,
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
      myMinistryContextProvider.overrideWith((ref) async => ministry),
      initialSetupStatusProvider.overrideWith(
        (ref) async => const InitialSetupStatus(isOpen: true),
      ),
      addableMembersProvider.overrideWith((ref, id) async => _addable),
      groupDisciplerCandidatesProvider.overrideWith(
        (ref, id) async => const [],
      ),
      churchDisciplerCandidatesProvider.overrideWith((ref) async => const []),
      dGroupsProvider.overrideWith((ref) async => _groups),
      unplacedMemberCountProvider.overrideWith((ref) async => 3),
      dGroupDetailProvider.overrideWith((ref, id) async => _groupDetail),
      placeableMembersProvider.overrideWith((ref, id) async => _placeable),
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

// ---------------------------------------------------------------------------
// Ministry structure
// ---------------------------------------------------------------------------

@Preview(name: '12. Home (Leader)', group: 'Ministry', size: Size(390, 844))
Widget homeLeader() => _wrap(
  const HomePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  ministry: _leaderContext,
);

@Preview(name: '13. Home (Disciple)', group: 'Ministry', size: Size(390, 844))
Widget homeDisciple() => _wrap(
  const HomePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  ministry: _discipleContext,
);

@Preview(
  name: '14. Home (needs setup)',
  group: 'Ministry',
  size: Size(390, 844),
)
Widget homeNeedsSetup() => _wrap(
  const HomePage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  ministry: _needsSetupContext,
);

@Preview(name: '15. D Groups', group: 'Ministry', size: Size(390, 844))
Widget dGroups() => _wrap(
  const DGroupsPage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  roles: const {ChurchRole.coordinator},
);

@Preview(name: '16. Group detail', group: 'Ministry', size: Size(390, 844))
Widget dGroupDetail() => _wrap(
  const DGroupDetailPage(groupId: _groupId),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  roles: const {ChurchRole.coordinator},
);

@Preview(name: '17. Add members', group: 'Ministry', size: Size(390, 844))
Widget addMembers() => _wrap(
  const AddMembersPage(groupId: _groupId),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  roles: const {ChurchRole.coordinator},
);

@Preview(name: '18. My group', group: 'Ministry', size: Size(390, 844))
Widget myGroup() => _wrap(
  const MyGroupPage(),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  ministry: _discipleContext,
);

@Preview(name: 'Group detail, dark', group: 'Dark', size: Size(390, 844))
Widget dGroupDetailDark() => _wrap(
  const DGroupDetailPage(groupId: _groupId),
  profile: _profile,
  membership: _membership(MembershipStatus.active),
  roles: const {ChurchRole.coordinator},
  dark: true,
);
