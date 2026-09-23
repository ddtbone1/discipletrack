import 'package:discipletrack/app/router.dart';
import 'package:discipletrack/app/routes.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/session/application/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveSessionState', () {
    test('no session is signedOut, even while loading', () {
      expect(
        resolveSessionState(
          hasSession: false,
          isLoading: true,
          hasError: false,
          membershipStatus: null,
        ),
        SessionState.signedOut,
      );
    });

    test('a session with data still loading is unknown, not signedOut', () {
      // This is what keeps the splash on screen during restoration instead of
      // flashing the sign-in page.
      expect(
        resolveSessionState(
          hasSession: true,
          isLoading: true,
          hasError: false,
          membershipStatus: null,
        ),
        SessionState.unknown,
      );
    });

    test('an error while signed in is unknown, not signedOut', () {
      // A failed profile fetch must never look like being logged out.
      expect(
        resolveSessionState(
          hasSession: true,
          isLoading: false,
          hasError: true,
          membershipStatus: null,
        ),
        SessionState.unknown,
      );
    });

    test('signed in with no membership', () {
      expect(
        resolveSessionState(
          hasSession: true,
          isLoading: false,
          hasError: false,
          membershipStatus: null,
        ),
        SessionState.noMembership,
      );
    });

    test('each membership status maps to its state', () {
      SessionState of(MembershipStatus s, {bool completed = false}) =>
          resolveSessionState(
            hasSession: true,
            isLoading: false,
            hasError: false,
            membershipStatus: s,
            onboardingCompleted: completed,
          );

      expect(of(MembershipStatus.pending), SessionState.pending);
      expect(of(MembershipStatus.active), SessionState.activeFirstEntry);
      expect(of(MembershipStatus.active, completed: true), SessionState.active);
      expect(of(MembershipStatus.inactive), SessionState.noAccess);
      expect(of(MembershipStatus.transferred), SessionState.noAccess);
      expect(of(MembershipStatus.archived), SessionState.noAccess);
    });

    test('onboarding completion only matters for ACTIVE', () {
      expect(
        resolveSessionState(
          hasSession: true,
          isLoading: false,
          hasError: false,
          membershipStatus: MembershipStatus.pending,
          onboardingCompleted: true,
        ),
        SessionState.pending,
      );
    });
  });

  group('destinationFor', () {
    test('every state has a destination', () {
      for (final state in SessionState.values) {
        expect(destinationFor(state), isNotEmpty);
      }
    });

    test('unknown goes to the splash, never to sign-in', () {
      expect(destinationFor(SessionState.unknown), Routes.splash);
    });

    test('active goes home, pending goes to approval', () {
      expect(destinationFor(SessionState.active), Routes.home);
      expect(destinationFor(SessionState.pending), Routes.pendingApproval);
    });

    test('first entry goes to the welcome, not home', () {
      expect(destinationFor(SessionState.activeFirstEntry), Routes.welcome);
    });

    test('noAccess has its own screen and is not routed to home or join', () {
      expect(destinationFor(SessionState.noAccess), Routes.noAccess);
      expect(destinationFor(SessionState.noAccess), isNot(Routes.home));
      expect(destinationFor(SessionState.noAccess), isNot(Routes.joinChurch));
    });
  });

  group('redirectFor', () {
    test('stays put when already on the right page', () {
      expect(redirectFor(SessionState.active, Routes.home), isNull);
      expect(redirectFor(SessionState.signedOut, Routes.signIn), isNull);
    });

    test('sign-up and email verification are allowed while signed out', () {
      expect(redirectFor(SessionState.signedOut, Routes.signUp), isNull);
      expect(redirectFor(SessionState.signedOut, Routes.verifyEmail), isNull);
    });

    test('a signed-out user is pushed off protected pages', () {
      expect(redirectFor(SessionState.signedOut, Routes.home), Routes.signIn);
      expect(
        redirectFor(SessionState.signedOut, Routes.profile),
        Routes.signIn,
      );
      expect(
        redirectFor(SessionState.signedOut, Routes.welcome),
        Routes.signIn,
      );
    });

    test('a signed-in user is pushed off the auth pages', () {
      expect(redirectFor(SessionState.active, Routes.signIn), Routes.home);
      expect(
        redirectFor(SessionState.noMembership, Routes.signUp),
        Routes.joinChurch,
      );
      expect(
        redirectFor(SessionState.pending, Routes.verifyEmail),
        Routes.pendingApproval,
      );
    });

    test('own profile is reachable from every resolved authenticated state '
        'except first entry', () {
      // RBAC section 3 grants "User -> own profile" ungated by membership,
      // and section 1a lets a PENDING member see their onboarding state.
      for (final state in [
        SessionState.noMembership,
        SessionState.pending,
        SessionState.active,
        SessionState.noAccess,
      ]) {
        expect(redirectFor(state, Routes.profile), isNull, reason: '$state');
        expect(
          redirectFor(state, Routes.editProfile),
          isNull,
          reason: '$state',
        );
      }
    });

    test('the welcome cannot be skipped by navigating elsewhere', () {
      expect(
        redirectFor(SessionState.activeFirstEntry, Routes.home),
        Routes.welcome,
      );
      expect(
        redirectFor(SessionState.activeFirstEntry, Routes.profile),
        Routes.welcome,
      );
    });

    test('the welcome is never shown once onboarding is complete', () {
      expect(redirectFor(SessionState.active, Routes.welcome), Routes.home);
    });

    test('profile is NOT reachable while unknown or signed out', () {
      expect(redirectFor(SessionState.unknown, Routes.profile), Routes.splash);
      expect(
        redirectFor(SessionState.signedOut, Routes.profile),
        Routes.signIn,
      );
    });

    test('an unresolved session is held on the splash', () {
      expect(redirectFor(SessionState.unknown, Routes.home), Routes.splash);
      expect(redirectFor(SessionState.unknown, Routes.signIn), Routes.splash);
    });

    test('a pending member cannot reach home', () {
      expect(
        redirectFor(SessionState.pending, Routes.home),
        Routes.pendingApproval,
      );
    });

    test('a member without access cannot reach home or the join flow', () {
      expect(redirectFor(SessionState.noAccess, Routes.home), Routes.noAccess);
      expect(
        redirectFor(SessionState.noAccess, Routes.joinChurch),
        Routes.noAccess,
      );
    });

    test('membership review is reachable only when active', () {
      expect(redirectFor(SessionState.active, Routes.pendingMembers), isNull);
      for (final state in [
        SessionState.noMembership,
        SessionState.pending,
        SessionState.activeFirstEntry,
        SessionState.noAccess,
        SessionState.signedOut,
      ]) {
        expect(
          redirectFor(state, Routes.pendingMembers),
          destinationFor(state),
          reason: '$state',
        );
      }
    });
  });
}
