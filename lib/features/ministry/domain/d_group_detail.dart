import 'package:flutter/foundation.dart';

import 'd_group.dart';
import 'd_group_member.dart';
import 'd_group_placement.dart';
import 'discipler_assignment.dart';

/// One person in the group, as the D Group page lists them: their placement
/// and whatever responsibilities they hold. Derived from the rows on screen,
/// never stored.
@immutable
class GroupPerson {
  const GroupPerson({required this.placement, required this.rows});

  final DGroupPlacement placement;

  /// Active responsibility rows, possibly none.
  final List<DGroupMember> rows;

  String get churchMembershipId => placement.churchMembershipId;
  String get fullName => placement.fullName;

  DGroupMember? _row(DGroupResponsibility r) {
    for (final m in rows) {
      if (m.responsibility == r) return m;
    }
    return null;
  }

  DGroupMember? get leaderRow => _row(DGroupResponsibility.leader);
  DGroupMember? get disciplerRow => _row(DGroupResponsibility.discipler);
  DGroupMember? get discipleRow => _row(DGroupResponsibility.disciple);

  bool get isLeader => leaderRow != null;
  bool get isDiscipler => disciplerRow != null;
  bool get isDisciple => discipleRow != null;

  /// Placed with no responsibility yet (Slice 6: "Needs setup").
  bool get needsSetup => rows.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupPerson &&
          other.placement == placement &&
          listEquals(other.rows, rows);

  @override
  int get hashCode => Object.hash(placement, Object.hashAll(rows));
}

/// The D Group page's local filters. Counts and membership are derived from
/// the rows on screen.
enum GroupFilter {
  all('All'),
  disciples('Disciples'),
  disciplers('Disciplers'),
  needsSetup('Needs setup');

  const GroupFilter(this.label);

  final String label;

  bool includes(GroupPerson p) => switch (this) {
    GroupFilter.all => true,
    GroupFilter.disciples => p.isDisciple,
    GroupFilter.disciplers => p.isDiscipler,
    GroupFilter.needsSetup => p.needsSetup,
  };
}

/// Everything the group page shows to the group's Coordinator or Leader:
/// who is in the group, what each person holds, and the active pairings.
@immutable
class DGroupDetail {
  const DGroupDetail({
    required this.group,
    required this.placements,
    required this.members,
    required this.assignments,
  });

  final DGroup group;

  /// Active placements: everyone in the group, set up or not.
  final List<DGroupPlacement> placements;

  /// Active responsibility rows only.
  final List<DGroupMember> members;

  /// Active pairings only.
  final List<DisciplerAssignment> assignments;

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

  /// Everyone in the group except a Leader who holds nothing else, by name.
  /// The Leader has their own card; a Leader who is also a Discipler appears
  /// here too, because they can be paired.
  List<GroupPerson> get people {
    final byPerson = <String, List<DGroupMember>>{};
    for (final m in members) {
      byPerson.putIfAbsent(m.churchMembershipId, () => []).add(m);
    }
    final result = <GroupPerson>[
      for (final p in placements)
        GroupPerson(placement: p, rows: byPerson[p.churchMembershipId] ?? []),
    ];
    result.removeWhere((p) => p.isLeader && !p.isDiscipler);
    result.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return result;
  }

  /// How many people each filter shows.
  Map<GroupFilter, int> get filterCounts {
    final all = people;
    return {
      for (final f in GroupFilter.values) f: all.where(f.includes).length,
    };
  }

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

  /// The Disciplers [disciple] may be paired with: anyone else holding
  /// DISCIPLER here, except someone they currently disciple (D7, no
  /// reciprocal pairing). The database refuses the same cases.
  List<DGroupMember> pairableDisciplersFor(DGroupMember disciple) {
    final theirDisciples = <String>{};
    for (final dr in disciplers) {
      if (dr.churchMembershipId == disciple.churchMembershipId) {
        theirDisciples.addAll(disciplesOf(dr).map((d) => d.churchMembershipId));
      }
    }
    return [
      for (final dr in disciplers)
        if (dr.churchMembershipId != disciple.churchMembershipId &&
            !theirDisciples.contains(dr.churchMembershipId))
          dr,
    ];
  }

  /// Whether the Leader also holds a DISCIPLER row here.
  bool get leaderIsDiscipler {
    final l = leader;
    if (l == null) return false;
    return disciplers.any((d) => d.churchMembershipId == l.churchMembershipId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DGroupDetail &&
          other.group == group &&
          listEquals(other.placements, placements) &&
          listEquals(other.members, members) &&
          listEquals(other.assignments, assignments);

  @override
  int get hashCode => Object.hash(
    group,
    Object.hashAll(placements),
    Object.hashAll(members),
    Object.hashAll(assignments),
  );
}
