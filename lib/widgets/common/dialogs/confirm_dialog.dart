import 'package:flutter/material.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelText = 'Cancel',
  String confirmText = 'Confirm',
  Color? confirmColor,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: confirmColor == null ? null : FilledButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result == true;
}

