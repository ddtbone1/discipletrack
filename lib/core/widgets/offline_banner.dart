import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Shown at the top of every page while offline: the page holds the last
/// saved information and changes are turned off (Slice 4 plan).
///
/// Uses the warning tone with an icon and words, never colour alone
/// (UI_DESIGN_SYSTEM section 44).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xs,
          AppSpacing.page,
          0,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.xxs,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: p.warningSurface,
          borderRadius: AppRadius.control,
          border: Border.all(color: p.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 20, color: p.warning),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're offline",
                    style: AppTypography.cardLabel.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    'Showing what was saved on this phone. Changes are off '
                    'until you reconnect.',
                    style: AppTypography.supporting.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: p.textPrimary,
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }
}
