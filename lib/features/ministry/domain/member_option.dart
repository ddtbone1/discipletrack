import 'package:flutter/foundation.dart';

import 'd_group_member.dart';

/// What a member is being picked for. The database decides in the end; this
/// only explains up front why a choice would be refused.
enum MemberPickPurpose {
  /// Leader of a new group (`create_d_group()`), or the replacement Leader of
  /// an existing one (`assign_d_group_leader()`).
  appointLeader,
}

/// One row of `list_placeable_members()`: a member's name and current
/// placement, never their phone number.
@immutable
class MemberOption {
  const MemberOption({
    required this.churchMembershipId,
    required this.fullName,
    this.currentDGroupId,
    this.currentDGroupName,
    this.currentResponsibilities = const {},
  });

  factory MemberOption.fromMap(Map<String, dynamic> map) {
    final roles = (map['current_responsibilities'] as List<dynamic>?) ?? [];
    return MemberOption(
      churchMembershipId: map['church_membership_id'] as String,
      fullName: map['full_name'] as String,
      currentDGroupId: map['current_d_group_id'] as String?,
      currentDGroupName: map['current_d_group_name'] as String?,
      currentResponsibilities: {
        for (final r in roles) DGroupResponsibility.fromDb(r as String),
      },
    );
  }

  final String churchMembershipId;
  final String fullName;
  final String? currentDGroupId;
  final String? currentDGroupName;

  /// Empty while placed: the person still needs setup.
  final Set<DGroupResponsibility> currentResponsibilities;

  bool get isPlaced => currentDGroupId != null;

  /// "Leader and Discipler in Young Adults A", "In Young Adults A, not set
  /// up yet", or null when in no group.
  String? get placementLabel {
    if (!isPlaced) return null;
    final group = currentDGroupName ?? 'a D Group';
    if (currentResponsibilities.isEmpty) return 'In $group, not set up yet';
    final roles = DGroupResponsibility.values
        .where(currentResponsibilities.contains)
        .map((r) => r.label)
        .join(' and ');
    return '$roles in $group';
  }

  /// Why this member cannot be chosen for [purpose], or null when they can.
  ///
  /// [dGroupId] is the group being acted on, if any: someone in that group
  /// holding nothing but DISCIPLER, or nothing yet, may become its Leader
  /// (Migration 012, assign_d_group_leader()).
  String? ineligibilityReason(MemberPickPurpose purpose, {String? dGroupId}) {
    switch (purpose) {
      case MemberPickPurpose.appointLeader:
        if (!isPlaced) return null;
        if (dGroupId != null && currentDGroupId == dGroupId) {
          if (currentResponsibilities.contains(DGroupResponsibility.leader)) {
            return 'Already leads this group';
          }
          if (currentResponsibilities.contains(DGroupResponsibility.disciple)) {
            return 'A Disciple cannot also lead the group';
          }
          return null;
        }
        return 'Already ${placementLabel!}';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberOption &&
          other.churchMembershipId == churchMembershipId &&
          other.fullName == fullName &&
          other.currentDGroupId == currentDGroupId &&
          setEquals(other.currentResponsibilities, currentResponsibilities);

  @override
  int get hashCode => Object.hash(
    churchMembershipId,
    fullName,
    currentDGroupId,
    Object.hashAllUnordered(currentResponsibilities),
  );
}
