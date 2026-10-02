import 'package:flutter/material.dart';

import '../connectivity/connection_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// An inline text link: optional muted [prefix] text followed by the tappable
/// [label], for example "New here? **Create an account**".
///
/// Lighter than a text [AppButton]: only the label is the action, so the
/// prefix reads as context rather than as part of a button. The tap target is
/// still at least 44px tall (UI_DESIGN_SYSTEM section 47).
class AppTextLink extends StatelessWidget {
  const AppTextLink({
    required this.label,
    required this.onTap,
    this.prefix,
    this.requiresConnection = false,
    super.key,
  });

  final String label;

  /// Null disables the link.
  final VoidCallback? onTap;
  final String? prefix;

  /// The action changes data, so it is disabled while offline.
  final bool requiresConnection;

  static const _minHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final blocked = requiresConnection && ConnectionScope.isOffline(context);
    final enabled = onTap != null && !blocked;
    final linkColor = enabled ? p.textPrimary : p.disabled;

    final link = Semantics(
      link: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.control,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: AppTypography.supporting.copyWith(
                  color: linkColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: linkColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (prefix == null) return link;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prefix!, style: AppTypography.supporting.copyWith(color: p.muted)),
        link,
      ],
    );
  }
}
