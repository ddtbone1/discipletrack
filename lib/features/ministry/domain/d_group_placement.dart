import 'package:flutter/foundation.dart';

/// A person's membership of a D Group (`d_group_placements`, Migration 012),
/// as the group's Coordinator or Leader sees it. Being placed is separate
/// from holding a responsibility: a placement with no responsibility is the
/// derived "Needs setup" state.
@immutable
class DGroupPlacement {
  const DGroupPlacement({
    required this.placementId,
    required this.churchMembershipId,
    required this.fullName,
    required this.startedAt,
    this.phone,
  });

  /// Shape of `d_group_placements?select=id,church_membership_id,started_at,
  /// member:church_memberships!...(profile:profiles!...(full_name,phone))`.
  factory DGroupPlacement.fromMap(Map<String, dynamic> map) {
    final member = map['member'] as Map<String, dynamic>?;
    final profile = member?['profile'] as Map<String, dynamic>?;
    return DGroupPlacement(
      placementId: map['id'] as String,
      churchMembershipId: map['church_membership_id'] as String,
      fullName: (profile?['full_name'] as String?) ?? 'Unnamed member',
      phone: profile?['phone'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
    );
  }

  final String placementId;
  final String churchMembershipId;
  final String fullName;
  final String? phone;
  final DateTime startedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DGroupPlacement &&
          other.placementId == placementId &&
          other.fullName == fullName &&
          other.phone == phone;

  @override
  int get hashCode => Object.hash(placementId, fullName, phone);
}

/// One row of `list_addable_members()`: an ACTIVE member in no D Group, by
/// name only.
@immutable
class AddableMember {
  const AddableMember({
    required this.churchMembershipId,
    required this.fullName,
    this.joinedAt,
  });

  factory AddableMember.fromMap(Map<String, dynamic> map) => AddableMember(
    churchMembershipId: map['church_membership_id'] as String,
    fullName: map['full_name'] as String,
    joinedAt: map['joined_at'] == null
        ? null
        : DateTime.parse(map['joined_at'] as String),
  );

  final String churchMembershipId;
  final String fullName;
  final DateTime? joinedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddableMember &&
          other.churchMembershipId == churchMembershipId &&
          other.fullName == fullName;

  @override
  int get hashCode => Object.hash(churchMembershipId, fullName);
}
