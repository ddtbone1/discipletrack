import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// The fill a card carries. Each one fixes its own foreground colours, so no
/// screen has to work out what text colour is legible on what background.
///
/// Which fill a screen uses, and whether it uses a card at all, is decided by
/// that screen's content (UI_DESIGN_SYSTEM section 10). There is no fixed
/// per-screen arrangement.
enum AppCardFill {
  /// Ink. Near-black in light mode, near-white in dark mode. Highest emphasis.
  ink,

  /// Soft mint, the primary accent. Carries dark text in both modes.
  mint,

  /// Sky blue, the secondary accent. Carries dark text in both modes.
  sky,

  /// Pale mint in light mode, deep green-grey in dark mode. Quiet grouping.
  pastel,

  /// Surface with a soft border. The default for plain grouped content.
  plain,
}

extension AppCardFillColors on AppCardFill {
  Color background(AppPalette p) => switch (this) {
    AppCardFill.ink => p.ink,
    AppCardFill.mint => p.mint,
    AppCardFill.sky => p.sky,
    AppCardFill.pastel => p.pastel,
    AppCardFill.plain => p.surface,
  };

  Color foreground(AppPalette p) => switch (this) {
    AppCardFill.ink => p.onInk,
    AppCardFill.mint => p.onMint,
    AppCardFill.sky => p.onSky,
    AppCardFill.pastel => p.onPastel,
    AppCardFill.plain => p.textPrimary,
  };

  /// Muted foreground, for supporting lines inside the card.
  Color foregroundMuted(AppPalette p) => switch (this) {
    AppCardFill.ink => p.onInkMuted,
    AppCardFill.mint => p.onMint.withValues(alpha: 0.7),
    AppCardFill.sky => p.onSky.withValues(alpha: 0.7),
    AppCardFill.pastel => p.onPastel.withValues(alpha: 0.65),
    AppCardFill.plain => p.muted,
  };

  bool get hasBorder => this == AppCardFill.plain;
}

/// A rounded surface for content that forms a meaningful group, has its own
/// interaction or communicates an important state.
///
/// Children inherit the fill's foreground colour through [DefaultTextStyle]
/// and [IconTheme], so text placed inside is legible without extra styling.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.fill = AppCardFill.plain,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    super.key,
  });

  final Widget child;
  final AppCardFill fill;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = fill.foreground(p);

    final content = Padding(
      padding: padding,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: child,
        ),
      ),
    );

    return Material(
      color: fill.background(p),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: fill.hasBorder ? BorderSide(color: p.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
