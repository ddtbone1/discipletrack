/// The one-time first-entry welcome state, `onboarding_completed_at`, against
/// the real local stack.
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;

  setUpAll(() async {
    church = await seedChurch(name: 'First Entry Church');
  });
  tearDownAll(() => deleteChurch(church));

  Future<Map<String, dynamic>> complete(TestUser u) async {
    final rows = await u.client.rpc<List<dynamic>>('complete_onboarding');
    return rows.single as Map<String, dynamic>;
  }

  test('a newly ACTIVE membership has no completion; completing it is '
      'recorded once and seen from another session', () async {
    final u = await createUser(fullName: 'First Timer', tag: 'first');
    addTearDown(() => deleteUser(u.userId));
    await seedMembership(church.churchId, u.userId, 'ACTIVE');

    final before = await u.client
        .from('church_memberships')
        .select('onboarding_completed_at')
        .single();
    expect(before['onboarding_completed_at'], isNull);

    final first = await complete(u);
    expect(first['onboarding_completed_at'], isNotNull);

    // Idempotent: the original timestamp is kept.
    final second = await complete(u);
    expect(second['onboarding_completed_at'], first['onboarding_completed_at']);

    // Another device signing in observes the completed state, so the welcome
    // is never replayed.
    final other = await signInAgain(u.email);
    final seen = await other
        .from('church_memberships')
        .select('onboarding_completed_at')
        .single();
    expect(seen['onboarding_completed_at'], first['onboarding_completed_at']);
  });

  test('a PENDING member cannot complete onboarding', () async {
    final u = await createUser(fullName: 'Still Pending', tag: 'pend');
    addTearDown(() => deleteUser(u.userId));
    await seedMembership(church.churchId, u.userId, 'PENDING');

    await expectLater(
      u.client.rpc<List<dynamic>>('complete_onboarding'),
      throwsPostgrestCode('PT409'),
    );
  });

  test('a client cannot write the column directly', () async {
    final u = await createUser(fullName: 'Direct Completer', tag: 'dc');
    addTearDown(() => deleteUser(u.userId));
    await seedMembership(church.churchId, u.userId, 'ACTIVE');

    await u.client
        .from('church_memberships')
        .update({'onboarding_completed_at': '2020-01-01T00:00:00Z'})
        .eq('user_id', u.userId);
    final row = await service
        .from('church_memberships')
        .select('onboarding_completed_at')
        .eq('user_id', u.userId)
        .single();
    expect(row['onboarding_completed_at'], isNull);
  });

  test('anonymous callers are refused', () async {
    await expectLater(
      anonClient().rpc<List<dynamic>>('complete_onboarding'),
      throwsPostgrestCode('42501'),
    );
  });
}
