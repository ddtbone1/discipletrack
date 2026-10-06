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

  /// The one-time first-entry welcome.
  static const welcome = '/welcome';

  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';

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
  static const profileRoutes = {profile, editProfile};

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
