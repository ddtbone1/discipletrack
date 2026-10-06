import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/d_group.dart';
import '../domain/d_group_detail.dart';
import '../domain/d_group_member.dart';
import '../domain/d_group_placement.dart';
import '../domain/discipler_assignment.dart';
import '../domain/discipler_candidate.dart';
import '../domain/member_option.dart';
import '../domain/ministry_context.dart';

/// A failed ministry operation, with a message fit to show a person.
///
/// [reason] is the stable reason the controlled operation raised (for
/// example `member_already_placed`), kept so callers and tests can branch on
/// it without parsing the message.
class MinistryFailure implements Exception, NetworkAwareFailure {
  const MinistryFailure(
    this.message, {
    this.code = DbFailureCode.unknown,
    this.reason,
  });

  final String message;
  final DbFailureCode code;
  final String? reason;

  @override
  bool get isNetwork => code == DbFailureCode.network;

  @override
  String toString() => message;
}

/// What `set_discipler()` did.
enum PairingOutcome {
  assigned,
  reassigned,
  unassigned;

  static PairingOutcome fromDb(String value) => switch (value) {
    'ASSIGNED' => PairingOutcome.assigned,
    'REASSIGNED' => PairingOutcome.reassigned,
    'UNASSIGNED' => PairingOutcome.unassigned,
    _ => throw ArgumentError('Unknown set_discipler outcome: $value'),
  };
}

/// The initial setup window of a church (Migration 013): while it is open, a
/// member may be recognized as an Existing Discipler at setup.
@immutable
class InitialSetupStatus {
  const InitialSetupStatus({required this.isOpen, this.closedAt});

  final bool isOpen;
  final DateTime? closedAt;
}

/// D Groups, placements, responsibilities and pairings.
///
/// Reads go through RLS (Migrations 006 and 012) and embed names through
/// foreign-key hints: several tables link `d_group_memberships`,
/// `church_memberships` and `d_groups` more than one way, so an unhinted embed
/// is ambiguous. Every write is a controlled operation; clients hold no write
/// grant on these tables.
class MinistryRepository {
  MinistryRepository(this._client);

  final SupabaseClient _client;

  static const _memberEmbed =
      'member:church_memberships!d_group_memberships_membership_fkey('
      'profile:profiles!church_memberships_user_id_fkey(full_name, phone))';

  /// Every D Group in [churchId] with its Leader and counts, by name. Empty
  /// for anyone but the church's Coordinator.
  Future<List<DGroupSummary>> fetchGroups(String churchId) {
    return _guard('Could not load D Groups.', () async {
      final rows = await _client
          .from('d_groups')
          .select(
            'id, name, description, status, '
            'members:d_group_memberships!d_group_memberships_d_group_id_fkey('
            'responsibility, ended_at, '
            'member:church_memberships!d_group_memberships_membership_fkey('
            'profile:profiles!church_memberships_user_id_fkey(full_name))), '
            'placements:d_group_placements!d_group_placements_d_group_id_fkey('
            'id, ended_at)',
          )
          .eq('church_id', churchId)
          .neq('status', 'ARCHIVED')
          .isFilter('members.ended_at', null)
          .isFilter('placements.ended_at', null)
          .order('name', ascending: true);
      return [for (final r in rows) DGroupSummary.fromMap(r)];
    });
  }

  /// One group as its Coordinator or Leader sees it, or null when the caller
  /// cannot read it.
  Future<DGroupDetail?> fetchGroupDetail(String groupId) {
    return _guard('Could not load this D Group.', () async {
      final groupRow = await _client
          .from('d_groups')
          .select('id, name, description, status')
          .eq('id', groupId)
          .maybeSingle();
      if (groupRow == null) return null;

      final placements = await _client
          .from('d_group_placements')
          .select(
            'id, church_membership_id, started_at, '
            'member:church_memberships!d_group_placements_membership_fkey('
            'profile:profiles!church_memberships_user_id_fkey(full_name, phone))',
          )
          .eq('d_group_id', groupId)
          .isFilter('ended_at', null);

      final members = await _client
          .from('d_group_memberships')
          .select(
            'id, church_membership_id, responsibility, started_at, '
            'discipler_basis, $_memberEmbed',
          )
          .eq('d_group_id', groupId)
          .isFilter('ended_at', null);

      final assignments = await _client
          .from('discipler_assignments')
          .select(
            'id, discipler_d_group_membership_id, '
            'disciple_d_group_membership_id, started_at',
          )
          .eq('d_group_id', groupId)
          .isFilter('ended_at', null);

      return DGroupDetail(
        group: DGroup.fromMap(groupRow),
        placements: [for (final r in placements) DGroupPlacement.fromMap(r)],
        members: [for (final r in members) DGroupMember.fromMap(r)],
        assignments: [
          for (final r in assignments) DisciplerAssignment.fromMap(r),
        ],
      );
    });
  }

