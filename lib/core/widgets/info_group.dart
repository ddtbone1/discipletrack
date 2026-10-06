import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// A titled group of related rows: the heading sits on the page background,
/// the rows share one soft surface separated by inset dividers.
///
/// Used for details and settings-style navigation, where each fact is short
/// and several belong together (UI_DESIGN_SYSTEM sections 10 and 41).
class InfoGroup extends StatelessWidget {
  const InfoGroup({required this.title, required this.rows, super.key});

  final String title;
  final List<InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xxs,
            bottom: AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.sectionTitle.copyWith(
                color: context.palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row in an [InfoGroup]: a label on the left and its value on the right.
/// With [onTap] the row becomes a navigation row and shows a chevron.
class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.label,
    this.value,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Comfortable touch target (section 47).
  static const _minHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: p.muted),
              const SizedBox(width: AppSpacing.sm),
            ],
            // A navigation row (one with a chevron) reads as a cell with a
            // subtitle, so neither the label nor the value has to share the
            // width and wrap. A plain key/value row keeps them side by side.
            if (onTap != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.body.copyWith(color: p.textPrimary),
                    ),
                    if (value != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        value!,
                        style: AppTypography.supporting.copyWith(
                          color: p.muted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: value == null
                    ? const SizedBox.shrink()
                    : Text(
                        value!,
                        style: AppTypography.body.copyWith(color: p.muted),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xxs),
              Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return MergeSemantics(child: row);
    }
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
