/// Ministry structure against the real local stack: groups with a Leader,
/// placement (Add Members), pairing and removal, and what the database
/// records.
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;

  setUpAll(() async {
    church = await seedChurch(name: 'Ministry Structure Church');
  });
  tearDownAll(() => deleteChurch(church));

  Future<TestMember> member(String tag) async {
    final m = await createActiveMember(
      church.churchId,
      fullName: 'Member $tag',
      tag: tag,
    );
    addTearDown(() => deleteUser(m.user.userId));
    return m;
  }

  Future<TestGroup> newGroup(String tag) async {
    final g = await createGroupWithLeader(church, tag: tag);
    addTearDown(() => deleteUser(g.leader.user.userId));
    return g;
  }

  Future<Map<String, dynamic>> dgm(String id) =>
      service.from('d_group_memberships').select().eq('id', id).single();

  Future<List<Map<String, dynamic>>> activeAssignmentsOf(
    String discipleDgmId,
  ) async {
    final rows = await service
        .from('discipler_assignments')
        .select()
        .eq('disciple_d_group_membership_id', discipleDgmId)
        .isFilter('ended_at', null);
    return rows.cast<Map<String, dynamic>>();
  }

  group('create_d_group', () {
    test('creates the group and its LEADER row, audited', () async {
      final g = await newGroup('create');

      final row = await service
          .from('d_groups')
          .select('church_id, status, created_by')
          .eq('id', g.groupId)
          .single();
      expect(row['church_id'], church.churchId);
      expect(row['status'], 'ACTIVE');
      expect(row['created_by'], church.approver.userId);

      final leader = await dgm(g.leaderDgmId);
      expect(leader['responsibility'], 'LEADER');
      expect(leader['church_membership_id'], g.leader.membershipId);
      expect(leader['ended_at'], isNull);

      expect(await auditActionsFor(g.groupId), ['D_GROUP_CREATED']);
    });

    test('names are unique per church ignoring case and spaces', () async {
      final name = uniqueGroupName('Unique');
      final g = await createGroupWithLeader(church, tag: 'uniq1', name: name);
      addTearDown(() => deleteUser(g.leader.user.userId));
      final other = await member('uniq2');

      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'create_d_group',
          params: {
            'p_name': '  ${name.toUpperCase()} ',
            'p_description': null,
            'p_leader_membership_id': other.membershipId,
          },
        ),
        throwsPostgrestCode('PT409'),
      );
    });

    test('a blank name and a placed Leader are refused', () async {
      final g = await newGroup('placed');
      final m = await member('blank');

      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'create_d_group',
          params: {
            'p_name': '   ',
            'p_description': null,
            'p_leader_membership_id': m.membershipId,
          },
        ),
        throwsPostgrestCode('PT400'),
      );
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'create_d_group',
          params: {
            'p_name': uniqueGroupName(),
            'p_description': null,
            'p_leader_membership_id': g.leader.membershipId,
          },
        ),
        throwsPostgrestCode('PT409'),
      );
    });
  });

  group('assign_d_group_leader', () {
    test('replacing the Leader ends the old row and keeps history', () async {
      final g = await newGroup('repl');
      final next = await member('repl-next');

      await rpcRow(church.approver.client, 'assign_d_group_leader', {
        'p_d_group_id': g.groupId,
        'p_membership_id': next.membershipId,
      });

      final old = await dgm(g.leaderDgmId);
      expect(old['ended_at'], isNotNull, reason: 'history is kept');

      final active = await service
          .from('d_group_memberships')
          .select('church_membership_id')
          .eq('d_group_id', g.groupId)
          .eq('responsibility', 'LEADER')
          .isFilter('ended_at', null)
          .single();
      expect(active['church_membership_id'], next.membershipId);

      // The replaced Leader is out of the group and can be added again.
      final placeable = await church.approver.client.rpc<List<dynamic>>(
        'list_placeable_members',
        params: {'p_d_group_id': g.groupId},
      );
      final oldRow = placeable.cast<Map<String, dynamic>>().singleWhere(
        (r) => r['church_membership_id'] == g.leader.membershipId,
      );
      expect(oldRow['current_d_group_id'], isNull);

      expect(await auditActionsFor(g.groupId), [
        'D_GROUP_CREATED',
        'D_GROUP_LEADER_ASSIGNED',
      ]);
    });

    test('a Discipler of the same group may become Leader and keeps the '
        'Discipler row; a Disciple may not', () async {
      final g = await newGroup('repl2');
      final discipler = await member('repl2-dr');
      final disciple = await member('repl2-dd');
      final drDgm = await place(
        church.approver.client,
        g.groupId,
        discipler,
        'DISCIPLER',
      );
      await place(church.approver.client, g.groupId, disciple, 'DISCIPLE');

      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'assign_d_group_leader',
          params: {
            'p_d_group_id': g.groupId,
            'p_membership_id': disciple.membershipId,
          },
        ),
        throwsPostgrestCode('PT409'),
      );

      await rpcRow(church.approver.client, 'assign_d_group_leader', {
        'p_d_group_id': g.groupId,
        'p_membership_id': discipler.membershipId,
      });
      expect((await dgm(drDgm))['ended_at'], isNull);

      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'assign_d_group_leader',
          params: {
            'p_d_group_id': g.groupId,
            'p_membership_id': discipler.membershipId,
          },
        ),
        throwsPostgrestCode('PT409'),
        reason: 'already the Leader',
      );
    });
  });

  group('placement (add members)', () {
    Future<Map<String, dynamic>> placement(String id) =>
        service.from('d_group_placements').select().eq('id', id).single();

    test(
      'adds several members at once in Needs setup, audited per person',
      () async {
        final g = await newGroup('add');
        final a = await member('add-a');
        final b = await member('add-b');

        final placed = await addMembers(g.leader.user.client, g.groupId, [
          a.membershipId,
          b.membershipId,
        ]);
        expect(placed.keys, unorderedEquals([a.membershipId, b.membershipId]));

        final row = await placement(placed[a.membershipId]!);
        expect(row['d_group_id'], g.groupId);
        expect(row['placed_by'], g.leader.user.userId);
        expect(row['ended_at'], isNull);

        // Needs setup: placed, no responsibility yet.
        final roles = await service
            .from('d_group_memberships')
            .select('id')
            .eq('church_membership_id', a.membershipId);
        expect(roles, isEmpty);

        expect(await auditActionsFor(placed[a.membershipId]!), [
          'D_GROUP_MEMBER_PLACED',
        ]);
      },
    );

    test('the addable list holds only ungrouped ACTIVE members and an added '
        'member leaves every group\'s list', () async {
      final g = await newGroup('list');
      final other = await newGroup('list-b');
      final m = await member('list-m');

      Future<Set<String>> addable(TestGroup grp) async {
        final rows = await grp.leader.user.client.rpc<List<dynamic>>(
          'list_addable_members',
          params: {'p_d_group_id': grp.groupId},
        );
        return {
          for (final r in rows.cast<Map<String, dynamic>>())
            r['church_membership_id'] as String,
        };
      }

      expect(await addable(other), contains(m.membershipId));
      expect(
        await addable(g),
        isNot(contains(g.leader.membershipId)),
        reason: 'a Leader is already in a group',
      );

      await addMembers(g.leader.user.client, g.groupId, [m.membershipId]);

      expect(await addable(g), isNot(contains(m.membershipId)));
      expect(await addable(other), isNot(contains(m.membershipId)));
    });

    test('a member already in a group is refused, and the batch is all or '
        'nothing', () async {
      final g = await newGroup('dup');
      final other = await newGroup('dup-b');
      final m = await member('dup-m');
      final fresh = await member('dup-fresh');

      await addMembers(g.leader.user.client, g.groupId, [m.membershipId]);

      await expectLater(
        addMembers(other.leader.user.client, other.groupId, [
          fresh.membershipId,
          m.membershipId,
        ]),
        throwsPostgrestCode('PT409'),
      );
      expect(
        await activePlacementOf(fresh.membershipId),
        isNull,
        reason: 'nobody in a refused batch is added',
      );
      await expectLater(
        addMembers(g.leader.user.client, g.groupId, [m.membershipId]),
        throwsPostgrestCode('PT409'),
        reason: 'already in this very group',
      );
    });

    test('two Leaders adding the same person at the same time: exactly one '
        'succeeds', () async {
      final g1 = await newGroup('race1');
      final g2 = await newGroup('race2');
      final m = await member('race-m');

      final results = await Future.wait([
        addMembers(g1.leader.user.client, g1.groupId, [
          m.membershipId,
        ]).then<Object>((v) => v, onError: (Object e) => e),
        addMembers(g2.leader.user.client, g2.groupId, [
          m.membershipId,
        ]).then<Object>((v) => v, onError: (Object e) => e),
      ]);

      final ok = results.whereType<Map<String, String>>().toList();
      final refused = results.whereType<Exception>().toList();
      expect(ok, hasLength(1));
      expect(refused, hasLength(1));

      final active = await service
          .from('d_group_placements')
          .select('id')
          .eq('church_membership_id', m.membershipId)
          .isFilter('ended_at', null);
      expect(active, hasLength(1));
    });

    test('an empty, inactive or unknown selection is refused', () async {
      final g = await newGroup('bad');
      final inactive = await member('bad-inactive');
      await service
          .from('church_memberships')
          .update({'status': 'INACTIVE'})
          .eq('id', inactive.membershipId);

      await expectLater(
        addMembers(g.leader.user.client, g.groupId, []),
        throwsPostgrestCode('PT400'),
      );
      await expectLater(
        addMembers(g.leader.user.client, g.groupId, [inactive.membershipId]),
        throwsPostgrestCode('PT409'),
      );
      await expectLater(
        addMembers(g.leader.user.client, g.groupId, [
          '00000000-0000-4000-8000-0000000000ff',
        ]),
        throwsPostgrestCode('PT404'),
      );
    });

    test('pending invitations were retired by the migration', () async {
      final pending = await service
          .from('d_group_invitations')
          .select('id')
          .eq('status', 'PENDING');
      expect(pending, isEmpty);
    });
  });

  group('pairing and removal', () {
    test('pair, re-pair and unpair keep every assignment as history', () async {
      final g = await newGroup('pair');
      final dr1 = await member('pair-dr1');
      final dr2 = await member('pair-dr2');
      final dd = await member('pair-dd');
      final dr1Dgm = await place(
        g.leader.user.client,
        g.groupId,
        dr1,
        'DISCIPLER',
      );
      final dr2Dgm = await place(
        g.leader.user.client,
        g.groupId,
        dr2,
        'DISCIPLER',
      );
      final ddDgm = await place(
        g.leader.user.client,
        g.groupId,
        dd,
        'DISCIPLE',
      );

      final first = await setDiscipler(g.leader.user.client, ddDgm, dr1Dgm);
      expect(first['outcome'], 'ASSIGNED');

      await expectLater(
        setDiscipler(g.leader.user.client, ddDgm, dr1Dgm),
        throwsPostgrestCode('PT409'),
        reason: 'already paired with that Discipler',
      );

      final second = await setDiscipler(g.leader.user.client, ddDgm, dr2Dgm);
      expect(second['outcome'], 'REASSIGNED');
      final active = await activeAssignmentsOf(ddDgm);
      expect(active.single['discipler_d_group_membership_id'], dr2Dgm);

      final unpaired = await setDiscipler(g.leader.user.client, ddDgm, null);
      expect(unpaired['outcome'], 'UNASSIGNED');
      expect(await activeAssignmentsOf(ddDgm), isEmpty);

      await expectLater(
        setDiscipler(g.leader.user.client, ddDgm, null),
        throwsPostgrestCode('PT409'),
        reason: 'not paired',
      );

      final all = await service
          .from('discipler_assignments')
          .select('id, ended_at')
          .eq('disciple_d_group_membership_id', ddDgm);
      expect(all, hasLength(2));
      expect(all.every((r) => r['ended_at'] != null), isTrue);

      expect(
        await auditActionsFor(first['discipler_assignment_id'] as String),
        ['DISCIPLER_ASSIGNED'],
      );
    });

    test('a Discipler from another group cannot be paired', () async {
      final g = await newGroup('xpair');
      final other = await newGroup('xpair-b');
      final dr = await member('xpair-dr');
      final dd = await member('xpair-dd');
      final drDgm = await place(
        other.leader.user.client,
        other.groupId,
        dr,
        'DISCIPLER',
      );
      final ddDgm = await place(
        g.leader.user.client,
        g.groupId,
        dd,
        'DISCIPLE',
      );

      await expectLater(
        setDiscipler(church.approver.client, ddDgm, drDgm),
        throwsPostgrestCode('PT409'),
      );
    });

    test('removing a Discipler takes them out of the group and unpairs their '
        'Disciples; the Leader cannot be removed', () async {
      final g = await newGroup('rm');
      final dr = await member('rm-dr');
      final dd = await member('rm-dd');
      final drDgm = await place(
        g.leader.user.client,
        g.groupId,
        dr,
        'DISCIPLER',
      );
      final ddDgm = await place(
        g.leader.user.client,
        g.groupId,
        dd,
        'DISCIPLE',
      );
      await setDiscipler(g.leader.user.client, ddDgm, drDgm);

      final drPlacement = (await activePlacementOf(dr.membershipId))!;
      await rpcRow(g.leader.user.client, 'remove_from_d_group', {
        'p_d_group_placement_id': drPlacement,
      });

      expect((await dgm(drDgm))['ended_at'], isNotNull);
      expect(await activePlacementOf(dr.membershipId), isNull);
      expect(await activeAssignmentsOf(ddDgm), isEmpty);
      expect(
        (await dgm(ddDgm))['ended_at'],
        isNull,
        reason: 'still a Disciple',
      );

      await expectLater(
        g.leader.user.client.rpc<List<dynamic>>(
          'remove_from_d_group',
          params: {'p_d_group_placement_id': drPlacement},
        ),
        throwsPostgrestCode('PT409'),
        reason: 'already removed',
      );
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'remove_from_d_group',
          params: {
            'p_d_group_placement_id': (await activePlacementOf(
              g.leader.membershipId,
            ))!,
          },
        ),
        throwsPostgrestCode('PT409'),
      );

      // The removed person is ungrouped and can be added again; history
      // keeps both placements.
      await addMembers(g.leader.user.client, g.groupId, [dr.membershipId]);
      final all = await service
          .from('d_group_placements')
          .select('id')
          .eq('church_membership_id', dr.membershipId);
      expect(all, hasLength(2));

      final audit = await auditActionsFor(drPlacement);
      expect(audit, ['D_GROUP_MEMBER_PLACED', 'D_GROUP_MEMBER_REMOVED']);
    });

    test('removing a member who still needs setup', () async {
      final g = await newGroup('rm-setup');
      final m = await member('rm-setup-m');
      final placed = await addMembers(g.leader.user.client, g.groupId, [
        m.membershipId,
      ]);
      await rpcRow(g.leader.user.client, 'remove_from_d_group', {
        'p_d_group_placement_id': placed[m.membershipId],
      });
      expect(await activePlacementOf(m.membershipId), isNull);
    });

    test(
      'a Leader can add themselves as Discipler once and be paired',
      () async {
        final g = await newGroup('self');
        final dd = await member('self-dd');
        final ddDgm = await place(
          g.leader.user.client,
          g.groupId,
          dd,
          'DISCIPLE',
        );

        final row = await rpcRow(
          g.leader.user.client,
          'add_self_as_discipler',
          {'p_d_group_id': g.groupId},
        );
        final selfDgm = row['d_group_membership_id'] as String;
        expect((await dgm(selfDgm))['responsibility'], 'DISCIPLER');

        await expectLater(
          g.leader.user.client.rpc<List<dynamic>>(
            'add_self_as_discipler',
            params: {'p_d_group_id': g.groupId},
          ),
          throwsPostgrestCode('PT409'),
        );

        final paired = await setDiscipler(g.leader.user.client, ddDgm, selfDgm);
        expect(paired['outcome'], 'ASSIGNED');
        expect(await auditActionsFor(selfDgm), ['D_GROUP_MEMBER_ADDED']);
      },
    );
  });
}
