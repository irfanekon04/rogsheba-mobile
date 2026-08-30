import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';
import 'package:rogsheba_mobile/features/emergency/presentation/hotline_pill.dart';
import 'package:rogsheba_mobile/features/triage/presentation/example_chips.dart';
import 'package:rogsheba_mobile/features/triage/presentation/feature_strip.dart';
import 'package:rogsheba_mobile/features/triage/presentation/hero_section.dart';
import 'package:rogsheba_mobile/features/triage/presentation/new_chat_button.dart';
import 'package:rogsheba_mobile/features/triage/presentation/triage_controller.dart';
import 'package:rogsheba_mobile/features/triage/presentation/triage_result_card.dart';
import 'package:rogsheba_mobile/features/triage/presentation/triage_skeleton.dart';
import 'package:rogsheba_mobile/features/triage/presentation/voice_symptom_field.dart';
import 'package:rogsheba_mobile/shared/widgets/app_button.dart';
import 'package:rogsheba_mobile/shared/widgets/app_card.dart';
import 'package:rogsheba_mobile/shared/widgets/offline_banner.dart';

/// The home / triage screen, porting the web layout: hero, symptom entry card,
/// example chips, feature strip and the triage result card.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey _resultKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(triageControllerProvider);
    final controller = ref.read(triageControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    _scrollResultIntoViewOnSubmit();

    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: BnStrings.appBrand,
                style: TextStyle(fontFamily: AppFonts.display),
              ),
              TextSpan(text: ' '),
              TextSpan(text: BnStrings.appTitle),
            ],
          ),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [HotlinePill()],
      ),
      floatingActionButton: state.result != null
          ? NewChatButton(onPressed: controller.resetConversation)
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768),
                child: const OfflineBanner(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 768),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const HeroSection(),
                        const SizedBox(height: 24),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              VoiceSymptomField(
                                onChanged: controller.onSymptomsChanged,
                                onSubmitted: controller.submit,
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: state.isSubmitting
                                    ? BnStrings.submitting
                                    : BnStrings.submit,
                                isLoading: state.isSubmitting,
                                onPressed: state.canSubmit
                                    ? controller.submit
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  BnStrings.inlineDisclaimer,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: scheme.error),
                                ),
                              ),
                              if (state.errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  state.errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: scheme.error),
                                ),
                              ],
                              if (state.result == null && !state.isSubmitting)
                                const ExampleChips(),
                            ],
                          ),
                        ),
                        if (state.result == null && !state.isSubmitting) ...[
                          const SizedBox(height: 32),
                          const FeatureStrip(),
                        ],
                        if (state.isSubmitting && state.result == null) ...[
                          const SizedBox(height: 24),
                          const TriageSkeleton(),
                        ],
                        if (state.result != null) ...[
                          const SizedBox(height: 24),
                          KeyedSubtree(
                            key: _resultKey,
                            child: state.isAnswerSubmitting
                                ? const TriageSkeleton()
                                : TriageResultCard(
                                    result: state.result!,
                                    showFollowUp: state.hasPendingQuestion,
                                  ),
                          ),
                        ],
                        const SizedBox(height: 72),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollResultIntoViewOnSubmit() {
    ref.listen<TriageFormState>(triageControllerProvider, (previous, next) {
      if (previous?.result == null && next.result != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final resultContext = _resultKey.currentContext;
          if (resultContext != null && resultContext.mounted) {
            Scrollable.ensureVisible(
              resultContext,
              alignment: 0.3,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    });
  }
}
