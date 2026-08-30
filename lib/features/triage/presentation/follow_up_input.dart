import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/features/triage/presentation/triage_controller.dart';
import 'package:rogsheba_mobile/features/triage/presentation/voice_input_controller.dart';
import 'package:rogsheba_mobile/shared/widgets/app_button.dart';
import 'package:rogsheba_mobile/shared/widgets/app_card.dart';
import 'package:rogsheba_mobile/shared/widgets/permission_rationale_dialog.dart';
import 'package:rogsheba_mobile/shared/widgets/pulsing_dot.dart';

/// Answer box shown while the AI is waiting for a reply: a single-line field,
/// a send button, and the mic for voice answers.
class FollowUpInput extends ConsumerStatefulWidget {
  const FollowUpInput({super.key});

  @override
  ConsumerState<FollowUpInput> createState() => _FollowUpInputState();
}

class _FollowUpInputState extends ConsumerState<FollowUpInput>
    with SingleTickerProviderStateMixin {
  static const _pulseDuration = Duration(milliseconds: 1300);

  final TextEditingController _text = TextEditingController();
  late final AnimationController _pulse;
  late final StreamSubscription<String> _finalSubscription;

  /// Unique key for the voice controller — changes each time the widget is
  /// re-created (keyed by [ValueKey] in the parent).
  String get _voiceId => 'followup_${widget.key}';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _pulseDuration);

    // Probe voice availability on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceInputProvider(_voiceId).notifier).checkVoiceAvailable();
    });

    // Subscribe to final transcripts from the controller.
    _finalSubscription =
        ref.read(voiceInputProvider(_voiceId).notifier).finalTranscripts.listen(
              _appendTranscript,
            );
  }

  void _appendTranscript(String text) {
    final current = _text.text;
    final appended = current.trim().isEmpty ? text : '$current $text';
    _text.value = TextEditingValue(
      text: appended,
      selection: TextSelection.collapsed(offset: appended.length),
    );
  }

  Future<void> _submit() async {
    final text = _text.text;
    final controller = ref.read(voiceInputProvider(_voiceId).notifier);
    await controller.stopListening();
    if (text.trim().isNotEmpty) {
      await ref.read(triageControllerProvider.notifier).submitAnswer(text);
    }
  }

  Future<void> _toggleListening() async {
    final controller = ref.read(voiceInputProvider(_voiceId).notifier);
    final action = await controller.toggleListening();
    if (!mounted) return;

    switch (action) {
      case VoiceAction.needsRationale:
        final ok = await showPermissionRationaleDialog(
          context,
          title: BnStrings.micRationaleTitle,
          body: BnStrings.micRationaleBody,
        );
        if (ok && mounted) {
          await controller.markRationaleAcceptedAndStart();
        }
      case VoiceAction.needsSettings:
        // Follow-up field does not offer the settings route — mic is simply
        // hidden and typing is always available.
        break;
      case VoiceAction.started:
      case VoiceAction.stopped:
        break;
    }
  }

  @override
  void dispose() {
    _finalSubscription.cancel();
    _pulse.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final submitting = ref.watch(triageControllerProvider).isAnswerSubmitting;
    final error = ref.watch(triageControllerProvider).answerError;

    final voiceState = ref.watch(voiceInputProvider(_voiceId));
    final isListening = voiceState.isListening;
    final interim = voiceState.interim;
    final micDenied = voiceState.micDenied;
    final voiceAvailable = voiceState.voiceAvailable;

    // Drive the pulse animation based on controller state.
    if (isListening && !_pulse.isAnimating) {
      unawaited(_pulse.repeat());
    } else if (!isListening && _pulse.isAnimating) {
      _pulse.stop();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isListening)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                PulsingDot(animation: _pulse),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    interim.isEmpty
                        ? BnStrings.listeningIndicator
                        : '${BnStrings.listeningIndicator} $interim',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _text,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: BnStrings.answerPlaceholder,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_text.text.isNotEmpty && !isListening)
                        IconButton(
                          tooltip: BnStrings.clearField,
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _text.clear();
                            setState(() {});
                          },
                        ),
                      if (!micDenied && (voiceAvailable ?? true))
                        IconButton(
                          tooltip: BnStrings.answerMicLabel,
                          icon: Icon(isListening ? Icons.stop : Icons.mic),
                          onPressed: isListening
                              ? () => ref
                                  .read(voiceInputProvider(_voiceId).notifier)
                                  .stopListening()
                              : _toggleListening,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: submitting ? BnStrings.submitting : BnStrings.answerSend,
                isLoading: submitting,
                onPressed: submitting ? null : _submit,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
