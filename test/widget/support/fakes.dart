/// Hand-written fakes for widget tests. No mocking package is needed for a
/// surface this small, and `noSuchMethod` keeps them short.
library;

import 'package:discipletrack/core/supabase/supabase_providers.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:discipletrack/features/membership/application/membership_providers.dart';
import 'package:discipletrack/features/membership/data/membership_repository.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/membership_review/application/membership_review_providers.dart';
import 'package:discipletrack/features/membership_review/data/membership_review_repository.dart';
import 'package:discipletrack/features/membership_review/domain/membership_request.dart';
import 'package:discipletrack/features/profile/application/profile_providers.dart';
import 'package:discipletrack/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const sampleUserId = '11111111-1111-1111-1111-111111111111';
const sampleChurchId = '44444444-4444-4444-4444-444444444444';

final sampleProfile = Profile(
  id: sampleUserId,
  fullName: 'James Mercado',
  createdAt: DateTime.utc(2026, 3, 14, 12),
  updatedAt: DateTime.utc(2026, 9, 20, 12),
);

const sampleChurch = ChurchSummary(
  id: sampleChurchId,
  name: 'Bankal Seventh-day Adventist Church',
);

ChurchMembership sampleMembership(
  MembershipStatus status, {
  DateTime? joinedAt,
  DateTime? requestedAt,
  DateTime? onboardingCompletedAt,
}) => ChurchMembership(
  id: '33333333-3333-3333-3333-333333333333',
  churchId: sampleChurchId,
  userId: sampleUserId,
  status: status,
  joinedAt: joinedAt,
  requestedAt: requestedAt ?? DateTime.utc(2026, 9, 25, 9),
  onboardingCompletedAt: onboardingCompletedAt,
);

/// Records calls and returns whatever the test configured.
class FakeMembershipRepository implements MembershipRepository {
  ChurchMembership? membership;
  ChurchSummary? church = sampleChurch;
  Set<ChurchRole> roles = const {};

  ChurchSummary? lookupResult;
  MembershipFailure? lookupFailure;
  JoinRequestOutcome requestOutcome = JoinRequestOutcome.requested;
  MembershipFailure? requestFailure;
  MembershipFailure? completeFailure;

  final lookups = <String>[];
  final requests = <({String churchId, String joinCode})>[];
  int fetchMembershipCalls = 0;
  int completeCalls = 0;

  @override
  Future<ChurchMembership?> fetchMyMembership(String userId) async {
    fetchMembershipCalls++;
    return membership;
  }

  @override
  Future<ChurchSummary?> lookupChurchByJoinCode(String code) async {
    lookups.add(code);
    if (lookupFailure != null) throw lookupFailure!;
    return lookupResult;
  }

  @override
  Future<JoinRequestOutcome> requestJoinChurch({
    required String churchId,
    required String joinCode,
  }) async {
    requests.add((churchId: churchId, joinCode: joinCode));
    if (requestFailure != null) throw requestFailure!;
    return requestOutcome;
  }

  @override
  Future<void> completeOnboarding() async {
    completeCalls++;
    if (completeFailure != null) throw completeFailure!;
  }

  @override
  Future<ChurchSummary?> fetchChurch(String churchId) async => church;

  @override
  Future<Set<ChurchRole>> fetchMyChurchRoles(String membershipId) async =>
      roles;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeAuthRepository implements AuthRepository {
  SignUpOutcome signUpOutcome = const SignUpVerificationRequired(
    'juan@example.test',
  );
  AuthFailure? signUpFailure;
  AuthFailure? signInFailure;
  AuthFailure? verifyFailure;
  AuthFailure? resendFailure;

  final signUps = <({String email, String password, String fullName})>[];
  final signIns = <({String email, String password})>[];
  final verifications = <({String email, String code})>[];
  final resends = <String>[];
  int signOuts = 0;

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    signUps.add((email: email, password: password, fullName: fullName));
    if (signUpFailure != null) throw signUpFailure!;
    return signUpOutcome;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signIns.add((email: email, password: password));
    if (signInFailure != null) throw signInFailure!;
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    verifications.add((email: email, code: code));
    if (verifyFailure != null) throw verifyFailure!;
  }

  @override
  Future<void> resendVerificationCode(String email) async {
    resends.add(email);
    if (resendFailure != null) throw resendFailure!;
  }

  @override
  Future<void> signOut() async => signOuts++;

  @override
  String? get currentUserId => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeMembershipReviewRepository implements MembershipReviewRepository {
  List<MembershipRequest> pending = const [];
  MembershipFailure? actionFailure;
  final approved = <String>[];
  final rejected = <String>[];

  @override
  Future<List<MembershipRequest>> fetchPendingRequests(String churchId) async =>
      pending;

  @override
  Future<void> approve(String membershipId) async {
    approved.add(membershipId);
    if (actionFailure != null) throw actionFailure!;
  }

  @override
  Future<void> reject(String membershipId) async {
    rejected.add(membershipId);
    if (actionFailure != null) throw actionFailure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Pumps [page] inside a `MaterialApp` with the standard overrides.
///
/// Every provider the onboarding screens read is overridden, so nothing
/// reaches `Supabase.instance`. The membership controller is real (only its
/// initial `build` is replaced), so `refresh()` runs against the fake
/// repository exactly as it would against the network.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  Profile? profile,
  ChurchMembership? membership,
  ChurchSummary? church = sampleChurch,
  Set<ChurchRole> roles = const {},
  FakeMembershipRepository? membershipRepo,
  FakeAuthRepository? auth,
  FakeMembershipReviewRepository? reviewRepo,
  ThemeMode mode = ThemeMode.light,
}) async {
  final repo = membershipRepo ?? FakeMembershipRepository()
    ..membership = membership;
  repo.church = church;
  repo.roles = roles;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(sampleUserId),
        myProfileProvider.overrideWith((ref) async => profile ?? sampleProfile),
        myMembershipProvider.overrideWithBuild(
          (ref, notifier) async => membership,
        ),
        membershipRepositoryProvider.overrideWithValue(repo),
        myChurchProvider.overrideWith((ref) async => church),
        myChurchRolesProvider.overrideWith((ref) async => roles),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
        if (reviewRepo != null)
          membershipReviewRepositoryProvider.overrideWithValue(reviewRepo),
        if (reviewRepo != null)
          pendingMembershipRequestsProvider.overrideWith(
            (ref) async => reviewRepo.pending,
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: page,
      ),
    ),
  );
  await tester.pump();
}
