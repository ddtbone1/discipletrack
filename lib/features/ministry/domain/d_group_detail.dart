import 'package:flutter/foundation.dart';

import 'd_group.dart';
import 'd_group_invitation.dart';
import 'd_group_member.dart';
import 'discipler_assignment.dart';

/// Everything the group detail screen shows to the group's Coordinator or
/// Leader: active responsibilities, active pairings and recent invitations.
@immutable
class DGroupDetail {
  const DGroupDetail({
    required this.group,
    required this.members,
    required this.assignments,
    required this.invitations,
  });

  final DGroup group;

  /// Active rows only.
  final List<DGroupMember> members;

  /// Active pairings only.
  final List<DisciplerAssignment> assignments;

  /// Newest first, every status.
  final List<DGroupInvitation> invitations;

  DGroupMember? get leader {
    for (final m in members) {
      if (m.responsibility == DGroupResponsibility.leader) return m;
    }
    return null;
  }

  List<DGroupMember> get disciplers => _with(DGroupResponsibility.discipler);
  List<DGroupMember> get disciples => _with(DGroupResponsibility.disciple);

  List<DGroupMember> _with(DGroupResponsibility r) =>
      [
        for (final m in members)
          if (m.responsibility == r) m,
      ]..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

  /// The Discipler a Disciple is paired with, if any.
  DGroupMember? disciplerOf(DGroupMember disciple) {
    for (final a in assignments) {
      if (a.discipleDGroupMembershipId == disciple.dGroupMembershipId) {
        for (final d in disciplers) {
          if (d.dGroupMembershipId == a.disciplerDGroupMembershipId) return d;
        }
      }
    }
    return null;
  }

  List<DGroupMember> disciplesOf(DGroupMember discipler) {
    final ids = {
      for (final a in assignments)
        if (a.disciplerDGroupMembershipId == discipler.dGroupMembershipId)
          a.discipleDGroupMembershipId,
    };
    return [
      for (final d in disciples)
        if (ids.contains(d.dGroupMembershipId)) d,
    ];
  }

  /// Whether the Leader also holds a DISCIPLER row here.
  bool get leaderIsDiscipler {
    final l = leader;
    if (l == null) return false;
    return disciplers.any((d) => d.churchMembershipId == l.churchMembershipId);
  }

  /// Invitations still waiting for an answer.
  List<DGroupInvitation> openInvitationsAt(DateTime now) => [
    for (final i in invitations)
      if (i.isOpenAt(now)) i,
  ];

  /// Declined or lapsed invitations from the last 14 days whose invitee has
  /// not been invited again or placed since, newest first. These are what an
  /// inviter may want to act on again (Plan decision 3: a decline is shown to
  /// the inviter, who may re-invite).
  List<DGroupInvitation> closedInvitationsAt(DateTime now) {
    final cutoff = now.subtract(const Duration(days: 14));
    final placed = {for (final m in members) m.churchMembershipId};
    final seen = <String?>{};
    final result = <DGroupInvitation>[];
    for (final i in invitations) {
      // Only the newest invitation per person counts.
      if (!seen.add(i.churchMembershipId)) continue;
      final status = i.statusAt(now);
      final closedAt = i.respondedAt ?? i.expiresAt;
      if ((status == DGroupInvitationStatus.declined ||
              status == DGroupInvitationStatus.expired) &&
          closedAt.isAfter(cutoff) &&
          !placed.contains(i.churchMembershipId)) {
        result.add(i);
      }
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DGroupDetail &&
          other.group == group &&
          listEquals(other.members, members) &&
          listEquals(other.assignments, assignments) &&
          listEquals(other.invitations, invitations);

  @override
  int get hashCode => Object.hash(
    group,
    Object.hashAll(members),
    Object.hashAll(assignments),
    Object.hashAll(invitations),
  );
}
