import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/discipleship/presentation/disciple_detail_page.dart';
import '../features/discipleship/presentation/journey_page.dart';
import '../features/discipleship/presentation/record_meeting_page.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/application/intro_state.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/presentation/start_page.dart';
import '../features/auth/presentation/verify_email_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/membership_review/presentation/pending_members_page.dart';
import '../features/ministry/presentation/add_members_page.dart';
import '../features/ministry/presentation/d_group_detail_page.dart';
import '../features/ministry/presentation/d_group_form_page.dart';
import '../features/ministry/presentation/d_groups_page.dart';
import '../features/ministry/presentation/my_group_page.dart';
import '../features/onboarding/presentation/join_church_page.dart';
import '../features/onboarding/presentation/no_access_page.dart';
import '../features/onboarding/presentation/pending_approval_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/session/application/session_state.dart';
import 'dock_shell.dart';
import 'routes.dart';
import 'transitions.dart';

/// The route a given session state belongs on.
///
/// Pure, so the whole redirect policy is unit-testable without a router,
/// a container or a network.
String destinationFor(SessionState state) => switch (state) {
  SessionState.unknown => Routes.splash,
  SessionState.signedOut => Routes.start,
  SessionState.noMembership => Routes.joinChurch,
  SessionState.pending => Routes.pendingApproval,
  SessionState.activeFirstEntry => Routes.welcome,
  SessionState.active => Routes.home,
  SessionState.noAccess => Routes.noAccess,
};

/// Locations a state may stay on besides its own destination.
Set<String> allowedFor(SessionState state) => switch (state) {
  // Nothing is shown until the session has resolved.
  SessionState.unknown => const {},
  // Sign-in, sign-up and email verification are interchangeable while
  // signed out. Verification lives here because Supabase issues no session
  // before the email is confirmed.
  SessionState.signedOut => const {
    Routes.signIn,
    Routes.signUp,
    Routes.verifyEmail,
  },
  SessionState.noMembership ||
  SessionState.pending ||
  SessionState.noAccess => Routes.profileRoutes,
  // The welcome is shown exactly once and cannot be skipped by navigating.
  SessionState.activeFirstEntry => const {},
  SessionState.active => const {
    ...Routes.profileRoutes,
    Routes.pendingMembers,
    ...Routes.ministryRoutes,
    ...Routes.discipleshipRoutes,
  },
};

/// Whether the route matched by [routePattern] is allowed while in [state].
///
/// [routePattern] is the matched route's full path with its parameters left
/// in, for example `/groups/:groupId`, so one entry in [allowedFor] covers
/// every group. An empty pattern (nothing matched) is never allowed.
///
/// Returns null to stay put, or the path to redirect to.
String? redirectFor(SessionState state, String routePattern) {
  final destination = destinationFor(state);
  if (routePattern == destination) return null;
  if (allowedFor(state).contains(routePattern)) return null;
  return destination;
}

final routerProvider = Provider<GoRouter>((ref) {
  // A plain ValueNotifier is enough: GoRouter only needs to be told that
  // something changed, and the redirect re-reads the state itself.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionStateProvider, (_, _) => refresh.value++);
  ref.listen(introCompleteProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      // The launch animation plays to the end before anything else shows.
      if (!ref.read(introCompleteProvider)) {
        return state.matchedLocation == Routes.splash ? null : Routes.splash;
      }
      return redirectFor(ref.read(sessionStateProvider), state.fullPath ?? '');
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (c, s) => buildPage(state: s, child: const SplashPage()),
      ),
      GoRoute(
        path: Routes.start,
        pageBuilder: (c, s) => buildPage(state: s, child: const StartPage()),
        routes: [
          GoRoute(
            path: 'sign-in',
            pageBuilder: (c, s) =>
                buildPage(state: s, child: const SignInPage()),
          ),
          GoRoute(
            path: 'sign-up',
            pageBuilder: (c, s) =>
                buildPage(state: s, child: const SignUpPage()),
          ),
        ],
      ),
      GoRoute(
        path: Routes.verifyEmail,
        pageBuilder: (c, s) =>
            buildPage(state: s, child: const VerifyEmailPage()),
      ),
      GoRoute(
        path: Routes.joinChurch,
        pageBuilder: (c, s) =>
            buildPage(state: s, child: const JoinChurchPage()),
      ),
      GoRoute(
        path: Routes.pendingApproval,
        pageBuilder: (c, s) =>
            buildPage(state: s, child: const PendingApprovalPage()),
      ),
      GoRoute(
        path: Routes.noAccess,
        pageBuilder: (c, s) => buildPage(state: s, child: const NoAccessPage()),
      ),
      GoRoute(
        path: Routes.welcome,
        pageBuilder: (c, s) => buildPage(state: s, child: const WelcomePage()),
      ),
      // Every screen of a signed-in member sits inside the dock shell. The
      // shell only draws the dock for an ACTIVE session, so the profile
      // screens reached while PENDING keep their plain back button.
      ShellRoute(
        builder: (c, s, child) => DockShell(location: s.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (c, s) => buildPage(state: s, child: const HomePage()),
          ),
          GoRoute(
            path: Routes.profile,
            pageBuilder: (c, s) =>
                buildPage(state: s, child: const ProfilePage()),
          ),
          GoRoute(
            path: Routes.editProfile,
            pageBuilder: (c, s) =>
                buildPage(state: s, child: const EditProfilePage()),
          ),
          GoRoute(
            path: Routes.pendingMembers,
            pageBuilder: (c, s) =>
                buildPage(state: s, child: const PendingMembersPage()),
          ),
          // Nested so the back stack follows the hierarchy. `new` is declared
          // before `:groupId` so it is not read as a group id.
          GoRoute(
            path: Routes.dGroups,
            pageBuilder: (c, s) =>
                buildPage(state: s, child: const DGroupsPage()),
            routes: [
              GoRoute(
                path: 'new',
                pageBuilder: (c, s) =>
                    buildPage(state: s, child: const DGroupFormPage()),
              ),
              GoRoute(
                path: ':groupId',
                pageBuilder: (c, s) => buildPage(
                  state: s,
                  child: DGroupDetailPage(
                    groupId: s.pathParameters['groupId']!,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'add-members',
                    pageBuilder: (c, s) => buildPage(
                      state: s,
                      child: AddMembersPage(
                        groupId: s.pathParameters['groupId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.myGroup,
            pageBuilder: (c, s) =>
                buildPage(state: s, child: const MyGroupPage()),
          ),
          GoRoute(
            path: Routes.journey,
            pageBuilder: (c, s) => buildPage(
              state: s,
              child: JourneyPage(initialView: s.uri.queryParameters['view']),
            ),
          ),
          // My Disciples lives in Journey (N8). The path stays as the parent
          // of one Disciple's pages, which are opened from a relationship.
          GoRoute(
            path: Routes.myDisciples,
            redirect: (c, s) => s.uri.path == Routes.myDisciples
                ? Routes.journeyDisciples
                : null,
            routes: [
              GoRoute(
                path: ':membershipId',
                pageBuilder: (c, s) => buildPage(
                  state: s,
                  child: DiscipleDetailPage(
                    membershipId: s.pathParameters['membershipId']!,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'record',
                    pageBuilder: (c, s) => buildPage(
                      state: s,
                      child: RecordMeetingPage(
                        membershipId: s.pathParameters['membershipId']!,
                        initialDate: DateTime.tryParse(
                          s.uri.queryParameters['date'] ?? '',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
