/// Slice 8 against the real local stack: the platform Super Admin, church
/// provisioning and the Coordinator invariant (ADR-022). Every negative is a
/// refusal by PostgreSQL itself, not by the client.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestUser superAdmin;
  late TestChurch church;
  final cleanupUsers = <String>[];
  final cleanupChurches = <String>[];

  setUpAll(() async {
    superAdmin = await createSuperAdmin(tag: 'pr-super');
    church = await seedChurch(name: 'Platform Roles Church');
  });

  tearDownAll(() async {
    for (final id in cleanupChurches) {
      await deleteChurchRows(id);
    }
    await deleteChurch(church);
    for (final id in cleanupUsers) {
      await deleteUser(id);
    }
    await deleteUser(superAdmin.userId);
  });

  /// A confirmed user with no membership, to be made a Coordinator.
  Future<TestUser> account(String tag) async {
    final u = await createUser(fullName: 'Account $tag', tag: tag);
    cleanupUsers.add(u.userId);
    return u;
  }

  Future<Map<String, dynamic>> createChurch(String name, String email) async {
    final row = await rpcRow(superAdmin.client, 'create_church', {
      'p_name': name,
      'p_coordinator_email': email,
    });
    cleanupChurches.add(row['church_id'] as String);
    return row;
  }

  Future<List<Map<String, dynamic>>> activeCoordinators(String churchId) async {
    final rows = await service
        .from('church_role_assignments')
        .select('id, church_membership_id, church_memberships!inner(church_id)')
        .eq('role', 'COORDINATOR')
        .isFilter('ended_at', null)
        .eq('church_memberships.church_id', churchId);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> audits(
    String churchId,
    String action,
  ) async =>
      (await service
              .from('audit_events')
              .select('action, actor_user_id, metadata')
              .eq('church_id', churchId)
              .eq('action', action))
          .cast<Map<String, dynamic>>();

  Matcher refusedWith(String code, [String? message]) => throwsA(
    isA<PostgrestException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.message, 'message', message ?? anything),
  );

  group('the platform role cannot be gained from a client', () {
    test('a person reads only their own platform role', () async {
      final own = await superAdmin.client
          .from('platform_roles')
          .select('role, ended_at');
      expect(own.single['role'], 'SUPER_ADMIN');

      final other = await account('pr-other');
      expect(await other.client.from('platform_roles').select('id'), isEmpty);
    });

    test('no client can insert, update or delete platform_roles', () async {
      final u = await account('pr-escalate');
      await expectLater(
        u.client.from('platform_roles').insert({
          'user_id': u.userId,
          'role': 'SUPER_ADMIN',
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        superAdmin.client
            .from('platform_roles')
            .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', superAdmin.userId)
            .select(),
        throwsA(isA<PostgrestException>()),
      );
      await superAdmin.client
          .from('platform_roles')
          .delete()
          .eq('user_id', superAdmin.userId)
          .then((_) {}, onError: (_) {});
      final still = await service
          .from('platform_roles')
          .select('id')
          .eq('user_id', superAdmin.userId)
          .isFilter('ended_at', null);
      expect(still, hasLength(1));
    });

    test('profile fields, user metadata and RPC parameters grant nothing; '
        'the grant function is not reachable', () async {
      final created = await service.auth.admin.createUser(
        AdminUserAttributes(
          email: uniqueEmail('pr-meta'),
          password: password,
          emailConfirm: true,
          userMetadata: {
            'full_name': 'Metadata Person',
            'role': 'SUPER_ADMIN',
            'platform_role': 'SUPER_ADMIN',
          },
          appMetadata: {'role': 'SUPER_ADMIN'},
        ),
      );
      cleanupUsers.add(created.user!.id);
      final c = anonClient();
      await c.auth.signInWithPassword(
        email: created.user!.email!,
        password: password,
      );

      await expectLater(
        c.rpc<List<dynamic>>('list_churches'),
        refusedWith('PT403'),
      );
      await expectLater(
        c.rpc<dynamic>(
          'grant_platform_role',
          params: {'p_user_id': created.user!.id},
        ),
        throwsA(isA<PostgrestException>()),
      );
      final denied = await sqlError(
        "set role authenticated; select private.grant_platform_role('${created.user!.id}')",
      );
      expect(denied, contains('permission denied'));
    });
  });

  group('create_church', () {
    test('a Super Admin creates a church with its Coordinator in one '
        'transaction, written church first (the invariant is checked at '
        'commit)', () async {
      final coord = await account('pr-create');
      final row = await createChurch('Created Church', coord.email);
      final churchId = row['church_id'] as String;
      expect(row['join_code'], matches(RegExp(r'^[A-HJ-NP-Z2-9]{10}$')));

      final c = await service
          .from('churches')
          .select('status')
          .eq('id', churchId)
          .single();
      expect(c['status'], 'ACTIVE');

      final m = await service
          .from('church_memberships')
          .select('status, approved_by, onboarding_completed_at')
          .eq('id', row['coordinator_membership_id'] as String)
          .single();
      expect(m['status'], 'ACTIVE');
      expect(m['approved_by'], isNull, reason: 'provisioned, not approved');
      expect(m['onboarding_completed_at'], isNotNull, reason: 'no Welcome');

      expect(await activeCoordinators(churchId), hasLength(1));
      final lessons = await service
          .from('curriculum_lessons')
          .select('id, curricula!inner(church_id)')
          .eq('curricula.church_id', churchId);
      expect(lessons, hasLength(10));
      expect(await audits(churchId, 'CHURCH_CREATED'), hasLength(1));
      expect(await audits(churchId, 'COORDINATOR_ASSIGNED'), hasLength(1));

      // The new Coordinator acts in their church at once.
      final code = await rpcRow(coord.client, 'get_church_join_code', {
        'p_church_id': churchId,
      });
      expect(code['join_code'], row['join_code']);
    });

    test('only a Super Admin may create a church', () async {
      final coord = await account('pr-create-forb');
      for (final c in [church.approver.client]) {
        await expectLater(
          c.rpc<List<dynamic>>(
            'create_church',
            params: {'p_name': 'Nope', 'p_coordinator_email': coord.email},
          ),
          refusedWith('PT403'),
        );
      }
      await expectLater(
        anonClient().rpc<List<dynamic>>(
          'create_church',
          params: {'p_name': 'Nope', 'p_coordinator_email': coord.email},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'refuses an unknown, unconfirmed or already-placed account, the '
      'Super Admin themselves and a blank name, and writes nothing',
      () async {
        // Counted by name: other test files create and delete churches in
        // parallel, so a global count is not stable.
        Future<int> refusedChurches() async =>
            (await service
                    .from('churches')
                    .select('id')
                    .eq('name', 'Refused Church'))
                .length;
        final before = await refusedChurches();

        Future<void> refused(String email, String code, String message) =>
            expectLater(
              superAdmin.client.rpc<List<dynamic>>(
                'create_church',
                params: {
                  'p_name': 'Refused Church',
                  'p_coordinator_email': email,
                },
              ),
              refusedWith(code, message),
            );

        await refused(
          'nobody-${DateTime.now().microsecondsSinceEpoch}@x.test',
          'PT404',
          'account_not_found',
        );

        final unconfirmed = await service.auth.admin.createUser(
          AdminUserAttributes(
            email: uniqueEmail('pr-unconf'),
            password: password,
            userMetadata: {'full_name': 'Unconfirmed'},
          ),
        );
        cleanupUsers.add(unconfirmed.user!.id);
        await refused(unconfirmed.user!.email!, 'PT409', 'email_not_confirmed');

        await refused(
          church.approver.email,
          'PT409',
          'member_of_another_church',
        );
        await refused(superAdmin.email, 'PT403', 'cannot_assign_self');

        final coord = await account('pr-blank');
        await expectLater(
          superAdmin.client.rpc<List<dynamic>>(
            'create_church',
            params: {'p_name': '  ', 'p_coordinator_email': coord.email},
          ),
          refusedWith('PT400', 'church_name_required'),
        );

        expect(await refusedChurches(), before);
        expect(before, 0);
      },
    );

    test('the confirm step names the account and where it belongs, and is '
        'for the Super Admin only', () async {
      final coord = await account('pr-preview');
      final none = await rpcRow(
        superAdmin.client,
        'preview_coordinator_account',
        {'p_church_id': church.churchId, 'p_email': coord.email.toUpperCase()},
      );
      expect(none['account_found'], isTrue);
      expect(none['full_name'], 'Account pr-preview');
      expect(none['membership'], 'NONE');

      final mine = await rpcRow(
        superAdmin.client,
        'preview_coordinator_account',
        {'p_church_id': church.churchId, 'p_email': church.approver.email},
      );
      expect(mine['membership'], 'THIS_CHURCH');
      expect(mine['is_coordinator'], isTrue);

      final missing = await rpcRow(
        superAdmin.client,
        'preview_coordinator_account',
        {'p_church_id': church.churchId, 'p_email': 'missing@x.test'},
      );
      expect(missing['account_found'], isFalse);
      expect(missing['full_name'], isNull);

      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'preview_coordinator_account',
          params: {'p_church_id': church.churchId, 'p_email': coord.email},
        ),
        refusedWith('PT403'),
      );
    });
  });

  group('Coordinators', () {
    test('assign adds one, reactivating a membership; replace swaps in one '
        'transaction; end refuses the last', () async {
      final first = await account('pr-c1');
      final created = await createChurch('Coordinator Church', first.email);
      final churchId = created['church_id'] as String;

      // A former member, INACTIVE, becomes a Coordinator again.
      final second = await account('pr-c2');
      final inactiveId = await seedMembership(
        churchId,
        second.userId,
        'INACTIVE',
      );
      final assigned = await rpcRow(
        superAdmin.client,
        'assign_church_coordinator',
        {'p_church_id': churchId, 'p_email': second.email},
      );
      expect(assigned['membership_id'], inactiveId);
      expect(assigned['prior_status'], 'INACTIVE');
      expect(await activeCoordinators(churchId), hasLength(2));

      await expectLater(
        superAdmin.client.rpc<List<dynamic>>(
          'assign_church_coordinator',
          params: {'p_church_id': churchId, 'p_email': second.email},
        ),
        refusedWith('PT409', 'already_coordinator'),
      );

      // End one of two.
      await rpcRow(superAdmin.client, 'end_church_coordinator', {
        'p_church_id': churchId,
        'p_membership_id': inactiveId,
      });
      expect(await activeCoordinators(churchId), hasLength(1));

      // Never the last.
      await expectLater(
        superAdmin.client.rpc<List<dynamic>>(
          'end_church_coordinator',
          params: {
            'p_church_id': churchId,
            'p_membership_id': created['coordinator_membership_id'],
          },
        ),
        refusedWith('PT409', 'last_coordinator'),
      );

      // Replace the only one: exactly one active afterwards, the replaced
      // person stays an ACTIVE member.
      final third = await account('pr-c3');
      final replaced = await rpcRow(
        superAdmin.client,
        'replace_church_coordinator',
        {
          'p_church_id': churchId,
          'p_current_membership_id': created['coordinator_membership_id'],
          'p_email': third.email,
        },
      );
      final now = await activeCoordinators(churchId);
      expect(now, hasLength(1));
      expect(now.single['church_membership_id'], replaced['membership_id']);
      final old = await service
          .from('church_memberships')
          .select('status')
          .eq('id', created['coordinator_membership_id'] as String)
          .single();
      expect(old['status'], 'ACTIVE');
      expect(await audits(churchId, 'COORDINATOR_REPLACED'), hasLength(1));
      expect(await audits(churchId, 'COORDINATOR_ENDED'), hasLength(1));

      // A Coordinator cannot manage Coordinators.
      await expectLater(
        third.client.rpc<List<dynamic>>(
          'assign_church_coordinator',
          params: {'p_church_id': churchId, 'p_email': first.email},
        ),
        refusedWith('PT403'),
      );
    });

    test('a Super Admin cannot make themselves Coordinator', () async {
      await expectLater(
        superAdmin.client.rpc<List<dynamic>>(
          'assign_church_coordinator',
          params: {'p_church_id': church.churchId, 'p_email': superAdmin.email},
        ),
        refusedWith('PT403', 'cannot_assign_self'),
      );
    });

    test(
      'the last Coordinator of a SUSPENDED church cannot be ended either',
      () async {
        final only = await account('pr-susp');
        final created = await createChurch('Suspended Coordinator', only.email);
        final churchId = created['church_id'] as String;
        await rpcRow(superAdmin.client, 'set_church_status', {
          'p_church_id': churchId,
          'p_status': 'SUSPENDED',
        });
        await expectLater(
          superAdmin.client.rpc<List<dynamic>>(
            'end_church_coordinator',
            params: {
              'p_church_id': churchId,
              'p_membership_id': created['coordinator_membership_id'],
            },
          ),
          refusedWith('PT409', 'last_coordinator'),
        );
      },
    );
  });

  group('the Coordinator invariant, checked at commit', () {
    test('a trusted direct write cannot commit an ACTIVE church without an '
        'active Coordinator, and leaves nothing behind', () async {
      final name = 'Lone Church ${DateTime.now().microsecondsSinceEpoch}';
      await expectLater(
        service.from('churches').insert({
          'name': name,
          'join_code': randomJoinCode(),
        }),
        refusedWith('23514', 'church_requires_coordinator'),
      );
      expect(
        await service.from('churches').select('id').eq('name', name),
        isEmpty,
      );
    });

    test('ending the only role, deactivating the only Coordinator, or '
        'activating a church without one is rejected', () async {
      final only = await account('pr-inv');
      final created = await createChurch('Invariant Church', only.email);
      final churchId = created['church_id'] as String;
      final membershipId = created['coordinator_membership_id'] as String;
      final role = (await activeCoordinators(churchId)).single['id'] as String;

      await expectLater(
        service
            .from('church_role_assignments')
            .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', role),
        refusedWith('23514', 'church_requires_coordinator'),
      );
      await expectLater(
        service
            .from('church_memberships')
            .update({'status': 'INACTIVE'})
            .eq('id', membershipId),
        refusedWith('23514', 'church_requires_coordinator'),
      );
      await expectLater(
        service.from('church_role_assignments').delete().eq('id', role),
        refusedWith('23514', 'church_requires_coordinator'),
      );
      expect(await activeCoordinators(churchId), hasLength(1));

      // Suspended, the role may be ended by trusted tooling; activating the
      // church then fails, through the operation and directly.
      await rpcRow(superAdmin.client, 'set_church_status', {
        'p_church_id': churchId,
        'p_status': 'SUSPENDED',
      });
      await service
          .from('church_role_assignments')
          .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', role);
      await expectLater(
        superAdmin.client.rpc<List<dynamic>>(
          'set_church_status',
          params: {'p_church_id': churchId, 'p_status': 'ACTIVE'},
        ),
        refusedWith('PT409', 'coordinator_required'),
      );
      await expectLater(
        service
            .from('churches')
            .update({'status': 'ACTIVE'})
            .eq('id', churchId),
        refusedWith('23514', 'church_requires_coordinator'),
      );
      final c = await service
          .from('churches')
          .select('status')
          .eq('id', churchId)
          .single();
      expect(c['status'], 'SUSPENDED');
    });

    test('church status changes only as allowed; ARCHIVED is final', () async {
      final only = await account('pr-status');
      final created = await createChurch('Status Church', only.email);
      final churchId = created['church_id'] as String;

      Future<void> setStatus(String s) => rpcRow(
        superAdmin.client,
        'set_church_status',
        {'p_church_id': churchId, 'p_status': s},
      );

      await expectLater(
        setStatus('ACTIVE'),
        refusedWith('PT409', 'status_unchanged'),
      );
      await setStatus('SUSPENDED');
      await setStatus('ACTIVE');
      await setStatus('ARCHIVED');
      await expectLater(
        setStatus('ACTIVE'),
        refusedWith('PT409', 'church_archived'),
      );
      await expectLater(
        service
            .from('churches')
            .update({'status': 'ACTIVE'})
            .eq('id', churchId),
        refusedWith('23514', 'church_status_transition_not_allowed'),
      );
      expect(
        (await audits(
          churchId,
          'CHURCH_STATUS_CHANGED',
        )).map((e) => (e['metadata'] as Map)['to']).toSet(),
        {'SUSPENDED', 'ACTIVE', 'ARCHIVED'},
      );
      await expectLater(
        church.approver.client.rpc<List<dynamic>>(
          'set_church_status',
          params: {'p_church_id': church.churchId, 'p_status': 'SUSPENDED'},
        ),
        refusedWith('PT403'),
      );
    });
  });

  group('concurrency', () {
    test('two concurrent ends of the two Coordinators never leave none '
        '(operations serialise on the church row)', () async {
      final a = await account('pr-ca');
      final created = await createChurch('Concurrent Church', a.email);
      final churchId = created['church_id'] as String;
      final b = await account('pr-cb');
      final bMembership =
          (await rpcRow(superAdmin.client, 'assign_church_coordinator', {
                'p_church_id': churchId,
                'p_email': b.email,
              }))['membership_id']
              as String;
      final aMembership = created['coordinator_membership_id'] as String;
      final second = await signInAgain(superAdmin.email);

      for (var round = 0; round < 10; round++) {
        final results = await Future.wait([
          superAdmin.client
              .rpc<List<dynamic>>(
                'end_church_coordinator',
                params: {
                  'p_church_id': churchId,
                  'p_membership_id': aMembership,
                },
              )
              .then<Object?>((_) => null, onError: (Object e) => e),
          second
              .rpc<List<dynamic>>(
                'end_church_coordinator',
                params: {
                  'p_church_id': churchId,
                  'p_membership_id': bMembership,
                },
              )
              .then<Object?>((_) => null, onError: (Object e) => e),
        ]);
        final failures = results.whereType<PostgrestException>().toList();
        expect(failures, hasLength(1), reason: 'round $round');
        expect(failures.single.message, 'last_coordinator');
        expect(await activeCoordinators(churchId), hasLength(1));

        // Restore the ended one for the next round.
        final ended = results.first == null ? a : b;
        await rpcRow(superAdmin.client, 'assign_church_coordinator', {
          'p_church_id': churchId,
          'p_email': ended.email,
        });
        expect(await activeCoordinators(churchId), hasLength(2));
      }
    });

    test('write skew is prevented by the trigger itself: a second transaction '
        'that ends the other Coordinator waits for the first and is rejected', () async {
      final a = await account('pr-wa');
      final created = await createChurch('Write Skew Church', a.email);
      final churchId = created['church_id'] as String;
      final b = await account('pr-wb');
      await rpcRow(superAdmin.client, 'assign_church_coordinator', {
        'p_church_id': churchId,
        'p_email': b.email,
      });
      final roles = await activeCoordinators(churchId);
      expect(roles, hasLength(2));
      final roleA = roles[0]['id'] as String;
      final roleB = roles[1]['id'] as String;

      // IMMEDIATE runs the check at the end of each UPDATE instead of at
      // commit, so the first session holds the church row lock while it
      // sleeps. Without the lock, the second session would count the first
      // Coordinator as still active (uncommitted) and both would commit.
      Future<ProcessResult> session(String sql) => Process.run('docker', [
        'exec',
        dbContainer,
        'psql',
        '-U',
        'postgres',
        '-v',
        'ON_ERROR_STOP=1',
        '-tA',
        '-c',
        sql,
      ]);
      final first = session(
        'begin; set constraints all immediate; '
        "update public.church_role_assignments set ended_at = now() where id = '$roleA'; "
        'select pg_sleep(2); commit;',
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final secondRun = session(
        'begin; set constraints all immediate; '
        "update public.church_role_assignments set ended_at = now() where id = '$roleB'; "
        'commit;',
      );
      final r1 = await first;
      final r2 = await secondRun;

      expect(r1.exitCode, 0, reason: '${r1.stderr}');
      expect(r2.exitCode, isNot(0));
      expect(r2.stderr as String, contains('church_requires_coordinator'));
      final left = await activeCoordinators(churchId);
      expect(left.single['id'], roleB);
    });
  });

  group('join codes', () {
    test(
      'regeneration: the old code stops working at once, the new one '
      'works, a pending request stays pending, and no code is audited',
      () async {
        final coord = await account('pr-code');
        final created = await createChurch('Join Code Church', coord.email);
        final churchId = created['church_id'] as String;
        final oldCode = created['join_code'] as String;

        final early = await account('pr-early');
        final req = await rpcRow(early.client, 'request_join_church', {
          'p_church_id': churchId,
          'p_join_code': oldCode,
        });
        expect(req['outcome'], 'REQUESTED');

        final regen = await rpcRow(superAdmin.client, 'regenerate_join_code', {
          'p_church_id': churchId,
        });
        final newCode = regen['join_code'] as String;
        expect(newCode, isNot(oldCode));

        final late1 = await account('pr-late1');
        expect(
          await late1.client.rpc<List<dynamic>>(
            'lookup_church_by_join_code',
            params: {'p_code': oldCode},
          ),
          isEmpty,
        );
        final refused = await rpcRow(late1.client, 'request_join_church', {
          'p_church_id': churchId,
          'p_join_code': oldCode,
        });
        expect(refused['outcome'], 'INVALID_CODE');

        final late2 = await account('pr-late2');
        final ok = await rpcRow(late2.client, 'request_join_church', {
          'p_church_id': churchId,
          'p_join_code': newCode,
        });
        expect(ok['outcome'], 'REQUESTED');

        final pending = await service
            .from('church_memberships')
            .select('status')
            .eq('user_id', early.userId)
            .single();
        expect(pending['status'], 'PENDING');

        final events = await audits(churchId, 'JOIN_CODE_REGENERATED');
        expect(events, hasLength(1));
        expect(events.single['metadata'].toString(), isNot(contains(oldCode)));
        expect(events.single['metadata'].toString(), isNot(contains(newCode)));

        await expectLater(
          coord.client.rpc<List<dynamic>>(
            'regenerate_join_code',
            params: {'p_church_id': churchId},
          ),
          refusedWith('PT403'),
        );

        // The Coordinator reads the new code, read-only.
        final read = await rpcRow(coord.client, 'get_church_join_code', {
          'p_church_id': churchId,
        });
        expect(read['join_code'], newCode);
      },
    );

    test('only the church\'s active Coordinator reads its code, only while '
        'it is ACTIVE, and no client reads or writes the column', () async {
      final g = await createGroupWithLeader(church, tag: 'pr-code-lead');
      cleanupUsers.add(g.leader.user.userId);
      final member = await createActiveMember(
        church.churchId,
        fullName: 'Code Member',
        tag: 'pr-code-mem',
      );
      cleanupUsers.add(member.user.userId);
      final pending = await account('pr-code-pend');
      await seedMembership(church.churchId, pending.userId, 'PENDING');
      final otherCoord = await account('pr-code-other');
      await createChurch('Other Code Church', otherCoord.email);

      final code = await rpcRow(
        church.approver.client,
        'get_church_join_code',
        {'p_church_id': church.churchId},
      );
      expect(code['join_code'], church.joinCode);

      for (final c in [
        g.leader.user.client,
        member.user.client,
        pending.client,
        otherCoord.client,
        superAdmin.client,
      ]) {
        await expectLater(
          c.rpc<List<dynamic>>(
            'get_church_join_code',
            params: {'p_church_id': church.churchId},
          ),
          refusedWith('PT403'),
        );
      }
      await expectLater(
        church.approver.client
            .from('churches')
            .select('join_code')
            .eq('id', church.churchId),
        throwsA(isA<PostgrestException>()),
      );
      await church.approver.client
          .from('churches')
          .update({'join_code': randomJoinCode()})
          .eq('id', church.churchId)
          .then((_) {}, onError: (_) {});
      final unchanged = await service
          .from('churches')
          .select('join_code')
          .eq('id', church.churchId)
          .single();
      expect(unchanged['join_code'], church.joinCode);

      await rpcRow(superAdmin.client, 'set_church_status', {
        'p_church_id': church.churchId,
        'p_status': 'SUSPENDED',
      });
      try {
        await expectLater(
          church.approver.client.rpc<List<dynamic>>(
            'get_church_join_code',
            params: {'p_church_id': church.churchId},
          ),
          refusedWith('PT403'),
        );
      } finally {
        await rpcRow(superAdmin.client, 'set_church_status', {
          'p_church_id': church.churchId,
          'p_status': 'ACTIVE',
        });
      }
    });
  });

  group('one church per person', () {
    test('a member of one church cannot request another, and the database '
        'refuses a second membership', () async {
      final coord = await account('pr-one');
      final created = await createChurch('Second Church', coord.email);
      final member = await createActiveMember(
        church.churchId,
        fullName: 'One Church Member',
        tag: 'pr-one-mem',
      );
      cleanupUsers.add(member.user.userId);

      final outcome = await rpcRow(member.user.client, 'request_join_church', {
        'p_church_id': created['church_id'],
        'p_join_code': created['join_code'],
      });
      expect(outcome['outcome'], 'IN_ANOTHER_CHURCH');

      await expectLater(
        service.from('church_memberships').insert({
          'church_id': created['church_id'],
          'user_id': member.user.userId,
          'status': 'PENDING',
        }),
        refusedWith('23505'),
      );
    });
  });

  group('the Super Admin sees no ministry data', () {
    test('no memberships, profiles, groups, meetings, progress, curriculum '
        'or lessons; no approval', () async {
      final g = await createGroupWithLeader(church, tag: 'pr-iso-lead');
      cleanupUsers.add(g.leader.user.userId);
      final applicant = await account('pr-iso-app');
      final pendingId = await seedMembership(
        church.churchId,
        applicant.userId,
        'PENDING',
      );
      final c = superAdmin.client;

      for (final table in [
        'church_memberships',
        'church_role_assignments',
        'd_groups',
        'd_group_memberships',
        'd_group_placements',
        'discipler_assignments',
        'discipleship_meetings',
        'discipleship_meeting_participants',
        'disciple_lesson_progress',
        'ministry_role_transitions',
        'curricula',
        'curriculum_lessons',
      ]) {
        expect(await c.from(table).select('id'), isEmpty, reason: table);
      }
      expect(
        await c.from('profiles').select('id').neq('id', superAdmin.userId),
        isEmpty,
      );
      expect(await c.from('churches').select('id'), isEmpty);

      await expectLater(
        c.rpc<List<dynamic>>(
          'approve_church_membership',
          params: {'p_membership_id': pendingId},
        ),
        refusedWith('PT403'),
      );
      await expectLater(
        c.rpc<List<dynamic>>('list_lesson_access'),
        refusedWith('PT403'),
      );
      expect(await c.rpc<List<dynamic>>('get_my_readable_content'), isEmpty);
      expect(await c.rpc<List<dynamic>>('get_lesson_covers'), isEmpty);
      expect(await c.rpc<List<dynamic>>('get_my_d_group_roster'), isEmpty);
      expect(await c.rpc<List<dynamic>>('list_disciple_progress'), isEmpty);
    });

    test('the platform overview carries counts and Coordinators only; the '
        'platform audit carries platform events only', () async {
      final rows = (await superAdmin.client.rpc<List<dynamic>>('list_churches'))
          .cast<Map<String, dynamic>>();
      final mine = rows.singleWhere((r) => r['church_id'] == church.churchId);
      expect(mine.keys.toSet(), {
        'church_id',
        'name',
        'status',
        'join_code',
        'join_code_updated_at',
        'created_at',
        'members_active',
        'members_pending',
        'members_other',
        'd_groups',
        'coordinators',
      });
      expect(mine['join_code'], church.joinCode);
      final coordinators = (mine['coordinators'] as List)
          .cast<Map<String, dynamic>>();
      expect(coordinators.single.keys.toSet(), {
        'membership_id',
        'full_name',
        'email',
      });
      expect(coordinators.single['email'], church.approver.email);

      final events = (await superAdmin.client.rpc<List<dynamic>>(
        'list_platform_audit',
        params: {'p_limit': 200},
      )).cast<Map<String, dynamic>>();
      const platform = {
        'PLATFORM_ROLE_GRANTED',
        'PLATFORM_ROLE_ENDED',
        'CHURCH_CREATED',
        'JOIN_CODE_REGENERATED',
        'COORDINATOR_ASSIGNED',
        'COORDINATOR_REPLACED',
        'COORDINATOR_ENDED',
        'CHURCH_STATUS_CHANGED',
        'CHURCH_ROLE_ENDED',
      };
      expect(events, isNotEmpty);
      expect(events.every((e) => platform.contains(e['action'])), isTrue);

      for (final c in [church.approver.client, anonClient()]) {
        await expectLater(
          c.rpc<List<dynamic>>('list_churches'),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          c.rpc<List<dynamic>>('list_platform_audit'),
          throwsA(isA<PostgrestException>()),
        );
      }
    });
  });
}
