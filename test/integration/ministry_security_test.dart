/// Ministry authorization against the real local stack: who can see and do
/// what, tested explicitly rather than assumed (AGENTS.md, Testing
/// expectations). Every negative here is a refusal by PostgreSQL itself.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestChurch otherChurch;

  // One populated group shared by the read-scope tests:
  //   leader, discipler (paired with disciple1), disciple1, disciple2, and
  //   newcomer, who was added but still needs setup
  late TestGroup g;
  late TestGroup g2;
  late TestMember discipler;
  late TestMember disciple1;
  late TestMember disciple2;
  late TestMember newcomer;
  late TestMember plain;
  late TestMember adminOnly;
  late String disciplerDgm;
  late String disciple1Dgm;
  late String disciple2Dgm;
  late String disciple2Placement;
  late String newcomerPlacement;

  const unknownId = '00000000-0000-4000-8000-0000000000ee';

  final cleanup = <String>[];

  setUpAll(() async {
    church = await seedChurch(name: 'Ministry Security Church');
    otherChurch = await seedChurch(name: 'Other Ministry Church');

    g = await createGroupWithLeader(church, tag: 'sec-lead');
    g2 = await createGroupWithLeader(church, tag: 'sec-lead2');
    discipler = await createActiveMember(
      church.churchId,
      fullName: 'Sec Discipler',
      tag: 'sec-dr',
      phone: '+63 900 000 0002',
    );
    disciple1 = await createActiveMember(
      church.churchId,
      fullName: 'Sec Disciple One',
      tag: 'sec-dd1',
      phone: '+63 900 000 0003',
    );
    disciple2 = await createActiveMember(
      church.churchId,
      fullName: 'Sec Disciple Two',
      tag: 'sec-dd2',
      phone: '+63 900 000 0004',
    );
    newcomer = await createActiveMember(
      church.churchId,
      fullName: 'Sec Newcomer',
      tag: 'sec-new',
      phone: '+63 900 000 0005',
    );
    plain = await createActiveMember(
      church.churchId,
      fullName: 'Sec Plain Member',
      tag: 'sec-plain',
    );
    adminOnly = await createActiveMember(
      church.churchId,
      fullName: 'Sec Admin Only',
      tag: 'sec-admin',
    );
    // A former Admin: the role is retired and its rows ended (ADR-022).
    await service
        .from('church_role_assignments')
        .insert(formerAdminRow(adminOnly.membershipId, church.approver.userId));

    final leaderClient = g.leader.user.client;
    disciplerDgm = await place(leaderClient, g.groupId, discipler, 'DISCIPLER');
    disciple1Dgm = await place(leaderClient, g.groupId, disciple1, 'DISCIPLE');
    disciple2Dgm = await place(leaderClient, g.groupId, disciple2, 'DISCIPLE');
    await setDiscipler(leaderClient, disciple1Dgm, disciplerDgm);
    disciple2Placement = (await activePlacementOf(disciple2.membershipId))!;
    newcomerPlacement = (await addMembers(leaderClient, g.groupId, [
      newcomer.membershipId,
    ]))[newcomer.membershipId]!;

    cleanup.addAll([
      g.leader.user.userId,
      g2.leader.user.userId,
      discipler.user.userId,
      disciple1.user.userId,
      disciple2.user.userId,
      newcomer.user.userId,
      plain.user.userId,
      adminOnly.user.userId,
    ]);
  });

  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final id in cleanup) {
      await deleteUser(id);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  Future<TestMember> unplaced(String tag) async {
    final m = await createActiveMember(
      church.churchId,
      fullName: 'Unplaced $tag',
      tag: tag,
    );
    addTearDown(() => deleteUser(m.user.userId));
    return m;
  }

  Future<List<dynamic>> groupsSeenBy(SupabaseClient c) =>
      c.from('d_groups').select('id').eq('id', g.groupId);

  Future<List<dynamic>> profileSeenBy(SupabaseClient c, TestMember m) =>
      c.from('profiles').select('id, phone').eq('id', m.user.userId);

  /// Every structure-changing operation on group [g], as [c]; each must be
  /// refused with PT403.
  Future<void> expectNoManagementAuthority(
    SupabaseClient c,
    TestMember target,
  ) async {
    await expectLater(
      addMembers(c, g.groupId, [target.membershipId]),
      throwsPostgrestCode('PT403'),
    );
    await expectLater(
      c.rpc<List<dynamic>>(
        'list_addable_members',
        params: {'p_d_group_id': g.groupId},
      ),
      throwsPostgrestCode('PT403'),
    );
    await expectLater(
      setUpMember(c, newcomerPlacement, 'DISCIPLE'),
      throwsPostgrestCode('PT403'),
    );
    await expectLater(
      setDiscipler(c, disciple2Dgm, disciplerDgm),
      throwsPostgrestCode('PT403'),
    );
    await expectLater(
      c.rpc<List<dynamic>>(
        'remove_from_d_group',
        params: {'p_d_group_placement_id': disciple2Placement},
      ),
      throwsPostgrestCode('PT403'),
    );
  }

  group('another church', () {
    test(
      'its Coordinator neither sees nor acts on this church\'s groups',
      () async {
        final c = otherChurch.approver.client;
        expect(await groupsSeenBy(c), isEmpty);
        expect(
          await c
              .from('d_group_memberships')
              .select('id')
              .eq('d_group_id', g.groupId),
          isEmpty,
        );
        expect(
          await c
              .from('d_group_placements')
              .select('id')
              .eq('d_group_id', g.groupId),
          isEmpty,
        );

        final m = await unplaced('xchurch');
        await expectNoManagementAuthority(c, m);
        await expectLater(
          c.rpc<List<dynamic>>(
            'create_d_group',
            params: {
              'p_name': uniqueGroupName(),
              'p_description': null,
              'p_leader_membership_id': m.membershipId,
            },
          ),
          throwsPostgrestCode('PT403'),
        );
        await expectLater(
          c.rpc<List<dynamic>>(
            'list_placeable_members',
            params: {'p_church_id': church.churchId},
          ),
          throwsPostgrestCode('PT403'),
        );
      },
    );

    test('a member of another church cannot be added', () async {
      final foreigner = await createActiveMember(
        otherChurch.churchId,
        fullName: 'Foreign Member',
        tag: 'foreign',
      );
      addTearDown(() => deleteUser(foreigner.user.userId));
      await expectLater(
        addMembers(g.leader.user.client, g.groupId, [foreigner.membershipId]),
        throwsPostgrestCode('PT404'),
        reason: 'reported as not found, like an unknown id',
      );
    });
  });

  group('unknown ids', () {
    test(
      'are refused exactly like someone else\'s, revealing nothing',
      () async {
        final c = g.leader.user.client;
        for (final call in [
          () => addMembers(c, unknownId, [plain.membershipId]),
          () => c.rpc<List<dynamic>>(
            'list_addable_members',
            params: {'p_d_group_id': unknownId},
          ),
          () => setUpMember(c, unknownId, 'DISCIPLE'),
          () => c.rpc<List<dynamic>>(
            'remove_from_d_group',
            params: {'p_d_group_placement_id': unknownId},
          ),
        ]) {
          await expectLater(call(), throwsPostgrestCode('PT403'));
        }
      },
    );
  });

  group('Leader', () {
    test('cannot act on another group or do Coordinator-only things', () async {
      final c = g.leader.user.client;
      final m = await unplaced('lead-neg');

      await expectLater(
        addMembers(c, g2.groupId, [m.membershipId]),
        throwsPostgrestCode('PT403'),
      );
      await expectLater(
        c.rpc<List<dynamic>>(
          'list_addable_members',
          params: {'p_d_group_id': g2.groupId},
        ),
        throwsPostgrestCode('PT403'),
      );
      await expectLater(
        c.rpc<List<dynamic>>(
          'create_d_group',
          params: {
            'p_name': uniqueGroupName(),
            'p_description': null,
            'p_leader_membership_id': m.membershipId,
          },
        ),
        throwsPostgrestCode('PT403'),
      );
      await expectLater(
        c.rpc<List<dynamic>>(
          'assign_d_group_leader',
          params: {
            'p_d_group_id': g.groupId,
            'p_membership_id': m.membershipId,
          },
        ),
        throwsPostgrestCode('PT403'),
      );
      expect(
        await c.from('d_groups').select('id').eq('id', g2.groupId),
        isEmpty,
      );
    });

    test(
      'the addable list has names only and no one already grouped',
      () async {
        final rows = (await g.leader.user.client.rpc<List<dynamic>>(
          'list_addable_members',
          params: {'p_d_group_id': g.groupId},
        )).cast<Map<String, dynamic>>();

        final ids = rows.map((r) => r['church_membership_id']).toSet();
        expect(ids, contains(plain.membershipId));
        expect(ids, isNot(contains(disciple1.membershipId)));
        expect(ids, isNot(contains(newcomer.membershipId)));
        expect(ids, isNot(contains(g2.leader.membershipId)));
        expect(rows.first.containsKey('phone'), isFalse);
      },
    );

    test('reads own group in full: responsibilities, placements (including '
        'Needs setup) and phone numbers', () async {
      final c = g.leader.user.client;
      expect(await groupsSeenBy(c), hasLength(1));
      final rows = await c
          .from('d_group_memberships')
          .select('id')
          .eq('d_group_id', g.groupId)
          .isFilter('ended_at', null);
      expect(
        rows,
        hasLength(5),
        reason: 'the Leader holds LEADER and DISCIPLER (ADR-020)',
      );
      final placements = await c
          .from('d_group_placements')
          .select('church_membership_id')
          .eq('d_group_id', g.groupId)
          .isFilter('ended_at', null);
      expect(placements, hasLength(5));
      expect(await profileSeenBy(c, newcomer), hasLength(1));
      final p = await profileSeenBy(c, disciple2);
      expect(p.single['phone'], '+63 900 000 0004');
    });

    test('a Leader whose responsibility has ended loses authority', () async {
      final grp = await createGroupWithLeader(church, tag: 'ended-lead');
      addTearDown(() => deleteUser(grp.leader.user.userId));
      final next = await unplaced('ended-next');
      final target = await unplaced('ended-target');

      await rpcRow(church.approver.client, 'assign_d_group_leader', {
        'p_d_group_id': grp.groupId,
        'p_membership_id': next.membershipId,
      });

      await expectLater(
        addMembers(grp.leader.user.client, grp.groupId, [target.membershipId]),
        throwsPostgrestCode('PT403'),
      );
      expect(
        await grp.leader.user.client
            .from('d_group_placements')
            .select('id')
            .eq('d_group_id', grp.groupId)
            .neq('church_membership_id', grp.leader.membershipId),
        isEmpty,
      );
    });
  });

  group('Discipler', () {
    test('cannot add, set up, pair or remove', () async {
      await expectNoManagementAuthority(
        discipler.user.client,
        await unplaced('dr-neg'),
      );
    });

    test('reads an assigned Disciple and the Leader, not an unrelated '
        'Disciple or a newcomer', () async {
      final c = discipler.user.client;
      expect(await profileSeenBy(c, disciple1), hasLength(1));
      expect(await profileSeenBy(c, g.leader), hasLength(1));
      expect(await profileSeenBy(c, disciple2), isEmpty);
      expect(await profileSeenBy(c, newcomer), isEmpty);

      final assignments = await c.from('discipler_assignments').select('id');
      expect(assignments, hasLength(1));
    });

    test(
      'the roster shows phones for own Leader and own Disciples only',
      () async {
        final rows = (await discipler.user.client.rpc<List<dynamic>>(
          'get_my_d_group_roster',
        )).cast<Map<String, dynamic>>();
        // The Leader appears twice: LEADER and DISCIPLER (ADR-020).
        Map<String, dynamic> of(TestMember m) =>
            rows.firstWhere((r) => r['church_membership_id'] == m.membershipId);

        expect(rows, hasLength(5), reason: 'Needs setup is not on the roster');
        expect(rows.map((r) => r['d_group_member_count']).toSet(), {
          5,
        }, reason: 'yet the newcomer counts as a member');
        expect(of(g.leader)['phone'], isNotNull);
        expect(of(disciple1)['phone'], '+63 900 000 0003');
        expect(of(disciple1)['is_my_disciple'], isTrue);
        expect(of(disciple2)['phone'], isNull);
        expect(of(disciple2)['full_name'], 'Sec Disciple Two');
      },
    );
  });

  group('Disciple', () {
    test('cannot add, set up, pair or remove', () async {
      await expectNoManagementAuthority(
        disciple1.user.client,
        await unplaced('dd-neg'),
      );
    });

    test('reads group mates by name only, and own Leader and Discipler with '
        'phone numbers', () async {
      final c = disciple1.user.client;
      final rows = (await c.rpc<List<dynamic>>('get_my_d_group_roster'))
          .cast<Map<String, dynamic>>();
      // The Leader appears twice: LEADER and DISCIPLER (ADR-020).
      Map<String, dynamic> of(TestMember m) =>
          rows.firstWhere((r) => r['church_membership_id'] == m.membershipId);

      expect(of(disciple2)['full_name'], 'Sec Disciple Two');
      expect(of(disciple2)['phone'], isNull);
      expect(of(g.leader)['phone'], '+63 900 000 0001');
      expect(of(g.leader)['is_my_leader'], isTrue);
      expect(of(discipler)['phone'], '+63 900 000 0002');
      expect(of(discipler)['is_my_discipler'], isTrue);

      expect(await profileSeenBy(c, disciple2), isEmpty);
      expect(await profileSeenBy(c, discipler), hasLength(1));
      expect(await profileSeenBy(c, g.leader), hasLength(1));

      // Own rows, the Leader's row and own Discipler's row; not disciple2's.
      final dgms = await c
          .from('d_group_memberships')
          .select('id')
          .eq('d_group_id', g.groupId);
      final ids = dgms.map((r) => r['id']).toSet();
      expect(ids, containsAll([disciple1Dgm, g.leaderDgmId, disciplerDgm]));
      expect(ids, isNot(contains(disciple2Dgm)));
    });

    test(
      'a Disciple with no Discipler sees no phone but the Leader\'s',
      () async {
        final rows = (await disciple2.user.client.rpc<List<dynamic>>(
          'get_my_d_group_roster',
        )).cast<Map<String, dynamic>>();
        final withPhone = rows
            .where((r) => r['phone'] != null && r['is_me'] != true)
            .map((r) => r['church_membership_id'])
            .toList();
        expect(withPhone, [g.leader.membershipId]);
      },
    );
  });

  group('Needs setup', () {
    test(
      'sees the group name and the Leader by name only, nothing else',
      () async {
        final c = newcomer.user.client;
        expect(await groupsSeenBy(c), hasLength(1));

        final rows = (await c.rpc<List<dynamic>>('get_my_d_group_roster'))
            .cast<Map<String, dynamic>>();
        expect(rows, hasLength(1));
        expect(rows.single['church_membership_id'], g.leader.membershipId);
        expect(rows.single['is_my_leader'], isTrue);
        expect(rows.single['phone'], isNull);
        expect(
          rows.single['d_group_member_count'],
          5,
          reason: 'everyone placed counts, including the newcomer',
        );

        expect(await profileSeenBy(c, g.leader), isEmpty);
        expect(await profileSeenBy(c, disciple1), isEmpty);
        expect(await c.from('d_group_memberships').select('id'), isEmpty);
        expect(await c.from('discipler_assignments').select('id'), isEmpty);
        expect(await c.from('d_group_placements').select('id'), hasLength(1));

        await expectNoManagementAuthority(c, await unplaced('new-neg'));
      },
    );
  });

  group('no ministry authority', () {
    test('an ordinary member and an Admin-only user are refused every '
        'operation and see no D Group data', () async {
      final target = await unplaced('noauth');
      for (final m in [plain, adminOnly]) {
        final c = m.user.client;
        expect(await groupsSeenBy(c), isEmpty);
        expect(await c.from('d_group_memberships').select('id'), isEmpty);
        expect(await c.from('d_group_placements').select('id'), isEmpty);
        expect(await c.from('discipler_assignments').select('id'), isEmpty);
        expect(await c.from('d_group_invitations').select('id'), isEmpty);
        expect(await c.rpc<List<dynamic>>('get_my_d_group_roster'), isEmpty);

        await expectNoManagementAuthority(c, target);
        await expectLater(
          c.rpc<List<dynamic>>(
            'create_d_group',
            params: {
              'p_name': uniqueGroupName(),
              'p_description': null,
              'p_leader_membership_id': target.membershipId,
            },
          ),
          throwsPostgrestCode('PT403'),
        );
        await expectLater(
          c.rpc<List<dynamic>>(
            'add_self_as_discipler',
            params: {'p_d_group_id': g.groupId},
          ),
          throwsPostgrestCode('PT403'),
        );
        await expectLater(
          c.rpc<List<dynamic>>(
            'list_placeable_members',
            params: {'p_d_group_id': g.groupId},
          ),
          throwsPostgrestCode('PT403'),
        );
      }
    });

    test('anon is denied tables and operations', () async {
      final anon = anonClient();
      for (final table in [
        'd_groups',
        'd_group_memberships',
        'd_group_placements',
        'discipler_assignments',
        'd_group_invitations',
      ]) {
        await expectLater(
          anon.from(table).select('id'),
          throwsA(isA<PostgrestException>()),
          reason: table,
        );
      }
      await expectLater(
        anon.rpc<List<dynamic>>('get_my_d_group_roster'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        anon.rpc<List<dynamic>>(
          'list_addable_members',
          params: {'p_d_group_id': g.groupId},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('the retired invitation operations no longer exist', () async {
      for (final fn in [
        'invite_to_d_group',
        'respond_to_d_group_invitation',
        'withdraw_d_group_invitation',
        'get_my_pending_invitation',
        'end_d_group_membership',
      ]) {
        await expectLater(
          church.approver.client.rpc<List<dynamic>>(fn),
          throwsA(isA<PostgrestException>()),
          reason: fn,
        );
      }
    });

    test(
      'direct client writes are refused, even for the Coordinator',
      () async {
        final c = church.approver.client;
        await expectLater(
          c.from('d_groups').insert({
            'church_id': church.churchId,
            'name': uniqueGroupName(),
            'created_by': church.approver.userId,
          }),
          throwsPostgrestCode('42501'),
        );
        await expectLater(
          c
              .from('d_group_memberships')
              .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', disciple2Dgm),
          throwsPostgrestCode('42501'),
        );
        await expectLater(
          c.from('d_group_placements').insert({
            'd_group_id': g.groupId,
            'church_membership_id': plain.membershipId,
            'started_at': DateTime.now().toUtc().toIso8601String(),
            'placed_by': church.approver.userId,
          }),
          throwsPostgrestCode('42501'),
        );
        await expectLater(
          c
              .from('d_group_placements')
              .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', disciple2Placement),
          throwsPostgrestCode('42501'),
        );
        await expectLater(
          c.from('discipler_assignments').delete().eq('d_group_id', g.groupId),
          throwsPostgrestCode('42501'),
        );
        await expectLater(
          c.from('church_role_assignments').insert({
            'church_membership_id': plain.membershipId,
            'role': 'COORDINATOR',
            'assigned_by': church.approver.userId,
            'started_at': DateTime.now().toUtc().toIso8601String(),
          }),
          throwsPostgrestCode('42501'),
        );
      },
    );

    test(
      'a Leader whose own membership is INACTIVE has no authority',
      () async {
        final lone = await createGroupWithLeader(church, tag: 'inactive-lead');
        addTearDown(() => deleteUser(lone.leader.user.userId));
        final m = await unplaced('inactive-target');

        await service
            .from('church_memberships')
            .update({'status': 'INACTIVE'})
            .eq('id', lone.leader.membershipId);

        await expectLater(
          addMembers(lone.leader.user.client, lone.groupId, [m.membershipId]),
          throwsPostgrestCode('PT403'),
        );
        expect(
          await lone.leader.user.client
              .from('d_groups')
              .select('id')
              .eq('id', lone.groupId),
          isEmpty,
        );
      },
    );
  });
}
