import 'dart:async';

import 'package:discipletrack/core/supabase/supabase_providers.dart';
import 'package:discipletrack/features/membership/application/membership_providers.dart';
import 'package:discipletrack/features/membership/data/membership_repository.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/offline/data/offline_snapshot.dart';
import 'package:discipletrack/features/platform/application/platform_providers.dart';
import 'package:discipletrack/features/platform/domain/platform_models.dart';
import 'package:discipletrack/features/profile/application/profile_providers.dart';
import 'package:discipletrack/features/profile/data/profile_repository.dart';
import 'package:discipletrack/features/profile/domain/profile.dart';
import 'package:discipletrack/features/session/application/session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'u1';

Session _session(String id) => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-09-01T00:00:00Z',
  ),
);

/// The session a test switches, standing in for Supabase auth.
class _SessionHolder extends Notifier<Session?> {
  @override
  Session? build() => null;

  void set(Session? s) => state = s;
}

final _sessionHolder = NotifierProvider<_SessionHolder, Session?>(
  _SessionHolder.new,
);

/// Answers only when the test completes [membership], so the state while
/// the fetch is in flight can be observed.
class _SlowMembershipRepo implements MembershipRepository {
  final membership = Completer<ChurchMembership?>();

  @override
  Future<ChurchMembership?> fetchMyMembership(String userId) =>
      membership.future;

  @override
  Future<ChurchSummary?> fetchChurch(String churchId) async =>
      ChurchSummary(id: churchId, name: 'Liberty Bible Baptist Church');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _ProfileRepo implements ProfileRepository {
  @override
  Future<Profile?> fetchMyProfile(String userId) async => Profile(
    id: userId,
    fullName: 'Diana Cruz',
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 2),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('signing in never routes on the signed-out membership: the state '
      'stays unknown until the member is loaded', () async {
    final membershipRepo = _SlowMembershipRepo();
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        currentSessionProvider.overrideWith((ref) => ref.watch(_sessionHolder)),
        offlineSnapshotStoreProvider.overrideWithValue(
          OfflineSnapshotStore(enabled: false),
        ),
        profileRepositoryProvider.overrideWithValue(_ProfileRepo()),
        membershipRepositoryProvider.overrideWithValue(membershipRepo),
        // No platform role: an ordinary member (ADR-022).
        myPlatformAccessProvider.overrideWith(
          (ref) async => PlatformAccess(
            userId: ref.watch(currentUserIdProvider) ?? '',
            roles: const {},
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    final seen = <SessionState>[];
    c.listen(sessionStateProvider, (_, next) => seen.add(next));
    // The splash reads the membership while signed out: it settles on null.
    c.listen(myMembershipProvider, (_, _) {});
    await c.read(myMembershipProvider.future);
    expect(c.read(sessionStateProvider), SessionState.signedOut);

    c.read(_sessionHolder.notifier).set(_session(_userId));
    await c.read(myProfileProvider.future);
    expect(c.read(sessionStateProvider), SessionState.unknown);

    membershipRepo.membership.complete(
      ChurchMembership(
        id: 'cm1',
        churchId: 'c1',
        userId: _userId,
        status: MembershipStatus.active,
        joinedAt: DateTime.utc(2026, 9, 3),
        requestedAt: DateTime.utc(2026, 9, 2),
        onboardingCompletedAt: DateTime.utc(2026, 9, 3),
      ),
    );
    await c.read(myMembershipProvider.future);
    await c.read(myChurchProvider.future);

    expect(c.read(sessionStateProvider), SessionState.active);
    // Never Join Church, the Platform area or the unavailable screen first.
    expect(seen, isNot(contains(SessionState.platform)));
    expect(seen, isNot(contains(SessionState.churchUnavailable)));
    expect(seen, isNot(contains(SessionState.noMembership)));
    expect(seen, isNot(contains(SessionState.activeFirstEntry)));
  });
}
