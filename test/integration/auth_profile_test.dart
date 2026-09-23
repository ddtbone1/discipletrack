/// Integration tests for the Auth + Profile slice, run against the real local
/// Supabase stack. Setup lives in support/test_env.dart.
///
/// Users are created through the admin API (confirmed), because with
/// `enable_confirmations = true` an anonymous sign-up no longer yields a
/// session. The trigger behaviour on sign-up itself is covered by
/// email_verification_test.dart and by the rejection tests below, which still
/// use the anonymous path deliberately.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  group('handle_new_user trigger', () {
    test(
      '1+2. a new user gets a profile whose id matches auth.users.id',
      () async {
        final u = await createUser(fullName: 'Valid User');
        addTearDown(() => deleteUser(u.userId));

        final row = await u.client
            .from('profiles')
            .select('id, full_name, phone, avatar_url, created_at, updated_at')
            .eq('id', u.userId)
            .single();

        expect(
          row['id'],
          u.userId,
          reason: 'profile.id must equal auth.users.id',
        );
        expect(row['full_name'], 'Valid User');
        expect(row['phone'], isNull);
        expect(row['avatar_url'], isNull);
        expect(row['created_at'], isNotNull);
        expect(row['updated_at'], isNotNull);
      },
    );

    test('trigger trims surrounding whitespace from full_name', () async {
      final u = await createUser(fullName: '  Padded Name  ');
      addTearDown(() => deleteUser(u.userId));

      final row = await u.client
          .from('profiles')
          .select('full_name')
          .eq('id', u.userId)
          .single();

      expect(row['full_name'], 'Padded Name');
    });

    test(
      '3. signup with MISSING full_name is rejected and leaves no auth user',
      () async {
        final client = anonClient();
        final email = uniqueEmail('nometa');

        await expectLater(
          client.auth.signUp(email: email, password: password),
          throwsA(isA<AuthException>()),
        );

        final users = await service.auth.admin.listUsers();
        expect(
          users.where((u) => u.email == email),
          isEmpty,
          reason: 'the raised exception must roll back the auth.users insert',
        );
      },
    );

    test('4. signup with WHITESPACE-ONLY full_name is rejected and leaves no auth user', () async {
      final client = anonClient();
      final email = uniqueEmail('blankmeta');

      await expectLater(
        client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': '   '},
        ),
        throwsA(isA<AuthException>()),
      );

      final users = await service.auth.admin.listUsers();
      expect(users.where((u) => u.email == email), isEmpty);
    });

    test(
      '5. duplicate email signup does not create a second profile',
      () async {
        final u = await createUser(fullName: 'First Registration', tag: 'dup');
        addTearDown(() => deleteUser(u.userId));

        // A confirmed address is refused outright by GoTrue. Either a throw or
        // an obfuscated user is acceptable; a SECOND profile row is not.
        try {
          await anonClient().auth.signUp(
            email: u.email,
            password: password,
            data: {'full_name': 'Second Registration'},
          );
        } on AuthException {
          // acceptable
        }

        final rows = await service
            .from('profiles')
            .select('id')
            .eq('id', u.userId);
        expect(rows.length, 1);
      },
    );
  });

  group('profiles RLS', () {
    test('6. a user can read their own profile', () async {
      final u = await createUser(fullName: 'Self Reader');
      addTearDown(() => deleteUser(u.userId));

      final rows = await u.client.from('profiles').select('id, full_name');
      expect(rows.length, 1);
      expect(rows.first['id'], u.userId);
    });

    test("7. a user cannot read another user's profile", () async {
      final a = await createUser(fullName: 'User A', tag: 'a');
      final b = await createUser(fullName: 'User B', tag: 'b');
      addTearDown(() => deleteUser(a.userId));
      addTearDown(() => deleteUser(b.userId));

      final rows = await a.client
          .from('profiles')
          .select('id')
          .eq('id', b.userId);

      expect(rows, isEmpty, reason: 'RLS must hide other profiles entirely');
    });

    test('8. a user can update their own full_name and phone', () async {
      final u = await createUser(fullName: 'Before Edit');
      addTearDown(() => deleteUser(u.userId));

      await u.client
          .from('profiles')
          .update({'full_name': 'After Edit', 'phone': '+63 900 000 0000'})
          .eq('id', u.userId);

      final row = await u.client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', u.userId)
          .single();

      expect(row['full_name'], 'After Edit');
      expect(row['phone'], '+63 900 000 0000');
    });

    test('9. a user cannot update non-permitted columns', () async {
      final u = await createUser(fullName: 'Column Guard');
      addTearDown(() => deleteUser(u.userId));

      // created_at is outside the granted column set.
      await expectLater(
        u.client
            .from('profiles')
            .update({'created_at': '2000-01-01T00:00:00Z'})
            .eq('id', u.userId),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('10. blanking full_name is rejected by the database CHECK', () async {
      final u = await createUser(fullName: 'Keeps A Name');
      addTearDown(() => deleteUser(u.userId));

      await expectLater(
        u.client
            .from('profiles')
            .update({'full_name': '   '})
            .eq('id', u.userId),
        throwsA(isA<PostgrestException>()),
      );

      final row = await u.client
          .from('profiles')
          .select('full_name')
          .eq('id', u.userId)
          .single();
      expect(row['full_name'], 'Keeps A Name');
    });

    test('11. updating a profile advances updated_at', () async {
      final u = await createUser(fullName: 'Timestamp Test');
      addTearDown(() => deleteUser(u.userId));

      final before = await u.client
          .from('profiles')
          .select('updated_at')
          .eq('id', u.userId)
          .single();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await u.client
          .from('profiles')
          .update({'full_name': 'Timestamp Test 2'})
          .eq('id', u.userId);

      final after = await u.client
          .from('profiles')
          .select('updated_at')
          .eq('id', u.userId)
          .single();

      expect(
        DateTime.parse(after['updated_at'] as String)
            .isAfter(DateTime.parse(before['updated_at'] as String)),
        isTrue,
        reason: 'set_updated_at trigger must fire on UPDATE',
      );
    });

    test('15. a client cannot INSERT a profile directly', () async {
      final u = await createUser(fullName: 'No Insert');
      addTearDown(() => deleteUser(u.userId));

      await expectLater(
        u.client.from('profiles').insert({
          'id': '00000000-0000-0000-0000-000000000123',
          'full_name': 'Forged',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('church_memberships RLS', () {
    late TestChurch church;
    setUpAll(() async {
      church = await seedChurch(name: 'Membership RLS Church');
    });
    tearDownAll(() => deleteChurch(church));

    test('12. a user can read their own membership', () async {
      final u = await createUser(fullName: 'Member', tag: 'mem');
      addTearDown(() => deleteUser(u.userId));
      await seedMembership(church.churchId, u.userId, 'ACTIVE');

      final rows = await u.client
          .from('church_memberships')
          .select('id, status, church_id');

      expect(rows.length, 1);
      expect(rows.first['status'], 'ACTIVE');
      expect(rows.first['church_id'], church.churchId);
    });

    test('a PENDING membership is visible to its own user', () async {
      final u = await createUser(fullName: 'Pending Member', tag: 'pend');
      addTearDown(() => deleteUser(u.userId));
      await seedMembership(church.churchId, u.userId, 'PENDING');

      final rows = await u.client.from('church_memberships').select('status');
      expect(rows.single['status'], 'PENDING');
    });

    test("13. a user cannot read another user's membership", () async {
      final a = await createUser(fullName: 'Member A', tag: 'ma');
      final b = await createUser(fullName: 'Member B', tag: 'mb');
      addTearDown(() => deleteUser(a.userId));
      addTearDown(() => deleteUser(b.userId));
      await seedMembership(church.churchId, b.userId, 'ACTIVE');

      final rows = await a.client.from('church_memberships').select('id');
      expect(rows, isEmpty);
    });
  });

  group('unauthenticated access', () {
    test(
      '14. an anonymous client reads nothing from profiles or memberships',
      () async {
        final u = await createUser(fullName: 'Has Profile', tag: 'anon');
        addTearDown(() => deleteUser(u.userId));

        final anon = anonClient();
        expect(await anon.from('profiles').select('id'), isEmpty);
        expect(await anon.from('church_memberships').select('id'), isEmpty);
      },
    );
  });
}
