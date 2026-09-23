import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant {
  /// Ink fill: near-black with a white label in light mode, near-white with a
  /// dark label in dark mode. The default for primary actions.
  ///
  /// The mint and sky accents are surfaces, not button fills, so an accent
  /// never competes with the one primary action on a screen.
  primary,

  /// Bordered, transparent fill. Secondary actions.
  secondary,

  /// No fill or border. Tertiary actions and inline links.
  text,
}

/// The single button in DiscipleTrack.
///
/// Gives every action the same feedback: an ink ripple, a disabled state, and
/// an inline spinner that replaces the label **without changing the button's
/// size**, so submitting never makes the layout jump.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    super.key,
  });

  final String label;

  /// Null disables the button. Also forced null while [isLoading].
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  /// Minimum 44px tall, per UI_DESIGN_SYSTEM section 47 (accessibility).
  static const _minHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final p = context.palette;

    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (
        enabled ? p.ink : p.surfaceAlt,
        enabled ? p.onInk : p.disabled,
        null,
      ),
      AppButtonVariant.secondary => (
        Colors.transparent,
        enabled ? p.textPrimary : p.disabled,
        p.border,
      ),
      AppButtonVariant.text => (
        Colors.transparent,
        enabled ? p.textPrimary : p.disabled,
        null,
      ),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: bg,
        borderRadius: AppRadius.control,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: AppRadius.control,
          child: Container(
            constraints: const BoxConstraints(minHeight: _minHeight),
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: border == null
                ? null
                : BoxDecoration(
                    borderRadius: AppRadius.control,
                    border: Border.all(color: border),
                  ),
            child: Center(
              // The spinner occupies the same box as the label, so swapping
              // between them cannot resize the button.
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(fg),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: fg),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        // Flexible so a long label at large text sizes wraps
                        // instead of overflowing a narrow button.
                        Flexible(
                          child: Text(
                            label,
                            style: AppTypography.button.copyWith(color: fg),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
