import 'package:flutter/material.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = TextSpan(
      children: [
        const TextSpan(text: 'আপনার লক্ষণ বলুন — '),
        TextSpan(
          text: 'তাৎক্ষণিক স্বাস্থ্য পরামর্শ',
          style: TextStyle(color: scheme.primary),
        ),
        const TextSpan(text: ' পান'),
      ],
    );
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.secondary.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(AppRadius.xxxl),
          ),
          child: Text(
            BnStrings.heroBadge,
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.inverseSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          BnStrings.heroSubtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
