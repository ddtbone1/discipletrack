import 'package:flutter/foundation.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../membership/domain/church_membership.dart';

/// Mirrors the `platform_role` enum (Migration 023, ADR-022).
enum PlatformRole {
  superAdmin;

  static PlatformRole? fromDb(String value) => switch (value) {
    'SUPER_ADMIN' => PlatformRole.superAdmin,
    _ => null,
  };
}

/// The person's active platform roles, tagged with whose they are so a value
/// left over from another user is never read as this one's.
@immutable
class PlatformAccess {
  const PlatformAccess({required this.userId, required this.roles});

  final String userId;
  final Set<PlatformRole> roles;

  bool get isSuperAdmin => roles.contains(PlatformRole.superAdmin);
}

/// One active Coordinator of a church, as `list_churches()` names them: the
/// one identity a Super Admin sees (ADR-022 decision 5).
@immutable
class CoordinatorRef {
  const CoordinatorRef({
    required this.membershipId,
    required this.fullName,
    required this.email,
  });

  factory CoordinatorRef.fromMap(Map<String, dynamic> map) => CoordinatorRef(
    membershipId: map['membership_id'] as String,
    fullName: map['full_name'] as String,
    email: map['email'] as String? ?? '',
  );

  final String membershipId;
  final String fullName;
  final String email;
}

/// A row of `list_churches()`: a church and its counts, never its members.
@immutable
class PlatformChurch {
  const PlatformChurch({
    required this.id,
    required this.name,
    required this.status,
    required this.joinCode,
    required this.createdAt,
    required this.membersActive,
    required this.membersPending,
    required this.membersOther,
    required this.dGroups,
    required this.coordinators,
    this.joinCodeSetAt,
  });

  factory PlatformChurch.fromMap(Map<String, dynamic> map) {
    DateTime? at(String key) =>
        map[key] == null ? null : DateTime.parse(map[key] as String);
    return PlatformChurch(
      id: map['church_id'] as String,
      name: map['name'] as String,
      status: ChurchStatus.fromDb(map['status'] as String),
      joinCode: map['join_code'] as String,
      joinCodeSetAt: at('join_code_updated_at'),
      createdAt: at('created_at') ?? DateTime.fromMillisecondsSinceEpoch(0),
      membersActive: map['members_active'] as int? ?? 0,
      membersPending: map['members_pending'] as int? ?? 0,
      membersOther: map['members_other'] as int? ?? 0,
      dGroups: map['d_groups'] as int? ?? 0,
      coordinators: [
        for (final c in (map['coordinators'] as List?) ?? const [])
          CoordinatorRef.fromMap((c as Map).cast<String, dynamic>()),
      ],
    );
  }

  final String id;
  final String name;
  final ChurchStatus status;
  final String joinCode;
  final DateTime? joinCodeSetAt;
  final DateTime createdAt;
  final int membersActive;
  final int membersPending;
  final int membersOther;
  final int dGroups;
  final List<CoordinatorRef> coordinators;

  bool get isArchived => status == ChurchStatus.archived;

  /// "24 members · 3 D Groups" (UI_DESIGN_SYSTEM section 70).
  String get countsLine {
    String n(int v, String one, String many) => '$v ${v == 1 ? one : many}';
    return '${n(membersActive, 'member', 'members')} · '
        '${n(dGroups, 'D Group', 'D Groups')}';
  }

  /// The Coordinator's name, or "2 Coordinators".
  String get coordinatorLine => switch (coordinators.length) {
    0 => 'No Coordinator',
    1 => coordinators.single.fullName,
    final n => '$n Coordinators',
  };
}

/// Where an account belongs, from `preview_coordinator_account()`.
enum AccountMembership {
  none,
  thisChurch,
  otherChurch;

  static AccountMembership fromDb(String? value) => switch (value) {
    'THIS_CHURCH' => AccountMembership.thisChurch,
    'OTHER_CHURCH' => AccountMembership.otherChurch,
    _ => AccountMembership.none,
  };
}

/// The confirm step's answer: whose account an email is, and nothing else
/// about the person (ADR-022 decision 8).
@immutable
class AccountPreview {
  const AccountPreview({
    required this.found,
    required this.emailConfirmed,
    required this.membership,
    required this.isCoordinator,
    this.fullName,
  });

