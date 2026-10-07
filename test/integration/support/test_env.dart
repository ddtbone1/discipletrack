/// Shared setup for integration tests against the real local Supabase stack.
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
/// involved. Each test owns its users and churches and cleans them up.
///
/// Users are created through the admin API with `emailConfirm: true`, which
/// works whether or not `enable_confirmations` is on. Only the tests that are
/// about verification itself use the anonymous sign-up path.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const url = String.fromEnvironment('SUPABASE_URL');
const anonKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Mailpit's HTTP API, served on `[local_smtp].port` from supabase/config.toml.
const mailpitUrl = String.fromEnvironment(
  'MAILPIT_URL',
  defaultValue: 'http://127.0.0.1:54324',
);

/// Read at runtime from the environment, with a compile-time define as a
/// fallback so CI can inject it either way.
final serviceKey =
    Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
    const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');

const password = 'Test-password-123';

/// The church and admin provisioned by supabase/seed.sql on `db reset`.
const seededChurchId = 'c0000000-0000-4000-8000-000000000001';
const seededAdminUserId = 'a0000000-0000-4000-8000-000000000001';
const seededAdminEmail = 'admin@discipletrack.local';
const seededAdminPassword = 'dev-password-123';
const seededJoinCode = '7QK4MZP2XR';
const seededChurchName = 'Liberty Bible Baptist Church - Gensan';

/// Service-role client. Bypasses RLS; used only for setup and teardown.
late SupabaseClient service;

/// The implicit flow is used deliberately. PKCE is the package default but
/// requires an async storage implementation that only the Flutter wrapper
/// supplies; these tests construct the client directly and hold no session.
const testAuthOptions = AuthClientOptions(
  authFlowType: AuthFlowType.implicit,
  autoRefreshToken: false,
);

/// Unique per run so repeated runs never collide.
String uniqueEmail([String tag = 'user']) =>
    'dt-$tag-${DateTime.now().microsecondsSinceEpoch}@example.test';

SupabaseClient anonClient() =>
    SupabaseClient(url, anonKey, authOptions: testAuthOptions);

/// Call from `setUpAll`. Fails with the exact fix when configuration is absent.
void ensureTestEnvironment() {
  expect(
    url.isNotEmpty && anonKey.isNotEmpty,
    isTrue,
    reason:
        'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY. Run with '
        '--dart-define-from-file=config/test.json',
  );
  expect(
    serviceKey.isNotEmpty,
    isTrue,
    reason:
        'Missing SUPABASE_SERVICE_ROLE_KEY. It is deliberately not committed. '
        'Set it from the running stack:\n'
        r'  $env:SUPABASE_SERVICE_ROLE_KEY = '
        r'(npx supabase status -o json | ConvertFrom-Json).SERVICE_ROLE_KEY',
  );
  service = SupabaseClient(url, serviceKey, authOptions: testAuthOptions);
}

typedef TestUser = ({SupabaseClient client, String userId, String email});

/// A confirmed user with a signed-in client, created through the admin API.
Future<TestUser> createUser({
  required String fullName,
  String tag = 'user',
}) async {
  final email = uniqueEmail(tag);
  final created = await service.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: password,
      emailConfirm: true,
      userMetadata: {'full_name': fullName},
    ),
  );
  final client = anonClient();
  await client.auth.signInWithPassword(email: email, password: password);
  return (client: client, userId: created.user!.id, email: email);
}

/// A second signed-in client for an existing user, as another device would be.
Future<SupabaseClient> signInAgain(String email) async {
  final client = anonClient();
  await client.auth.signInWithPassword(email: email, password: password);
  return client;
}

List<String> _ids(List<Map<String, dynamic>> rows, [String key = 'id']) => [
  for (final r in rows)
    if (r[key] != null) r[key] as String,
];

