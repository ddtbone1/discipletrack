/// Slice 8 Phase 3: the app's PlatformRepository and MembershipRepository
/// against the real local stack. The Dart parsing matches what the Phase 2
/// operations return, and refusals come back with their reason, so the
/// Platform area, Church information and the church unavailable state read
/// exactly what the database says.
library;

import 'package:discipletrack/core/supabase/postgrest_failure.dart';
import 'package:discipletrack/features/curriculum/data/curriculum_repository.dart';
import 'package:discipletrack/features/membership/data/membership_repository.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/platform/data/platform_repository.dart';
import 'package:discipletrack/features/platform/domain/platform_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestUser superAdmin;
  late TestChurch church;
  final cleanupUsers = <String>[];
  final cleanupChurches = <String>[];

  setUpAll(() async {
    superAdmin = await createSuperAdmin(tag: 'prr-super');
    church = await seedChurch(name: 'Platform Repository Church');
  });

  tearDownAll(() async {
    for (final id in cleanupChurches) {
      await deleteChurchRows(id);
    }
    await deleteChurch(church);
    for (final id in cleanupUsers) {
      await deleteUser(id);
    }
    await deleteUser(superAdmin.userId);
  });

  Future<TestUser> account(String tag) async {
    final u = await createUser(fullName: 'Account $tag', tag: tag);
    cleanupUsers.add(u.userId);
    return u;
  }

  test('the platform role is read for the person themselves only', () async {
    expect(
      await PlatformRepository(superAdmin.client)
          .fetchMyRoles(superAdmin.userId),
      {PlatformRole.superAdmin},
    );
    expect(
      await PlatformRepository(church.approver.client)
          .fetchMyRoles(church.approver.userId),
      isEmpty,
    );
  });

  test('provisioning end to end through the app repository', () async {
    final repo = PlatformRepository(superAdmin.client);
    final coord = await account('prr-coord');

    final preview = await repo.previewAccount(null, coord.email);
    expect(preview.found, isTrue);
    expect(preview.fullName, 'Account prr-coord');
    expect(preview.problem, isNull);

    final missing = await repo.previewAccount(null, 'nobody@x.test');
    expect(missing.found, isFalse);
    expect(missing.problem, PlatformFailure.messageFor('account_not_found'));

    final created = await repo.createChurch(
      name: 'Repository Created Church',
      coordinatorEmail: coord.email,
    );
    cleanupChurches.add(created.churchId);
    expect(created.joinCode, matches(RegExp(r'^[A-HJ-NP-Z2-9]{10}$')));

    var row = (await repo.listChurches()).singleWhere(
      (c) => c.id == created.churchId,
    );
    expect(row.status, ChurchStatus.active);
    expect(row.joinCode, created.joinCode);
    expect(row.coordinators.single.fullName, 'Account prr-coord');
    expect(row.coordinators.single.email, coord.email);
    expect(row.membersActive, 1);

    // The only Coordinator cannot be removed; the refusal keeps its reason.
    await expectLater(
      repo.endCoordinator(
        created.churchId,
        row.coordinators.single.membershipId,
      ),
      throwsA(
        isA<PlatformFailure>()
            .having((e) => e.reason, 'reason', 'last_coordinator')
            .having(
              (e) => e.message,
              'message',
              PlatformFailure.messageFor('last_coordinator'),
            ),
      ),
    );

    // Replace them.
    final next = await account('prr-next');
    await repo.replaceCoordinator(
      created.churchId,
      currentMembershipId: row.coordinators.single.membershipId,
      email: next.email,
    );
    row = (await repo.listChurches()).singleWhere(
      (c) => c.id == created.churchId,
    );
    expect(row.coordinators.single.fullName, 'Account prr-next');
    expect(row.membersActive, 2, reason: 'the replaced person stays a member');

    final code = await repo.regenerateJoinCode(created.churchId);
    expect(code, isNot(created.joinCode));

    await repo.setStatus(created.churchId, ChurchStatus.suspended);
    row = (await repo.listChurches()).singleWhere(
      (c) => c.id == created.churchId,
    );
    expect(row.status, ChurchStatus.suspended);

    final events = await repo.listEvents(churchId: created.churchId);
    expect(
      events.map((e) => e.label).toSet(),
      containsAll([
        'Church created',
        'Coordinator added',
        'Coordinator replaced',
        'Join code changed',
        'Church suspended',
      ]),
    );

    await repo.setStatus(created.churchId, ChurchStatus.archived);
    await expectLater(
      repo.setStatus(created.churchId, ChurchStatus.active),
      throwsA(
        isA<PlatformFailure>().having(
          (e) => e.reason,
          'reason',
          'church_archived',
        ),
      ),
    );
  });

  test('a church member is refused every platform operation', () async {
    final repo = PlatformRepository(church.approver.client);
    await expectLater(
      repo.listChurches(),
      throwsA(
        isA<PlatformFailure>().having(
          (e) => e.message,
          'message',
          PlatformFailure.messageFor('not_authorized'),
        ),
      ),
    );
    await expectLater(
      repo.regenerateJoinCode(church.churchId),
      throwsA(isA<PlatformFailure>()),
    );
  });

  test('the church status the app resolves, and the Coordinator\'s join code, '
      'while ACTIVE and while SUSPENDED', () async {
    final coordinatorRepo = MembershipRepository(church.approver.client);
    final member = await createActiveMember(
      church.churchId,
      fullName: 'Repo Member',
      tag: 'prr-mem',
    );
    cleanupUsers.add(member.user.userId);
    final memberRepo = MembershipRepository(member.user.client);

    expect(
      (await memberRepo.fetchChurch(church.churchId))!.status,
      ChurchStatus.active,
    );
    final code = await coordinatorRepo.fetchJoinCode(church.churchId);
    expect(code.code, church.joinCode);
    expect(code.setAt, isNull, reason: 'seeded without a regeneration');
    await expectLater(
      memberRepo.fetchJoinCode(church.churchId),
      throwsA(
        isA<MembershipFailure>().having(
          (e) => e.code,
          'code',
          DbFailureCode.forbidden,
        ),
      ),
    );

    await PlatformRepository(superAdmin.client)
        .setStatus(church.churchId, ChurchStatus.suspended);
    try {
      final seen = await memberRepo.fetchChurch(church.churchId);
      expect(seen!.status, ChurchStatus.suspended);
      expect(seen.name, 'Platform Repository Church');
      expect(
        await memberRepo.fetchMyMembership(member.user.userId),
        isNotNull,
        reason: 'the own membership stays readable',
      );
      await expectLater(
        coordinatorRepo.fetchJoinCode(church.churchId),
        throwsA(isA<MembershipFailure>()),
      );
      // Nothing of the curriculum while suspended.
      final content = CurriculumRepository(member.user.client);
      await expectLater(
        content.fetchLessonAccess(),
        throwsA(isA<CurriculumFailure>()),
      );
    } finally {
      await PlatformRepository(superAdmin.client)
          .setStatus(church.churchId, ChurchStatus.active);
    }
  });
}