  factory AccountPreview.fromMap(Map<String, dynamic> map) => AccountPreview(
    found: map['account_found'] as bool? ?? false,
    emailConfirmed: map['email_confirmed'] as bool? ?? false,
    fullName: map['full_name'] as String?,
    membership: AccountMembership.fromDb(map['membership'] as String?),
    isCoordinator: map['is_coordinator'] as bool? ?? false,
  );

  final bool found;
  final bool emailConfirmed;
  final String? fullName;
  final AccountMembership membership;
  final bool isCoordinator;

  /// Why this account cannot be made a Coordinator here, in the words of
  /// UI_DESIGN_SYSTEM section 70, or null when it can.
  String? get problem {
    if (!found) return PlatformFailure.messageFor('account_not_found');
    if (!emailConfirmed) {
      return PlatformFailure.messageFor('email_not_confirmed');
    }
    if (membership == AccountMembership.otherChurch) {
      return PlatformFailure.messageFor('member_of_another_church');
    }
    if (isCoordinator) {
      return '$fullName is already a Coordinator of this church.';
    }
    return null;
  }
}

/// A platform audit event (`list_platform_audit()`).
@immutable
class PlatformEvent {
  const PlatformEvent({
    required this.id,
    required this.at,
    required this.action,
    this.actorName,
    this.churchName,
    this.metadata = const {},
  });

  factory PlatformEvent.fromMap(Map<String, dynamic> map) => PlatformEvent(
    id: map['event_id'] as String,
    at: DateTime.parse(map['created_at'] as String),
    action: map['action'] as String,
    actorName: map['actor_name'] as String?,
    churchName: map['church_name'] as String?,
    metadata: (map['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
  );

  final String id;
  final DateTime at;
  final String action;
  final String? actorName;
  final String? churchName;
  final Map<String, dynamic> metadata;

  /// What happened, in plain words.
  String get label => switch (action) {
    'CHURCH_CREATED' => 'Church created',
    'COORDINATOR_ASSIGNED' => 'Coordinator added',
    'COORDINATOR_REPLACED' => 'Coordinator replaced',
    'COORDINATOR_ENDED' => 'Coordinator removed',
    'JOIN_CODE_REGENERATED' => 'Join code changed',
    'CHURCH_STATUS_CHANGED' => switch (metadata['to']) {
      'SUSPENDED' => 'Church suspended',
      'ACTIVE' => 'Church reactivated',
      'ARCHIVED' => 'Church archived',
      _ => 'Status changed',
    },
    'CHURCH_ROLE_ENDED' => 'Former Admin role ended',
    'PLATFORM_ROLE_GRANTED' => 'Super Admin granted',
    'PLATFORM_ROLE_ENDED' => 'Super Admin ended',
    _ => action,
  };
}

/// A refused or failed platform operation, with its database reason.
class PlatformFailure implements Exception, NetworkAwareFailure {
  const PlatformFailure(this.message, {this.reason, this.isNetwork = false});

  final String message;

  /// The function's refusal (for example `last_coordinator`), when it gave one.
  final String? reason;

  @override
  final bool isNetwork;

  /// The sentence for each refusal (UI_DESIGN_SYSTEM section 70).
  static String? messageFor(String reason) => switch (reason) {
    'account_not_found' =>
      'No DiscipleTrack account uses that email. Ask them to register first.',
    'email_not_confirmed' => "That account hasn't confirmed its email yet.",
    'member_of_another_church' =>
      'That person already belongs to another church.',
    'cannot_assign_self' =>
      "You can't make yourself a Coordinator. Ask another Super Admin.",
    'already_coordinator' => 'That person is already a Coordinator here.',
    'last_coordinator' =>
      'An active church needs a Coordinator. Replace this one instead.',
    'church_archived' => "This church is archived, so it can't be changed.",
    'coordinator_required' =>
      'A church needs a Coordinator before it can be reactivated.',
    'status_unchanged' => 'The church already has that status.',
    'church_name_required' => 'Enter the church name.',
    'church_not_found' => "That church couldn't be found.",
    'coordinator_not_found' => 'That person is no longer a Coordinator here.',
    'not_authorized' => 'Only a Super Admin can do this.',
    _ => null,
  };

  @override
  String toString() => message;
}
