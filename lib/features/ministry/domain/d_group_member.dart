import 'package:flutter/foundation.dart';

/// Mirrors the `d_group_responsibility` enum in Migration 001.
enum DGroupResponsibility {
  leader,
  discipler,
  disciple;

  static DGroupResponsibility fromDb(String value) => switch (value) {
    'LEADER' => DGroupResponsibility.leader,
    'DISCIPLER' => DGroupResponsibility.discipler,
    'DISCIPLE' => DGroupResponsibility.disciple,
    _ => throw ArgumentError('Unknown d_group_responsibility: $value'),
  };

  String get toDb => name.toUpperCase();

  String get label => switch (this) {
    DGroupResponsibility.leader => 'Leader',
    DGroupResponsibility.discipler => 'Discipler',
    DGroupResponsibility.disciple => 'Disciple',
  };
}

/// One active responsibility in a D Group, as the group's Coordinator or
/// Leader sees it (`d_group_memberships` with the person's name embedded).
///
/// A Leader who is also a Discipler has two of these, one per row.
@immutable
class DGroupMember {
  const DGroupMember({
    required this.dGroupMembershipId,
    required this.churchMembershipId,
    required this.fullName,
    required this.responsibility,
    required this.startedAt,
    this.phone,
  });

  /// Shape of `d_group_memberships?select=id,church_membership_id,
  /// responsibility,started_at,member:church_memberships!...(profile:
  /// profiles!...(full_name,phone))`.
  factory DGroupMember.fromMap(Map<String, dynamic> map) {
    final member = map['member'] as Map<String, dynamic>?;
    final profile = member?['profile'] as Map<String, dynamic>?;
    return DGroupMember(
      dGroupMembershipId: map['id'] as String,
      churchMembershipId: map['church_membership_id'] as String,
      // Null only if the read scope were missing; a visible fallback beats a
      // silent blank.
      fullName: (profile?['full_name'] as String?) ?? 'Unnamed member',
      phone: profile?['phone'] as String?,
      responsibility: DGroupResponsibility.fromDb(
        map['responsibility'] as String,
      ),
      startedAt: DateTime.parse(map['started_at'] as String),
    );
  }

  final String dGroupMembershipId;
  final String churchMembershipId;
  final String fullName;
  final String? phone;
  final DGroupResponsibility responsibility;
  final DateTime startedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DGroupMember &&
          other.dGroupMembershipId == dGroupMembershipId &&
          other.fullName == fullName &&
          other.phone == phone;

  @override
  int get hashCode => Object.hash(dGroupMembershipId, fullName, phone);
}
