import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/services/permission_service.dart';
import 'package:rogsheba_mobile/core/services/speech_service.dart';

/// Result of [VoiceInputController.toggleListening] telling the widget which
/// UI action to take (show a rationale dialog, open settings, etc.).
enum VoiceAction { started, stopped, needsRationale, needsSettings }

/// Immutable state for a single voice input instance.
class VoiceInputState {
  const VoiceInputState({
    this.voiceAvailable,
    this.isListening = false,
    this.interim = '',
    this.micDenied = false,
  });

  /// `null` while the capability check is in flight.
  final bool? voiceAvailable;
  final bool isListening;
  final String interim;

  /// `true` once the user has permanently denied the mic — the settings route
  /// is offered.
  final bool micDenied;

  VoiceInputState copyWith({
    bool? voiceAvailable,
    bool? isListening,
    String? interim,
    bool? micDenied,
    bool clearVoiceAvailable = false,
  }) {
    return VoiceInputState(
      voiceAvailable:
          clearVoiceAvailable ? null : voiceAvailable ?? this.voiceAvailable,
      isListening: isListening ?? this.isListening,
      interim: interim ?? this.interim,
      micDenied: micDenied ?? this.micDenied,
    );
  }
}

/// Manages voice-input state for a single text field: permission checks,
/// speech-service interaction, transcript streaming, and interim text.
///
/// Each widget instance gets its own controller via the `autoDispose.family`
/// provider keyed by a unique id (e.g. `'symptom'` or `'followup_0'`).
class VoiceInputController extends Notifier<VoiceInputState> {
  // ignore: avoid_unused_constructor_parameters
  VoiceInputController(String _);

  late final SpeechService _speech;
  late final PermissionService _permission;
  StreamSubscription<SpeechTranscript>? _subscription;

  /// Broadcast stream of final transcripts. The widget subscribes once in
  /// its initState and appends each value to its TextEditingController.
  final StreamController<String> _finalTranscriptController =
      StreamController<String>.broadcast();

  /// Final transcripts — emitted once per utterance when the recogniser
  /// commits the text. The owning widget subscribes and appends.
  Stream<String> get finalTranscripts => _finalTranscriptController.stream;

  @override
  VoiceInputState build() {
    _speech = ref.read(speechServiceProvider);
    _permission = ref.read(permissionServiceProvider);
    ref.onDispose(() {
      _subscription?.cancel();
      _speech.stopListening();
      _finalTranscriptController.close();
    });
    return const VoiceInputState();
  }

  /// Probe mic permission and voice availability. Called once on widget init.
  Future<void> checkVoiceAvailable() async {
    final mic = await _permission.microphoneStatus();
    switch (mic) {
      case PermissionState.granted:
        final available = await _speech.supportsBangla();
        state = state.copyWith(voiceAvailable: available);
      case PermissionState.notDetermined:
        break;
      case PermissionState.denied:
      case PermissionState.deniedForever:
      case PermissionState.restricted:
        final store = await ref.read(permissionRationaleStoreProvider.future);
        final accepted = await store.micAccepted();
        if (accepted) {
          state = state.copyWith(voiceAvailable: false, micDenied: true);
        }
    }
  }

  /// Toggle listening. Returns a [VoiceAction] telling the widget which UI
  /// action to take after the controller has done its part.
  Future<VoiceAction> toggleListening() async {
    if (state.isListening) {
      await stopListening();
      return VoiceAction.stopped;
    }

    final mic = await _permission.microphoneStatus();
    if (mic == PermissionState.granted) {
      await _ensureAvailableAndStart();
      return VoiceAction.started;
    }

    final store = await ref.read(permissionRationaleStoreProvider.future);
    if (!await store.micAccepted()) {
      return VoiceAction.needsRationale;
    }

    if (mic == PermissionState.notDetermined) {
      await _ensureAvailableAndStart();
      return VoiceAction.started;
    }

    return VoiceAction.needsSettings;
  }

  /// Mark rationale accepted and attempt to start listening.
  Future<void> markRationaleAcceptedAndStart() async {
    final store = await ref.read(permissionRationaleStoreProvider.future);
    await store.markMicAccepted();
    await _ensureAvailableAndStart();
  }

  /// Start listening unconditionally (called after permission is confirmed).
  Future<void> startListening() async {
    await _startListening();
  }

  Future<void> _ensureAvailableAndStart() async {
    if (state.voiceAvailable == null) {
      final available = await _speech.supportsBangla();
      state = state.copyWith(voiceAvailable: available);
      if (!available) {
        final mic = await _permission.microphoneStatus();
        if (mic != PermissionState.granted) {
          state = state.copyWith(micDenied: true);
        }
        return;
      }
    }
    if (state.voiceAvailable != true) return;
    await _startListening();
  }

  Future<void> _startListening() async {
    _subscription = _speech.transcripts.listen(_onTranscript);
    await _speech.startListening();
    state = state.copyWith(isListening: true, interim: '');
  }

  void _onTranscript(SpeechTranscript transcript) {
    if (transcript.isFinal) {
      _finalTranscriptController.add(transcript.text);
      _stopListeningInternal();
    } else {
      state = state.copyWith(interim: transcript.text);
    }
  }

  Future<void> stopListening() async {
    await _stopListeningInternal();
  }

  Future<void> _stopListeningInternal() async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _speech.stopListening();
    state = state.copyWith(isListening: false, interim: '');
  }
}

final voiceInputProvider = NotifierProvider.autoDispose.family<
    VoiceInputController, VoiceInputState, String>(
  VoiceInputController.new,
);
