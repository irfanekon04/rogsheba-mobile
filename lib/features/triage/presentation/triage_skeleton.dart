import 'package:flutter/material.dart';

import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';
import 'package:shimmer/shimmer.dart';

/// Pulsing skeleton placeholder shown while waiting for the AI to respond.
/// Mirrors the triage result card layout: level badge, title, summary, advice
/// lines — all as rounded bars that shimmer left-to-right.
class TriageSkeleton extends StatelessWidget {
  const TriageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1A2E30) : const Color(0xFFE0E0E0);
    final highlight =
        isDark ? const Color(0xFF2A4042) : const Color(0xFFF5F5F5);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
        boxShadow: kShadowSoft,
      ),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(80, 28, base),
            const SizedBox(height: 16),
            _bar(200, 20, base),
            const SizedBox(height: 8),
            _bar(280, 16, base),
            const SizedBox(height: 8),
            _bar(240, 16, base),
            const SizedBox(height: 16),
            _bar(140, 14, base),
            const SizedBox(height: 8),
            _bar(260, 14, base),
            const SizedBox(height: 8),
            _bar(180, 14, base),
          ],
        ),
      ),
    );
  }

  Widget _bar(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
