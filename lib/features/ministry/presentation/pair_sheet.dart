import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/d_group_detail.dart';
import '../domain/d_group_member.dart';
import 'ministry_ui.dart';

/// The choice made in the pair sheet. A null [disciplerDGroupMembershipId]
/// means unpair; dismissing the sheet yields no selection at all.
@immutable
class PairSelection {
  const PairSelection(this.disciplerDGroupMembershipId);
  final String? disciplerDGroupMembershipId;
}

/// Lets a Coordinator or Leader choose the Discipler for [disciple]. There is
/// no limit on how many Disciples one Discipler has (Plan decision 4), so
/// every Discipler is offered, with their current count for context.
Future<PairSelection?> showPairSheet(
  BuildContext context, {
  required DGroupDetail detail,
  required DGroupMember disciple,
}) {
  final current = detail.disciplerOf(disciple);
  return showModalBottomSheet<PairSelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final p = context.palette;
      final disciplers = detail.disciplers;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'Discipler for ${disciple.fullName}',
                  style: AppTypography.sectionTitle.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (disciplers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'This group has no Disciplers yet. Invite someone as '
                    'Discipler first.',
                    style: context.supportingStyle,
                  ),
                ),
              for (final d in disciplers)
                ListTile(
                  title: Text(
                    d.fullName,
                    style: AppTypography.body.copyWith(color: p.textPrimary),
                  ),
                  subtitle: Text(
                    MinistryFormat.count(
                      detail.disciplesOf(d).length,
                      'Disciple',
                    ),
                    style: context.supportingStyle,
                  ),
                  trailing: d.dGroupMembershipId == current?.dGroupMembershipId
                      ? Icon(Icons.check_rounded, color: p.textPrimary)
                      : null,
                  onTap: d.dGroupMembershipId == current?.dGroupMembershipId
                      ? null
                      : () =>
                            Navigator.of(context)
                                .pop(PairSelection(d.dGroupMembershipId)),
                ),
              if (current != null) ...[
                const Divider(),
                ListTile(
                  leading: Icon(Icons.link_off_rounded, color: p.muted),
                  title: Text(
                    'Unpair from ${current.fullName}',
                    style: AppTypography.body.copyWith(color: p.textPrimary),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(const PairSelection(null)),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
