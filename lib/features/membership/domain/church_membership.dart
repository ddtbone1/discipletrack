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
///
/// [admin] is retired (ADR-022): no active ADMIN row can exist, and nothing in
/// the app is gated by it. It is kept only so an ended row still parses.
enum ChurchRole {
  admin,
  coordinator;

  static ChurchRole fromDb(String value) => switch (value) {
    'ADMIN' => ChurchRole.admin,
    'COORDINATOR' => ChurchRole.coordinator,
    _ => throw ArgumentError('Unknown church_role: $value'),
  };
}

/// Mirrors the `church_status` enum (Migrations 001 and 022, ADR-022).
enum ChurchStatus {
  active,

  /// Reversible: nobody reads or acts on church data until it is ACTIVE again.
  suspended,

  /// Final in the app; the history is kept.
  archived;

  static ChurchStatus fromDb(String value) => switch (value) {
    'ACTIVE' => ChurchStatus.active,
    'SUSPENDED' => ChurchStatus.suspended,
    'ARCHIVED' => ChurchStatus.archived,
    _ => throw ArgumentError('Unknown church_status: $value'),
  };

  String get toDb => name.toUpperCase();
}

/// The only church fields a member ever sees: `id`, `name` and `status`.
///
/// Migration 005 grants SELECT on exactly `id, name, status`; the join code
/// is unreadable by every client role, and `lookup_church_by_join_code()`
/// returns just the id and name. The status stays readable while the church
/// is SUSPENDED or ARCHIVED, so the app can say the church is unavailable
/// (ADR-022 decision 14). A row without one (a lookup result) is ACTIVE,
/// because the lookup finds ACTIVE churches only.
@immutable
class ChurchSummary {
  const ChurchSummary({
    required this.id,
    required this.name,
    this.status = ChurchStatus.active,
  });

  factory ChurchSummary.fromMap(Map<String, dynamic> map) => ChurchSummary(
    id: (map['church_id'] ?? map['id']) as String,
    name: (map['church_name'] ?? map['name']) as String,
    status: map['status'] == null
        ? ChurchStatus.active
        : ChurchStatus.fromDb(map['status'] as String),
  );

  final String id;
  final String name;
  final ChurchStatus status;

  /// Whether the church grants its members anything (RBAC section 1a).
  bool get isAvailable => status == ChurchStatus.active;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChurchSummary &&
          other.id == id &&
          other.name == name &&
          other.status == status;

  @override
  int get hashCode => Object.hash(id, name, status);

  @override
  String toString() => 'ChurchSummary($id, $name, ${status.name})';
}

/// The church's current join code, as `get_church_join_code()` returns it to
/// its Coordinator (ADR-022 decision 10a). Read-only: only the Super Admin
/// generates or regenerates a code.
@immutable
class ChurchJoinCode {
  const ChurchJoinCode({required this.code, this.setAt});

  final String code;

  /// When the current code was set, at creation or by a regeneration.
  final DateTime? setAt;

  /// The code in two groups of five, easier to read aloud.
  String get grouped =>
      code.length == 10 ? '${code.substring(0, 5)} ${code.substring(5)}' : code;
}

/// A row of `public.church_memberships`, readable for oneself under the
/// policy added in Migration 003 and for one's church as its Coordinator
/// under Migration 005 (ADR-022: the church Admin role is retired).
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
