import 'package:flutter/material.dart';

import '../../../core/widgets/status_pill.dart';
import '../domain/church_membership.dart';

/// The label shown for a membership state. Null means no membership row.
String membershipStatusLabel(MembershipStatus? status) => switch (status) {
  null => 'Not in a church yet',
  MembershipStatus.pending => 'Awaiting approval',
  MembershipStatus.active => 'Active member',
  MembershipStatus.inactive => 'Inactive',
  MembershipStatus.transferred => 'Transferred',
  MembershipStatus.archived => 'Archived',
};

/// A [StatusPill] for a church membership, so every screen describes a
/// membership state with the same words and tone.
class MembershipStatusPill extends StatelessWidget {
  const MembershipStatusPill({required this.status, super.key});

  final MembershipStatus? status;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: membershipStatusLabel(status),
      tone: switch (status) {
        MembershipStatus.active => StatusTone.positive,
        MembershipStatus.pending => StatusTone.waiting,
        _ => StatusTone.neutral,
      },
    );
  }
}
