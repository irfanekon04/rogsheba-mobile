import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:rogsheba_mobile/features/triage/presentation/tts_controller.dart';

/// Speaker toggle on the result card header: reads the result aloud in Bangla,
/// or stops playback when already speaking. Hidden entirely when no `bn-BD`
/// voice is installed.
class SpeakButton extends ConsumerWidget {
  const SpeakButton({required this.result, super.key});

  final TriageResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsProvider);
    if (ttsState.voiceAvailable != true) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: () => ref.read(ttsProvider.notifier).toggle(result),
      icon: Icon(
        ttsState.isSpeaking ? Icons.stop : Icons.volume_up,
        size: 20,
      ),
      label: Text(
        ttsState.isSpeaking ? BnStrings.ttsStop : BnStrings.ttsListen,
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: scheme.primary,
      ),
    );
  }
}
