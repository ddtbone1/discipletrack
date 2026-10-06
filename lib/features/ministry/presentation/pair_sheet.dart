import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_pill.dart';
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
/// no limit on how many Disciples one Discipler has (Slice 3 decision 4), so
/// every Discipler they may be paired with is offered, with their current
/// count for context. A Disciple who is also a Discipler is never offered
/// themselves, nor someone they disciple (ADR-012; D7); the database
/// refuses both anyway.
Future<PairSelection?> showPairSheet(
  BuildContext context, {
  required DGroupDetail detail,
  required DGroupMember disciple,
}) {
  final current = detail.disciplerOf(disciple);
  return showModalBottomSheet<PairSelection>(
    context: context,
    // Above the floating dock, which lives in the shell route.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final p = context.palette;
      final disciplers = detail.pairableDisciplersFor(disciple);
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
                    'There is no Discipler in this group to pair with yet. '
                    'Set someone up as a Discipler first.',
                    style: context.supportingStyle,
                  ),
                ),
              for (final d in disciplers)
                ListTile(
                  leading: InitialsAvatar(name: d.fullName),
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
