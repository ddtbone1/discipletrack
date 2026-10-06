/// The integrity rules of Migrations 006, 012 and 013 hold for every writer,
/// including the service role, which bypasses RLS and the controlled
/// operations. Defence in depth: these rules do not rely on the RPCs being
/// the only path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestChurch otherChurch;
  late TestGroup g1;
  late TestGroup g2;

  setUpAll(() async {
    church = await seedChurch(name: 'Ministry Integrity Church');
    otherChurch = await seedChurch(name: 'Other Integrity Church');
    g1 = await createGroupWithLeader(church, tag: 'int-g1');
    g2 = await createGroupWithLeader(church, tag: 'int-g2');
  });
  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    await deleteUser(g1.leader.user.userId);
    await deleteUser(g2.leader.user.userId);
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  final rejected = throwsA(isA<PostgrestException>());

  String now([Duration offset = Duration.zero]) =>
      DateTime.now().toUtc().add(offset).toIso8601String();

  Future<TestMember> member(String tag, [String? churchId]) async {
    final m = await createActiveMember(
      churchId ?? church.churchId,
      fullName: 'Integrity $tag',
      tag: tag,
    );
    addTearDown(() => deleteUser(m.user.userId));
    return m;
  }

  Future<String> insertPlacement(
    String groupId,
    String membershipId, {
    String? startedAt,
  }) async {
    final row = await service
        .from('d_group_placements')
        .insert({
          'd_group_id': groupId,
          'church_membership_id': membershipId,
          'started_at': startedAt ?? now(const Duration(days: -30)),
          'placed_by': church.approver.userId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> insertDgm(
    String groupId,
    String membershipId,
    String responsibility, {
    String? startedAt,
    String? endedAt,
    String? basis,
    bool withBasis = true,
  }) async {
    final row = await service
        .from('d_group_memberships')
        .insert({
          'd_group_id': groupId,
          'church_membership_id': membershipId,
          'responsibility': responsibility,
          'started_at': startedAt ?? now(),
          'ended_at': ?endedAt,
          'assigned_by': church.approver.userId,
          'discipler_basis':
              basis ??
              (withBasis && responsibility == 'DISCIPLER'
                  ? 'INITIAL_ROLLOUT'
                  : null),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Places [m] in [groupId] and gives them [responsibility].
  Future<String> placed(
    String groupId,
    TestMember m,
    String responsibility,
  ) async {
    if (await activePlacementOf(m.membershipId) == null) {
      await insertPlacement(groupId, m.membershipId);
    }
    return insertDgm(groupId, m.membershipId, responsibility);
  }

  Future<void> insertAssignment(
    String groupId,
    String disciplerDgm,
    String discipleDgm,
  ) => service.from('discipler_assignments').insert({
    'd_group_id': groupId,
    'discipler_d_group_membership_id': disciplerDgm,
    'disciple_d_group_membership_id': discipleDgm,
    'assigned_by': church.approver.userId,
    'started_at': now(),
  });

  group('placements', () {
    test('a person is in at most one group at a time', () async {
      final m = await member('one-group');
      await insertPlacement(g1.groupId, m.membershipId);
      await expectLater(insertPlacement(g2.groupId, m.membershipId), rejected);
      await expectLater(
        insertPlacement(g1.groupId, m.membershipId),
        rejected,
        reason: 'not twice in the same group either',
      );
    });

    test('a placement cannot cross churches', () async {
      final foreign = await member('foreign-pl', otherChurch.churchId);
      await expectLater(
        insertPlacement(g1.groupId, foreign.membershipId),
        rejected,
      );
    });

    test('an active responsibility needs a placement in that group', () async {
      final m = await member('no-placement');
      await expectLater(
        insertDgm(g1.groupId, m.membershipId, 'DISCIPLE'),
        rejected,
      );
      await insertPlacement(g2.groupId, m.membershipId);
      await expectLater(
        insertDgm(g1.groupId, m.membershipId, 'DISCIPLE'),
        rejected,
        reason: 'placed in a different group',
      );
    });

    test('a placement cannot end while it holds a responsibility', () async {
      final m = await member('end-early');
      await placed(g1.groupId, m, 'DISCIPLE');
      final id = (await activePlacementOf(m.membershipId))!;
      await expectLater(
        service
            .from('d_group_placements')
            .update({'ended_at': now(), 'ended_by': church.approver.userId})
            .eq('id', id),
        rejected,
      );
    });
  });

  test('a person cannot hold responsibilities in two groups at once', () async {
    final m = await member('two');
    await placed(g1.groupId, m, 'DISCIPLER');
    await expectLater(
      insertDgm(g2.groupId, m.membershipId, 'DISCIPLER'),
      rejected,
    );
  });

  test('DISCIPLE may coexist with DISCIPLER (ADR-012) but not with '
      'LEADER', () async {
    final m = await member('excl');
    await placed(g1.groupId, m, 'DISCIPLE');
    await insertDgm(g1.groupId, m.membershipId, 'DISCIPLER');

    // A Leader cannot also be a Disciple.
    await expectLater(
      insertDgm(g1.groupId, g1.leader.membershipId, 'DISCIPLE'),
      rejected,
    );
  });

  test('a DISCIPLER row carries its basis; other rows carry none', () async {
    final m = await member('basis');
    await insertPlacement(g1.groupId, m.membershipId);
    await expectLater(
      insertDgm(g1.groupId, m.membershipId, 'DISCIPLER', withBasis: false),
      rejected,
    );
    await expectLater(
      insertDgm(g1.groupId, m.membershipId, 'DISCIPLE', basis: 'APPOINTMENT'),
      rejected,
    );
  });

  test('periods for the same person, group and responsibility cannot '
      'overlap, even in history', () async {
    final m = await member('overlap');
    await insertDgm(
      g1.groupId,
      m.membershipId,
      'DISCIPLER',
      startedAt: now(const Duration(days: -10)),
      endedAt: now(const Duration(days: -5)),
    );
    await expectLater(
      insertDgm(
        g1.groupId,
        m.membershipId,
        'DISCIPLER',
        startedAt: now(const Duration(days: -7)),
        endedAt: now(const Duration(days: -6)),
      ),
      rejected,
    );
    // Back to back is not an overlap.
    await insertDgm(
      g1.groupId,
      m.membershipId,
      'DISCIPLER',
      startedAt: now(const Duration(days: -5)),
      endedAt: now(const Duration(days: -4)),
    );
  });

  test('a D Group membership cannot cross churches', () async {
    final foreign = await member('foreign', otherChurch.churchId);
    await expectLater(
      insertDgm(
        g1.groupId,
        foreign.membershipId,
        'DISCIPLE',
        endedAt: now(const Duration(days: 1)),
        startedAt: now(const Duration(days: -1)),
      ),
      rejected,
    );
  });

  test('an invitation cannot cross churches', () async {
    final foreign = await member('foreign-inv', otherChurch.churchId);
    await expectLater(
      service.from('d_group_invitations').insert({
        'd_group_id': g1.groupId,
        'church_membership_id': foreign.membershipId,
        'responsibility': 'DISCIPLE',
        'invited_by': church.approver.userId,
        'expires_at': now(const Duration(days: 14)),
      }),
      rejected,
    );
  });

  test('an assignment needs a DISCIPLER side and a DISCIPLE side in its own '
      'group', () async {
    final dr = await member('pair-dr');
    final dd = await member('pair-dd');
    final dd2 = await member('pair-dd2');
    final drDgm = await placed(g1.groupId, dr, 'DISCIPLER');
    final ddDgm = await placed(g1.groupId, dd, 'DISCIPLE');
    final dd2Dgm = await placed(g2.groupId, dd2, 'DISCIPLE');

    // Sides swapped.
    await expectLater(insertAssignment(g1.groupId, ddDgm, drDgm), rejected);
    // The Leader row is not a DISCIPLER row.
    await expectLater(
      insertAssignment(g1.groupId, g1.leaderDgmId, ddDgm),
      rejected,
    );
    // Disciple in another group.
    await expectLater(insertAssignment(g1.groupId, drDgm, dd2Dgm), rejected);
    // Assignment recorded against the wrong group.
    await expectLater(insertAssignment(g2.groupId, drDgm, ddDgm), rejected);

    await insertAssignment(g1.groupId, drDgm, ddDgm);
  });

  test('a Disciple who is also a Discipler cannot be paired with '
      'themselves', () async {
    final m = await member('self');
    final ddDgm = await placed(g1.groupId, m, 'DISCIPLE');
    final drDgm = await insertDgm(g1.groupId, m.membershipId, 'DISCIPLER');
    await expectLater(insertAssignment(g1.groupId, drDgm, ddDgm), rejected);
  });

  test('two people cannot disciple each other at the same time (D7)', () async {
    final a = await member('recip-a');
    final b = await member('recip-b');
    final aDd = await placed(g1.groupId, a, 'DISCIPLE');
    final aDr = await insertDgm(g1.groupId, a.membershipId, 'DISCIPLER');
    final bDd = await placed(g1.groupId, b, 'DISCIPLE');
    final bDr = await insertDgm(g1.groupId, b.membershipId, 'DISCIPLER');

    await insertAssignment(g1.groupId, aDr, bDd);
    await expectLater(insertAssignment(g1.groupId, bDr, aDd), rejected);
  });
}
