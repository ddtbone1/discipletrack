import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// One figure on a full-width soft card: an icon in a round chip, its label
/// over the figure, and an arrow when tapping opens the screen behind it.
///
/// Shows a dash while the value is still unknown, never a guessed number.
/// [supporting] adds one factual line under the figure, such as
/// "2 people waiting to join".
class StatTile extends StatelessWidget {
  const StatTile({
    required this.icon,
    required this.label,
    required int? value,
    this.supporting,
    this.onTap,
    super.key,
  }) : text = value == null ? null : '$value';

  /// A figure that is not a plain number, such as "Lesson 4".
  const StatTile.text({
    required this.icon,
    required this.label,
    required this.text,
    this.supporting,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;

  /// The figure as shown; null while loading.
  final String? text;
  final String? supporting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: onTap != null,
      label: ['$label: ${text ?? 'loading'}', ?supporting].join('. '),
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: p.textPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text ?? '–',
                    style: AppTypography.metricSmall.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  if (supporting != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      supporting!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: p.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
          ],
        ),
      ),
    );
  }
}
