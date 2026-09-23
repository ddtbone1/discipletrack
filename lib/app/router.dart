import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/presentation/verify_email_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/membership_review/presentation/pending_members_page.dart';
import '../features/onboarding/presentation/join_church_page.dart';
import '../features/onboarding/presentation/no_access_page.dart';
import '../features/onboarding/presentation/pending_approval_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/session/application/session_state.dart';
import 'routes.dart';
import 'transitions.dart';

/// The route a given session state belongs on.
///
/// Pure, so the whole redirect policy is unit-testable without a router,
/// a container or a network.
String destinationFor(SessionState state) => switch (state) {
  SessionState.unknown => Routes.splash,
  SessionState.signedOut => Routes.signIn,
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
  SessionState.signedOut => const {Routes.signUp, Routes.verifyEmail},
  SessionState.noMembership ||
  SessionState.pending ||
  SessionState.noAccess => Routes.profileRoutes,
  // The welcome is shown exactly once and cannot be skipped by navigating.
  SessionState.activeFirstEntry => const {},
  SessionState.active => const {...Routes.profileRoutes, Routes.pendingMembers},
};

/// Whether [location] is allowed while in [state].
///
/// Returns null to stay put, or the path to redirect to.
String? redirectFor(SessionState state, String location) {
  final destination = destinationFor(state);
  if (location == destination) return null;
  if (allowedFor(state).contains(location)) return null;
  return destination;
}

final routerProvider = Provider<GoRouter>((ref) {
  // A plain ValueNotifier is enough: GoRouter only needs to be told that
  // something changed, and the redirect re-reads the state itself.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionStateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionStateProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (c, s) => buildPage(state: s, child: const SplashPage()),
      ),
      GoRoute(
        path: Routes.signIn,
        pageBuilder: (c, s) => buildPage(state: s, child: const SignInPage()),
      ),
      GoRoute(
        path: Routes.signUp,
        pageBuilder: (c, s) => buildPage(state: s, child: const SignUpPage()),
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
      GoRoute(
        path: Routes.home,
        pageBuilder: (c, s) => buildPage(state: s, child: const HomePage()),
      ),
      GoRoute(
        path: Routes.profile,
        pageBuilder: (c, s) => buildPage(state: s, child: const ProfilePage()),
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
    ],
  );
});
