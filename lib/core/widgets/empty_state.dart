import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'illustration.dart';

export 'illustration.dart' show Illustration;

/// Explains why a screen or section has nothing to show, and what happens
/// next (UI_DESIGN_SYSTEM section 42).
///
/// [action] is offered only when the person can actually take it. The
/// restricted form says a screen is not available to this person, without
/// confirming what it would have shown.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.title,
    this.icon,
    this.action,
    this.illustration,
    super.key,
  });

  /// A screen or record this person may not open.
  const EmptyState.restricted({
    required this.message,
    this.title = "This isn't available to you",
    this.action,
    this.illustration = Illustration.restricted,
    super.key,
  }) : icon = null;

  final String? title;
  final String message;
  final IconData? icon;

  /// An action the person is allowed to take from here.
  final Widget? action;

  /// Sets the mood of a whole-screen or section state; the card then centres
  /// an illustration above the words. Without one, the compact form is used
  /// (an icon beside the title), for small states inside a list.
  final Illustration? illustration;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const fill = AppCardFill.pastel;
    final art = illustration;
    if (art != null) {
      return AppCard(
        fill: AppCardFill.plain,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          children: [
            IllustrationView(art, height: 120),
            const SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Semantics(
                header: true,
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.supportingStyle,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      );
    }
    return AppCard(
      fill: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: fill.foreground(p)),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title!,
                      style: AppTypography.sectionTitle.copyWith(
                        color: fill.foreground(p),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            message,
            style: AppTypography.body.copyWith(
              color: title == null
                  ? fill.foreground(p)
                  : fill.foregroundMuted(p),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
