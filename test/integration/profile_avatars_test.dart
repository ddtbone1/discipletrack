/// Migration 021 against the real local stack: avatars are bundled preset
/// keys only, and fellow ACTIVE members of the church read them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestChurch church;
  late TestChurch other;
  late TestMember ana;
  late TestMember ben;
  final cleanup = <String>[];

  setUpAll(() async {
    church = await seedChurch(name: 'Avatar Church');
    other = await seedChurch(name: 'Other Avatar Church');
    ana = await createActiveMember(
      church.churchId,
      fullName: 'Ana Avatar',
      tag: 'av-ana',
    );
    ben = await createActiveMember(
      church.churchId,
      fullName: 'Ben Avatar',
      tag: 'av-ben',
    );
    cleanup.addAll([ana.user.userId, ben.user.userId]);
  });

  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final id in cleanup) {
      await deleteUser(id);
    }
    await deleteUser(church.approver.userId);
    await deleteChurch(other);
  });

  Future<void> setAvatar(TestMember m, String? avatar) => m.user.client
      .from('profiles')
      .update({'avatar_url': avatar})
      .eq('id', m.user.userId);

  Future<Map<String, String>> avatars(SupabaseClient c) async => {
    for (final r in (await c.rpc<List<dynamic>>(
      'get_church_avatars',
    )).cast<Map<String, dynamic>>())
      r['church_membership_id'] as String: r['avatar'] as String,
  };

  test('a member picks a preset; anything else is refused', () async {
    await setAvatar(ana, 'preset:3');
    for (final bad in ['preset:0', 'preset:13', 'https://x.test/a.png']) {
      await expectLater(
        setAvatar(ana, bad),
        throwsA(isA<PostgrestException>()),
        reason: bad,
      );
    }
    await setAvatar(ana, null);
    await setAvatar(ana, 'preset:12');
  });

  test('fellow members read the avatar; another church does not', () async {
    await setAvatar(ana, 'preset:5');
    expect((await avatars(ben.user.client))[ana.membershipId], 'preset:5');
    expect(
      (await avatars(other.approver.client)).containsKey(ana.membershipId),
      isFalse,
    );
    await expectLater(
      anonClient().rpc<List<dynamic>>('get_church_avatars'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
