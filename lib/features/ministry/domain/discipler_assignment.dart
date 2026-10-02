import 'package:flutter/foundation.dart';

/// An active Discipler -> Disciple pairing (`discipler_assignments`).
@immutable
class DisciplerAssignment {
  const DisciplerAssignment({
    required this.id,
    required this.disciplerDGroupMembershipId,
    required this.discipleDGroupMembershipId,
    required this.startedAt,
  });

  factory DisciplerAssignment.fromMap(Map<String, dynamic> map) =>
      DisciplerAssignment(
        id: map['id'] as String,
        disciplerDGroupMembershipId:
            map['discipler_d_group_membership_id'] as String,
        discipleDGroupMembershipId:
            map['disciple_d_group_membership_id'] as String,
        startedAt: DateTime.parse(map['started_at'] as String),
      );

  final String id;
  final String disciplerDGroupMembershipId;
  final String discipleDGroupMembershipId;
  final DateTime startedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisciplerAssignment &&
          other.id == id &&
          other.disciplerDGroupMembershipId == disciplerDGroupMembershipId &&
          other.discipleDGroupMembershipId == discipleDGroupMembershipId;

  @override
  int get hashCode =>
      Object.hash(id, disciplerDGroupMembershipId, discipleDGroupMembershipId);
}
