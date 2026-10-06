import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/d_group_member.dart';

/// Asks how a member of the group takes part: as a Disciple, or (during the
/// church's initial setup period) as an Existing Discipler, someone who
/// already disciples people in the church.
///
/// Options the person already holds, or may not take, are not offered.
/// When the setup period has ended, Existing Discipler stays visible but
/// disabled with the reason, so the Leader learns the normal path instead
/// of wondering where the option went. The database enforces the same
/// rules (Migration 013, set_up_member()).
///
/// Returns DISCIPLE or DISCIPLER, or null when dismissed.
Future<DGroupResponsibility?> showMemberSetupSheet(
  BuildContext context, {
  required String name,
  required bool offerDisciple,
  required bool offerDiscipler,
  required bool setupOpen,
}) {
  return showModalBottomSheet<DGroupResponsibility>(
    context: context,
    // Above the floating dock, which lives in the shell route.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final p = context.palette;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'Set up $name',
                  style: AppTypography.sectionTitle.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'How do they take part in this group?',
                  style: context.supportingStyle,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (offerDisciple)
                _Option(
                  icon: Icons.person_outline_rounded,
                  title: 'Disciple',
                  detail:
                      'Starts their own journey at Lesson 1. Pair them with a '
                      'Discipler next.',
                  onTap: () =>
                      Navigator.of(context).pop(DGroupResponsibility.disciple),
                ),
              if (offerDiscipler)
                _Option(
                  icon: Icons.school_outlined,
                  title: 'Existing Discipler',
                  detail: setupOpen
                      ? 'Already disciples people in the church. No lessons '
                            'are recorded for them to get here.'
                      : 'The setup period has ended. A Disciple becomes a '
                            'Discipler after Lesson 5, when the Coordinator '
                            'appoints them.',
                  onTap: setupOpen
                      ? () =>
                            Navigator.of(context)
                                .pop(DGroupResponsibility.discipler)
                      : null,
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onTap != null;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? p.textPrimary : p.disabled),
      title: Text(
        title,
        style: AppTypography.body.copyWith(
          color: enabled ? p.textPrimary : p.disabled,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(detail, style: context.supportingStyle),
      trailing: enabled
          ? Icon(Icons.chevron_right_rounded, color: p.muted)
          : Icon(Icons.lock_outline_rounded, color: p.disabled, size: 20),
      onTap: onTap,
    );
  }
}
