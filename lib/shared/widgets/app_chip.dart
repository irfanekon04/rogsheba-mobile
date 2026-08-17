import 'package:flutter/material.dart';

import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';

/// Small tappable pill (web `AppChip`), used for example symptom phrases and
/// inline actions. The tap target is at least 48dp tall (Material's minimum),
/// enforced by the container's min-height constraint — the visual padding
/// stays tight but the hit area never shrinks below the standard.
class AppChip extends StatelessWidget {
  const AppChip({required this.label, this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xxxl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.xxxl),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
