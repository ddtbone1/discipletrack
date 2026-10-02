import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Small presentation helpers shared by the ministry screens.
abstract final class MinistryFormat {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Sep 20".
  static String shortDate(DateTime utc) {
    final d = utc.toLocal();
    return '${_months[d.month - 1]} ${d.day}';
  }

  /// "Expires today", "Expires tomorrow", "Expires in 12 days".
  static String expiresIn(int daysLeft) => switch (daysLeft) {
    0 => 'Expires today',
    1 => 'Expires tomorrow',
    _ => 'Expires in $daysLeft days',
  };

  /// "1 Discipler", "3 Disciples".
  static String count(int n, String singular) =>
      '$n ${n == 1 ? singular : '${singular}s'}';
}

/// A confirmation for a destructive or hard-to-reverse action
/// (UI_DESIGN_SYSTEM section 45). Resolves true only on [confirmLabel].
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A section heading on the page background, matching [InfoGroup]'s.
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
              child: Text(title.toUpperCase(), style: context.captionStyle),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A person row inside a card: name, an optional supporting line, and an
/// optional trailing control. Used for rosters and group sections.
class PersonRow extends StatelessWidget {
  const PersonRow({
    required this.name,
    this.detail,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String name;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;

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
                valueColor: AlwaysStoppedAnimation(done ? p.success : p.sky),
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
