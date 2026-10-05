import 'package:flutter/material.dart';

import '../../../core/format/app_format.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

export '../../../core/widgets/confirm_dialog.dart';
export '../../../core/widgets/person_row.dart';

/// Small presentation helpers shared by the ministry screens.
abstract final class MinistryFormat {
  /// "Sep 20".
  static String shortDate(DateTime utc) => AppFormat.shortDate(utc);

  /// "Expires today", "Expires tomorrow", "Expires in 12 days".
  static String expiresIn(int daysLeft) => switch (daysLeft) {
    0 => 'Expires today',
    1 => 'Expires tomorrow',
    _ => 'Expires in $daysLeft days',
  };

  /// "1 Discipler", "3 Disciples".
  static String count(int n, String singular) => AppFormat.count(n, singular);
}

/// How many Disciples have a Discipler, as a bar that fills toward done
/// (goal-gradient): the closer a group is to fully paired, the more visible
/// the remaining step. Derived from the rows on screen, never stored.
class PairingProgress extends StatelessWidget {
  const PairingProgress({required this.paired, required this.total, super.key});

  final int paired;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = paired == total;
    final label = done
        ? 'Every Disciple has a Discipler'
        : '$paired of $total Disciples paired';
    return Semantics(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : paired / total,
                minHeight: 6,
                backgroundColor: p.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(done ? p.success : p.brand),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ExcludeSemantics(child: Text(label, style: context.captionStyle)),
        ],
      ),
    );
  }
}