  /// `list_addable_members()`: ACTIVE members of the group's church who are
  /// in no D Group. Refused for anyone but the Coordinator or the group's
  /// Leader.
  Future<List<AddableMember>> fetchAddableMembers(String groupId) {
    return _guard('Could not load members.', () async {
      final rows = await _client.rpc<List<dynamic>>(
        'list_addable_members',
        params: {'p_d_group_id': groupId},
      );
      return [
        for (final r in rows) AddableMember.fromMap(r as Map<String, dynamic>),
      ];
    });
  }

  /// `list_discipler_candidates()`: eligible Disciples who are not
  /// Disciplers, for one group ([groupId]) or church-wide ([churchId],
  /// Coordinator only).
  Future<List<DisciplerCandidate>> fetchDisciplerCandidates({
    String? groupId,
    String? churchId,
  }) {
    return _guard('Could not load who is eligible.', () async {
      final rows = await _client.rpc<List<dynamic>>(
        'list_discipler_candidates',
        params: {'p_d_group_id': groupId, 'p_church_id': churchId},
      );
      return [
        for (final r in rows)
          DisciplerCandidate.fromMap(r as Map<String, dynamic>),
      ];
    });
  }

  /// `appoint_discipler()`. Coordinator only.
  Future<void> appointDiscipler(String membershipId) {
    return _guard('Could not appoint them.', () async {
      await _row('appoint_discipler', {'p_membership_id': membershipId});
    });
  }

  /// `get_initial_setup_status()`.
  Future<InitialSetupStatus> fetchInitialSetupStatus(String churchId) {
    return _guard('Could not load the setup status.', () async {
      final row = await _row('get_initial_setup_status', {
        'p_church_id': churchId,
      });
      final closed = row['closed_at'] as String?;
      return InitialSetupStatus(
        isOpen: row['initial_setup_open'] as bool,
        closedAt: closed == null ? null : DateTime.parse(closed),
      );
    });
  }

  /// `list_placeable_members()`: for a group when [groupId] is given,
  /// otherwise every ACTIVE member of [churchId] (Coordinator only).
  Future<List<MemberOption>> fetchPlaceableMembers({
    String? groupId,
    String? churchId,
  }) {
    return _guard('Could not load members.', () async {
      final rows = await _client.rpc<List<dynamic>>(
        'list_placeable_members',
        params: {'p_d_group_id': groupId, 'p_church_id': churchId},
      );
      return [
        for (final r in rows) MemberOption.fromMap(r as Map<String, dynamic>),
      ];
    });
  }

  /// `get_my_d_group_roster()`: the caller's group, or null when unplaced.
  Future<MinistryContext?> fetchMyMinistryContext() {
    return _guard('Could not load your D Group.', () async {
      final rows = await _client.rpc<List<dynamic>>('get_my_d_group_roster');
      return MinistryContext.fromRosterRows(rows.cast<Map<String, dynamic>>());
    });
  }

  /// `create_d_group()`. Returns the new group's id.
  Future<String> createGroup({
    required String name,
    String? description,
    required String leaderMembershipId,
  }) {
    return _guard('Could not create the D Group.', () async {
      final row = await _row('create_d_group', {
        'p_name': name,
        'p_description': description,
        'p_leader_membership_id': leaderMembershipId,
      });
      return row['d_group_id'] as String;
    });
  }

  /// `assign_d_group_leader()`.
  Future<void> assignLeader({
    required String groupId,
    required String membershipId,
  }) {
    return _guard('Could not change the Leader.', () async {
      await _row('assign_d_group_leader', {
        'p_d_group_id': groupId,
        'p_membership_id': membershipId,
      });
    });
  }

  /// `add_members_to_d_group()`: all or nothing.
  Future<void> addMembers({
    required String groupId,
    required List<String> membershipIds,
  }) {
    return _guard('Could not add them to the group.', () async {
      await _client.rpc<List<dynamic>>(
        'add_members_to_d_group',
        params: {'p_d_group_id': groupId, 'p_membership_ids': membershipIds},
      );
    });
  }

  /// `set_up_member()`. [responsibility] DISCIPLER is Existing Discipler
  /// recognition, available only while the initial setup window is open.
  Future<void> setUpMember({
    required String placementId,
    required DGroupResponsibility responsibility,
  }) {
    return _guard('Could not set up their role.', () async {
      await _row('set_up_member', {
        'p_d_group_placement_id': placementId,
        'p_responsibility': responsibility.toDb,
      });
    });
  }

