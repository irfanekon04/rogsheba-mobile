import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:rogsheba_mobile/features/triage/presentation/tts_script.dart';

/// Immutable state for the TTS speak button.
class TtsState {
  const TtsState({this.voiceAvailable, this.isSpeaking = false});

  /// `null` while the capability check is in flight, `false` when no `bn-BD`
  /// voice exists. Only `true` renders the button.
  final bool? voiceAvailable;
  final bool isSpeaking;

  TtsState copyWith({bool? voiceAvailable, bool? isSpeaking}) {
    return TtsState(
      voiceAvailable: voiceAvailable ?? this.voiceAvailable,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

/// Manages text-to-speech state: voice capability check, play/stop toggle.
class TtsController extends Notifier<TtsState> {
  late final TtsService _tts;

  @override
  TtsState build() {
    _tts = ref.read(ttsServiceProvider);
    ref.onDispose(() => _tts.stop());
    _checkVoiceAvailable();
    return const TtsState();
  }

  Future<void> _checkVoiceAvailable() async {
    final available = await _tts.supportsBanglaVoice();
    state = state.copyWith(voiceAvailable: available);
  }

  /// Toggle playback for the given [result]. Stops if already speaking,
  /// otherwise reads the result aloud in Bangla.
  Future<void> toggle(TriageResult result) async {
    if (state.isSpeaking) {
      await _tts.stop();
      if (ref.mounted) state = state.copyWith(isSpeaking: false);
    } else {
      state = state.copyWith(isSpeaking: true);
      await _tts.speak(buildSpeechText(result));
      if (ref.mounted) state = state.copyWith(isSpeaking: false);
    }
  }
}

final ttsProvider =
    NotifierProvider.autoDispose<TtsController, TtsState>(TtsController.new);
