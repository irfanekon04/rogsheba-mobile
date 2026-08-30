import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/theme/app_theme.dart';
import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_level.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:rogsheba_mobile/features/triage/presentation/follow_up_input.dart';
import 'package:rogsheba_mobile/features/triage/presentation/speak_button.dart';
import 'package:rogsheba_mobile/shared/widgets/app_card.dart';

/// Styled triage result card. Renders the level badge, TTS, advice, follow-up
/// question, and clinics CTA.
class TriageResultCard extends StatelessWidget {
  const TriageResultCard({
    required this.result,
    this.showFollowUp = false,
    super.key,
  });

  final TriageResult result;

  /// True while there is an unanswered follow-up question; the follow-up
  /// question + answer box are then rendered inline at the foot of this card.
  final bool showFollowUp;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _LevelBadge(level: result.level)),
              const SizedBox(width: 8),
              SpeakButton(result: result),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.titleBn,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(result.summaryBn, style: textTheme.bodyLarge),
          if (result.adviceBn.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionHeading(BnStrings.adviceTitle),
            for (final (index, step) in result.adviceBn.indexed)
              Text('${index + 1}. $step', style: textTheme.bodyMedium),
          ],
          if (result.warningSignsBn.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionHeading(BnStrings.warningSignsTitle),
            for (final sign in result.warningSignsBn)
              Text('• $sign', style: textTheme.bodyMedium),
          ],
          const _ClinicsCtaButton(),
          const SizedBox(height: 12),
          Center(
            child: Text(
              result.disclaimerBn,
              style: textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: scheme.error,
              ),
            ),
          ),
          if (showFollowUp) ...[
            const Divider(height: 24),
            _FollowUpQuestion(result: result),
            const SizedBox(height: 12),
            FollowUpInput(key: ValueKey(result.turn)),
          ],
        ],
      ),
    );
  }
}

class _FollowUpQuestion extends StatelessWidget {
  const _FollowUpQuestion({required this.result});

  final TriageResult result;

  @override
  Widget build(BuildContext context) {
    final question = result.followupQuestionBn?.trim() ?? '';
    if (question.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          BnStrings.followUpTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              question,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final TriageLevel level;

  @override
  Widget build(BuildContext context) {
    final triage = triageColorsOf(context);
    final background = triage.backgroundFor(level, isForeground: false);
    final foreground = triage.backgroundFor(level, isForeground: true);
    final label = switch (level) {
      TriageLevel.green => BnStrings.levelGreen,
      TriageLevel.yellow => BnStrings.levelYellow,
      TriageLevel.red => BnStrings.levelRed,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.xxxl),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ClinicsCtaButton extends StatelessWidget {
  const _ClinicsCtaButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxxl),
          ),
          child: InkWell(
            onTap: () => context.go('/clinics'),
            borderRadius: BorderRadius.circular(AppRadius.xxxl),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: scheme.onPrimary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    BnStrings.nearbyClinicsCta,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
