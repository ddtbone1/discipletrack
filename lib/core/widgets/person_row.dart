import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A section heading on the page background, matching [InfoGroup]'s.
///
/// Shared by every feature (UI_DESIGN_SYSTEM section 67).
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
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
          ?trailing,
        ],
      ),
    );
  }
}

/// A person row inside a card: an optional avatar, the name, an optional
/// supporting line, optional pills for role or state, and an optional
/// trailing control. Used for rosters and group sections.
class PersonRow extends StatelessWidget {
  const PersonRow({
    required this.name,
    this.detail,
    this.trailing,
    this.onTap,
    this.leading,
    this.pills = const [],
    super.key,
  });

  final String name;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? leading;
  final List<Widget> pills;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: AppTypography.body.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      style: AppTypography.supporting.copyWith(color: p.muted),
                    ),
                  ],
                  if (pills.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: pills),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.xs),
              trailing!,
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return InkWell(onTap: onTap, child: row);
  }
}

/// Rows separated by inset dividers inside one card surface.
List<Widget> dividedRows(List<Widget> rows) => [
  for (var i = 0; i < rows.length; i++) ...[
    if (i > 0) const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
    rows[i],
  ],
];
