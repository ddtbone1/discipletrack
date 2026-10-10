/// Slice 8 against the real local stack: what a SUSPENDED or ARCHIVED church
/// means (ADR-022 decisions 13 to 15). Members keep their account and their
/// own profile; nobody, the Coordinator included, reads or writes church
/// data; reactivation restores every read exactly.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/discipleship_fixture.dart';
import 'support/ministry_fixture.dart';
import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  late TestUser superAdmin;
  late TestChurch church;
  late TestCurriculum curriculum;
  late TestGroup g;
  late PairedDisciple p;
  late TestMember plain;
  late TestMember notOnboarded;
  late TestUser pending;
  late String pendingId;
  late String meetingId;
  late String participantId;
  late String placementId;
  final cleanup = <String>[];

  Map<String, dynamic> definition() => {
    'lessons': [
      for (var n = 1; n <= 10; n++)
        {
          'number': n,
          'title': 'Lesson $n',
          'blocks': [
            {
              'type': 'LESSON_THEME',
              'tier': 'DISCIPLE',
              'body': {'text': 'Theme $n'},
            },
            {
              'type': 'FILL_IN',
              'tier': 'DISCIPLE',
              'section': 'A',
              'body': {'text': 'God ___ the world.'},
              'answers': [
                ['loves'],
              ],
            },
            {
              'type': 'MODULE_HEADING',
              'tier': 'DISCIPLER',
              'body': {'number': n, 'title': 'Module $n'},
            },
          ],
        },
    ],
  };

  Future<void> setStatus(String churchId, String status) => rpcRow(
    superAdmin.client,
    'set_church_status',
    {'p_church_id': churchId, 'p_status': status},
  );

  setUpAll(() async {
    superAdmin = await createSuperAdmin(tag: 'cs-super');
    church = await seedChurch(name: 'Church Status Church');
    curriculum = await seedCurriculum(church.churchId);
    await service.rpc<List<dynamic>>(
      'publish_curriculum',
      params: {
        'p_church_id': church.churchId,
        'p_definition': definition(),
        'p_content_level': 'FULL',
        'p_licence_reference': 'TEST-LICENCE-CS',
        'p_published_by': church.approver.userId,
      },
    );
    g = await createGroupWithLeader(church, tag: 'cs-lead');
    p = await placePairedDisciple(
      church,
      g,
      since: DateTime.now().subtract(const Duration(days: 20)),
      tag: 'cs',
    );
    meetingId = await recordMeeting(
      p.discipler.user.client,
      disciplerDgmId: p.disciplerDgmId,
      lessonId: curriculum.lessonIds.first,
      outcomes: {p.disciple.membershipId: 'PRESENT'},
      occurredAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    participantId =
        (await service
                .from('discipleship_meeting_participants')
                .select('id')
                .eq('meeting_id', meetingId)
                .single())['id']
            as String;
    plain = await createActiveMember(
      church.churchId,
      fullName: 'CS Plain',
      tag: 'cs-plain',
    );
    placementId = (await addMembers(g.leader.user.client, g.groupId, [
      plain.membershipId,
    ]))[plain.membershipId]!;
    final u = await createUser(fullName: 'CS Not Onboarded', tag: 'cs-new');
    notOnboarded = (
      user: u,
      membershipId: await seedMembership(church.churchId, u.userId, 'ACTIVE'),
    );
    pending = await createUser(fullName: 'CS Pending', tag: 'cs-pend');
    pendingId = await seedMembership(
      church.churchId,
      pending.userId,
      'PENDING',
    );
    cleanup.addAll([
      g.leader.user.userId,
      p.disciple.user.userId,
      p.discipler.user.userId,
      plain.user.userId,
      notOnboarded.user.userId,
      pending.userId,
    ]);
  });

  tearDownAll(() async {
    await deleteChurchRows(church.churchId);
    for (final id in cleanup) {
      await deleteUser(id);
    }
    await deleteUser(church.approver.userId);
    await deleteUser(superAdmin.userId);
  });

  /// What [c] can read of the church, as comparable text: table rows and
  /// read-operation results, or the refusal code.
  Future<String> snapshot(SupabaseClient c) async {
    Future<Object?> attempt(Future<Object?> Function() f) async {
      try {
        return await f();
      } on PostgrestException catch (e) {
        return 'refused ${e.code}';
      }
    }

    final out = <String, Object?>{};
    for (final table in [
      'church_memberships',
      'd_groups',
      'd_group_memberships',
      'd_group_placements',
      'discipler_assignments',
      'discipleship_meetings',
      'discipleship_meeting_participants',
      'disciple_lesson_progress',
      'curricula',
      'curriculum_lessons',
    ]) {
      out[table] = await attempt(() => c.from(table).select('id').order('id'));
    }
    for (final fn in [
      'get_my_d_group_roster',
      'list_disciple_progress',
      'get_church_avatars',
      'list_lesson_access',
    ]) {
      out[fn] = await attempt(() => c.rpc<dynamic>(fn));
    }
    out['readable'] = await attempt(
      () async =>
          (await c.rpc<List<dynamic>>('get_my_readable_content'))
              .map((r) => (r as Map)['block_id'])
              .toList()
            ..sort((a, b) => '$a'.compareTo('$b')),
    );
    out['journey'] = await attempt(
      () => c.rpc<dynamic>(
        'get_disciple_journey',
        params: {'p_membership_id': p.disciple.membershipId},
      ),
    );
    out['setup'] = await attempt(
      () => c.rpc<dynamic>(
        'get_initial_setup_status',
        params: {'p_church_id': church.churchId},
      ),
    );
    return jsonEncode(out);
  }

  /// Refused, empty, or rows that carry no value at all (for example
  /// get_progress_summary()'s single null row for a non-Coordinator).
  bool blocked(Object? result) =>
      result == null ||
      (result is String && result.startsWith('refused')) ||
      (result is List &&
          result.every((r) => r is Map && r.values.every((v) => v == null)));

  group('the status lookup the app uses (ADR-022 decision 14)', () {
    test('while SUSPENDED and while ARCHIVED, an ACTIVE or PENDING member '
        'resolves their own church\'s id, name and status and their own '
        'membership row, and nothing else of the church', () async {
      final coord = await createUser(fullName: 'CS Lookup Coord', tag: 'cs-lk');
      cleanup.add(coord.userId);
      final created = await rpcRow(superAdmin.client, 'create_church', {
        'p_name': 'Lookup Church',
        'p_coordinator_email': coord.email,
      });
      final churchId = created['church_id'] as String;
      addTearDown(() => deleteChurchRows(churchId));
      final member = await createActiveMember(
        churchId,
        fullName: 'CS Lookup Member',
        tag: 'cs-lk-mem',
      );
      cleanup.add(member.user.userId);
      final applicant = await createUser(
        fullName: 'CS Lookup Pend',
        tag: 'cs-lk-p',
      );
      cleanup.add(applicant.userId);
      await seedMembership(churchId, applicant.userId, 'PENDING');
      final gone = await createUser(fullName: 'CS Lookup Gone', tag: 'cs-lk-g');
      cleanup.add(gone.userId);
      await seedMembership(churchId, gone.userId, 'INACTIVE');

      for (final status in ['SUSPENDED', 'ARCHIVED']) {
        await setStatus(churchId, status);
        for (final (who, c, userId) in [
          ('coordinator', coord.client, coord.userId),
          ('member', member.user.client, member.user.userId),
          ('pending', applicant.client, applicant.userId),
        ]) {
          final why = '$status, $who';
          final row = await c
              .from('churches')
              .select('id, name, status')
              .single();
          expect(row, {
            'id': churchId,
            'name': 'Lookup Church',
            'status': status,
          }, reason: why);

          // The join code stays closed: by column and by select=*.
          await expectLater(
            c.from('churches').select('join_code'),
            throwsA(isA<PostgrestException>()),
            reason: why,
          );
          await expectLater(
            c.from('churches').select(),
            throwsA(isA<PostgrestException>()),
            reason: why,
          );

          // Their own membership row only; no other member, profile or role.
          final memberships = await c
              .from('church_memberships')
              .select('user_id, status');
          expect(memberships, hasLength(1), reason: why);
          expect(memberships.single['user_id'], userId, reason: why);
          final profiles = await c.from('profiles').select('id');
          expect(profiles.map((p) => p['id']), [userId], reason: why);
          final roles = await c
              .from('church_role_assignments')
              .select(
                'church_membership_id, church_memberships!inner(user_id)',
              );
          expect(
            roles.every(
              (r) => (r['church_memberships'] as Map)['user_id'] == userId,
            ),
            isTrue,
            reason: why,
          );
          for (final table in ['curricula', 'curriculum_lessons', 'd_groups']) {
            expect(
              await c.from(table).select('id'),
              isEmpty,
              reason: '$why, $table',
            );
          }
        }

        // An INACTIVE membership sees no church at all, as before Slice 8.
        expect(await gone.client.from('churches').select('id'), isEmpty);
        if (status == 'SUSPENDED') await setStatus(churchId, 'ACTIVE');
      }
    });
  });

  group('a SUSPENDED church', () {
    test('every role keeps sign-in, their profile, their own membership row '
        'and the church\'s name and status, and reads nothing else; '
        'reactivation restores every read exactly', () async {
      final people = <String, SupabaseClient>{
        'coordinator': church.approver.client,
        'leader': g.leader.user.client,
        'discipler': p.discipler.user.client,
        'disciple': p.disciple.user.client,
        'member': plain.user.client,
      };
      final before = {
        for (final e in people.entries) e.key: await snapshot(e.value),
      };
      expect(
        jsonDecode(before['coordinator']!)['d_groups'],
        isNotEmpty,
        reason: 'the comparison must cover real data',
      );

      await setStatus(church.churchId, 'SUSPENDED');
      try {
        for (final e in people.entries) {
          final c = e.value;
          final now = jsonDecode(await snapshot(c)) as Map<String, dynamic>;
          for (final key in now.keys) {
            if (key == 'church_memberships') {
              expect(now[key], hasLength(1), reason: '${e.key}: own row only');
              continue;
            }
            expect(blocked(now[key]), isTrue, reason: '${e.key}: $key');
          }
          final churchRow = await c
              .from('churches')
              .select('id, name, status')
              .single();
          expect(churchRow['status'], 'SUSPENDED', reason: e.key);
          final own = await c.from('profiles').select('full_name');
          expect(own, hasLength(1), reason: '${e.key}: own profile only');
        }

        // Authentication is platform-level: sign-in works, and the own
        // profile can still be edited.
        final again = await signInAgain(p.disciple.user.email);
        expect(again.auth.currentUser?.id, p.disciple.user.userId);
        await p.disciple.user.client
            .from('profiles')
            .update({'phone': '+63 900 111 2222'})
            .eq('id', p.disciple.user.userId);
        final edited = await service
            .from('profiles')
            .select('phone')
            .eq('id', p.disciple.user.userId)
            .single();
        expect(edited['phone'], '+63 900 111 2222');
      } finally {
        await setStatus(church.churchId, 'ACTIVE');
      }

      await service
          .from('profiles')
          .update({'phone': null})
          .eq('id', p.disciple.user.userId);
      final after = {
        for (final e in people.entries) e.key: await snapshot(e.value),
      };
      expect(after, before, reason: 'reactivation restores everything');
    });

    test(
      'nobody acts: approval, groups, pairing, meetings, completion, '
      'onboarding and the join code are refused; pending stays pending',
      () async {
        await setStatus(church.churchId, 'SUSPENDED');
        try {
          Future<void> refused(Future<Object?> call, String what) =>
              expectLater(
                call,
                throwsA(isA<PostgrestException>()),
                reason: what,
              );

          final coordinator = church.approver.client;
          await refused(
            coordinator.rpc<dynamic>(
              'approve_church_membership',
              params: {'p_membership_id': pendingId},
            ),
            'approve',
          );
          await refused(
            coordinator.rpc<dynamic>(
              'reject_church_membership',
              params: {'p_membership_id': pendingId},
            ),
            'reject',
          );
          await refused(
            coordinator.rpc<dynamic>(
              'create_d_group',
              params: {
                'p_name': uniqueGroupName('CS'),
                'p_description': null,
                'p_leader_membership_id': notOnboarded.membershipId,
              },
            ),
            'create_d_group',
          );
          await refused(
            g.leader.user.client.rpc<dynamic>(
              'set_discipler',
              params: {
                'p_disciple_d_group_membership_id': p.discipleDgmId,
                'p_discipler_d_group_membership_id': null,
              },
            ),
            'unpair',
          );
          await refused(
            recordMeeting(
              p.discipler.user.client,
              disciplerDgmId: p.disciplerDgmId,
              lessonId: curriculum.lessonIds.first,
              outcomes: {p.disciple.membershipId: 'PRESENT'},
            ),
            'record meeting',
          );
          await refused(
            p.discipler.user.client.rpc<dynamic>(
              'complete_lesson',
              params: {
                'p_membership_id': p.disciple.membershipId,
                'p_lesson_id': curriculum.lessonIds.first,
              },
            ),
            'complete lesson',
          );
          await refused(
            notOnboarded.user.client.rpc<dynamic>('complete_onboarding'),
            'complete onboarding',
          );
          await refused(
            coordinator.rpc<dynamic>(
              'get_church_join_code',
              params: {'p_church_id': church.churchId},
            ),
            'join code',
          );

          final stillPending = await service
              .from('church_memberships')
              .select('status')
              .eq('id', pendingId)
              .single();
          expect(stillPending['status'], 'PENDING');
          final pendingView = await pending.client
              .from('churches')
              .select('status')
              .single();
          expect(pendingView['status'], 'SUSPENDED');

          // The join code finds nothing, and does not reveal the suspension.
          final stranger = await createUser(
            fullName: 'CS Stranger',
            tag: 'cs-str',
          );
          cleanup.add(stranger.userId);
          expect(
            await stranger.client.rpc<List<dynamic>>(
              'lookup_church_by_join_code',
              params: {'p_code': church.joinCode},
            ),
            isEmpty,
          );
          final outcome = await rpcRow(stranger.client, 'request_join_church', {
            'p_church_id': church.churchId,
            'p_join_code': church.joinCode,
          });
          expect(outcome['outcome'], 'INVALID_CODE');

          // The Super Admin still manages the church.
          final regen = await rpcRow(
            superAdmin.client,
            'regenerate_join_code',
            {'p_church_id': church.churchId},
          );
          await service
              .from('churches')
              .update({'join_code': church.joinCode})
              .eq('id', church.churchId);
          expect(regen['join_code'], isNot(church.joinCode));
        } finally {
          await setStatus(church.churchId, 'ACTIVE');
        }

        // Nothing was written while suspended.
        final groups = await service
            .from('d_groups')
            .select('id')
            .eq('church_id', church.churchId);
        expect(groups, hasLength(1));
        final m = await service
            .from('disciple_lesson_progress')
            .select('status')
            .eq('church_membership_id', p.disciple.membershipId)
            .eq('lesson_id', curriculum.lessonIds.first)
            .maybeSingle();
        expect(m?['status'], isNot('COMPLETED'));
      },
    );

    test(
      'registry: every client operation refuses or returns nothing to the '
      'suspended church\'s Coordinator, and every operation is classified',
      () async {
        final known = <String, Map<String, dynamic>>{
          // Church operations, with realistic arguments.
          'get_recording_options': {'p_membership_id': p.disciple.membershipId},
          'set_discipler': {
            'p_disciple_d_group_membership_id': p.discipleDgmId,
            'p_discipler_d_group_membership_id': p.disciplerDgmId,
          },
          'get_my_readable_content': {},
          'get_my_d_group_roster': {},
          'reject_church_membership': {'p_membership_id': pendingId},
          'list_group_progress': {'p_d_group_id': g.groupId},
          'get_church_avatars': {},
          'list_addable_members': {'p_d_group_id': g.groupId},
          'check_lesson_answers': {
            'p_lesson_id': curriculum.lessonIds.first,
            'p_responses': <String, dynamic>{},
          },
          'get_progress_summary': {},
          'get_meeting_history': {
            'p_membership_id': p.disciple.membershipId,
            'p_from': DateTime.now()
                .subtract(const Duration(days: 30))
                .toUtc()
                .toIso8601String(),
            'p_to': DateTime.now().toUtc().toIso8601String(),
          },
          'void_meeting_participant': {'p_participant_id': participantId},
          'reopen_lesson_completion': {
            'p_membership_id': p.disciple.membershipId,
            'p_lesson_id': curriculum.lessonIds.first,
          },
          'list_placeable_members': {
            'p_church_id': church.churchId,
            'p_d_group_id': g.groupId,
          },
          'get_disciple_meeting_summary': {
            'p_membership_id': p.disciple.membershipId,
          },
          'list_lesson_access': {
            'p_for_membership_id': p.disciple.membershipId,
          },
          'add_self_as_discipler': {'p_d_group_id': g.groupId},
          'add_members_to_d_group': {
            'p_d_group_id': g.groupId,
            'p_membership_ids': [notOnboarded.membershipId],
          },
          'remove_from_d_group': {'p_d_group_placement_id': placementId},
          'undo_lesson_completion': {
            'p_membership_id': p.disciple.membershipId,
            'p_lesson_id': curriculum.lessonIds.first,
          },
          'get_initial_setup_status': {'p_church_id': church.churchId},
          'get_church_join_code': {'p_church_id': church.churchId},
          'get_disciple_journey': {'p_membership_id': p.disciple.membershipId},
          'complete_onboarding': {},
          'get_lesson_content': {
            'p_lesson_id': curriculum.lessonIds.first,
            'p_for_membership_id': p.disciple.membershipId,
          },
          'list_discipler_candidates': {
            'p_church_id': church.churchId,
            'p_d_group_id': g.groupId,
          },
          'get_disciple_context': {'p_membership_id': p.disciple.membershipId},
          'assign_d_group_leader': {
            'p_d_group_id': g.groupId,
            'p_membership_id': notOnboarded.membershipId,
          },
          'list_disciple_progress': {},
          'create_d_group': {
            'p_name': uniqueGroupName('CS reg'),
            'p_description': null,
            'p_leader_membership_id': notOnboarded.membershipId,
          },
          'appoint_discipler': {'p_membership_id': p.disciple.membershipId},
          'get_lesson_covers': {},
          'record_discipleship_meeting': {
            'p_discipler_d_group_membership_id': p.disciplerDgmId,
            'p_lesson_id': curriculum.lessonIds.first,
            'p_occurred_at': DateTime.now().toUtc().toIso8601String(),
            'p_participants': [
              {
                'church_membership_id': p.disciple.membershipId,
                'attendance_status': 'PRESENT',
              },
            ],
            'p_notes': null,
          },
          'complete_lesson': {
            'p_membership_id': p.disciple.membershipId,
            'p_lesson_id': curriculum.lessonIds.first,
          },
          'approve_church_membership': {'p_membership_id': pendingId},
          'set_up_member': {
            'p_d_group_placement_id': placementId,
            'p_responsibility': 'DISCIPLE',
          },
          'void_discipleship_meeting': {'p_meeting_id': meetingId},
          'set_initial_setup_open': {
            'p_church_id': church.churchId,
            'p_open': false,
          },
          // Platform operations: the Super Admin only.
          'create_church': {'p_name': 'X', 'p_coordinator_email': 'x@x.test'},
          'set_church_status': {
            'p_church_id': church.churchId,
            'p_status': 'ACTIVE',
          },
          'assign_church_coordinator': {
            'p_church_id': church.churchId,
            'p_email': 'x@x.test',
          },
          'list_platform_audit': {},
          'regenerate_join_code': {'p_church_id': church.churchId},
          'replace_church_coordinator': {
            'p_church_id': church.churchId,
            'p_current_membership_id': church.approverMembershipId,
            'p_email': 'x@x.test',
          },
          'list_churches': {},
          'preview_coordinator_account': {
            'p_church_id': church.churchId,
            'p_email': 'x@x.test',
          },
          'end_church_coordinator': {
            'p_church_id': church.churchId,
            'p_membership_id': church.approverMembershipId,
          },
          // Trusted tooling only (service role).
          'publish_curriculum': {
            'p_church_id': church.churchId,
            'p_definition': definition(),
            'p_content_level': 'FULL',
            'p_licence_reference': 'X',
            'p_published_by': church.approver.userId,
          },
          'set_lesson_cover': {
            'p_lesson_id': curriculum.lessonIds.first,
            'p_image': 'eA==',
            'p_mime_type': 'image/jpeg',
          },
          // Joining is checked on its own below.
          'lookup_church_by_join_code': {'p_code': church.joinCode},
          'request_join_church': {
            'p_church_id': church.churchId,
            'p_join_code': church.joinCode,
          },
        };

        // Every function PostgREST serves must be classified here, so a new
        // one cannot skip this check.
        final http = HttpClient();
        final Set<String> served;
        try {
          final req = await http.getUrl(Uri.parse('$url/rest/v1/'));
          req.headers
            ..set('apikey', serviceKey)
            ..set('Authorization', 'Bearer $serviceKey');
          final res = await req.close();
          final spec = jsonDecode(
            await res.transform(utf8.decoder).join(),
          ) as Map<String, dynamic>;
          served = {
            for (final path in (spec['paths'] as Map<String, dynamic>).keys)
              if (path.startsWith('/rpc/')) path.substring(5),
          };
        } finally {
          http.close(force: true);
        }
        expect(
          served.difference(known.keys.toSet()),
          isEmpty,
          reason: 'unclassified functions',
        );

        await setStatus(church.churchId, 'SUSPENDED');
        try {
          final coordinator = church.approver.client;
          for (final e in known.entries) {
            if (e.key == 'request_join_church') continue; // rate-limited; below
            Object? result;
            try {
              result = await coordinator.rpc<dynamic>(e.key, params: e.value);
            } on PostgrestException catch (err) {
              result = 'refused ${err.code}';
            }
            expect(blocked(result), isTrue, reason: '${e.key}: $result');
          }
          final join = await rpcRow(coordinator, 'request_join_church', {
            'p_church_id': church.churchId,
            'p_join_code': church.joinCode,
          });
          expect(join['outcome'], isNot('REQUESTED'));
        } finally {
          await setStatus(church.churchId, 'ACTIVE');
        }

        // Nothing the sweep called changed the church.
        final stillPending = await service
            .from('church_memberships')
            .select('status')
            .eq('id', pendingId)
            .single();
        expect(stillPending['status'], 'PENDING');
        final meeting = await service
            .from('discipleship_meetings')
            .select('status')
            .eq('id', meetingId)
            .single();
        expect(meeting['status'], 'RECORDED');
      },
    );
  });

  group('an ARCHIVED church', () {
    test(
      'is final: the same blocks, no reactivation, and no platform change',
      () async {
        final coord = await createUser(
          fullName: 'CS Archive Coord',
          tag: 'cs-arc',
        );
        cleanup.add(coord.userId);
        final created = await rpcRow(superAdmin.client, 'create_church', {
          'p_name': 'Archived Church',
          'p_coordinator_email': coord.email,
        });
        final churchId = created['church_id'] as String;
        addTearDown(() => deleteChurchRows(churchId));

        await setStatus(churchId, 'ARCHIVED');
        await expectLater(
          coord.client.rpc<List<dynamic>>(
            'get_church_join_code',
            params: {'p_church_id': churchId},
          ),
          throwsPostgrestCode('PT403'),
        );
        await expectLater(
          coord.client.rpc<List<dynamic>>('list_lesson_access'),
          throwsPostgrestCode('PT403'),
        );
        final row = await coord.client
            .from('churches')
            .select('status')
            .single();
        expect(row['status'], 'ARCHIVED');
        for (final call in [
          () => setStatus(churchId, 'ACTIVE'),
          () => rpcRow(superAdmin.client, 'regenerate_join_code', {
            'p_church_id': churchId,
          }),
          () => rpcRow(superAdmin.client, 'assign_church_coordinator', {
            'p_church_id': churchId,
            'p_email': church.approver.email,
          }),
        ]) {
          await expectLater(call(), throwsPostgrestCode('PT409'));
        }
        final memberships = await service
            .from('church_memberships')
            .select('status')
            .eq('church_id', churchId);
        expect(memberships.single['status'], 'ACTIVE', reason: 'history kept');
      },
    );
  });
}
