import 'package:discipletrack/core/connectivity/connection_status.dart';
import 'package:discipletrack/core/supabase/supabase_providers.dart';
import 'package:discipletrack/features/membership/data/membership_repository.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:discipletrack/features/offline/data/offline_snapshot.dart';
import 'package:discipletrack/features/profile/data/profile_repository.dart';
import 'package:discipletrack/features/profile/domain/profile.dart';
import 'package:discipletrack/features/session/application/session_state.dart';
import 'package:discipletrack/features/membership/application/membership_providers.dart';
import 'package:discipletrack/features/profile/application/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'u1';

OfflineSnapshot _snapshot({String userId = _userId}) => OfflineSnapshot(
  userId: userId,
  savedAt: DateTime.utc(2026, 10, 1, 9),
  profile: Profile(
    id: userId,
    fullName: 'Diana Cruz',
    phone: '+63 900 000 0003',
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 2),
  ),
  membership: ChurchMembership(
    id: 'cm1',
    churchId: 'c1',
    userId: userId,
    status: MembershipStatus.active,
    joinedAt: DateTime.utc(2026, 9, 3),
    requestedAt: DateTime.utc(2026, 9, 2),
    onboardingCompletedAt: DateTime.utc(2026, 9, 3),
  ),
  church: const ChurchSummary(
    id: 'c1',
    name: 'Liberty Bible Baptist Church - Gensan',
  ),
  roles: const {ChurchRole.coordinator},
  ministry: const MinistryContext(
    dGroupId: 'g1',
    dGroupName: 'Young Adults A',
    memberCount: 7,
    roster: [
      RosterEntry(
        dGroupMembershipId: 'dgm-lea',
        churchMembershipId: 'cm-lea',
        fullName: 'Lea Santos',
        responsibility: DGroupResponsibility.leader,
        phone: '+63 900 000 0001',
        isMyLeader: true,
      ),
      RosterEntry(
        dGroupMembershipId: 'dgm-me',
        churchMembershipId: 'cm1',
        fullName: 'Diana Cruz',
        responsibility: DGroupResponsibility.disciple,
        isMe: true,
      ),
    ],
  ),
);

/// Throws the network failure a repository raises when the server cannot be
/// reached, or returns the configured value.
class _ProfileRepo implements ProfileRepository {
  Object? failure;
  Profile? value;

