/// Membership approval and rejection against the real local stack: who can see
/// requests, who can act, and what the database records.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestChurch otherChurch;

  setUpAll(() async {
    church = await seedChurch(name: 'Approval Test Church');
    otherChurch = await seedChurch(name: 'Other Church');
  });
  tearDownAll(() async {
    await deleteChurch(church);
    await deleteChurch(otherChurch);
  });

  Future<TestUser> applicant(String tag) async {
    final u = await createUser(fullName: 'Applicant $tag', tag: tag);
    await u.client.rpc<List<dynamic>>(
      'request_join_church',
      params: {'p_church_id': church.churchId, 'p_join_code': church.joinCode},
    );
    return u;
  }

  Future<List<dynamic>> pendingSeenBy(SupabaseClient client) => client
      .from('church_memberships')
      .select(
        'id, created_at, status, '
        'profiles!church_memberships_user_id_fkey(full_name)',
      )
      .eq('church_id', church.churchId)
      .eq('status', 'PENDING');

  Future<String> membershipIdOf(String userId) async {
    final row = await service
        .from('church_memberships')
        .select('id')
        .eq('user_id', userId)
        .eq('church_id', church.churchId)
        .single();
    return row['id'] as String;
  }

  group('visibility', () {
    test(
      'the approver sees pending requests with the applicant name',
      () async {
        final u = await applicant('vis');
        addTearDown(() => deleteUser(u.userId));

        final rows = await pendingSeenBy(church.approver.client);
        final mine = rows.cast<Map<String, dynamic>>().where(
          (r) => r['profiles']?['full_name'] == 'Applicant vis',
        );
        expect(mine, hasLength(1));
      },
    );

    test('an ordinary member, the applicant, and another church\'s approver '
        'see none', () async {
      final u = await applicant('novis');
      addTearDown(() => deleteUser(u.userId));

      final member = await createUser(fullName: 'Plain Member', tag: 'plain');
      addTearDown(() => deleteUser(member.userId));
      await seedMembership(church.churchId, member.userId, 'ACTIVE');

      expect(await pendingSeenBy(member.client), isEmpty);
      expect(await pendingSeenBy(otherChurch.approver.client), isEmpty);

      // The applicant sees only their own row, and not others' profiles.
      final own = await u.client.from('church_memberships').select('id');
      expect(own, hasLength(1));
      expect(
        await u.client
            .from('profiles')
            .select('id')
            .eq('id', church.approver.userId),
        isEmpty,
      );
    });

    test('an approver sees their own roles', () async {
      final roles = await church.approver.client
          .from('church_role_assignments')
          .select('role');
      expect(roles.map((r) => r['role']).toSet(), {'ADMIN', 'COORDINATOR'});
    });
  });

  group('approve_church_membership', () {
    test(
      'PENDING -> ACTIVE with approver, timestamps and an audit event',
      () async {
        final u = await applicant('appr');
        addTearDown(() => deleteUser(u.userId));
        final id = await membershipIdOf(u.userId);

        final res = await church.approver.client.rpc<List<dynamic>>(
          'approve_church_membership',
          params: {'p_membership_id': id},
        );
        expect((res.single as Map)['membership_status'], 'ACTIVE');

        final row = await service
            .from('church_memberships')
            .select(
              'status, approved_by, approved_at, joined_at, onboarding_completed_at',
            )
            .eq('id', id)
            .single();
        expect(row['status'], 'ACTIVE');
        expect(row['approved_by'], church.approver.userId);
        expect(row['approved_at'], isNotNull);
        expect(row['joined_at'], isNotNull);
        expect(
          row['onboarding_completed_at'],
          isNull,
          reason: 'first entry not done',
        );

        final audit = await service
            .from('audit_events')
            .select('action, actor_user_id, entity_type, metadata')
            .eq('entity_id', id);
        expect(audit, hasLength(1));
        expect(audit.single['action'], 'MEMBERSHIP_APPROVED');
        expect(audit.single['actor_user_id'], church.approver.userId);
        expect(audit.single['entity_type'], 'church_memberships');

        // The applicant now sees ACTIVE without signing in again.
        final seen = await u.client
            .from('church_memberships')
            .select('status')
            .single();
        expect(seen['status'], 'ACTIVE');
      },
    );

    test('a Coordinator without ADMIN may also approve', () async {
      final coordinatorChurch = await seedChurch(
        name: 'Coordinator Only Church',
        approverRoles: const {'COORDINATOR'},
      );
      addTearDown(() => deleteChurch(coordinatorChurch));

      final u = await createUser(fullName: 'Coord Applicant', tag: 'coord');
      addTearDown(() => deleteUser(u.userId));
      await u.client.rpc<List<dynamic>>(
        'request_join_church',
        params: {
          'p_church_id': coordinatorChurch.churchId,
          'p_join_code': coordinatorChurch.joinCode,
        },
      );
      final id =
          (await service
                  .from('church_memberships')
                  .select('id')
                  .eq('user_id', u.userId)
                  .single())['id']
              as String;

      final res = await coordinatorChurch.approver.client.rpc<List<dynamic>>(
        'approve_church_membership',
        params: {'p_membership_id': id},
      );
      expect((res.single as Map)['membership_status'], 'ACTIVE');
    });

    test('the applicant, an ordinary member and another church\'s approver '
        'are refused', () async {
      final u = await applicant('forb');
      addTearDown(() => deleteUser(u.userId));
      final id = await membershipIdOf(u.userId);

      final member = await createUser(fullName: 'Plain Member', tag: 'plain2');
      addTearDown(() => deleteUser(member.userId));
      await seedMembership(church.churchId, member.userId, 'ACTIVE');

      for (final client in [
        u.client,
        member.client,
        otherChurch.approver.client,
      ]) {
        await expectLater(
          client.rpc<List<dynamic>>(
            'approve_church_membership',
            params: {'p_membership_id': id},
          ),
          throwsPostgrestCode('PT403'),
        );
      }
      await expectLater(
        anonClient().rpc<List<dynamic>>(
          'approve_church_membership',
          params: {'p_membership_id': id},
        ),
        throwsPostgrestCode('42501'),
      );

      final row = await service
          .from('church_memberships')
          .select('status')
          .eq('id', id)
          .single();
      expect(row['status'], 'PENDING');
    });

    test(
      'a role on a non-ACTIVE membership grants nothing (RBAC 1a)',
      () async {
        final u = await applicant('inact');
        addTearDown(() => deleteUser(u.userId));
        final id = await membershipIdOf(u.userId);

        // Suspend the approver's own membership, then restore it afterwards.
        await service
            .from('church_memberships')
            .update({'status': 'INACTIVE'})
            .eq('id', church.approverMembershipId);
        addTearDown(
          () => service
              .from('church_memberships')
              .update({'status': 'ACTIVE'})
              .eq('id', church.approverMembershipId),
        );

        await expectLater(
          church.approver.client.rpc<List<dynamic>>(
            'approve_church_membership',
            params: {'p_membership_id': id},
          ),
          throwsPostgrestCode('PT403'),
        );
      },
    );

    test('approving a non-PENDING membership or an unknown id fails', () async {
      final u = await applicant('twice');
      addTearDown(() => deleteUser(u.userId));
      final id = await membershipIdOf(u.userId);

      await church.approver.client.rpc<List<dynamic>>(
        'approve_church_membership',
        params: {'p_membership_id': id},
      );
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'approve_church_membership',
          params: {'p_membership_id': id},
        ),
        throwsPostgrestCode('PT409'),
      );
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'approve_church_membership',
          params: {'p_membership_id': '00000000-0000-4000-8000-00000000dead'},
        ),
        throwsPostgrestCode('PT404'),
      );
    });
  });

  group('reject_church_membership', () {
    test(
      'PENDING -> ARCHIVED, audited, with approval fields untouched',
      () async {
        final u = await applicant('rej');
        addTearDown(() => deleteUser(u.userId));
        final id = await membershipIdOf(u.userId);

        final res = await church.approver.client.rpc<List<dynamic>>(
          'reject_church_membership',
          params: {'p_membership_id': id},
        );
        expect((res.single as Map)['membership_status'], 'ARCHIVED');

        final row = await service
            .from('church_memberships')
            .select('status, approved_by, approved_at, joined_at')
            .eq('id', id)
            .single();
        expect(row['status'], 'ARCHIVED');
        expect(row['approved_by'], isNull);
        expect(row['approved_at'], isNull);
        expect(row['joined_at'], isNull);

        final audit = await service
            .from('audit_events')
            .select('action')
            .eq('entity_id', id);
        expect(audit.map((a) => a['action']), ['MEMBERSHIP_REJECTED']);

        // The applicant sees the closed state and can no longer see the church
        // (RBAC 1a: no protected church access).
        final seen = await u.client
            .from('church_memberships')
            .select('status')
            .single();
        expect(seen['status'], 'ARCHIVED');
        expect(await u.client.from('churches').select('id, name'), isEmpty);
      },
    );

    test('only an approver of the same church may reject', () async {
      final u = await applicant('rejforb');
      addTearDown(() => deleteUser(u.userId));
      final id = await membershipIdOf(u.userId);

      await expectLater(
        otherChurch.approver.client.rpc<List<dynamic>>(
          'reject_church_membership',
          params: {'p_membership_id': id},
        ),
        throwsPostgrestCode('PT403'),
      );
      await expectLater(
        u.client.rpc<List<dynamic>>(
          'reject_church_membership',
          params: {'p_membership_id': id},
        ),
        throwsPostgrestCode('PT403'),
      );
    });
  });
}