/// Deletes discipleship rows in foreign-key order: meeting participants,
/// meetings, then lesson progress.
///
/// Meetings are selected by group, by Discipler row ([dgmIds]) or by
/// recorder; participant and progress rows also by person or by actor.
Future<void> deleteDiscipleshipRows({
  List<String> groupIds = const [],
  List<String> dgmIds = const [],
  List<String> membershipIds = const [],
  String? actorId,
}) async {
  final meetingIds = <String>{};
  if (groupIds.isNotEmpty) {
    meetingIds.addAll(
      _ids(
        await service
            .from('discipleship_meetings')
            .select('id')
            .inFilter('d_group_id', groupIds),
      ),
    );
  }
  if (dgmIds.isNotEmpty) {
    meetingIds.addAll(
      _ids(
        await service
            .from('discipleship_meetings')
            .select('id')
            .inFilter('discipler_d_group_membership_id', dgmIds),
      ),
    );
  }
  if (actorId != null) {
    meetingIds.addAll(
      _ids(
        await service
            .from('discipleship_meetings')
            .select('id')
            .or('recorded_by.eq.$actorId,voided_by.eq.$actorId'),
      ),
    );
  }
  final meetings = meetingIds.toList();

  if (meetings.isNotEmpty) {
    await service
        .from('discipleship_meeting_participants')
        .delete()
        .inFilter('meeting_id', meetings);
  }
  if (membershipIds.isNotEmpty) {
    await service
        .from('discipleship_meeting_participants')
        .delete()
        .inFilter('church_membership_id', membershipIds);
    await service
        .from('disciple_lesson_progress')
        .delete()
        .inFilter('church_membership_id', membershipIds);
  }
  if (actorId != null) {
    await service
        .from('discipleship_meeting_participants')
        .delete()
        .eq('voided_by', actorId);
    await service
        .from('disciple_lesson_progress')
        .delete()
        .or('submitted_by.eq.$actorId,confirmed_by.eq.$actorId');
  }
  if (meetings.isNotEmpty) {
    await service
        .from('discipleship_meetings')
        .delete()
        .inFilter('id', meetings);
  }
}

/// Deletes D Group rows in foreign-key order: discipleship rows,
/// assignments, invitations, D Group memberships, placements, then the
/// groups themselves.
///
/// Rows are selected by any of: belonging to [groupIds], touching one of
/// [membershipIds] (on either side of an assignment), or having been written
/// by [actorId]. A group is deleted only when listed in [groupIds].
Future<void> deleteMinistryRows({
  List<String> groupIds = const [],
  List<String> membershipIds = const [],
  String? actorId,
}) async {
  final dgmIds = <String>{};
  if (groupIds.isNotEmpty) {
    dgmIds.addAll(
      _ids(
        await service
            .from('d_group_memberships')
            .select('id')
            .inFilter('d_group_id', groupIds),
      ),
    );
  }
  if (membershipIds.isNotEmpty) {
    dgmIds.addAll(
      _ids(
        await service
            .from('d_group_memberships')
            .select('id')
            .inFilter('church_membership_id', membershipIds),
      ),
    );
  }
  if (actorId != null) {
    dgmIds.addAll(
      _ids(
        await service
            .from('d_group_memberships')
            .select('id')
            .eq('assigned_by', actorId),
      ),
    );
  }
  final dgms = dgmIds.toList();

  await deleteDiscipleshipRows(
    groupIds: groupIds,
    dgmIds: dgms,
    membershipIds: membershipIds,
    actorId: actorId,
  );

  if (dgms.isNotEmpty) {
    await service
        .from('discipler_assignments')
        .delete()
        .inFilter('discipler_d_group_membership_id', dgms);
    await service
        .from('discipler_assignments')
        .delete()
        .inFilter('disciple_d_group_membership_id', dgms);
    await service
        .from('d_group_invitations')
        .delete()
        .inFilter('resulting_d_group_membership_id', dgms);
  }
  if (groupIds.isNotEmpty) {
    await service
        .from('discipler_assignments')
        .delete()
        .inFilter('d_group_id', groupIds);
    await service
        .from('d_group_invitations')
        .delete()
        .inFilter('d_group_id', groupIds);
  }
  if (membershipIds.isNotEmpty) {
    await service
        .from('d_group_invitations')
        .delete()
        .inFilter('church_membership_id', membershipIds);
  }
  if (actorId != null) {
    await service
        .from('discipler_assignments')
        .delete()
        .eq('assigned_by', actorId);
    await service
        .from('d_group_invitations')
        .delete()
        .eq('invited_by', actorId);
  }
  // Appointment records (Migration 014) reference groups and memberships.
  if (groupIds.isNotEmpty) {
    await service
        .from('ministry_role_transitions')
        .delete()
        .inFilter('d_group_id', groupIds);
  }
  if (membershipIds.isNotEmpty) {
    await service
        .from('ministry_role_transitions')
        .delete()
        .inFilter('church_membership_id', membershipIds);
  }
  if (actorId != null) {
    await service
        .from('ministry_role_transitions')
        .delete()
        .eq('approved_by', actorId);
  }
  if (dgms.isNotEmpty) {
    await service.from('d_group_memberships').delete().inFilter('id', dgms);
  }
  // Placements (Migration 012) after the responsibilities they hold.
  if (groupIds.isNotEmpty) {
    await service
        .from('d_group_placements')
        .delete()
        .inFilter('d_group_id', groupIds);
  }
  if (membershipIds.isNotEmpty) {
    await service
        .from('d_group_placements')
        .delete()
        .inFilter('church_membership_id', membershipIds);
  }
  if (actorId != null) {
    await service.from('d_group_placements').delete().eq('placed_by', actorId);
    await service.from('d_group_placements').delete().eq('ended_by', actorId);
  }
  if (groupIds.isNotEmpty) {
    await service.from('d_groups').delete().inFilter('id', groupIds);
  }
}

