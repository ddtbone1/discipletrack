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

/// Mirrors the `church_role` enum in Migration 001.
enum ChurchRole {
  admin,
  coordinator;

  static ChurchRole fromDb(String value) => switch (value) {
    'ADMIN' => ChurchRole.admin,
    'COORDINATOR' => ChurchRole.coordinator,
    _ => throw ArgumentError('Unknown church_role: $value'),
  };
}

/// The only church fields a client ever sees: `id` and `name`.
///
/// Migration 005 grants SELECT on exactly `id, name, status`; the join code
/// is unreadable by every client role, and `lookup_church_by_join_code()`
/// returns just these two columns.
@immutable
class ChurchSummary {
  const ChurchSummary({required this.id, required this.name});

  factory ChurchSummary.fromMap(Map<String, dynamic> map) => ChurchSummary(
    id: (map['church_id'] ?? map['id']) as String,
    name: (map['church_name'] ?? map['name']) as String,
  );

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChurchSummary && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'ChurchSummary($id, $name)';
}

/// A row of `public.church_memberships`, readable for oneself under the
/// policy added in Migration 003 and for one's church as an Admin or
/// Coordinator under Migration 005.
@immutable
class ChurchMembership {
  const ChurchMembership({
    required this.id,
    required this.churchId,
    required this.userId,
    required this.status,
    this.joinedAt,
    this.requestedAt,
    this.approvedAt,
    this.onboardingCompletedAt,
  });

  factory ChurchMembership.fromMap(Map<String, dynamic> map) {
    DateTime? at(String key) =>
        map[key] == null ? null : DateTime.parse(map[key] as String);
    return ChurchMembership(
      id: map['id'] as String,
      churchId: map['church_id'] as String,
      userId: map['user_id'] as String,
      status: MembershipStatus.fromDb(map['status'] as String),
      joinedAt: at('joined_at'),
      requestedAt: at('created_at'),
      approvedAt: at('approved_at'),
      onboardingCompletedAt: at('onboarding_completed_at'),
    );
  }

  final String id;
  final String churchId;
  final String userId;
  final MembershipStatus status;

  /// The first time the membership became ACTIVE. Never overwritten later.
  final DateTime? joinedAt;

  /// `created_at`: when the join request was made.
  final DateTime? requestedAt;

  /// Set by `approve_church_membership()`; stays null on rejection.
  final DateTime? approvedAt;

  /// Set once by `complete_onboarding()`. While null on an ACTIVE membership,
  /// the app shows the one-time first-entry welcome.
  final DateTime? onboardingCompletedAt;

  /// ACTIVE but the first-entry welcome has not been completed yet.
  bool get needsFirstEntry =>
      status == MembershipStatus.active && onboardingCompletedAt == null;

  /// Equality covers every field the router branches on. A refresh that only
  /// changes `onboardingCompletedAt` must still register as a change, or the
  /// welcome would never give way to Home.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChurchMembership &&
          other.id == id &&
          other.status == status &&
          other.onboardingCompletedAt == onboardingCompletedAt;

  @override
  int get hashCode => Object.hash(id, status, onboardingCompletedAt);

  @override
  String toString() => 'ChurchMembership($id, ${status.name})';
}
