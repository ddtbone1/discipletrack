/// Join-code lookup and membership requests against the real local stack:
/// the controlled operations, the rate limit, and what clients cannot read.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;

  setUpAll(() async {
    church = await seedChurch(name: 'Join Test Church');
  });
  tearDownAll(() => deleteChurch(church));

  Future<List<dynamic>> lookup(SupabaseClient client, String code) =>
      client.rpc<List<dynamic>>(
        'lookup_church_by_join_code',
        params: {'p_code': code},
      );

  Future<Map<String, dynamic>> request(
    SupabaseClient client,
    String churchId,
    String code,
  ) async {
    final rows = await client.rpc<List<dynamic>>(
      'request_join_church',
      params: {'p_church_id': churchId, 'p_join_code': code},
    );
    return rows.single as Map<String, dynamic>;
  }

  group('lookup_church_by_join_code', () {
    test('a valid code, however typed, resolves to id and name only', () async {
      final u = await createUser(fullName: 'Looker', tag: 'look');
      addTearDown(() => deleteUser(u.userId));

      final code = church.joinCode;
      final spaced =
          '${code.substring(0, 5).toLowerCase()} - ${code.substring(5)}';
      final rows = await lookup(u.client, spaced);

      expect(rows, hasLength(1));
      final row = rows.single as Map<String, dynamic>;
      expect(row['church_id'], church.churchId);
      expect(row['church_name'], church.name);
      expect(row.keys.toSet(), {'church_id', 'church_name'});
    });

    test(
      'an unknown or malformed code returns nothing and does not raise',
      () async {
        final u = await createUser(fullName: 'Guesser', tag: 'guess');
        addTearDown(() => deleteUser(u.userId));

        expect(await lookup(u.client, 'ABCDEFGHJK'), isEmpty);
        expect(await lookup(u.client, 'not a code'), isEmpty);
      },
    );

    test('an anonymous client is refused', () async {
      await expectLater(
        lookup(anonClient(), church.joinCode),
        throwsPostgrestCode('42501'),
      );
    });

    test(
      'the sixth attempt inside ten minutes is refused with PT429',
      () async {
        final u = await createUser(fullName: 'Hammer', tag: 'rate');
        addTearDown(() => deleteUser(u.userId));

        for (var i = 0; i < 5; i++) {
          await lookup(u.client, 'ABCDEFGHJ${i + 2}');
        }
        await expectLater(
          lookup(u.client, church.joinCode),
          throwsPostgrestCode('PT429'),
        );
      },
    );
  });

  group('request_join_church', () {
    test(
      'creates a PENDING membership for the caller and is idempotent',
      () async {
        final u = await createUser(fullName: 'Applicant', tag: 'apply');
        addTearDown(() => deleteUser(u.userId));

        final first = await request(u.client, church.churchId, church.joinCode);
        expect(first['outcome'], 'REQUESTED');
        expect(first['membership_status'], 'PENDING');

        final mine = await u.client
            .from('church_memberships')
            .select(
              'id, church_id, status, joined_at, approved_by, onboarding_completed_at',
            )
            .single();
        expect(mine['id'], first['membership_id']);
        expect(mine['church_id'], church.churchId);
        expect(mine['status'], 'PENDING');
        expect(mine['joined_at'], isNull);
        expect(mine['approved_by'], isNull);
        expect(mine['onboarding_completed_at'], isNull);

        final again = await request(u.client, church.churchId, church.joinCode);
        expect(again['outcome'], 'ALREADY_PENDING');
        expect(again['membership_id'], first['membership_id']);

        final rows = await service
            .from('church_memberships')
            .select('id')
            .eq('user_id', u.userId);
        expect(rows, hasLength(1));
      },
    );

    test('a leaked church id without the right code is refused', () async {
      final u = await createUser(fullName: 'Bypasser', tag: 'bypass');
      addTearDown(() => deleteUser(u.userId));

      final res = await request(u.client, church.churchId, 'ABCDEFGHJK');
      expect(res['outcome'], 'INVALID_CODE');
      expect(
        await service
            .from('church_memberships')
            .select('id')
            .eq('user_id', u.userId),
        isEmpty,
      );
    });

    test('a PENDING member can read the requested church by name, and only '
        'that', () async {
      final u = await createUser(fullName: 'Pending Reader', tag: 'pread');
      addTearDown(() => deleteUser(u.userId));
      await request(u.client, church.churchId, church.joinCode);

      final churches = await u.client
          .from('churches')
          .select('id, name, status');
      expect(churches, hasLength(1));
      expect(churches.single['name'], church.name);

      // join_code has no client grant at all.
      await expectLater(
        u.client.from('churches').select('join_code'),
        throwsPostgrestCode('42501'),
      );
      await expectLater(
        u.client.from('churches').select(),
        throwsPostgrestCode('42501'),
      );
    });

    test(
      'an ARCHIVED (rejected) member cannot request again from the app',
      () async {
        final u = await createUser(fullName: 'Rejected', tag: 'rej');
        addTearDown(() => deleteUser(u.userId));
        await seedMembership(church.churchId, u.userId, 'ARCHIVED');

        final res = await request(u.client, church.churchId, church.joinCode);
        expect(res['outcome'], 'NOT_REQUESTABLE');
        expect(res['membership_status'], 'ARCHIVED');
      },
    );
  });

  group('what a client may not do directly', () {
    test(
      'cannot INSERT or UPDATE church_memberships, or see other churches',
      () async {
        final u = await createUser(fullName: 'Direct Writer', tag: 'direct');
        addTearDown(() => deleteUser(u.userId));

        // No INSERT policy: a self-made ACTIVE membership is impossible.
        await expectLater(
          u.client.from('church_memberships').insert({
            'church_id': church.churchId,
            'user_id': u.userId,
            'status': 'ACTIVE',
          }),
          throwsA(isA<PostgrestException>()),
        );

        await request(u.client, church.churchId, church.joinCode);

        // No UPDATE policy: PostgREST reports zero rows affected rather than
        // an error, so verify the row is unchanged.
        await u.client
            .from('church_memberships')
            .update({'status': 'ACTIVE'})
            .eq('user_id', u.userId);
        final row = await service
            .from('church_memberships')
            .select('status')
            .eq('user_id', u.userId)
            .single();
        expect(row['status'], 'PENDING');

        // Cannot grant oneself a role.
        final mine = await u.client
            .from('church_memberships')
            .select('id')
            .single();
        await expectLater(
          u.client.from('church_role_assignments').insert({
            'church_membership_id': mine['id'],
            'role': 'ADMIN',
            'assigned_by': u.userId,
            'started_at': DateTime.now().toUtc().toIso8601String(),
          }),
          throwsA(isA<PostgrestException>()),
        );

        // Only their own church is visible; the seeded church is not.
        final churches = await u.client.from('churches').select('id');
        expect(churches.map((c) => c['id']), [church.churchId]);
      },
    );

    test('a user cannot create a request on behalf of another user', () async {
      final a = await createUser(fullName: 'Person A', tag: 'pa');
      final b = await createUser(fullName: 'Person B', tag: 'pb');
      addTearDown(() => deleteUser(a.userId));
      addTearDown(() => deleteUser(b.userId));

      // request_join_church takes no user id: the caller is always auth.uid().
      await request(a.client, church.churchId, church.joinCode);
      final rows = await service
          .from('church_memberships')
          .select('user_id')
          .eq('church_id', church.churchId)
          .inFilter('user_id', [a.userId, b.userId]);
      expect(rows.map((r) => r['user_id']), [a.userId]);

      // And B sees nothing of A's request.
      expect(await b.client.from('church_memberships').select('id'), isEmpty);
    });
  });
}
