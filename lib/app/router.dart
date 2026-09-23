import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/onboarding/presentation/join_church_page.dart';
import '../features/onboarding/presentation/pending_approval_page.dart';
import '../features/profile/presentation/edit_profile_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/home/presentation/home_page.dart';
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
  SessionState.active => Routes.home,
  SessionState.noAccess => Routes.joinChurch,
};

/// Whether [location] is allowed while in [state].
///
/// Returns null to stay put, or the path to redirect to.
String? redirectFor(SessionState state, String location) {
  final destination = destinationFor(state);
  if (location == destination) return null;

  // Sign-in and sign-up are interchangeable while signed out.
  if (state == SessionState.signedOut) {
    return location == Routes.signUp ? null : Routes.signIn;
  }

  // Own profile stays reachable from every authenticated state.
  if (state != SessionState.unknown &&
      Routes.alwaysAllowedWhenAuthenticated.contains(location)) {
    return null;
  }

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
    ],
  );
});
