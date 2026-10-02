import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/d_group.dart';
import '../domain/d_group_detail.dart';
import '../domain/d_group_invitation.dart';
import '../domain/d_group_member.dart';
import '../domain/discipler_assignment.dart';
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

/// D Groups, invitations and pairings.
///
/// Reads go through RLS (Migration 006) and embed names through foreign-key
/// hints: several tables link `d_group_memberships`, `church_memberships` and
/// `d_groups` more than one way, so an unhinted embed is ambiguous. Every
/// write is a controlled operation; clients hold no write grant on these
/// tables.
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
            'profile:profiles!church_memberships_user_id_fkey(full_name)))',
          )
          .eq('church_id', churchId)
          .neq('status', 'ARCHIVED')
          .isFilter('members.ended_at', null)
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

      final members = await _client
          .from('d_group_memberships')
          .select(
            'id, church_membership_id, responsibility, started_at, '
            '$_memberEmbed',
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

      final invitations = await _client
          .from('d_group_invitations')
          .select(
            'id, d_group_id, church_membership_id, responsibility, status, '
            'invited_by, created_at, expires_at, responded_at, '
            'invitee:church_memberships!d_group_invitations_membership_fkey('
            'profile:profiles!church_memberships_user_id_fkey(full_name))',
          )
          .eq('d_group_id', groupId)
          .order('created_at', ascending: false)
          .limit(100);

      return DGroupDetail(
        group: DGroup.fromMap(groupRow),
        members: [for (final r in members) DGroupMember.fromMap(r)],
        assignments: [
          for (final r in assignments) DisciplerAssignment.fromMap(r),
        ],
        invitations: [for (final r in invitations) DGroupInvitation.fromMap(r)],
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

  /// `get_my_pending_invitation()`: the caller's live invitation, if any.
  Future<DGroupInvitation?> fetchMyPendingInvitation() {
    return _guard('Could not load your invitation.', () async {
      final rows = await _client.rpc<List<dynamic>>(
        'get_my_pending_invitation',
      );
      if (rows.isEmpty) return null;
      return DGroupInvitation.fromPendingMap(
        rows.first as Map<String, dynamic>,
      );
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

  /// `invite_to_d_group()`.
  Future<void> invite({
    required String groupId,
    required String membershipId,
    required DGroupResponsibility responsibility,
  }) {
    return _guard('Could not send the invitation.', () async {
      await _row('invite_to_d_group', {
        'p_d_group_id': groupId,
        'p_membership_id': membershipId,
        'p_responsibility': responsibility.toDb,
      });
    });
  }

  /// `withdraw_d_group_invitation()`.
  Future<void> withdrawInvitation(String invitationId) {
    return _guard('Could not withdraw the invitation.', () async {
      await _row('withdraw_d_group_invitation', {
        'p_invitation_id': invitationId,
      });
    });
  }

  /// `respond_to_d_group_invitation()`.
  Future<void> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) {
    return _guard('Could not send your answer.', () async {
      await _row('respond_to_d_group_invitation', {
        'p_invitation_id': invitationId,
        'p_accept': accept,
      });
    });
  }

  /// `add_self_as_discipler()`.
  Future<void> addSelfAsDiscipler(String groupId) {
    return _guard('Could not add you as Discipler.', () async {
      await _row('add_self_as_discipler', {'p_d_group_id': groupId});
    });
  }

  /// `end_d_group_membership()`.
  Future<void> endMembership(String dGroupMembershipId) {
    return _guard('Could not remove them from the group.', () async {
      await _row('end_d_group_membership', {
        'p_d_group_membership_id': dGroupMembershipId,
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

  /// Maps the reason raised by a Migration 006 operation to wording. Exposed
  /// for tests.
  static MinistryFailure failureFrom(PostgrestException e, String fallback) {
    final code = PostgrestFailure.codeOf(e);
    final message = switch (e.message) {
      'member_already_placed' => 'That person is already in a D Group.',
      'member_has_pending_invitation' =>
        'That person already has a pending invitation.',
      'member_not_active' => 'That person is not an active member.',
      'd_group_name_taken' => 'A D Group with that name already exists.',
      'd_group_name_required' => 'Enter a name for the group.',
      'd_group_not_active' => 'This D Group is not active.',
      'invitation_expired' => 'This invitation has expired.',
      'invitation_not_pending' =>
        'This invitation has already been answered or withdrawn.',
      'already_leader' => 'That person already leads this group.',
      'leader_not_eligible' =>
        'That person is already in a D Group. A new Leader must be unplaced, '
            'or a Discipler in this group.',
      'already_discipler' => 'You are already a Discipler in this group.',
      'already_paired' => 'They are already paired with that Discipler.',
      'not_paired' => 'This Disciple is not paired with anyone.',
      'leader_cannot_be_ended' =>
        'The Leader cannot be removed. Change the Leader instead.',
      'not_an_active_disciple' ||
      'not_an_active_discipler' ||
      'd_group_membership_not_active' =>
        'That person no longer holds that role here. Refresh and try again.',
      _ => PostgrestFailure.friendlyMessage(e, fallback),
    };
    return MinistryFailure(message, code: code, reason: e.message);
  }
}

final ministryRepositoryProvider = Provider<MinistryRepository>((ref) {
  return MinistryRepository(ref.watch(supabaseClientProvider));
});
