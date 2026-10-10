import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The one confirmation pattern for a destructive or hard-to-reverse action
/// (UI_DESIGN_SYSTEM sections 45 and 59). Resolves true only on
/// [confirmLabel]; dismissing or cancelling resolves false.
///
/// Routine, easily undone actions do not use it. [destructive] sets the
/// confirm label in the error colour, for an action that ends or removes
/// something (archive, remove), matching the button that opened it.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
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
          style: destructive
              ? TextButton.styleFrom(foregroundColor: context.palette.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
