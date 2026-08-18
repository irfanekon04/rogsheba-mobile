import 'package:flutter/material.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';

/// Modal rationale shown once before a system permission prompt. Returns
/// `true` when the user accepts and consents to the prompt, `false` when they
/// decline (in which case the app must proceed without the permission).
Future<bool> showPermissionRationaleDialog(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(BnStrings.rationaleCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(BnStrings.rationaleContinue),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

/// Modal shown after a permission was denied: offers the system settings
/// route or a dismissal that keeps the app fully usable. Returns `true` when
/// the user opts to open app settings.
Future<bool> showPermissionSettingsDialog(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final goToSettings = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(BnStrings.rationaleCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(BnStrings.openSettings),
        ),
      ],
    ),
  );
  return goToSettings ?? false;
}
