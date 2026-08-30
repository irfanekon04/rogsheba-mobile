import 'package:flutter/material.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';

class NewChatButton extends StatelessWidget {
  const NewChatButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: BnStrings.newChatLabel,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text(BnStrings.newChatLabel),
      ),
    );
  }
}
