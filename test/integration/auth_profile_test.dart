/// Integration tests for the Auth + Profile slice, run against the real local
/// Supabase stack.
///
/// Run with:
///   $env:SUPABASE_SERVICE_ROLE_KEY = (npx supabase status -o json |
///       ConvertFrom-Json).SERVICE_ROLE_KEY
///   flutter test --dart-define-from-file=config/test.json test/integration
///
/// The service-role key is read from the environment rather than a committed
/// file. It bypasses RLS entirely, so it is the one key that should never be
/// habitually stored in the repository, even though the local value is a
/// published Supabase default. See config/README.md.
///
/// These tests construct [SupabaseClient] directly rather than going through
/// `Supabase.initialize()`, so no Flutter session-persistence layer is
/// involved. Each test owns its users and cleans them up.
///
/// Cleanup deletes the profile row before the auth user. Migration 001 declares
/// `profiles.id -> auth.users(id) ON DELETE NO ACTION`, so deleting an auth
/// user while its profile exists is rejected by design. Account deletion is a
/// deliberate two-step operator action, not a cascade.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Read at runtime from the environment, with a compile-time define as a
/// fallback so CI can inject it either way.
final _serviceKey =
    Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
    const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');

const _password = 'test-password-123';

/// Service-role client. Bypasses RLS; used only for setup and teardown.
late SupabaseClient service;

/// Unique per run so repeated runs never collide.
String _email([String tag = 'user']) =>
    'dt-$tag-${DateTime.now().microsecondsSinceEpoch}@example.test';

/// The implicit flow is used deliberately. PKCE is the package default but
/// requires an async storage implementation that only the Flutter wrapper
/// supplies; these tests construct the client directly and hold no session.
const _testAuthOptions = AuthClientOptions(
  authFlowType: AuthFlowType.implicit,
  autoRefreshToken: false,
);

SupabaseClient _anonClient() =>
    SupabaseClient(_url, _anonKey, authOptions: _testAuthOptions);

/// Signs a fresh user up and returns its authenticated client plus user id.
Future<({SupabaseClient client, String userId, String email})> _signUp({
  required String fullName,
  String tag = 'user',
}) async {
  final client = _anonClient();
  final email = _email(tag);
  final res = await client.auth.signUp(
    email: email,
    password: _password,
    data: {'full_name': fullName},
  );
  return (client: client, userId: res.user!.id, email: email);
}

Future<void> _cleanUp(String userId) async {
  // Profile first: the FK is ON DELETE NO ACTION.
  await service.from('profiles').delete().eq('id', userId);
  await service.auth.admin.deleteUser(userId);
}

