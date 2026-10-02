import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/d_group_member.dart';

/// Asks which responsibility to invite [name] for. Resolves null when
/// dismissed. LEADER is never offered: it is a direct Coordinator appointment.
Future<DGroupResponsibility?> showInviteRoleSheet(
  BuildContext context, {
  required String name,
}) {
  return showModalBottomSheet<DGroupResponsibility>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final p = context.palette;
      Widget option(DGroupResponsibility r, String detail) => ListTile(
        title: Text(
          'Invite as ${r.label}',
          style: AppTypography.body.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(detail, style: context.supportingStyle),
        onTap: () => Navigator.of(context).pop(r),
      );

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
                  'Invite $name',
                  style: AppTypography.sectionTitle.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              option(
                DGroupResponsibility.disciple,
                'Joins the group and can be paired with a Discipler.',
              ),
              option(
                DGroupResponsibility.discipler,
                'Joins the group to disciple members you pair with them.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'They accept or decline in the app. The invitation expires '
                  'after 14 days.',
                  style: context.supportingStyle,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
