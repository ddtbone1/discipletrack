import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// What a status means, which decides its fill. UI_DESIGN_SYSTEM section 39:
/// status styling is centralised here so features do not invent badges.
enum StatusTone {
  /// In good standing: active, completed. Mint.
  positive,

  /// Waiting on someone else: pending, in review. Sky.
  waiting,

  /// No access or no longer current: inactive, archived, none. Neutral.
  neutral,
}

/// A compact status label. The text always carries the meaning, so the state
/// is understandable without relying on colour (section 47).
class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, required this.tone, super.key});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg, border) = switch (tone) {
      StatusTone.positive => (p.mint, p.onMint, null),
      StatusTone.waiting => (p.sky, p.onSky, null),
      StatusTone.neutral => (p.surfaceAlt, p.textPrimary, p.border),
    };

    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.pill,
          border: border == null ? null : Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
