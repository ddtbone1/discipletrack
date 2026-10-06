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

/// `add_members_to_d_group()`: places [membershipIds] in the group and
/// returns their placement ids, keyed by church membership id.
Future<Map<String, String>> addMembers(
  SupabaseClient caller,
  String groupId,
  List<String> membershipIds,
) async {
  final rows = await caller.rpc<List<dynamic>>(
    'add_members_to_d_group',
    params: {'p_d_group_id': groupId, 'p_membership_ids': membershipIds},
  );
  return {
    for (final r in rows.cast<Map<String, dynamic>>())
      r['church_membership_id'] as String: r['d_group_placement_id'] as String,
  };
}

/// `set_up_member()`: returns the new D Group membership id. DISCIPLER is
/// Existing Discipler recognition, refused once the setup window is closed.
Future<String> setUpMember(
  SupabaseClient caller,
  String placementId,
  String responsibility,
) async {
  final row = await rpcRow(caller, 'set_up_member', {
    'p_d_group_placement_id': placementId,
    'p_responsibility': responsibility,
  });
  return row['d_group_membership_id'] as String;
}

/// The person's active placement id, read as the service role.
Future<String?> activePlacementOf(String membershipId) async {
  final row = await service
      .from('d_group_placements')
      .select('id')
      .eq('church_membership_id', membershipId)
      .isFilter('ended_at', null)
      .maybeSingle();
  return row?['id'] as String?;
}

/// Adds [member] to the group and sets them up as [responsibility],
/// returning the D Group membership id. A DISCIPLER here is an Existing
/// Discipler (initial setup window), the usual state for fixtures.
Future<String> place(
  SupabaseClient manager,
  String groupId,
  TestMember member,
  String responsibility,
) async {
  final placements = await addMembers(manager, groupId, [member.membershipId]);
  return setUpMember(manager, placements[member.membershipId]!, responsibility);
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
