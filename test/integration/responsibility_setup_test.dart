/// Slice 6.2 against the real local stack: setting up members placed in a
/// group, the church's initial setup window that bounds Existing Discipler
/// recognition, and pairing once DISCIPLE and DISCIPLER may coexist
/// (ADR-012): no self-pairing, no reciprocal pairing (D7), and visibility
/// still scoped to each relationship.
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestChurch otherChurch;

  setUpAll(() async {
    church = await seedChurch(name: 'Responsibility Setup Church');
    otherChurch = await seedChurch(name: 'Other Setup Church');
  });
  tearDownAll(() async {
    await deleteChurch(church);
    await deleteChurch(otherChurch);
  });

  Future<TestMember> member(String tag) async {
    final m = await createActiveMember(
      church.churchId,
      fullName: 'Setup $tag',
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

  Future<String> added(TestGroup g, TestMember m) async => (await addMembers(
    g.leader.user.client,
    g.groupId,
    [m.membershipId],
  ))[m.membershipId]!;

  Future<Map<String, dynamic>> dgm(String id) =>
      service.from('d_group_memberships').select().eq('id', id).single();

  Future<void> setWindow({required bool open}) => rpcRow(
    church.approver.client,
    'set_initial_setup_open',
    {'p_church_id': church.churchId, 'p_open': open},
  );

  group('set_up_member', () {
    test('a newcomer becomes a Disciple, audited', () async {
      final g = await newGroup('su-dd');
      final m = await member('su-dd-m');
      final pl = await added(g, m);

      final id = await setUpMember(g.leader.user.client, pl, 'DISCIPLE');
      final row = await dgm(id);
      expect(row['responsibility'], 'DISCIPLE');
      expect(row['discipler_basis'], isNull);
      expect(row['assigned_by'], g.leader.user.userId);
      expect(await auditActionsFor(id), ['D_GROUP_MEMBER_SET_UP']);

      await expectLater(
        setUpMember(g.leader.user.client, pl, 'DISCIPLE'),
        throwsPostgrestCode('PT409'),
        reason: 'already a Disciple',
      );
    });

    test('an Existing Discipler is recorded as INITIAL_ROLLOUT and may also '
        'be a Disciple (ADR-012)', () async {
      final g = await newGroup('su-dr');
      final m = await member('su-dr-m');
      final pl = await added(g, m);

      final drId = await setUpMember(g.leader.user.client, pl, 'DISCIPLER');
      expect((await dgm(drId))['discipler_basis'], 'INITIAL_ROLLOUT');
      await expectLater(
        setUpMember(g.leader.user.client, pl, 'DISCIPLER'),
        throwsPostgrestCode('PT409'),
      );

      final ddId = await setUpMember(g.leader.user.client, pl, 'DISCIPLE');
      expect((await dgm(ddId))['ended_at'], isNull);
      expect((await dgm(drId))['ended_at'], isNull);

      // Recognition is not an appointment: no appointment record exists.
      final transitions = await service
          .from('ministry_role_transitions')
          .select('id')
          .eq('church_membership_id', m.membershipId);
      expect(transitions, isEmpty);
    });

    test('the Leader cannot be set up as a Disciple, and LEADER is not a '
        'setup choice', () async {
      final g = await newGroup('su-lead');
      final pl = (await activePlacementOf(g.leader.membershipId))!;
      await expectLater(
        setUpMember(g.leader.user.client, pl, 'DISCIPLE'),
        throwsPostgrestCode('PT409'),
      );
      await expectLater(
        setUpMember(g.leader.user.client, pl, 'LEADER'),
        throwsPostgrestCode('PT400'),
      );
    });

    test('a Leader adding themselves is recorded as LEADER_SELF', () async {
      final g = await newGroup('su-self');
      final row = await rpcRow(g.leader.user.client, 'add_self_as_discipler', {
        'p_d_group_id': g.groupId,
      });
      expect(
        (await dgm(row['d_group_membership_id'] as String))['discipler_basis'],
        'LEADER_SELF',
      );
    });

    test('a removed placement cannot be set up, and an inactive member '
        'cannot be set up', () async {
      final g = await newGroup('su-gone');
      final m = await member('su-gone-m');
      final pl = await added(g, m);
      await rpcRow(g.leader.user.client, 'remove_from_d_group', {
        'p_d_group_placement_id': pl,
      });
      await expectLater(
        setUpMember(g.leader.user.client, pl, 'DISCIPLE'),
        throwsPostgrestCode('PT409'),
      );

      final inactive = await member('su-inactive');
      final pl2 = await added(g, inactive);
      await service
          .from('church_memberships')
          .update({'status': 'INACTIVE'})
          .eq('id', inactive.membershipId);
      await expectLater(
        setUpMember(g.leader.user.client, pl2, 'DISCIPLE'),
        throwsPostgrestCode('PT409'),
      );
    });

    test(
      'another group\'s Leader cannot set up this group\'s members',
      () async {
        final g = await newGroup('su-x1');
        final other = await newGroup('su-x2');
        final m = await member('su-x-m');
        final pl = await added(g, m);
        await expectLater(
          setUpMember(other.leader.user.client, pl, 'DISCIPLE'),
          throwsPostgrestCode('PT403'),
        );
      },
    );
  });

  group('initial setup window', () {
    tearDown(() async {
      // Leave the church open for the other tests.
      final status = await rpcRow(
        church.approver.client,
        'get_initial_setup_status',
        {'p_church_id': church.churchId},
      );
      if (status['initial_setup_open'] != true) await setWindow(open: true);
    });

    test('once closed, Existing Discipler recognition is refused; Disciple '
        'setup and the Leader adding themselves still work', () async {
      final g = await newGroup('win');
      final m = await member('win-m');
      final pl = await added(g, m);

      await setWindow(open: false);
      final status = await rpcRow(m.user.client, 'get_initial_setup_status', {
        'p_church_id': church.churchId,
      });
      expect(status['initial_setup_open'], isFalse);
      expect(status['closed_at'], isNotNull);

      await expectLater(
        setUpMember(g.leader.user.client, pl, 'DISCIPLER'),
        throwsPostgrestCode('PT409'),
      );
      await expectLater(
        setUpMember(church.approver.client, pl, 'DISCIPLER'),
        throwsPostgrestCode('PT409'),
        reason: 'not even the Coordinator, while it is closed',
      );

      final dd = await setUpMember(g.leader.user.client, pl, 'DISCIPLE');
      expect((await dgm(dd))['responsibility'], 'DISCIPLE');

      await rpcRow(g.leader.user.client, 'add_self_as_discipler', {
        'p_d_group_id': g.groupId,
      });
    });

    test('only the church\'s Coordinator opens or closes it, each change '
        'audited, and a no-op is refused', () async {
      final g = await newGroup('win-auth');
      for (final c in [g.leader.user.client, otherChurch.approver.client]) {
        await expectLater(
          c.rpc<List<dynamic>>(
            'set_initial_setup_open',
            params: {'p_church_id': church.churchId, 'p_open': false},
          ),
          throwsPostgrestCode('PT403'),
        );
      }
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'set_initial_setup_open',
          params: {'p_church_id': church.churchId, 'p_open': true},
        ),
        throwsPostgrestCode('PT409'),
        reason: 'already open',
      );

      Future<Map<String, int>> counts() async {
        final rows = await service
            .from('audit_events')
            .select('action')
            .eq('entity_id', church.churchId)
            .inFilter('action', [
              'INITIAL_SETUP_CLOSED',
              'INITIAL_SETUP_REOPENED',
            ]);
        final result = <String, int>{};
        for (final r in rows) {
          final a = r['action'] as String;
          result[a] = (result[a] ?? 0) + 1;
        }
        return result;
      }

      final before = await counts();
      await setWindow(open: false);
      await setWindow(open: true);
      final after = await counts();
      expect(
        after['INITIAL_SETUP_CLOSED'],
        (before['INITIAL_SETUP_CLOSED'] ?? 0) + 1,
      );
      expect(
        after['INITIAL_SETUP_REOPENED'],
        (before['INITIAL_SETUP_REOPENED'] ?? 0) + 1,
      );
    });

    test('another church cannot read it', () async {
      await expectLater(
        otherChurch.approver.client.rpc<List<dynamic>>(
          'get_initial_setup_status',
          params: {'p_church_id': church.churchId},
        ),
        throwsPostgrestCode('PT403'),
      );
    });
  });

  group('pairing with concurrent responsibilities', () {
    test('a Disciple who is also a Discipler disciples others but never '
        'themselves, and two people cannot disciple each other', () async {
      final g = await newGroup('pair-dd');
      final a = await member('pair-a');
      final b = await member('pair-b');
      final c = await member('pair-c');
      final aPl = await added(g, a);
      final bPl = await added(g, b);
      final cPl = await added(g, c);
      final aDd = await setUpMember(g.leader.user.client, aPl, 'DISCIPLE');
      final aDr = await setUpMember(g.leader.user.client, aPl, 'DISCIPLER');
      final bDd = await setUpMember(g.leader.user.client, bPl, 'DISCIPLE');
      final bDr = await setUpMember(g.leader.user.client, bPl, 'DISCIPLER');
      final cDd = await setUpMember(g.leader.user.client, cPl, 'DISCIPLE');

      await expectLater(
        setDiscipler(g.leader.user.client, aDd, aDr),
        throwsPostgrestCode('PT409'),
        reason: 'no self-pairing',
      );

      // a disciples c and b; b cannot then disciple a.
      expect(
        (await setDiscipler(g.leader.user.client, cDd, aDr))['outcome'],
        'ASSIGNED',
      );
      expect(
        (await setDiscipler(g.leader.user.client, bDd, aDr))['outcome'],
        'ASSIGNED',
      );
      await expectLater(
        setDiscipler(g.leader.user.client, aDd, bDr),
        throwsPostgrestCode('PT409'),
        reason: 'reciprocal (D7)',
      );

      // Once b has another Discipler, a may be paired with b.
      await setDiscipler(g.leader.user.client, bDd, null);
      expect(
        (await setDiscipler(g.leader.user.client, aDd, bDr))['outcome'],
        'ASSIGNED',
      );
    });

    test(
      'someone without the needed responsibility cannot be paired',
      () async {
        final g = await newGroup('pair-none');
        final dr = await member('pair-none-dr');
        final waiting = await member('pair-none-w');
        final drDgm = await place(
          g.leader.user.client,
          g.groupId,
          dr,
          'DISCIPLER',
        );
        final ddOnly = await place(
          g.leader.user.client,
          g.groupId,
          await member('pair-none-dd'),
          'DISCIPLE',
        );
        await added(g, waiting);

        // A DISCIPLE row on the Discipler side is refused.
        await expectLater(
          setDiscipler(g.leader.user.client, ddOnly, ddOnly),
          throwsPostgrestCode('PT409'),
        );
        // A DISCIPLER row on the Disciple side is refused.
        await expectLater(
          setDiscipler(g.leader.user.client, drDgm, drDgm),
          throwsPostgrestCode('PT409'),
        );
      },
    );

    test(
      'a Disciple-Discipler sees only the Disciples assigned to them',
      () async {
        final g = await newGroup('vis');
        final a = await member('vis-a');
        final mine = await member('vis-mine');
        final notMine = await member('vis-not');
        final aPl = await added(g, a);
        await setUpMember(g.leader.user.client, aPl, 'DISCIPLE');
        final aDr = await setUpMember(g.leader.user.client, aPl, 'DISCIPLER');
        final mineDd = await place(
          g.leader.user.client,
          g.groupId,
          mine,
          'DISCIPLE',
        );
        await place(g.leader.user.client, g.groupId, notMine, 'DISCIPLE');
        await setDiscipler(g.leader.user.client, mineDd, aDr);

        final c = a.user.client;
        expect(
          await c.from('profiles').select('id').eq('id', mine.user.userId),
          hasLength(1),
        );
        expect(
          await c.from('profiles').select('id').eq('id', notMine.user.userId),
          isEmpty,
        );
        await expectLater(
          c.rpc<List<dynamic>>(
            'get_disciple_journey',
            params: {'p_membership_id': notMine.membershipId},
          ),
          throwsPostgrestCode('PT403'),
        );
        // Their own journey is still theirs to read (not refused).
        await c.rpc<List<dynamic>>(
          'get_disciple_journey',
          params: {'p_membership_id': a.membershipId},
        );
      },
    );
  });
}
