import 'package:flutter/foundation.dart';

import 'd_group_member.dart';

/// Mirrors the `d_group_status` enum in Migration 001. Groups stay ACTIVE in
/// this slice; the lifecycle operation comes later.
enum DGroupStatus {
  active,
  inactive,
  archived;

  static DGroupStatus fromDb(String value) => switch (value) {
    'ACTIVE' => DGroupStatus.active,
    'INACTIVE' => DGroupStatus.inactive,
    'ARCHIVED' => DGroupStatus.archived,
    _ => throw ArgumentError('Unknown d_group_status: $value'),
  };
}

@immutable
class DGroup {
  const DGroup({
    required this.id,
    required this.name,
    required this.status,
    this.description,
  });

  factory DGroup.fromMap(Map<String, dynamic> map) => DGroup(
    id: map['id'] as String,
    name: map['name'] as String,
    description: map['description'] as String?,
    status: DGroupStatus.fromDb(map['status'] as String),
  );

  final String id;
  final String name;
  final String? description;
  final DGroupStatus status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DGroup &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.status == status;

  @override
  int get hashCode => Object.hash(id, name, description, status);
}

/// A row in the Coordinator's list: the group, its Leader and how many people
/// hold each responsibility now (UI_DESIGN_SYSTEM section 35: a group list
/// item carries the name, Leader and member count).
@immutable
class DGroupSummary {
  const DGroupSummary({
    required this.group,
    required this.leaderName,
    required this.disciplerCount,
    required this.discipleCount,
    this.memberCount,
  });

  /// Shape of `d_groups?select=id,name,description,status,members:
  /// d_group_memberships!...(responsibility,member:church_memberships!...(
  /// profile:profiles!...(full_name)))` with the embed filtered to active rows.
  factory DGroupSummary.fromMap(Map<String, dynamic> map) {
    final members = (map['members'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    String? leaderName;
    var disciplers = 0;
    var disciples = 0;
    for (final m in members) {
      switch (DGroupResponsibility.fromDb(m['responsibility'] as String)) {
        case DGroupResponsibility.leader:
          final member = m['member'] as Map<String, dynamic>?;
          final profile = member?['profile'] as Map<String, dynamic>?;
          leaderName = profile?['full_name'] as String?;
        case DGroupResponsibility.discipler:
          disciplers++;
        case DGroupResponsibility.disciple:
          disciples++;
      }
    }
    return DGroupSummary(
      group: DGroup.fromMap(map),
      leaderName: leaderName,
      disciplerCount: disciplers,
      discipleCount: disciples,
      memberCount: (map['placements'] as List<dynamic>?)?.length,
    );
  }

  final DGroup group;

  /// Null only if a group somehow had no active Leader, which the operations
  /// never allow.
  final String? leaderName;
  final int disciplerCount;
  final int discipleCount;

  /// Everyone placed in the group, including the Leader and people who still
  /// need setup (ADR-018). Disciple and Discipler counts above are
  /// responsibility counts. Null when the read did not include placements.
  final int? memberCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DGroupSummary &&
          other.group == group &&
          other.leaderName == leaderName &&
          other.disciplerCount == disciplerCount &&
          other.discipleCount == discipleCount &&
          other.memberCount == memberCount;

  @override
  int get hashCode => Object.hash(
    group,
    leaderName,
    disciplerCount,
    discipleCount,
    memberCount,
  );
}
