import 'package:flutter/material.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';
import 'package:rogsheba_mobile/features/emergency/presentation/emergency_sheet.dart';

/// The web header's red emergency pill (`৯৯৯` → taps open the hotline sheet).
///
/// Lives in the emergency feature so every screen's AppBar reaches the same
/// chrome (and the same on-tap behaviour) from one source. Wrapped in an
/// `InkWell` to give the tap a pressed ripple without changing the visual —
/// the chip stays informational chrome from a screen away. A `Semantics`
/// label makes the pill meaningful to a screen reader (visible ৯৯৯ alone is
/// cryptic), and the tap target is padded to Material's 48dp minimum.
class HotlinePill extends StatelessWidget {
  const HotlinePill({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: BnStrings.hotlinePillLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: Material(
            color: scheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xxxl),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.xxxl),
              onTap: () => showEmergencySheet(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                alignment: Alignment.center,
                child: Text(
                  BnStrings.hotline999,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
