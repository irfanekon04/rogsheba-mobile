import 'package:flutter/material.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/shared/widgets/app_card.dart';

class FeatureStrip extends StatelessWidget {
  const FeatureStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FeatureItem(
          icon: Icons.health_and_safety_outlined,
          title: BnStrings.featureTriageTitle,
          body: BnStrings.featureTriageBody,
        ),
        FeatureItem(
          icon: Icons.local_hospital_outlined,
          title: BnStrings.featureClinicsTitle,
          body: BnStrings.featureClinicsBody,
        ),
        FeatureItem(
          icon: Icons.lock_outline,
          title: BnStrings.featurePrivateTitle,
          body: BnStrings.featurePrivateBody,
        ),
      ],
    );
  }
}

class FeatureItem extends StatelessWidget {
  const FeatureItem({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  body,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