  @override
  Future<Profile?> fetchMyProfile(String userId) async {
    if (failure != null) throw failure!;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _MembershipRepo implements MembershipRepository {
  Object? failure;
  ChurchMembership? value;

  @override
  Future<ChurchMembership?> fetchMyMembership(String userId) async {
    if (failure != null) throw failure!;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _offline = ProfileFailure(
  'Could not load your profile.',
  isNetwork: true,
);
const _membershipOffline = MembershipFailure(
  'Could not reach DiscipleTrack.',
  code: MembershipFailureCode.network,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OfflineSnapshot', () {
    test('round-trips every part through JSON', () {
      final original = _snapshot();
      final back = OfflineSnapshot.fromJson(original.toJson())!;

      expect(back.userId, _userId);
      expect(back.savedAt, original.savedAt);
      expect(back.profile!.fullName, 'Diana Cruz');
      expect(back.profile!.phone, '+63 900 000 0003');
      expect(back.membership!.status, MembershipStatus.active);
      expect(back.membership!.onboardingCompletedAt, DateTime.utc(2026, 9, 3));
      expect(back.church!.name, 'Liberty Bible Baptist Church - Gensan');
      expect(back.roles, {ChurchRole.coordinator});
      expect(back.ministry!.dGroupName, 'Young Adults A');
      expect(back.ministry!.memberCount, 7);
      expect(back.ministry!.isDisciple, isTrue);
      expect(back.ministry!.leader!.phone, '+63 900 000 0001');
    });

    test('an unplaced member saves no roster and reads back unplaced', () {
      final unplaced = OfflineSnapshot(
        userId: _userId,
        savedAt: DateTime.utc(2026, 10, 1),
        profile: null,
        membership: null,
        church: null,
        roles: const {},
        ministry: null,
      );
      final back = OfflineSnapshot.fromJson(unplaced.toJson())!;
      expect(back.ministry, isNull);
      expect(back.membership, isNull);
    });

    test('another version or a damaged entry is ignored, not misread', () {
      final json = _snapshot().toJson()..['version'] = 999;
      expect(OfflineSnapshot.fromJson(json), isNull);
      expect(OfflineSnapshot.fromJson({'version': 1}), isNull);
    });
  });

  group('OfflineSnapshotStore', () {
    test(
      'keeps one snapshot per user and never returns another user\'s',
      () async {
        final store = OfflineSnapshotStore(enabled: true);
        await store.write(_snapshot());
        await store.write(_snapshot(userId: 'u2'));

        expect((await store.read(_userId))!.userId, _userId);
        expect((await store.read('u2'))!.userId, 'u2');
        expect(await store.read('u3'), isNull);
      },
    );

    test(
      'clearAll deletes every snapshot and leaves other keys alone',
      () async {
        SharedPreferences.setMockInitialValues({'other': 'kept'});
        final store = OfflineSnapshotStore(enabled: true);
        await store.write(_snapshot());
        await store.write(_snapshot(userId: 'u2'));

        await store.clearAll();

        expect(await store.read(_userId), isNull);
        expect(await store.read('u2'), isNull);
        expect(
          (await SharedPreferences.getInstance()).getString('other'),
          'kept',
        );
      },
    );

    test('disabled (the web) writes and reads nothing', () async {
      final store = OfflineSnapshotStore(enabled: false);
      await store.write(_snapshot());
      expect(await store.read(_userId), isNull);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });
  });

  group('liveOrSaved', () {
    late OfflineSnapshotStore store;
    setUp(() => store = OfflineSnapshotStore(enabled: true));

    ProviderContainer container(_ProfileRepo repo) {
      final c = ProviderContainer(
        // Riverpod retries failed providers; the tests want the failure.
        retry: (_, _) => null,
        overrides: [
          currentUserIdProvider.overrideWithValue(_userId),
          offlineSnapshotStoreProvider.overrideWithValue(store),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a live answer is used and marks the app online', () async {
      final repo = _ProfileRepo()..value = _snapshot().profile;
      final c = container(repo);
      c.read(isOfflineProvider.notifier).markOffline();

      final profile = await c.read(myProfileProvider.future);
      expect(profile!.fullName, 'Diana Cruz');
      expect(c.read(isOfflineProvider), isFalse);
    });

    test('an unreachable server answers from the snapshot and marks the app '
        'offline', () async {
      await store.write(_snapshot());
      final c = container(_ProfileRepo()..failure = _offline);

      final profile = await c.read(myProfileProvider.future);
      expect(profile!.phone, '+63 900 000 0003');
      expect(c.read(isOfflineProvider), isTrue);
    });

    test('once offline, reads answer from the snapshot without calling the '
        'server', () async {
      await store.write(_snapshot());
      final repo = _ProfileRepo()..failure = StateError('must not be called');
      final c = container(repo);
      c.read(isOfflineProvider.notifier).markOffline();

      final profile = await c.read(myProfileProvider.future);
      expect(profile!.fullName, 'Diana Cruz');
      expect(c.read(isOfflineProvider), isTrue);
    });

    test('with no snapshot the network failure stands', () async {
      final c = container(_ProfileRepo()..failure = _offline);

      await expectLater(
        c.read(myProfileProvider.future),
        throwsA(isA<ProfileFailure>()),
      );
      expect(c.read(isOfflineProvider), isTrue);
    });

    test('a refusal is never replaced by saved data', () async {
      await store.write(_snapshot());
      final c = container(
        _ProfileRepo()..failure = const ProfileFailure('Not allowed.'),
      );

      await expectLater(
        c.read(myProfileProvider.future),
        throwsA(isA<ProfileFailure>()),
      );
      expect(c.read(isOfflineProvider), isFalse);
    });

    test('a raw transport exception is not mistaken for anything but '
        'itself; only failures that say isNetwork count', () {
      expect(isNetworkFailure(_offline), isTrue);
      expect(isNetworkFailure(_membershipOffline), isTrue);
      expect(isNetworkFailure(const ProfileFailure('x')), isFalse);
      expect(isNetworkFailure(const AuthException('x')), isFalse);
    });
  });

  test(
    'a restored session opened offline resolves from the snapshot',
    () async {
      final store = OfflineSnapshotStore(enabled: true);
      await store.write(_snapshot());
      final c = ProviderContainer(
        // Riverpod retries failed providers; the tests want the failure.
        retry: (_, _) => null,
        overrides: [
          currentSessionProvider.overrideWithValue(
            Session(
              accessToken: 'token',
              tokenType: 'bearer',
              user: const User(
                id: _userId,
                appMetadata: {},
                userMetadata: {},
                aud: 'authenticated',
                createdAt: '2026-09-01T00:00:00Z',
              ),
            ),
          ),
          currentUserIdProvider.overrideWithValue(_userId),
          offlineSnapshotStoreProvider.overrideWithValue(store),
          profileRepositoryProvider.overrideWithValue(
            _ProfileRepo()..failure = _offline,
          ),
          membershipRepositoryProvider.overrideWithValue(
            _MembershipRepo()..failure = _membershipOffline,
          ),
        ],
      );
      addTearDown(c.dispose);

      c.listen(sessionStateProvider, (_, _) {});
      await c.read(myProfileProvider.future);
      await c.read(myMembershipProvider.future);

      expect(c.read(sessionStateProvider), SessionState.active);
      expect(c.read(isOfflineProvider), isTrue);
    },
  );
}
