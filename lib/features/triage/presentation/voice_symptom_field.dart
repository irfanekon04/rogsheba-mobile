import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/services/permission_service.dart';
import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';
import 'package:rogsheba_mobile/features/triage/presentation/triage_controller.dart';
import 'package:rogsheba_mobile/features/triage/presentation/voice_input_controller.dart';
import 'package:rogsheba_mobile/shared/widgets/permission_rationale_dialog.dart';
import 'package:rogsheba_mobile/shared/widgets/pulsing_dot.dart';

/// Multiline symptom field with voice-input controls: a mic pill with pulse
/// animation, a live "শুনছি…" + interim transcript while speaking, a clear
/// button, and the fallback message when no `bn-BD` recogniser exists.
class VoiceSymptomField extends ConsumerStatefulWidget {
  const VoiceSymptomField({
    required this.onChanged,
    required this.onSubmitted,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<VoiceSymptomField> createState() => _VoiceSymptomFieldState();
}

class _VoiceSymptomFieldState extends ConsumerState<VoiceSymptomField>
    with SingleTickerProviderStateMixin {
  static const _voiceId = 'symptom';
  static const _pulseDuration = Duration(milliseconds: 1300);

  final TextEditingController _text = TextEditingController();
  late final AnimationController _pulse;
  late final StreamSubscription<String> _finalSubscription;

  /// Set to `true` while programmatically syncing [_text] from Riverpod state
  /// so the `_notifyChanged` listener does not echo back.
  bool _syncingFromState = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _pulseDuration);
    _text.addListener(_notifyChanged);

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

  void _notifyChanged() {
    if (_syncingFromState) return;
    widget.onChanged(_text.text);
  }

  void _appendTranscript(String text) {
    final current = _text.text;
    final appended = current.trim().isEmpty ? text : '$current $text';
    _text.value = TextEditingValue(
      text: appended,
      selection: TextSelection.collapsed(offset: appended.length),
    );
  }

  void _clear() {
    _text.clear();
    widget.onChanged('');
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
        final open = await showPermissionSettingsDialog(
          context,
          title: BnStrings.micRationaleTitle,
          body: BnStrings.micPermissionDenied,
        );
        if (open && mounted) {
          await ref.read(permissionServiceProvider).openAppSettings();
        }
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
    // Sync the local TextEditingController when an example chip updates state.
    final stateSymptoms = ref.watch(
      triageControllerProvider.select((s) => s.symptoms),
    );
    if (!_syncingFromState && _text.text != stateSymptoms) {
      _syncingFromState = true;
      _text.value = TextEditingValue(
        text: stateSymptoms,
        selection: TextSelection.collapsed(offset: stateSymptoms.length),
      );
      _syncingFromState = false;
    }

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
        TextField(
          controller: _text,
          onSubmitted: (_) => widget.onSubmitted(),
          keyboardType: TextInputType.multiline,
          maxLines: null,
          minLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: BnStrings.symptomPlaceholder,
            suffixIcon: _text.text.isNotEmpty && !isListening
                ? IconButton(
                    tooltip: BnStrings.clearField,
                    icon: const Icon(Icons.close),
                    onPressed: _clear,
                  )
                : null,
          ),
        ),
        if (isListening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                PulsingDot(animation: _pulse),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    interim.isEmpty
                        ? BnStrings.listeningIndicator
                        : '${BnStrings.listeningIndicator} $interim',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (micDenied)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    BnStrings.micPermissionDenied,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(permissionServiceProvider).openAppSettings(),
                  child: const Text(BnStrings.openSettings),
                ),
              ],
            ),
          )
        else if (voiceAvailable == false)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              BnStrings.voiceUnavailable,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (!micDenied && (voiceAvailable ?? true)) ...[
          const SizedBox(height: 12),
          _buildMicPill(isListening),
        ],
      ],
    );
  }

  Widget _buildMicPill(bool listening) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: listening ? BnStrings.stopListening : BnStrings.micLabel,
      child: Semantics(
        button: true,
        label: listening ? BnStrings.stopListening : BnStrings.micLabel,
        excludeSemantics: true,
        child: InkWell(
          onTap: _toggleListening,
          borderRadius: BorderRadius.circular(AppRadius.xxxl),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: listening ? scheme.error : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xxxl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  listening ? Icons.stop : Icons.mic,
                  size: 20,
                  color: listening
                      ? scheme.onError
                      : scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  listening ? BnStrings.stopListening : BnStrings.micLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: listening
                        ? scheme.onError
                        : scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
