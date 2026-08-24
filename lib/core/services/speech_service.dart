import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// One recognised unit of speech, streamed as **partial** results (updating
/// live while the user talks) and closed by a **final** result (the committed
/// transcript for that utterance).
class SpeechTranscript {
  const SpeechTranscript(this.text, {this.isFinal = false});

  final String text;

  /// `true` when the recogniser is done with this utterance and the text is
  /// safe to commit to the field.
  final bool isFinal;
}

/// Streams Bangla dictation for the symptom field — the counterpart to voice
/// output. Narrow by design: UI and tests depend only on this contract, never
/// on `speech_to_text` directly.
abstract interface class SpeechService {
  /// Whether `bn-BD` on-device recognition is available on this device.
  Future<bool> supportsBangla();

  /// Live dictation: partial transcripts updating while speaking, then a final
  /// transcript per utterance. Nothing is emitted while not listening.
  Stream<SpeechTranscript> get transcripts;

  /// Begins a listening session. Recognised text arrives on [transcripts].
  Future<void> startListening();

  /// Ends the current session; no further events are emitted.
  Future<void> stopListening();

  /// Whether a listening session is currently active.
  bool get isListening;
}

/// Real implementation backed by `speech_to_text`, configured for `bn-BD`
/// with partial results enabled so interim words can be rendered live.
class FlutterSpeechService implements SpeechService {
  FlutterSpeechService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  /// Upper bound for the locale probe in [supportsBangla].
  static const Duration _localeProbeTimeout = Duration(seconds: 2);

  final SpeechToText _speech;
  final StreamController<SpeechTranscript> _controller =
      StreamController<SpeechTranscript>.broadcast();

  bool? _initWorked;
  bool _listening = false;

  @override
  Stream<SpeechTranscript> get transcripts => _controller.stream;

  @override
  bool get isListening => _listening;

  Future<bool> _initialize() async {
    if (_initWorked != null) return _initWorked!;
    debugPrint('STT: initialize() starting');
    final ok = await _speech.initialize(
      onError: (e) => debugPrint('STT: error ${e.errorMsg}'),
      onStatus: (s) => debugPrint('STT: status $s'),
    );
    debugPrint('STT: initialize() -> $ok');
    _initWorked = ok;
    return ok;
  }

  @override
  Future<bool> supportsBangla() async {
    if (!await _initialize()) return false;
    try {
      final locales = await _speech.locales().timeout(_localeProbeTimeout);
      debugPrint('STT: locales=${locales.map((l) => l.localeId).toList()}');
      final has = locales.any((l) => l.localeId.toLowerCase().startsWith('bn'));
      debugPrint('STT: supportsBangla -> $has');
      return has;
    } on TimeoutException {
      // speech_to_text 7.4.0 never resolves its Android `locales` result on
      // devices without an on-device recogniser (the plugin only completes
      // the platform answer inside `isOnDeviceRecognitionAvailable`'s happy
      // path). Optimistically assume support and let `listen()` report real
      // failures through its error callback.
      debugPrint('STT: locales probe timed out — assuming Bangla supported');
      return true;
    }
  }

  @override
  Future<void> startListening() async {
    if (_listening) return;
    if (!await _initialize()) {
      debugPrint('STT: startListening aborted — not initialized');
      return;
    }
    _listening = true;
    debugPrint('STT: listen(bn-BD) starting');
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        localeId: 'bn-BD',
      ),
      onResult: (result) {
        if (!_controller.isClosed) {
          _controller.add(
            SpeechTranscript(
              result.recognizedWords,
              isFinal: result.finalResult,
            ),
          );
        }
      },
    );
  }

  @override
  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;
    await _speech.stop();
  }
}

/// Composition root. Tests override this with a hand-written fake.
final speechServiceProvider =
    Provider<SpeechService>((ref) => FlutterSpeechService());
