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
  //   leader, discipler (paired with disciple1), disciple1, disciple2
  late TestGroup g;
  late TestGroup g2;
  late TestMember discipler;
  late TestMember disciple1;
  late TestMember disciple2;
  late TestMember plain;
  late TestMember adminOnly;
  late String disciplerDgm;
  late String disciple1Dgm;
  late String disciple2Dgm;

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
    await service.from('church_role_assignments').insert({
      'church_membership_id': adminOnly.membershipId,
      'role': 'ADMIN',
      'assigned_by': church.approver.userId,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    });

    final leaderClient = g.leader.user.client;
    disciplerDgm = await place(leaderClient, g.groupId, discipler, 'DISCIPLER');
    disciple1Dgm = await place(leaderClient, g.groupId, disciple1, 'DISCIPLE');
    disciple2Dgm = await place(leaderClient, g.groupId, disciple2, 'DISCIPLE');
    await setDiscipler(leaderClient, disciple1Dgm, disciplerDgm);

    cleanup.addAll([
      g.leader.user.userId,
      g2.leader.user.userId,
      discipler.user.userId,
      disciple1.user.userId,
      disciple2.user.userId,
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

        final m = await unplaced('xchurch');
        await expectLater(
          invite(c, g.groupId, m.membershipId, 'DISCIPLE'),
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
            'list_placeable_members',
            params: {'p_church_id': church.churchId},
          ),
          throwsPostgrestCode('PT403'),
        );
      },
    );
  });

  group('Leader', () {
    test('cannot act on another group or do Coordinator-only things', () async {
      final c = g.leader.user.client;
      final m = await unplaced('lead-neg');

      await expectLater(
        invite(c, g2.groupId, m.membershipId, 'DISCIPLE'),
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

    test('cannot invite an already-placed member', () async {
      await expectLater(
        invite(
          g.leader.user.client,
          g.groupId,
          g2.leader.membershipId,
          'DISCIPLE',
        ),
        throwsPostgrestCode('PT409'),
      );
    });

    test(
      'sees only unplaced members when picking, with no phone numbers',
      () async {
        final rows = (await g.leader.user.client.rpc<List<dynamic>>(
          'list_placeable_members',
          params: {'p_d_group_id': g.groupId},
        )).cast<Map<String, dynamic>>();

        expect(rows.every((r) => r['current_d_group_id'] == null), isTrue);
        final ids = rows.map((r) => r['church_membership_id']).toSet();
        expect(ids, contains(plain.membershipId));
        expect(ids, isNot(contains(disciple1.membershipId)));
        expect(rows.first.containsKey('phone'), isFalse);

        // The Coordinator sees everyone, with their placement.
        final all = (await church.approver.client.rpc<List<dynamic>>(
          'list_placeable_members',
          params: {'p_d_group_id': g.groupId},
        )).cast<Map<String, dynamic>>();
        final d1 = all.singleWhere(
          (r) => r['church_membership_id'] == disciple1.membershipId,
        );
        expect(d1['current_d_group_id'], g.groupId);
        expect(d1['current_responsibilities'], ['DISCIPLE']);
      },
    );

    test('reads own group in full, including member phone numbers', () async {
      final c = g.leader.user.client;
      expect(await groupsSeenBy(c), hasLength(1));
      final rows = await c
          .from('d_group_memberships')
          .select('id')
          .eq('d_group_id', g.groupId)
          .isFilter('ended_at', null);
      expect(rows, hasLength(4));
      final p = await profileSeenBy(c, disciple2);
      expect(p.single['phone'], '+63 900 000 0004');
    });
  });

  group('Discipler', () {
    test('cannot invite, pair or remove', () async {
      final c = discipler.user.client;
      final m = await unplaced('dr-neg');

      await expectLater(
        invite(c, g.groupId, m.membershipId, 'DISCIPLE'),
        throwsPostgrestCode('PT403'),
      );
      await expectLater(
        setDiscipler(c, disciple2Dgm, disciplerDgm),
        throwsPostgrestCode('PT403'),
      );
      await expectLater(
        c.rpc<List<dynamic>>(
          'end_d_group_membership',
          params: {'p_d_group_membership_id': disciple2Dgm},
        ),
        throwsPostgrestCode('PT403'),
      );
    });

    test('reads an assigned Disciple and the Leader, not an unrelated '
        'Disciple', () async {
      final c = discipler.user.client;
      expect(await profileSeenBy(c, disciple1), hasLength(1));
      expect(await profileSeenBy(c, g.leader), hasLength(1));
      expect(await profileSeenBy(c, disciple2), isEmpty);

      final assignments = await c.from('discipler_assignments').select('id');
      expect(assignments, hasLength(1));
    });

    test(
      'the roster shows phones for own Leader and own Disciples only',
      () async {
        final rows = (await discipler.user.client.rpc<List<dynamic>>(
          'get_my_d_group_roster',
        )).cast<Map<String, dynamic>>();
        Map<String, dynamic> of(TestMember m) => rows.singleWhere(
          (r) => r['church_membership_id'] == m.membershipId,
        );

        expect(rows, hasLength(4));
        expect(of(g.leader)['phone'], isNotNull);
        expect(of(disciple1)['phone'], '+63 900 000 0003');
        expect(of(disciple1)['is_my_disciple'], isTrue);
        expect(of(disciple2)['phone'], isNull);
        expect(of(disciple2)['full_name'], 'Sec Disciple Two');
      },
    );
  });

  group('Disciple', () {
    test('reads group mates by name only, and own Leader and Discipler with '
        'phone numbers', () async {
      final c = disciple1.user.client;
      final rows = (await c.rpc<List<dynamic>>('get_my_d_group_roster'))
          .cast<Map<String, dynamic>>();
      Map<String, dynamic> of(TestMember m) =>
          rows.singleWhere((r) => r['church_membership_id'] == m.membershipId);

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

  group('no ministry authority', () {
    test('an ordinary member and an Admin-only user are refused every '
        'operation and see no D Group data', () async {
      final target = await unplaced('noauth');
      for (final m in [plain, adminOnly]) {
        final c = m.user.client;
        expect(await groupsSeenBy(c), isEmpty);
        expect(await c.from('d_group_memberships').select('id'), isEmpty);
        expect(await c.from('discipler_assignments').select('id'), isEmpty);
        expect(await c.from('d_group_invitations').select('id'), isEmpty);
        expect(await c.rpc<List<dynamic>>('get_my_d_group_roster'), isEmpty);

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
          invite(c, g.groupId, target.membershipId, 'DISCIPLE'),
          throwsPostgrestCode('PT403'),
        );
        await expectLater(
          setDiscipler(c, disciple2Dgm, disciplerDgm),
          throwsPostgrestCode('PT403'),
        );
        await expectLater(
          c.rpc<List<dynamic>>(
            'end_d_group_membership',
            params: {'p_d_group_membership_id': disciple2Dgm},
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
          invite(
            lone.leader.user.client,
            lone.groupId,
            m.membershipId,
            'DISCIPLE',
          ),
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

    test('only the invitee can answer an invitation', () async {
      final m = await unplaced('answer');
      final id = await invite(
        g.leader.user.client,
        g.groupId,
        m.membershipId,
        'DISCIPLE',
      );
      for (final c in [
        g.leader.user.client,
        church.approver.client,
        plain.user.client,
      ]) {
        await expectLater(
          c.rpc<List<dynamic>>(
            'respond_to_d_group_invitation',
            params: {'p_invitation_id': id, 'p_accept': true},
          ),
          throwsPostgrestCode('PT403'),
        );
      }
      // A Discipler of the group cannot withdraw it either.
      await expectLater(
        discipler.user.client.rpc<List<dynamic>>(
          'withdraw_d_group_invitation',
          params: {'p_invitation_id': id},
        ),
        throwsPostgrestCode('PT403'),
      );
    });
  });
}
