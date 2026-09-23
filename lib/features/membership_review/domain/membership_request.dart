import 'package:flutter/foundation.dart';

/// A PENDING membership as an approver sees it: who asked, and when.
///
/// Only the applicant's name and request date are shown. Their email lives in
/// Supabase Auth, not in `profiles`, and is deliberately not exposed to
/// approvers in this slice.
@immutable
class MembershipRequest {
  const MembershipRequest({
    required this.membershipId,
    required this.fullName,
    required this.requestedAt,
  });

  /// Shape of `church_memberships?select=id,created_at,profiles!church_memberships_user_id_fkey(full_name)`.
  factory MembershipRequest.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return MembershipRequest(
      membershipId: map['id'] as String,
      // Null only if the profiles read scope were missing; the database
      // policy in Migration 005 grants it, so this is a visible fallback
      // rather than a silent blank.
      fullName: (profile?['full_name'] as String?) ?? 'Unnamed member',
      requestedAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String membershipId;
  final String fullName;
  final DateTime requestedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MembershipRequest &&
          other.membershipId == membershipId &&
          other.fullName == fullName &&
          other.requestedAt == requestedAt;

  @override
  int get hashCode => Object.hash(membershipId, fullName, requestedAt);
}
