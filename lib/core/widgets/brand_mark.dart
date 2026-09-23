import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The DiscipleTrack mark: a mint tile with the leaf icon, optionally followed
/// by the wordmark. Mint with a dark icon reads on both page colours.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 44, this.showWordmark = true, super.key});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.mint,
        borderRadius: size >= 56 ? AppRadius.card : AppRadius.control,
      ),
      child: Icon(Icons.eco_outlined, color: p.onMint, size: size * 0.5),
    );

    if (!showWordmark) return tile;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        const SizedBox(width: AppSpacing.sm),
        Text('DiscipleTrack', style: AppTypography.sectionTitle),
      ],
    );
  }
}
