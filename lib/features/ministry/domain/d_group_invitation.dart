import 'package:flutter/foundation.dart';

import 'd_group_member.dart';

/// Mirrors the `d_group_invitation_status` enum in Migration 006.
enum DGroupInvitationStatus {
  pending,
  accepted,
  declined,
  withdrawn,
  expired;

  static DGroupInvitationStatus fromDb(String value) => switch (value) {
    'PENDING' => DGroupInvitationStatus.pending,
    'ACCEPTED' => DGroupInvitationStatus.accepted,
    'DECLINED' => DGroupInvitationStatus.declined,
    'WITHDRAWN' => DGroupInvitationStatus.withdrawn,
    'EXPIRED' => DGroupInvitationStatus.expired,
    _ => throw ArgumentError('Unknown d_group_invitation_status: $value'),
  };
}

/// An invitation to join a D Group as Discipler or Disciple.
///
/// Built from two shapes: a `d_group_invitations` row as the group's
/// Coordinator or Leader reads it, and a `get_my_pending_invitation()` row as
/// the invitee sees it. Fields only one side has are nullable.
@immutable
class DGroupInvitation {
  const DGroupInvitation({
    required this.id,
    required this.dGroupId,
    required this.responsibility,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.churchMembershipId,
    this.inviteeName,
    this.dGroupName,
    this.invitedBy,
    this.invitedByName,
    this.respondedAt,
  });

  /// A row of `d_group_invitations` with the invitee's name embedded.
  factory DGroupInvitation.fromMap(Map<String, dynamic> map) {
    final invitee = map['invitee'] as Map<String, dynamic>?;
    final profile = invitee?['profile'] as Map<String, dynamic>?;
    return DGroupInvitation(
      id: map['id'] as String,
      dGroupId: map['d_group_id'] as String,
      churchMembershipId: map['church_membership_id'] as String?,
      inviteeName: (profile?['full_name'] as String?) ?? 'Unnamed member',
      responsibility: DGroupResponsibility.fromDb(
        map['responsibility'] as String,
      ),
      status: DGroupInvitationStatus.fromDb(map['status'] as String),
      invitedBy: map['invited_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      respondedAt: map['responded_at'] == null
          ? null
          : DateTime.parse(map['responded_at'] as String),
    );
  }

  /// A row of `get_my_pending_invitation()`.
  factory DGroupInvitation.fromPendingMap(Map<String, dynamic> map) =>
      DGroupInvitation(
        id: map['invitation_id'] as String,
        dGroupId: map['d_group_id'] as String,
        dGroupName: map['d_group_name'] as String,
        responsibility: DGroupResponsibility.fromDb(
          map['responsibility'] as String,
        ),
        status: DGroupInvitationStatus.pending,
        invitedByName: map['invited_by_name'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        expiresAt: DateTime.parse(map['expires_at'] as String),
      );

  final String id;
  final String dGroupId;
  final String? dGroupName;
  final String? churchMembershipId;
  final String? inviteeName;
  final DGroupResponsibility responsibility;

  /// As stored. Use [statusAt] for what it means now.
  final DGroupInvitationStatus status;
  final String? invitedBy;
  final String? invitedByName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  /// Expiry is lazy in the database (Migration 006): a PENDING row past
  /// [expiresAt] is EXPIRED in meaning even before any write marks it so.
  DGroupInvitationStatus statusAt(DateTime now) =>
      status == DGroupInvitationStatus.pending && !now.isBefore(expiresAt)
      ? DGroupInvitationStatus.expired
      : status;

  bool isOpenAt(DateTime now) =>
      statusAt(now) == DGroupInvitationStatus.pending;

  /// Whole days left before it lapses, at least 0. "Expires today" is 0.
  int daysLeftAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? 0 : left.inDays;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DGroupInvitation &&
          other.id == id &&
          other.status == status &&
          other.expiresAt == expiresAt &&
          other.respondedAt == respondedAt;

  @override
  int get hashCode => Object.hash(id, status, expiresAt, respondedAt);
}
