import 'package:flutter/foundation.dart';

import 'd_group_member.dart';

/// What a member is being picked for. The database decides in the end; this
/// only explains up front why a choice would be refused.
enum MemberPickPurpose {
  /// Invite as Discipler or Disciple (`invite_to_d_group()`).
  invite,

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
    required this.hasPendingInvitation,
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
      hasPendingInvitation: map['has_pending_invitation'] as bool,
    );
  }

  final String churchMembershipId;
  final String fullName;
  final String? currentDGroupId;
  final String? currentDGroupName;
  final Set<DGroupResponsibility> currentResponsibilities;
  final bool hasPendingInvitation;

  bool get isPlaced => currentDGroupId != null;

  /// "Leader and Discipler in Young Adults A", or null when unplaced.
  String? get placementLabel {
    if (!isPlaced) return null;
    final roles = DGroupResponsibility.values
        .where(currentResponsibilities.contains)
        .map((r) => r.label)
        .join(' and ');
    return '$roles in ${currentDGroupName ?? 'a D Group'}';
  }

  /// Why this member cannot be chosen for [purpose], or null when they can.
  ///
  /// [dGroupId] is the group being acted on, if any: a Discipler of that
  /// group may become its Leader (Migration 006, assign_d_group_leader()).
  String? ineligibilityReason(MemberPickPurpose purpose, {String? dGroupId}) {
    switch (purpose) {
      case MemberPickPurpose.invite:
        if (isPlaced) return 'Already ${placementLabel!}';
        if (hasPendingInvitation) return 'Has a pending invitation';
        return null;
      case MemberPickPurpose.appointLeader:
        if (!isPlaced) return null;
        final onlyDisciplerHere =
            dGroupId != null &&
            currentDGroupId == dGroupId &&
            currentResponsibilities.length == 1 &&
            currentResponsibilities.single == DGroupResponsibility.discipler;
        if (onlyDisciplerHere) return null;
        if (currentDGroupId == dGroupId &&
            currentResponsibilities.contains(DGroupResponsibility.leader)) {
          return 'Already leads this group';
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
          setEquals(other.currentResponsibilities, currentResponsibilities) &&
          other.hasPendingInvitation == hasPendingInvitation;

  @override
  int get hashCode => Object.hash(
    churchMembershipId,
    fullName,
    currentDGroupId,
    Object.hashAllUnordered(currentResponsibilities),
    hasPendingInvitation,
  );
}
