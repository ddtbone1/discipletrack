import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A labelled text field with a **fixed-height error slot**.
///
/// The slot is always present, so a validation message appearing or
/// disappearing never changes the field's height and never makes the form jump.
/// This is why the theme suppresses Material's own error text.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
    this.trailing,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textStyle,
    this.leadingIcon,
    this.pill = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// Shown in the reserved slot. Null leaves the slot empty but still sized.
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  /// For constrained inputs such as a join code or a numeric verification
  /// code. The database and Supabase Auth still validate independently.
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  /// Overrides the body style, for example wider letter spacing on a code.
  final TextStyle? textStyle;

  /// Shown inside the field before the text, for example a mail icon.
  final IconData? leadingIcon;

  /// The app-wide entry style, set by the login and sign-up pages: a pill
  /// with the label inside it, floating above the text once typing starts,
  /// so the field always has a visible label (UI_DESIGN_SYSTEM section 41)
  /// without a separate caption above it. False gives the older boxed field
  /// with its label above.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    final p = context.palette;
    OutlineInputBorder pillBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.pill,
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!pill) ...[
          Text(label, style: context.captionStyle),
          const SizedBox(height: AppSpacing.xxs),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          enabled: enabled,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: textStyle ?? AppTypography.body,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: trailing,
            labelText: pill ? label : null,
            floatingLabelStyle: AppTypography.caption.copyWith(
              color: p.textPrimary,
            ),
            prefixIcon: leadingIcon == null
                ? null
                : Icon(leadingIcon, size: 20, color: p.muted),
            fillColor: pill ? p.surface : null,
            contentPadding: pill
                ? const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  )
                : null,
            border: pill ? pillBorder(p.border) : null,
            enabledBorder: pill ? pillBorder(p.border) : null,
            disabledBorder: pill ? pillBorder(p.border) : null,
            focusedBorder: pill ? pillBorder(p.brand, 1.5) : null,
            errorBorder: pill ? pillBorder(p.error) : null,
            focusedErrorBorder: pill ? pillBorder(p.error, 1.5) : null,
            // Drives the themed error border without emitting layout-shifting
            // helper text.
            errorText: hasError ? '' : null,
          ),
        ),
        SizedBox(
          height: AppSpacing.errorSlot,
          child: hasError
              ? Padding(
                  padding: EdgeInsets.only(
                    top: AppSpacing.xxs,
                    left: pill ? AppSpacing.lg : AppSpacing.xxs,
                  ),
                  child: Text(
                    errorText!,
                    style: AppTypography.caption.copyWith(
                      color: context.palette.error,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
