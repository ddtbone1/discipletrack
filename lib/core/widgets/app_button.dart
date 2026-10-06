import 'package:flutter/material.dart';

import '../connectivity/connection_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant {
  /// Brand forest fill (lime in dark mode), the 10% accent of the 60-30-10
  /// rule (UI_DESIGN_SYSTEM section 40). The default for primary actions, so
  /// the one primary action on a screen is always the most prominent element.
  primary,

  /// Bordered, transparent fill. Secondary actions.
  secondary,

  /// No fill or border. Tertiary actions and inline links.
  text,

  /// Recording a meeting: the brand lime with black text in both modes.
  record,
}

/// The single button in DiscipleTrack.
///
/// Gives every action the same feedback: a pressed shade one step darker
/// than the resting fill, a greyed-out disabled state, and an inline spinner that replaces the label **without changing the button's
/// size**, so submitting never makes the layout jump.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.requiresConnection = false,
    this.offlineAction,
    this.pill = true,
    this.dense = false,
    super.key,
  });

  /// A smaller button that fits its label, for an action inside a card.
  final bool dense;

  final String label;

  /// Null disables the button. Also forced null while [isLoading].
  final VoidCallback? onPressed;

  /// The action changes data. While offline it looks disabled, because the
  /// app is view-only then (Slice 4 plan), and a tap explains why instead of
  /// doing nothing.
  final bool requiresConnection;

  /// Completes "You're offline. Connect to ...", for example
  /// "record this meeting". A generic sentence is used when null.
  final String? offlineAction;

  /// Fully rounded ends, the app-wide default. False gives the squarer
  /// control radius.
  final bool pill;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  /// Minimum 44px tall, per UI_DESIGN_SYSTEM section 47 (accessibility).
  static const _minHeight = 48.0;

  /// Dense buttons stay at 40px, close to the 44px touch target.
  static const _denseHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final blocked = requiresConnection && ConnectionScope.isOffline(context);
    final enabled = onPressed != null && !isLoading && !blocked;
    final radius = pill ? AppRadius.pill : AppRadius.control;
    final p = context.palette;

    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (
        enabled ? p.brand : p.surfaceAlt,
        enabled ? p.onBrand : p.disabled,
        null,
      ),
      // A component: white on the grey page (charcoal in dark mode).
      AppButtonVariant.secondary => (
        enabled ? p.surface : Colors.transparent,
        enabled ? p.textPrimary : p.disabled,
        p.border,
      ),
      AppButtonVariant.text => (
        Colors.transparent,
        enabled ? p.textPrimary : p.disabled,
        null,
      ),
      AppButtonVariant.record => (
        enabled ? p.brand : p.surfaceAlt,
        enabled ? p.onBrand : p.disabled,
        null,
      ),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: bg,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? onPressed
              : (blocked && onPressed != null && !isLoading)
              ? () => explainOffline(context, action: offlineAction)
              : null,
          borderRadius: radius,
          // Mobile states only (no hover): pressed is one shade step from the
          // resting fill. The overlay is drawn under the label, so a fully
          // opaque pressed colour still leaves the label readable.
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? (variant == AppButtonVariant.primary
                      ? p.brandPressed
                      : p.border.withValues(alpha: 0.6))
                : Colors.transparent,
          ),
          child: Container(
            constraints: BoxConstraints(
              minHeight: dense ? _denseHeight : _minHeight,
            ),
            width: expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? AppSpacing.md : AppSpacing.lg,
            ),
            decoration: border == null
                ? null
                : BoxDecoration(
                    borderRadius: radius,
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
                          Icon(icon, size: dense ? 16 : 18, color: fg),
                          SizedBox(width: dense ? 6 : AppSpacing.xs),
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
