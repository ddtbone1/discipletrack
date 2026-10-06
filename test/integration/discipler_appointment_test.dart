/// Slice 6.3 against the real local stack: Discipler eligibility after
/// Lesson 5 is derived, never stored, and appoints nobody by itself; the
/// Coordinator appoints (ADR-012, BR-036, BR-037, DC sections 5 and 11).
/// The appointed person keeps their own Disciple journey.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/discipleship_fixture.dart';
import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestChurch otherChurch;
  late TestCurriculum curriculum;
  late TestGroup g;

  setUpAll(() async {
    church = await seedChurch(name: 'Appointment Church');
    otherChurch = await seedChurch(name: 'Other Appointment Church');
    curriculum = await seedCurriculum(church.churchId);
    g = await createGroupWithLeader(church, tag: 'appt-lead');
  });
  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    await deleteUser(g.leader.user.userId);
    await deleteUser(church.approver.userId);
    await deleteChurch(otherChurch);
  });

  Future<PairedDisciple> paired(String tag) async {
    final p = await placePairedDisciple(
      church,
      g,
      since: DateTime.now().subtract(const Duration(days: 60)),
      tag: tag,
    );
    addTearDown(() async {
      await deleteUser(p.disciple.user.userId);
      await deleteUser(p.discipler.user.userId);
    });
    return p;
  }

  /// The Discipler marks Lessons 1 to [upTo] completed, in order.
  Future<void> complete(PairedDisciple p, int upTo) async {
    for (var i = 0; i < upTo; i++) {
      await rpcRow(p.discipler.user.client, 'complete_lesson', {
        'p_membership_id': p.disciple.membershipId,
        'p_lesson_id': curriculum.lessonIds[i],
      });
    }
  }

  Future<void> complete6(PairedDisciple p) =>
      rpcRow(p.discipler.user.client, 'complete_lesson', {
        'p_membership_id': p.disciple.membershipId,
        'p_lesson_id': curriculum.lessonIds[5],
      });

  Future<Map<String, dynamic>> appoint(SupabaseClient c, String membershipId) =>
      rpcRow(c, 'appoint_discipler', {'p_membership_id': membershipId});

  Future<Set<String>> candidates(SupabaseClient c, {String? groupId}) async {
    final rows = await c.rpc<List<dynamic>>(
      'list_discipler_candidates',
      params: groupId == null
          ? {'p_church_id': church.churchId}
          : {'p_d_group_id': groupId},
    );
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        r['church_membership_id'] as String,
    };
  }

  Future<List<Map<String, dynamic>>> activeRows(String membershipId) async =>
      (await service
              .from('d_group_memberships')
              .select()
              .eq('church_membership_id', membershipId)
              .isFilter('ended_at', null))
          .cast<Map<String, dynamic>>();

  test('below Lesson 5 there is no eligibility and appointment is refused '
      '(D5)', () async {
    final p = await paired('below');
    await complete(p, 4);

    expect(
      await candidates(church.approver.client),
      isNot(contains(p.disciple.membershipId)),
    );
    await expectLater(
      appoint(church.approver.client, p.disciple.membershipId),
      throwsPostgrestCode('PT409'),
    );
  });

  test('Lesson 5 completed makes them eligible, visible to the Leader and '
      'the Coordinator, and appoints nobody', () async {
    final p = await paired('elig');
    await complete(p, 5);

    expect(
      await candidates(church.approver.client),
      contains(p.disciple.membershipId),
    );
    expect(
      await candidates(g.leader.user.client, groupId: g.groupId),
      contains(p.disciple.membershipId),
    );

    // Eligible is not appointed: no DISCIPLER row, no appointment record.
    final rows = await activeRows(p.disciple.membershipId);
    expect(rows.map((r) => r['responsibility']), ['DISCIPLE']);
    expect(
      await service
          .from('ministry_role_transitions')
          .select('id')
          .eq('church_membership_id', p.disciple.membershipId),
      isEmpty,
    );
  });

  test(
    'the Coordinator appoints; the Disciple journey, pairing and progress '
    'are untouched; audited; they can then be paired with Disciples',
    () async {
      final p = await paired('appt');
      await complete(p, 5);
      final progressBefore = await service
          .from('disciple_lesson_progress')
          .select('lesson_id, status, completed_at')
          .eq('church_membership_id', p.disciple.membershipId)
          .order('lesson_id');

      final res = await appoint(
        church.approver.client,
        p.disciple.membershipId,
      );
      final dgmId = res['d_group_membership_id'] as String;
      final mrtId = res['ministry_role_transition_id'] as String;

      final rows = await activeRows(p.disciple.membershipId);
      expect(rows.map((r) => r['responsibility']).toSet(), {
        'DISCIPLE',
        'DISCIPLER',
      });
      final dr = rows.singleWhere((r) => r['responsibility'] == 'DISCIPLER');
      expect(dr['id'], dgmId);
      expect(dr['discipler_basis'], 'APPOINTMENT');
      expect(dr['d_group_id'], g.groupId);
      expect(
        rows.singleWhere((r) => r['responsibility'] == 'DISCIPLE')['id'],
        p.discipleDgmId,
        reason: 'the same DISCIPLE row continues',
      );

      final mrt = await service
          .from('ministry_role_transitions')
          .select()
          .eq('id', mrtId)
          .single();
      expect(mrt['from_responsibility'], 'DISCIPLE');
      expect(mrt['to_responsibility'], 'DISCIPLER');
      expect(mrt['approved_by'], church.approver.userId);

      // Own pairing and progress unchanged.
      final assignment = await service
          .from('discipler_assignments')
          .select('discipler_d_group_membership_id')
          .eq('disciple_d_group_membership_id', p.discipleDgmId)
          .isFilter('ended_at', null)
          .single();
      expect(assignment['discipler_d_group_membership_id'], p.disciplerDgmId);
      final progressAfter = await service
          .from('disciple_lesson_progress')
          .select('lesson_id, status, completed_at')
          .eq('church_membership_id', p.disciple.membershipId)
          .order('lesson_id');
      expect(progressAfter, progressBefore);

      expect(await auditActionsFor(mrtId), ['DISCIPLER_APPOINTED']);

      // No longer a candidate, and cannot be appointed twice.
      expect(
        await candidates(church.approver.client),
        isNot(contains(p.disciple.membershipId)),
      );
      await expectLater(
        appoint(church.approver.client, p.disciple.membershipId),
        throwsPostgrestCode('PT409'),
      );

      // Their own Discipler still completes their Lesson 6.
      await rpcRow(p.discipler.user.client, 'complete_lesson', {
        'p_membership_id': p.disciple.membershipId,
        'p_lesson_id': curriculum.lessonIds[5],
      });

      // The Leader pairs a new Disciple with them (D6).
      final newcomer = await createActiveMember(
        church.churchId,
        fullName: 'Appt Newcomer',
        tag: 'appt-new',
      );
      addTearDown(() => deleteUser(newcomer.user.userId));
      final newDd = await place(
        g.leader.user.client,
        g.groupId,
        newcomer,
        'DISCIPLE',
      );
      final pairRes = await setDiscipler(g.leader.user.client, newDd, dgmId);
      expect(pairRes['outcome'], 'ASSIGNED');

      // As the new Disciple's Discipler they can read that journey.
      await p.disciple.user.client.rpc<List<dynamic>>(
        'get_disciple_journey',
        params: {'p_membership_id': newcomer.membershipId},
      );
    },
  );

  test('only the Coordinator appoints; not the Leader, the Discipler, the '
      'person, nor another church', () async {
    final p = await paired('auth');
    await complete(p, 5);
    for (final c in [
      g.leader.user.client,
      p.discipler.user.client,
      p.disciple.user.client,
      otherChurch.approver.client,
    ]) {
      await expectLater(
        appoint(c, p.disciple.membershipId),
        throwsPostgrestCode('PT403'),
      );
    }
    await expectLater(
      appoint(church.approver.client, '00000000-0000-4000-8000-0000000000ab'),
      throwsPostgrestCode('PT403'),
      reason: 'unknown ids reveal nothing',
    );
    await expectLater(
      otherChurch.approver.client.rpc<List<dynamic>>(
        'list_discipler_candidates',
        params: {'p_church_id': church.churchId},
      ),
      throwsPostgrestCode('PT403'),
    );
    await expectLater(
      p.discipler.user.client.rpc<List<dynamic>>(
        'list_discipler_candidates',
        params: {'p_d_group_id': g.groupId},
      ),
      throwsPostgrestCode('PT403'),
    );
  });

  test('a Coordinator cannot appoint themselves (D9)', () async {
    // The Coordinator is a Disciple of this group who completed Lesson 5.
    final coordDd = await place(g.leader.user.client, g.groupId, (
      user: church.approver,
      membershipId: church.approverMembershipId,
    ), 'DISCIPLE');
    final dr = await paired('self-dr');
    await setDiscipler(g.leader.user.client, coordDd, dr.disciplerDgmId);
    for (var i = 0; i < 5; i++) {
      await rpcRow(dr.discipler.user.client, 'complete_lesson', {
        'p_membership_id': church.approverMembershipId,
        'p_lesson_id': curriculum.lessonIds[i],
      });
    }
    await expectLater(
      appoint(church.approver.client, church.approverMembershipId),
      throwsPostgrestCode('PT409'),
    );
    await rpcRow(g.leader.user.client, 'remove_from_d_group', {
      'p_d_group_placement_id': await activePlacementOf(
        church.approverMembershipId,
      ),
    });
  });

  test('no appointment once the DISCIPLE row has ended (D8); re-added and '
      'set up again, their progress makes them eligible again', () async {
    final p = await paired('ended');
    await complete(p, 5);
    await rpcRow(g.leader.user.client, 'remove_from_d_group', {
      'p_d_group_placement_id': await activePlacementOf(
        p.disciple.membershipId,
      ),
    });
    await expectLater(
      appoint(church.approver.client, p.disciple.membershipId),
      throwsPostgrestCode('PT409'),
    );

    await place(g.leader.user.client, g.groupId, p.disciple, 'DISCIPLE');
    expect(
      await candidates(church.approver.client),
      contains(p.disciple.membershipId),
    );
  });

  test('an Existing Discipler recognized at rollout is not an appointment '
      'and is not a candidate', () async {
    final p = await paired('rollout');
    await complete(p, 5);
    // Recognized as Existing Discipler during the open setup period.
    await setUpMember(
      g.leader.user.client,
      (await activePlacementOf(p.disciple.membershipId))!,
      'DISCIPLER',
    );
    expect(
      await candidates(church.approver.client),
      isNot(contains(p.disciple.membershipId)),
    );
    expect(
      await service
          .from('ministry_role_transitions')
          .select('id')
          .eq('church_membership_id', p.disciple.membershipId),
      isEmpty,
    );
    await expectLater(
      appoint(church.approver.client, p.disciple.membershipId),
      throwsPostgrestCode('PT409'),
    );
  });

  test(
    'undoing Lesson 5 before appointment withdraws eligibility at once',
    () async {
      final p = await paired('undo');
      await complete(p, 5);
      await rpcRow(p.discipler.user.client, 'undo_lesson_completion', {
        'p_membership_id': p.disciple.membershipId,
        'p_lesson_id': curriculum.lessonIds[4],
      });
      expect(
        await candidates(church.approver.client),
        isNot(contains(p.disciple.membershipId)),
      );
      await expectLater(
        appoint(church.approver.client, p.disciple.membershipId),
        throwsPostgrestCode('PT409'),
      );
    },
  );

  test('once appointed, Lesson 5 and earlier can no longer be undone and '
      'the journey stops offering it; later lessons undo as usual', () async {
    final p = await paired('lock');
    await complete(p, 5);

    Future<bool> canUndo(int lessonIndex) async {
      final rows = (await p.discipler.user.client.rpc<List<dynamic>>(
        'get_disciple_journey',
        params: {'p_membership_id': p.disciple.membershipId},
      )).cast<Map<String, dynamic>>();
      return rows[lessonIndex]['can_undo'] as bool;
    }

    expect(await canUndo(4), isTrue, reason: 'inside the undo window');
    await appoint(church.approver.client, p.disciple.membershipId);
    expect(await canUndo(4), isFalse);

    await expectLater(
      p.discipler.user.client.rpc<List<dynamic>>(
        'undo_lesson_completion',
        params: {
          'p_membership_id': p.disciple.membershipId,
          'p_lesson_id': curriculum.lessonIds[4],
        },
      ),
      throwsA(
        isA<PostgrestException>()
            .having((e) => e.code, 'code', 'PT409')
            .having(
              (e) => e.message,
              'message',
              'eligibility_lesson_protected',
            ),
      ),
    );

    await complete6(p);
    expect(await canUndo(5), isTrue);
    await rpcRow(p.discipler.user.client, 'undo_lesson_completion', {
      'p_membership_id': p.disciple.membershipId,
      'p_lesson_id': curriculum.lessonIds[5],
    });
  });

  test('appointment history is readable by the Coordinator, the Leader and '
      'the person, and nobody else', () async {
    final p = await paired('hist');
    await complete(p, 5);
    final res = await appoint(church.approver.client, p.disciple.membershipId);
    final id = res['ministry_role_transition_id'] as String;

    Future<List<dynamic>> seen(SupabaseClient c) =>
        c.from('ministry_role_transitions').select('id').eq('id', id);

    expect(await seen(church.approver.client), hasLength(1));
    expect(await seen(g.leader.user.client), hasLength(1));
    expect(await seen(p.disciple.user.client), hasLength(1));
    expect(await seen(p.discipler.user.client), isEmpty);
    expect(await seen(otherChurch.approver.client), isEmpty);
    await expectLater(
      church.approver.client.from('ministry_role_transitions').insert({
        'church_membership_id': p.disciple.membershipId,
        'd_group_id': g.groupId,
        'from_responsibility': 'DISCIPLE',
        'to_responsibility': 'DISCIPLER',
        'approved_by': church.approver.userId,
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      }),
      throwsPostgrestCode('42501'),
    );
  });
}
