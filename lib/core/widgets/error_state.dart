import 'package:flutter/material.dart';

import '../connectivity/connection_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Full-page error with an optional retry.
///
/// UI_DESIGN_SYSTEM section 44: errors must be understandable without exposing
/// internal detail, and must not rely on colour alone, so an icon and text
/// carry the meaning too.
///
/// Use [ErrorState.load] when loading something failed. The default
/// constructor is for sentences written for the screen; it must never receive
/// exception text.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    super.key,
  });

  /// A failed load of [subject] ("your D Group"), in fixed wording.
  ///
  /// The error itself is never shown. When it means the server could not be
  /// reached, the offline wording is used instead, because "try again" will
  /// only help once the connection is back.
  factory ErrorState.load({
    required String subject,
    required Object error,
    VoidCallback? onRetry,
    Key? key,
  }) {
    if (isNetworkFailure(error)) {
      return ErrorState(
        key: key,
        title: "You're offline",
        message:
            '${_capitalise(subject)} needs a connection. Connect and try '
            'again.',
        onRetry: onRetry,
      );
    }
    return ErrorState(
      key: key,
      title: "Couldn't load $subject",
      message:
          "We couldn't load $subject. Check your connection and try again.",
      onRetry: onRetry,
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: p.errorSurface,
                borderRadius: AppRadius.card,
              ),
              child: Icon(Icons.error_outline, color: p.error, size: 28),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: context.supportingStyle,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Try again',
                onPressed: onRetry,
                variant: AppButtonVariant.secondary,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error banner for form-level failures, where a full-page error would
/// discard what the person already typed.
class InlineError extends StatelessWidget {
  const InlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.errorSurface,
        borderRadius: AppRadius.control,
        border: Border.all(color: p.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: p.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTypography.supporting.copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
