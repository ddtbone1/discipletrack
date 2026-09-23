import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.captionStyle),
        const SizedBox(height: AppSpacing.xxs),
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
            // Drives the themed error border without emitting layout-shifting
            // helper text.
            errorText: hasError ? '' : null,
          ),
        ),
        SizedBox(
          height: AppSpacing.errorSlot,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xxs,
                    left: AppSpacing.xxs,
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