  /// `set_initial_setup_open()`. Coordinator only.
  Future<void> setInitialSetupOpen({
    required String churchId,
    required bool open,
  }) {
    return _guard('Could not change the setup period.', () async {
      await _row('set_initial_setup_open', {
        'p_church_id': churchId,
        'p_open': open,
      });
    });
  }

  /// `add_self_as_discipler()`.
  Future<void> addSelfAsDiscipler(String groupId) {
    return _guard('Could not add you as Discipler.', () async {
      await _row('add_self_as_discipler', {'p_d_group_id': groupId});
    });
  }

  /// `remove_from_d_group()`: ends the placement, every responsibility and
  /// every pairing on either side.
  Future<void> removeFromGroup(String placementId) {
    return _guard('Could not remove them from the group.', () async {
      await _row('remove_from_d_group', {
        'p_d_group_placement_id': placementId,
      });
    });
  }

  /// `set_discipler()`. A null [disciplerDGroupMembershipId] unpairs.
  Future<PairingOutcome> setDiscipler({
    required String discipleDGroupMembershipId,
    String? disciplerDGroupMembershipId,
  }) {
    return _guard('Could not update the pairing.', () async {
      final row = await _row('set_discipler', {
        'p_disciple_d_group_membership_id': discipleDGroupMembershipId,
        'p_discipler_d_group_membership_id': disciplerDGroupMembershipId,
      });
      return PairingOutcome.fromDb(row['outcome'] as String);
    });
  }

  Future<Map<String, dynamic>> _row(
    String fn,
    Map<String, dynamic> params,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(fn, params: params);
    return rows.single as Map<String, dynamic>;
  }

  Future<T> _guard<T>(String fallback, Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw failureFrom(e, fallback);
    } on MinistryFailure {
      rethrow;
    } on Exception {
      throw const MinistryFailure(
        PostgrestFailure.networkMessage,
        code: DbFailureCode.network,
      );
    } catch (_) {
      throw MinistryFailure(fallback);
    }
  }

  /// Maps the reason raised by a ministry operation (Migrations 006, 012 and
  /// 013) to wording. Exposed for tests.
  static MinistryFailure failureFrom(PostgrestException e, String fallback) {
    final code = PostgrestFailure.codeOf(e);
    final message = switch (e.message) {
      'member_already_placed' =>
        'Someone you chose was just added to another D Group. The list has '
            'been refreshed; choose again.',
      'member_not_active' => 'That person is not an active member.',
      'membership_not_found' =>
        'Someone you chose is no longer a member here. Refresh and try again.',
      'members_required' => 'Choose at least one person to add.',
      'too_many_members' => 'Add at most 100 people at a time.',
      'd_group_name_taken' => 'A D Group with that name already exists.',
      'd_group_name_required' => 'Enter a name for the group.',
      'd_group_not_active' => 'This D Group is not active.',
      'already_leader' => 'That person already leads this group.',
      'leader_not_eligible' =>
        'That person is already in a D Group. A new Leader must be in no '
            'group, or in this group with no role other than Discipler.',
      'already_discipler' => 'They are already a Discipler in this group.',
      'already_disciple' => 'They are already a Disciple in this group.',
      'not_eligible' =>
        'They have not yet completed the lessons needed to become a '
            'Discipler, so they cannot be appointed.',
      'cannot_appoint_self' => 'You cannot appoint yourself as a Discipler.',
      'leader_cannot_be_disciple' =>
        'The Leader cannot also be a Disciple in the group.',
      'initial_setup_closed' =>
        'The setup period has ended. A Disciple becomes a Discipler only '
            'after Lesson 5, when the Coordinator appoints them.',
      'initial_setup_already_open' => 'The setup period is already open.',
      'initial_setup_already_closed' => 'The setup period is already closed.',
      'already_paired' => 'They are already paired with that Discipler.',
      'not_paired' => 'This Disciple is not paired with anyone.',
      'cannot_pair_with_self' => 'Nobody can be their own Discipler.',
      'reciprocal_pairing' =>
        'Two people cannot disciple each other at the same time.',
      'leader_cannot_be_removed' =>
        'The Leader cannot be removed. Change the Leader instead.',
      'not_an_active_disciple' ||
      'not_an_active_discipler' ||
      'd_group_membership_not_active' ||
      'd_group_placement_not_active' =>
        'That person is no longer in that role here. Refresh and try again.',
      _ => PostgrestFailure.friendlyMessage(e, fallback),
    };
    return MinistryFailure(message, code: code, reason: e.message);
  }
}

final ministryRepositoryProvider = Provider<MinistryRepository>((ref) {
  return MinistryRepository(ref.watch(supabaseClientProvider));
});
