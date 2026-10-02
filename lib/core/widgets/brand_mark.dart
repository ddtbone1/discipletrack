import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The DiscipleTrack logo: the lime "d" with its leaf, on no background,
/// optionally followed by the wordmark. The logo's forest green is kept for
/// the launcher icon and store listing only.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 44, this.showWordmark = true, super.key});

  final double size;
  final bool showWordmark;

  /// The transparent lime mark from assets/brand.
  static const asset = 'assets/brand/icon_logo.png';

  @override
  Widget build(BuildContext context) {
    final tile = SizedBox(width: size, height: size, child: const BrandLogo());

    if (!showWordmark) return Semantics(label: 'DiscipleTrack', child: tile);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: tile),
        const SizedBox(width: AppSpacing.sm),
        Text('DiscipleTrack', style: AppTypography.sectionTitle),
      ],
    );
  }
}

/// The bare logo image, filling its box. For a tile, use [BrandMark].
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
    BrandMark.asset,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    // A missing asset (a bare test harness) must never break a screen.
    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
  );
}
