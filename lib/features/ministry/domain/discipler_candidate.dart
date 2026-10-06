import 'package:flutter/foundation.dart';

/// One row of `list_discipler_candidates()` (Migration 014): a Disciple who
/// completed the eligibility lesson (Lesson 5) and is not a Discipler.
///
/// Eligible is not appointed: only the Coordinator appoints. Eligibility is
/// derived by the database at read time and never stored, so an undo of the
/// lesson removes the person from this list at once.
@immutable
class DisciplerCandidate {
  const DisciplerCandidate({
    required this.churchMembershipId,
    required this.fullName,
    required this.dGroupId,
    required this.dGroupName,
    required this.eligibleSince,
  });

  factory DisciplerCandidate.fromMap(Map<String, dynamic> map) =>
      DisciplerCandidate(
        churchMembershipId: map['church_membership_id'] as String,
        fullName: map['full_name'] as String,
        dGroupId: map['d_group_id'] as String,
        dGroupName: map['d_group_name'] as String,
        eligibleSince: DateTime.parse(map['eligible_since'] as String),
      );

  final String churchMembershipId;
  final String fullName;
  final String dGroupId;
  final String dGroupName;

  /// When the eligibility lesson was completed.
  final DateTime eligibleSince;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisciplerCandidate &&
          other.churchMembershipId == churchMembershipId &&
          other.eligibleSince == eligibleSince;

  @override
  int get hashCode => Object.hash(churchMembershipId, eligibleSince);
}
