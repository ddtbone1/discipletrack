/// Route paths, in one place so no string is typed twice.
abstract final class Routes {
  static const splash = '/splash';

  /// The welcome page for someone signed out. Login and Sign Up open as
  /// sheets over it, so they are nested under it.
  static const start = '/start';
  static const signIn = '/start/sign-in';
  static const signUp = '/start/sign-up';

  /// Reached from sign-up (no session is issued until the email is confirmed)
  /// or from a sign-in that failed with `email_not_confirmed`.
  static const verifyEmail = '/verify-email';

  static const joinChurch = '/onboarding/join';
  static const pendingApproval = '/onboarding/pending';

  /// INACTIVE, TRANSFERRED or ARCHIVED, including a rejected request.
  static const noAccess = '/onboarding/no-access';

  /// A PENDING or ACTIVE membership in a SUSPENDED or ARCHIVED church
  /// (ADR-022 decision 14).
  static const churchUnavailable = '/church-unavailable';

  /// The Coordinator's read-only view of the church's join code (ADR-022
  /// decision 10a).
  static const churchInfo = '/church/info';

  /// The platform Super Admin's area (ADR-022, UI_DESIGN_SYSTEM section 70).
  /// [platformChurch] is a pattern: build a path with [platformChurchFor].
  static const platform = '/platform';
  static const platformNewChurch = '/platform/new';

  /// The New church stepper's later pages (UI_DESIGN_SYSTEM section 70).
  static const platformNewChurchCoordinator = '/platform/new/coordinator';
  static const platformNewChurchConfirm = '/platform/new/confirm';

  /// Not under [platformNewChurch]: back from it returns to the list.
  static const platformNewChurchDone = '/platform/created';
  static const platformChurch = '/platform/churches/:churchId';

  static String platformChurchFor(String churchId) =>
      '/platform/churches/$churchId';

  /// Reachable by a Super Admin from any resolved state; the database checks
  /// the platform role on every call.
  static const platformRoutes = {
    platform,
    platformNewChurch,
    platformNewChurchCoordinator,
    platformNewChurchConfirm,
    platformNewChurchDone,
    platformChurch,
  };

  /// The one-time first-entry welcome.
  static const welcome = '/welcome';

  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const changePassword = '/profile/password';

  /// Membership-request review for Admins and Coordinators.
  static const pendingMembers = '/members/pending';

  /// The Coordinator's list of D Groups.
  static const dGroups = '/groups';
  static const newDGroup = '/groups/new';

  /// One D Group, for its Coordinator or Leader. A pattern: build a concrete
  /// path with [dGroupDetailFor].
  static const dGroupDetail = '/groups/:groupId';
  static const dGroupAddMembers = '/groups/:groupId/add-members';

  /// The roster for a Discipler or Disciple.
  static const myGroup = '/my-group';

  /// Journey (Slice 5, N8): My Journey and My Disciples, derived from the
  /// person's relationships. [journeyDisciples] selects the My Disciples tab
  /// when both views exist; it is ignored otherwise.
  static const journey = '/journey';
  static const journeyDisciples = '/journey?view=disciples';

  /// One Disciple's journey and history, and recording a meeting for them.
  /// Patterns: build concrete paths with [discipleDetailFor] and
  /// [recordMeetingFor]. [myDisciples] itself redirects to Journey.
  static const myDisciples = '/disciples';
  static const discipleDetail = '/disciples/:membershipId';
  static const recordMeeting = '/disciples/:membershipId/record';

  static String discipleDetailFor(String membershipId) =>
      '/disciples/$membershipId';

  /// [on] preselects the meeting's date (a day, local time).
  static String recordMeetingFor(String membershipId, {DateTime? on}) =>
      on == null
      ? '/disciples/$membershipId/record'
      : '/disciples/$membershipId/record?date=${_isoDay(on)}';

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String dGroupDetailFor(String groupId) => '/groups/$groupId';
  static String dGroupAddMembersFor(String groupId) =>
      '/groups/$groupId/add-members';

  /// D Group screens. Reachable by any ACTIVE member; what each one shows is
  /// decided by RLS and the controlled operations, so a deep link by someone
  /// without authority opens an empty or refused screen, never data.
  static const ministryRoutes = {
    dGroups,
    newDGroup,
    dGroupDetail,
    dGroupAddMembers,
    myGroup,
  };

  /// Reachable from every authenticated state that has resolved a membership.
  ///
  /// RBAC section 3 grants "User -> own profile" without gating it on
  /// membership, and section 1a lets a PENDING member see their own onboarding
  /// state, so the profile screens are not restricted to ACTIVE members.
  static const profileRoutes = {profile, editProfile, changePassword};

  /// The lesson list and the lesson reader (Slice 7). [lessonsFor] and
  /// [lessonFor] add `?for=<membershipId>` to read in the context of a
  /// Disciple; the database decides what each reader may open (ADR-019).
  static const lessons = '/lessons';
  static const lessonReader = '/lessons/:lessonId';

  /// The Coordinator's Curriculum: the lesson list as oversight, kept apart
  /// from My Journey (ADR-023 decision 10). What opens is still the
  /// database's answer; the view only decides how a lesson is presented.
  static const curriculumView = 'curriculum';
  static const curriculum = '/lessons?view=$curriculumView';

  static String lessonsFor({String? forMembershipId}) =>
      forMembershipId == null ? lessons : '/lessons?for=$forMembershipId';

  static String lessonFor(
    String lessonId, {
    String? forMembershipId,
    bool oversight = false,
  }) => Uri(
    path: '/lessons/$lessonId',
    queryParameters: {
      'for': ?forMembershipId,
      if (oversight) 'view': curriculumView,
    },
  ).toString().replaceFirst(RegExp(r'\?$'), '');

  /// Curriculum screens. Reachable by any ACTIVE member; a lesson the reader
  /// may not open is refused by the database, never shown.
  static const curriculumRoutes = {lessons, lessonReader};

  /// Discipleship screens. Reachable by any ACTIVE member; each read and
  /// write is authorized by the database for the pair (caller, person), so
  /// a deep link without authority opens a refused screen, never data.
  static const discipleshipRoutes = {
    journey,
    myDisciples,
    discipleDetail,
    recordMeeting,
  };
}