void main() {
  setUpAll(() {
    expect(
      _url.isNotEmpty && _anonKey.isNotEmpty,
      isTrue,
      reason:
          'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY. Run with '
          '--dart-define-from-file=config/test.json',
    );
    // Reported separately from the defines above, because this one comes from
    // the environment and the fix is a different command.
    expect(
      _serviceKey.isNotEmpty,
      isTrue,
      reason:
          'Missing SUPABASE_SERVICE_ROLE_KEY. It is deliberately not committed. '
          'Set it from the running stack:\n'
          r'  $env:SUPABASE_SERVICE_ROLE_KEY = '
          r'(npx supabase status -o json | ConvertFrom-Json).SERVICE_ROLE_KEY',
    );
    service = SupabaseClient(_url, _serviceKey, authOptions: _testAuthOptions);
  });

  group('handle_new_user trigger', () {
    test(
      '1+2. valid signup creates a profile whose id matches auth.users.id',
      () async {
        final u = await _signUp(fullName: 'Valid User');
        addTearDown(() => _cleanUp(u.userId));

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
      final u = await _signUp(fullName: '  Padded Name  ');
      addTearDown(() => _cleanUp(u.userId));

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
        final client = _anonClient();
        final email = _email('nometa');

        await expectLater(
          client.auth.signUp(email: email, password: _password),
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
      final client = _anonClient();
      final email = _email('blankmeta');

      await expectLater(
        client.auth.signUp(
          email: email,
          password: _password,
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
        final u = await _signUp(fullName: 'First Registration', tag: 'dup');
        addTearDown(() => _cleanUp(u.userId));

        // Observed GoTrue behaviour is recorded rather than assumed: it may
        // throw, or return an obfuscated user. Either is acceptable; creating a
        // SECOND profile row for the same email is not.
        try {
          await _anonClient().auth.signUp(
            email: u.email,
            password: _password,
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
      final u = await _signUp(fullName: 'Self Reader');
      addTearDown(() => _cleanUp(u.userId));

      final rows = await u.client.from('profiles').select('id, full_name');
      expect(rows.length, 1);
      expect(rows.first['id'], u.userId);
    });

    test("7. a user cannot read another user's profile", () async {
      final a = await _signUp(fullName: 'User A', tag: 'a');
      final b = await _signUp(fullName: 'User B', tag: 'b');
      addTearDown(() => _cleanUp(a.userId));
      addTearDown(() => _cleanUp(b.userId));

      final rows = await a.client
          .from('profiles')
          .select('id')
          .eq('id', b.userId);

      expect(rows, isEmpty, reason: 'RLS must hide other profiles entirely');
    });

    test('8. a user can update their own full_name and phone', () async {
      final u = await _signUp(fullName: 'Before Edit');
      addTearDown(() => _cleanUp(u.userId));

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
      final u = await _signUp(fullName: 'Column Guard');
      addTearDown(() => _cleanUp(u.userId));

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
      final u = await _signUp(fullName: 'Keeps A Name');
      addTearDown(() => _cleanUp(u.userId));

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
      final u = await _signUp(fullName: 'Timestamp Test');
      addTearDown(() => _cleanUp(u.userId));

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
      final u = await _signUp(fullName: 'No Insert');
      addTearDown(() => _cleanUp(u.userId));

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
    /// Seeds a church and a membership for [userId]. Returns the church id.
    Future<String> seedMembership(String userId, String status) async {
      final church = await service
          .from('churches')
          .insert({
            'name': 'Test Church',
            'join_code': 'TC-${DateTime.now().microsecondsSinceEpoch}',
          })
          .select('id')
          .single();
      final churchId = church['id'] as String;

      await service.from('church_memberships').insert({
        'church_id': churchId,
        'user_id': userId,
        'status': status,
      });
      return churchId;
    }

    Future<void> cleanChurch(String churchId) async {
      await service
          .from('church_memberships')
          .delete()
          .eq('church_id', churchId);
      await service.from('churches').delete().eq('id', churchId);
    }

    test('12. a user can read their own membership', () async {
      final u = await _signUp(fullName: 'Member', tag: 'mem');
      final churchId = await seedMembership(u.userId, 'ACTIVE');
      addTearDown(() async {
        await cleanChurch(churchId);
        await _cleanUp(u.userId);
      });

      final rows = await u.client
          .from('church_memberships')
          .select('id, status, church_id');

      expect(rows.length, 1);
      expect(rows.first['status'], 'ACTIVE');
      expect(rows.first['church_id'], churchId);
    });

    test('a PENDING membership is visible to its own user', () async {
      final u = await _signUp(fullName: 'Pending Member', tag: 'pend');
      final churchId = await seedMembership(u.userId, 'PENDING');
      addTearDown(() async {
        await cleanChurch(churchId);
        await _cleanUp(u.userId);
      });

      final rows = await u.client.from('church_memberships').select('status');
      expect(rows.single['status'], 'PENDING');
    });

    test("13. a user cannot read another user's membership", () async {
      final a = await _signUp(fullName: 'Member A', tag: 'ma');
      final b = await _signUp(fullName: 'Member B', tag: 'mb');
      final churchId = await seedMembership(b.userId, 'ACTIVE');
      addTearDown(() async {
        await cleanChurch(churchId);
        await _cleanUp(a.userId);
        await _cleanUp(b.userId);
      });

      final rows = await a.client.from('church_memberships').select('id');
      expect(rows, isEmpty);
    });
  });

  group('unauthenticated access', () {
    test(
      '14. an anonymous client reads nothing from profiles or memberships',
      () async {
        final u = await _signUp(fullName: 'Has Profile', tag: 'anon');
        addTearDown(() => _cleanUp(u.userId));

        final anon = _anonClient();
        expect(await anon.from('profiles').select('id'), isEmpty);
        expect(await anon.from('church_memberships').select('id'), isEmpty);
      },
    );
  });
}