/// Removes everything a test user can own, in dependency order.
///
/// Migration 001 declares every foreign key ON DELETE NO ACTION, so rows that
/// reference the profile (memberships, audit events they performed, roles
/// they assigned) go first, then the profile, then the auth user. D Group rows
/// touching the person's memberships, written by them, or in groups they
/// created, go before all of that.
Future<void> deleteUser(String userId) async {
  final memberships = await service
      .from('church_memberships')
      .select('id')
      .eq('user_id', userId);
  final createdGroups = await service
      .from('d_groups')
      .select('id')
      .eq('created_by', userId);
  await deleteMinistryRows(
    groupIds: _ids(createdGroups),
    membershipIds: _ids(memberships),
    actorId: userId,
  );
  for (final m in memberships) {
    await service
        .from('church_role_assignments')
        .delete()
        .eq('church_membership_id', m['id'] as String);
  }
  await service
      .from('church_role_assignments')
      .delete()
      .eq('assigned_by', userId);
  await service.from('audit_events').delete().eq('actor_user_id', userId);
  await service.from('church_memberships').delete().eq('user_id', userId);
  await service.from('church_memberships').delete().eq('approved_by', userId);
  await service.from('profiles').delete().eq('id', userId);
  await service.auth.admin.deleteUser(userId);
}

/// A join code in the production format, from a secure random source.
String randomJoinCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(
    10,
    (_) => alphabet[rng.nextInt(alphabet.length)],
  ).join();
}

typedef TestChurch = ({
  String churchId,
  String joinCode,
  String name,
  TestUser approver,
  String approverMembershipId,
});

