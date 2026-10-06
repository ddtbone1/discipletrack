import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_pill.dart';
import '../domain/ministry_context.dart';

/// For someone added to a D Group whose role has not been set up yet: which
/// group, who leads it, and that the Leader sets up their role. Nothing is
/// asked of them, so nothing is offered.
class NeedsSetupNotice extends StatelessWidget {
  const NeedsSetupNotice({required this.ministry, super.key});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context) {
    final leader = ministry.leader?.fullName;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppPill(
            tone: PillTone.warning,
            icon: Icons.hourglass_empty_rounded,
            label: 'Role not set up yet',
            outlined: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "You're in ${ministry.dGroupName}",
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            leader == null
                ? 'Your Leader will set up your role in the group.'
                : '$leader, your Leader, will set up your role in the group. '
                      'Your journey starts once that is done.',
            style: context.supportingStyle,
          ),
        ],
      ),
    );
  }
}
