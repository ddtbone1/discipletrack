/// D Group fixtures built through the real controlled operations, so every
/// test starts from a state the app itself could have produced.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_env.dart';

typedef TestGroup = ({String groupId, TestMember leader, String leaderDgmId});

/// Unique per call, because group names are unique per church.
String uniqueGroupName([String tag = 'Group']) =>
    '$tag ${DateTime.now().microsecondsSinceEpoch}';

/// A new group in [church], created by its Coordinator (the approver) with a
/// freshly created ACTIVE member as Leader.
Future<TestGroup> createGroupWithLeader(
  TestChurch church, {
  String tag = 'lead',
  String? name,
}) async {
  final leader = await createActiveMember(
    church.churchId,
    fullName: 'Leader $tag',
    tag: tag,
    phone: '+63 900 000 0001',
  );
  final row = await rpcRow(church.approver.client, 'create_d_group', {
    'p_name': name ?? uniqueGroupName(),
    'p_description': null,
    'p_leader_membership_id': leader.membershipId,
  });
  return (
    groupId: row['d_group_id'] as String,
    leader: leader,
    leaderDgmId: row['leader_d_group_membership_id'] as String,
  );
}

Future<String> invite(
  SupabaseClient inviter,
  String groupId,
  String membershipId,
  String responsibility,
) async {
  final row = await rpcRow(inviter, 'invite_to_d_group', {
    'p_d_group_id': groupId,
    'p_membership_id': membershipId,
    'p_responsibility': responsibility,
  });
  return row['invitation_id'] as String;
}

/// Accepts [invitationId] as [invitee] and returns the new D Group
/// membership id.
Future<String> accept(SupabaseClient invitee, String invitationId) async {
  final row = await rpcRow(invitee, 'respond_to_d_group_invitation', {
    'p_invitation_id': invitationId,
    'p_accept': true,
  });
  return row['d_group_membership_id'] as String;
}

/// Invites [member] as [responsibility] and accepts, returning the D Group
/// membership id.
Future<String> place(
  SupabaseClient inviter,
  String groupId,
  TestMember member,
  String responsibility,
) async {
  final id = await invite(
    inviter,
    groupId,
    member.membershipId,
    responsibility,
  );
  return accept(member.user.client, id);
}

Future<Map<String, dynamic>> setDiscipler(
  SupabaseClient caller,
  String discipleDgmId,
  String? disciplerDgmId,
) => rpcRow(caller, 'set_discipler', {
  'p_disciple_d_group_membership_id': discipleDgmId,
  'p_discipler_d_group_membership_id': disciplerDgmId,
});

/// Audit actions recorded against [entityId].
Future<List<String>> auditActionsFor(String entityId) async {
  final rows = await service
      .from('audit_events')
      .select('action')
      .eq('entity_id', entityId)
      .order('created_at', ascending: true);
  return [for (final r in rows) r['action'] as String];
}
