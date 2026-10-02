/// Ministry structure against the real local stack: groups with a Leader,
/// invitations, pairing and removal, and what the database records.
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

  Future<Map<String, dynamic>> invitation(String id) =>
      service.from('d_group_invitations').select().eq('id', id).single();

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

      // The replaced Leader is unplaced again and can be invited.
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

  group('invitations', () {
    test('accept creates the responsibility and links it', () async {
      final g = await newGroup('acc');
      final m = await member('acc-m');

      final id = await invite(
        g.leader.user.client,
        g.groupId,
        m.membershipId,
        'DISCIPLE',
      );

      final pending = await m.user.client.rpc<List<dynamic>>(
        'get_my_pending_invitation',
      );
      expect(pending, hasLength(1));
      final p = pending.single as Map<String, dynamic>;
      expect(p['invitation_id'], id);
      expect(p['d_group_id'], g.groupId);
      expect(p['responsibility'], 'DISCIPLE');
      expect(p['invited_by_name'], 'Leader acc');

      final dgmId = await accept(m.user.client, id);
      final inv = await invitation(id);
      expect(inv['status'], 'ACCEPTED');
      expect(inv['resulting_d_group_membership_id'], dgmId);
      expect(inv['responded_at'], isNotNull);

      final row = await dgm(dgmId);
      expect(row['responsibility'], 'DISCIPLE');
      expect(row['d_group_id'], g.groupId);
      // The placement records the inviter's decision.
      expect(row['assigned_by'], g.leader.user.userId);

      expect(
        await m.user.client.rpc<List<dynamic>>('get_my_pending_invitation'),
        isEmpty,
      );
      expect(await auditActionsFor(id), [
        'D_GROUP_INVITATION_SENT',
        'D_GROUP_INVITATION_ACCEPTED',
      ]);
    });

    test('decline is visible to the inviter, who may re-invite', () async {
      final g = await newGroup('dec');
      final m = await member('dec-m');

      final id = await invite(
        g.leader.user.client,
        g.groupId,
        m.membershipId,
        'DISCIPLER',
      );
      final res = await rpcRow(m.user.client, 'respond_to_d_group_invitation', {
        'p_invitation_id': id,
        'p_accept': false,
      });
      expect(res['invitation_status'], 'DECLINED');

      final seen = await g.leader.user.client
          .from('d_group_invitations')
          .select('status')
          .eq('id', id)
          .single();
      expect(seen['status'], 'DECLINED');

      // Answered once: a second answer is refused.
      await expectLater(
        m.user.client.rpc<List<dynamic>>(
          'respond_to_d_group_invitation',
          params: {'p_invitation_id': id, 'p_accept': true},
        ),
        throwsPostgrestCode('PT409'),
      );

      final again = await invite(
        g.leader.user.client,
        g.groupId,
        m.membershipId,
        'DISCIPLER',
      );
      expect(again, isNot(id));
    });

    test(
      'one pending invitation at a time; withdraw frees the member',
      () async {
        final g = await newGroup('one');
        final other = await newGroup('one-b');
        final m = await member('one-m');

        final id = await invite(
          g.leader.user.client,
          g.groupId,
          m.membershipId,
          'DISCIPLE',
        );
        await expectLater(
          invite(
            other.leader.user.client,
            other.groupId,
            m.membershipId,
            'DISCIPLE',
          ),
          throwsPostgrestCode('PT409'),
        );

        final res = await rpcRow(
          g.leader.user.client,
          'withdraw_d_group_invitation',
          {'p_invitation_id': id},
        );
        expect(res['invitation_status'], 'WITHDRAWN');
        expect((await invitation(id))['status'], 'WITHDRAWN');

        await expectLater(
          m.user.client.rpc<List<dynamic>>(
            'respond_to_d_group_invitation',
            params: {'p_invitation_id': id, 'p_accept': true},
          ),
          throwsPostgrestCode('PT409'),
        );

        await invite(
          other.leader.user.client,
          other.groupId,
          m.membershipId,
          'DISCIPLE',
        );
      },
    );

    test('an overdue invitation is expired: refused, hidden, and marked by '
        'the next invitation', () async {
      final g = await newGroup('exp');
      final m = await member('exp-m');

      final id = await invite(
        g.leader.user.client,
        g.groupId,
        m.membershipId,
        'DISCIPLE',
      );
      // Age it past 14 days directly; there is no scheduler to wait for.
      final past = DateTime.now().toUtc().subtract(const Duration(days: 15));
      await service
          .from('d_group_invitations')
          .update({
            'created_at': past.toIso8601String(),
            'expires_at': past.add(const Duration(days: 14)).toIso8601String(),
          })
          .eq('id', id);

      expect(
        await m.user.client.rpc<List<dynamic>>('get_my_pending_invitation'),
        isEmpty,
      );
      await expectLater(
        m.user.client.rpc<List<dynamic>>(
          'respond_to_d_group_invitation',
          params: {'p_invitation_id': id, 'p_accept': true},
        ),
        throwsPostgrestCode('PT409'),
      );

      final placeable = await g.leader.user.client.rpc<List<dynamic>>(
        'list_placeable_members',
        params: {'p_d_group_id': g.groupId},
      );
      final row = placeable.cast<Map<String, dynamic>>().singleWhere(
        (r) => r['church_membership_id'] == m.membershipId,
      );
      expect(row['has_pending_invitation'], isFalse);

      await invite(g.leader.user.client, g.groupId, m.membershipId, 'DISCIPLE');
      final old = await invitation(id);
      expect(old['status'], 'EXPIRED');
      expect(
        DateTime.parse(old['responded_at'] as String),
        DateTime.parse(old['expires_at'] as String),
      );
    });

    test(
      'accepting is refused when the invitee was placed meanwhile',
      () async {
        final g = await newGroup('meanwhile');
        final m = await member('meanwhile-m');

        final id = await invite(
          g.leader.user.client,
          g.groupId,
          m.membershipId,
          'DISCIPLE',
        );
        // The Coordinator appoints the same person Leader of a new group.
        final row = await rpcRow(church.approver.client, 'create_d_group', {
          'p_name': uniqueGroupName('Meanwhile'),
          'p_description': null,
          'p_leader_membership_id': m.membershipId,
        });
        expect(row['d_group_id'], isNotNull);

        await expectLater(
          accept(m.user.client, id),
          throwsPostgrestCode('PT409'),
        );
        expect((await invitation(id))['status'], 'PENDING');
      },
    );
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

    test('removing a Discipler unpairs their Disciples; Leader rows cannot be '
        'ended here', () async {
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

      await rpcRow(g.leader.user.client, 'end_d_group_membership', {
        'p_d_group_membership_id': drDgm,
      });

      expect((await dgm(drDgm))['ended_at'], isNotNull);
      expect(await activeAssignmentsOf(ddDgm), isEmpty);
      expect(
        (await dgm(ddDgm))['ended_at'],
        isNull,
        reason: 'still a Disciple',
      );

      await expectLater(
        g.leader.user.client.rpc<List<dynamic>>(
          'end_d_group_membership',
          params: {'p_d_group_membership_id': drDgm},
        ),
        throwsPostgrestCode('PT409'),
        reason: 'already ended',
      );
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'end_d_group_membership',
          params: {'p_d_group_membership_id': g.leaderDgmId},
        ),
        throwsPostgrestCode('PT409'),
      );

      // The removed person is unplaced and can be invited again.
      await invite(
        g.leader.user.client,
        g.groupId,
        dr.membershipId,
        'DISCIPLE',
      );

      final audit = await auditActionsFor(drDgm);
      expect(audit, ['D_GROUP_MEMBER_ENDED']);
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