/// A fresh church with an ACTIVE approver holding the given roles.
///
/// Seeded through the service role rather than bootstrap so each test owns an
/// independent church and its rows can be removed afterwards. The seeded
/// bootstrap church is exercised by bootstrap_test.dart.
Future<TestChurch> seedChurch({
  String name = 'Test Church',
  Set<String> approverRoles = const {'ADMIN', 'COORDINATOR'},
}) async {
  final approver = await createUser(fullName: 'Approver Person', tag: 'appr');
  final joinCode = randomJoinCode();

  final church = await service
      .from('churches')
      .insert({'name': name, 'join_code': joinCode})
      .select('id')
      .single();
  final churchId = church['id'] as String;

  await service.from('church_settings').insert({
    'church_id': churchId,
    'follow_up_due_days': 7,
  });

  final membership = await service
      .from('church_memberships')
      .insert({
        'church_id': churchId,
        'user_id': approver.userId,
        'status': 'ACTIVE',
        'joined_at': DateTime.now().toUtc().toIso8601String(),
        'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select('id')
      .single();
  final membershipId = membership['id'] as String;

  for (final role in approverRoles) {
    await service.from('church_role_assignments').insert({
      'church_membership_id': membershipId,
      'role': role,
      'assigned_by': approver.userId,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  return (
    churchId: churchId,
    joinCode: joinCode,
    name: name,
    approver: approver,
    approverMembershipId: membershipId,
  );
}

/// Adds a membership for [userId] in [churchId] directly, for tests that
/// start from a given state rather than from the join flow.
Future<String> seedMembership(
  String churchId,
  String userId,
  String status, {
  DateTime? onboardingCompletedAt,
}) async {
  final row = await service
      .from('church_memberships')
      .insert({
        'church_id': churchId,
        'user_id': userId,
        'status': status,
        if (status == 'ACTIVE')
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        if (onboardingCompletedAt != null)
          'onboarding_completed_at': onboardingCompletedAt.toIso8601String(),
      })
      .select('id')
      .single();
  return row['id'] as String;
}

typedef TestMember = ({TestUser user, String membershipId});

/// A confirmed user with an ACTIVE, onboarded membership in [churchId].
Future<TestMember> createActiveMember(
  String churchId, {
  required String fullName,
  String tag = 'member',
  String? phone,
}) async {
  final user = await createUser(fullName: fullName, tag: tag);
  if (phone != null) {
    await service
        .from('profiles')
        .update({'phone': phone})
        .eq('id', user.userId);
  }
  final membershipId = await seedMembership(
    churchId,
    user.userId,
    'ACTIVE',
    onboardingCompletedAt: DateTime.now().toUtc(),
  );
  return (user: user, membershipId: membershipId);
}

/// Calls an RPC that returns a table and gives back its single row.
Future<Map<String, dynamic>> rpcRow(
  SupabaseClient client,
  String fn, [
  Map<String, dynamic>? params,
]) async {
  final rows = await client.rpc<List<dynamic>>(fn, params: params);
  return rows.single as Map<String, dynamic>;
}

/// Removes a church and everything hanging off it, then its approver.
Future<void> deleteChurch(TestChurch church) async {
  await deleteChurchRows(church.churchId);
  await deleteUser(church.approver.userId);
}

Future<void> deleteChurchRows(String churchId) async {
  final groups = await service
      .from('d_groups')
      .select('id')
      .eq('church_id', churchId);
  final memberships = await service
      .from('church_memberships')
      .select('id')
      .eq('church_id', churchId);
  await deleteMinistryRows(
    groupIds: _ids(groups),
    membershipIds: _ids(memberships),
  );
  final curricula = _ids(
    await service.from('curricula').select('id').eq('church_id', churchId),
  );
  if (curricula.isNotEmpty) {
    // Published content (Migration 017) before the lessons it belongs to.
    final publications = _ids(
      await service
          .from('curriculum_publications')
          .select('id')
          .inFilter('curriculum_id', curricula),
    );
    if (publications.isNotEmpty) {
      final blocks = _ids(
        await service
            .from('lesson_content_blocks')
            .select('id')
            .inFilter('publication_id', publications),
      );
      if (blocks.isNotEmpty) {
        await service
            .from('lesson_block_answers')
            .delete()
            .inFilter('block_id', blocks);
      }
      await service
          .from('lesson_content_blocks')
          .delete()
          .inFilter('publication_id', publications);
      await service
          .from('curriculum_publications')
          .delete()
          .inFilter('id', publications);
    }
    final lessons = _ids(
      await service
          .from('curriculum_lessons')
          .select('id')
          .inFilter('curriculum_id', curricula),
    );
    if (lessons.isNotEmpty) {
      await service
          .from('lesson_covers')
          .delete()
          .inFilter('lesson_id', lessons);
    }
    await service
        .from('curriculum_lessons')
        .delete()
        .inFilter('curriculum_id', curricula);
    await service.from('curricula').delete().inFilter('id', curricula);
  }
  for (final m in memberships) {
    await service
        .from('church_role_assignments')
        .delete()
        .eq('church_membership_id', m['id'] as String);
  }
  await service.from('audit_events').delete().eq('church_id', churchId);
  await service.from('church_memberships').delete().eq('church_id', churchId);
  await service.from('church_settings').delete().eq('church_id', churchId);
  await service.from('churches').delete().eq('id', churchId);
}

/// Waits for the confirmation email to [email] and returns its 6-digit code.
Future<String> fetchVerificationCode(
  String email, {
  Duration timeout = const Duration(seconds: 15),
  int skip = 0,
}) async {
  final deadline = DateTime.now().add(timeout);
  final http = HttpClient();
  try {
    while (DateTime.now().isBefore(deadline)) {
      final search = await _getJson(
        http,
        Uri.parse('$mailpitUrl/api/v1/search?query=to:$email'),
      );
      final messages = (search['messages'] as List<dynamic>?) ?? const [];
      if (messages.length > skip) {
        // Newest first; `skip` lets a test pick the second email.
        final id = messages[skip]['ID'] as String;
        final message = await _getJson(
          http,
          Uri.parse('$mailpitUrl/api/v1/message/$id'),
        );
        final match = RegExp(r'\b(\d{6})\b')
            .firstMatch(message['Text'] as String? ?? '');
        if (match != null) return match.group(1)!;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  } finally {
    http.close(force: true);
  }
  fail('No verification email for $email reached Mailpit at $mailpitUrl');
}

/// How many emails Mailpit holds for [email].
Future<int> countEmails(String email) async {
  final http = HttpClient();
  try {
    final search = await _getJson(
      http,
      Uri.parse('$mailpitUrl/api/v1/search?query=to:$email'),
    );
    return ((search['messages'] as List<dynamic>?) ?? const []).length;
  } finally {
    http.close(force: true);
  }
}

Future<Map<String, dynamic>> _getJson(HttpClient http, Uri uri) async {
  final request = await http.getUrl(uri);
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    fail('GET $uri returned ${response.statusCode}: $body');
  }
  return jsonDecode(body) as Map<String, dynamic>;
}

/// Matches a [PostgrestException] with the given SQLSTATE / PostgREST code.
Matcher throwsPostgrestCode(String code) =>
    throwsA(isA<PostgrestException>().having((e) => e.code, 'code', code));

/// Matches an [AuthApiException] with the given GoTrue error code.
Matcher throwsAuthCode(String code) =>
    throwsA(isA<AuthApiException>().having((e) => e.code, 'code', code));

/// The local stack's database container, for [sqlRows] and [sqlError].
final dbContainer =
    Platform.environment['SUPABASE_DB_CONTAINER'] ??
    'supabase_db_discipletrack';

Future<ProcessResult> _psql(String sql) => Process.run('docker', [
  'exec',
  dbContainer,
  'psql',
  '-U',
  'postgres',
  '-v',
  'ON_ERROR_STOP=1',
  '-tA',
  '-F',
  '\t',
  '-c',
  sql,
]);

/// Runs [sql] in the local database as postgres and returns each row's
/// fields (NULL as an empty string). For trusted functions in the private
/// schema, which PostgREST deliberately does not expose. Needs Docker and
/// the local stack's database container.
Future<List<List<String>>> sqlRows(String sql) async {
  final r = await _psql(sql);
  if (r.exitCode != 0) fail('psql in $dbContainer failed: ${r.stderr}');
  return [
    for (final line in (r.stdout as String).split('\n'))
      if (line.trim().isNotEmpty) line.replaceAll('\r', '').split('\t'),
  ];
}

/// Runs [sql], which must fail, and returns the error text.
Future<String> sqlError(String sql) async {
  final r = await _psql(sql);
  expect(r.exitCode, isNot(0), reason: 'expected to fail: $sql');
  return r.stderr as String;
}
