/// The integrity triggers of Migration 006 hold for every writer, including
/// the service role, which bypasses RLS and the controlled operations.
/// Defence in depth: these rules do not rely on the RPCs being the only path.
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

  Future<String> insertDgm(
    String groupId,
    String membershipId,
    String responsibility, {
    String? startedAt,
    String? endedAt,
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
        })
        .select('id')
        .single();
    return row['id'] as String;
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

  test('a person cannot hold responsibilities in two groups at once', () async {
    final m = await member('two');
    await insertDgm(g1.groupId, m.membershipId, 'DISCIPLER');
    await expectLater(
      insertDgm(g2.groupId, m.membershipId, 'DISCIPLER'),
      rejected,
    );
  });

  test('DISCIPLE cannot coexist with DISCIPLER or LEADER', () async {
    final m = await member('excl');
    await insertDgm(g1.groupId, m.membershipId, 'DISCIPLE');
    await expectLater(
      insertDgm(g1.groupId, m.membershipId, 'DISCIPLER'),
      rejected,
    );

    // A Leader cannot also be a Disciple.
    await expectLater(
      insertDgm(g1.groupId, g1.leader.membershipId, 'DISCIPLE'),
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
      insertDgm(g1.groupId, foreign.membershipId, 'DISCIPLE'),
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
    final drDgm = await insertDgm(g1.groupId, dr.membershipId, 'DISCIPLER');
    final ddDgm = await insertDgm(g1.groupId, dd.membershipId, 'DISCIPLE');
    final dd2Dgm = await insertDgm(g2.groupId, dd2.membershipId, 'DISCIPLE');

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
}
