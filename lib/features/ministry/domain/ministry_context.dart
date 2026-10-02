import 'package:flutter/foundation.dart';

import 'd_group_member.dart';

/// One row of `get_my_d_group_roster()`: a group mate by name, with a phone
/// number only where the database allows the caller to see it.
@immutable
class RosterEntry {
  const RosterEntry({
    required this.dGroupMembershipId,
    required this.churchMembershipId,
    required this.fullName,
    required this.responsibility,
    this.phone,
    this.isMe = false,
    this.isMyLeader = false,
    this.isMyDiscipler = false,
    this.isMyDisciple = false,
  });

  factory RosterEntry.fromMap(Map<String, dynamic> map) => RosterEntry(
    dGroupMembershipId: map['d_group_membership_id'] as String,
    churchMembershipId: map['church_membership_id'] as String,
    fullName: map['full_name'] as String,
    responsibility: DGroupResponsibility.fromDb(
      map['responsibility'] as String,
    ),
    phone: map['phone'] as String?,
    isMe: map['is_me'] as bool,
    isMyLeader: map['is_my_leader'] as bool,
    isMyDiscipler: map['is_my_discipler'] as bool,
    isMyDisciple: map['is_my_disciple'] as bool,
  );

  final String dGroupMembershipId;
  final String churchMembershipId;
  final String fullName;
  final DGroupResponsibility responsibility;
  final String? phone;
  final bool isMe;
  final bool isMyLeader;
  final bool isMyDiscipler;
  final bool isMyDisciple;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RosterEntry &&
          other.dGroupMembershipId == dGroupMembershipId &&
          other.fullName == fullName &&
          other.phone == phone &&
          other.isMyDiscipler == isMyDiscipler &&
          other.isMyDisciple == isMyDisciple;

  @override
  int get hashCode => Object.hash(
    dGroupMembershipId,
    fullName,
    phone,
    isMyDiscipler,
    isMyDisciple,
  );
}

/// The caller's place in the ministry structure: their group, what they hold
/// in it, and the people who matter to them there.
///
/// Null (no context) means the member is unplaced. Whether they have a
/// pending invitation is a separate question, answered by
/// `myPendingInvitationProvider`.
@immutable
class MinistryContext {
  const MinistryContext({
    required this.dGroupId,
    required this.dGroupName,
    required this.roster,
  });

  /// Builds the context from `get_my_d_group_roster()` rows, or null when the
  /// caller holds no active responsibility.
  static MinistryContext? fromRosterRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return null;
    return MinistryContext(
      dGroupId: rows.first['d_group_id'] as String,
      dGroupName: rows.first['d_group_name'] as String,
      roster: [for (final r in rows) RosterEntry.fromMap(r)],
    );
  }

  final String dGroupId;
  final String dGroupName;

  /// Ordered Leader, Disciplers, Disciples, then by name.
  final List<RosterEntry> roster;

  Set<DGroupResponsibility> get myResponsibilities => {
    for (final e in roster)
      if (e.isMe) e.responsibility,
  };

  bool get isLeader => myResponsibilities.contains(DGroupResponsibility.leader);
  bool get isDiscipler =>
      myResponsibilities.contains(DGroupResponsibility.discipler);
  bool get isDisciple =>
      myResponsibilities.contains(DGroupResponsibility.disciple);

  /// The group's Leader, unless that is the caller.
  RosterEntry? get leader {
    for (final e in roster) {
      if (e.isMyLeader) return e;
    }
    return null;
  }

  /// The caller's own Discipler, when paired.
  RosterEntry? get myDiscipler {
    for (final e in roster) {
      if (e.isMyDiscipler) return e;
    }
    return null;
  }

  /// The caller's assigned Disciples, when they are a Discipler.
  List<RosterEntry> get myDisciples => [
    for (final e in roster)
      if (e.isMyDisciple) e,
  ];

  /// Everyone else in the group, once each. A person holding two
  /// responsibilities appears under the first of them in roster order.
  List<RosterEntry> get groupMates {
    final seen = <String>{};
    return [
      for (final e in roster)
        if (!e.isMe && seen.add(e.churchMembershipId)) e,
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinistryContext &&
          other.dGroupId == dGroupId &&
          other.dGroupName == dGroupName &&
          listEquals(other.roster, roster);

  @override
  int get hashCode => Object.hash(dGroupId, dGroupName, Object.hashAll(roster));
}
