import 'package:flutter/material.dart';

/// The one confirmation pattern for a destructive or hard-to-reverse action
/// (UI_DESIGN_SYSTEM sections 45 and 59). Resolves true only on
/// [confirmLabel]; dismissing or cancelling resolves false.
///
/// Routine, easily undone actions do not use it.
Future<bool> showConfirmDialog(
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
