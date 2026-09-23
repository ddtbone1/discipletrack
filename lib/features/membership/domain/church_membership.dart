import 'package:flutter/foundation.dart';

/// Mirrors the `membership_status` enum in Migration 001.
///
/// DATABASE_CONSTRAINTS section 1 and RBAC_RLS_MATRIX section 1a define what
/// each status grants. The client uses them only to choose a route; the
/// database remains the authority on what may actually be read.
enum MembershipStatus {
  pending,
  active,
  inactive,
  transferred,
  archived;

  static MembershipStatus fromDb(String value) => switch (value) {
    'PENDING' => MembershipStatus.pending,
    'ACTIVE' => MembershipStatus.active,
    'INACTIVE' => MembershipStatus.inactive,
    'TRANSFERRED' => MembershipStatus.transferred,
    'ARCHIVED' => MembershipStatus.archived,
    _ => throw ArgumentError('Unknown membership_status: $value'),
  };

  /// RBAC section 1a: only an ACTIVE membership grants normal church access.
  /// PENDING sees onboarding only; the rest have no protected church access.
  bool get grantsChurchAccess => this == MembershipStatus.active;
}

/// A row of `public.church_memberships`, readable only for oneself under the
/// policy added in Migration 003.
@immutable
class ChurchMembership {
  const ChurchMembership({
    required this.id,
    required this.churchId,
    required this.userId,
    required this.status,
    this.joinedAt,
  });

  factory ChurchMembership.fromMap(Map<String, dynamic> map) {
    return ChurchMembership(
      id: map['id'] as String,
      churchId: map['church_id'] as String,
      userId: map['user_id'] as String,
      status: MembershipStatus.fromDb(map['status'] as String),
      joinedAt: map['joined_at'] == null
          ? null
          : DateTime.parse(map['joined_at'] as String),
    );
  }

  final String id;
  final String churchId;
  final String userId;
  final MembershipStatus status;
  final DateTime? joinedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChurchMembership && other.id == id && other.status == status;

  @override
  int get hashCode => Object.hash(id, status);

  @override
  String toString() => 'ChurchMembership($id, ${status.name})';
}
