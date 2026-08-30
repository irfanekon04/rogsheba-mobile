import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/api_exception.dart';
import 'package:rogsheba_mobile/core/services/cache_service.dart';
import 'package:rogsheba_mobile/features/triage/data/triage_repository.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// State backing the home screen's symptom entry + result.
class TriageFormState {
  const TriageFormState({
    this.symptoms = '',
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.isAnswerSubmitting = false,
    this.answerError,
    this.initialSymptoms,
  });

  final String symptoms;
  final bool isSubmitting;
  final TriageResult? result;

  /// The original symptom description sent to `/triage`, kept for the life of
  /// the conversation and echoed to `/triage/followup` on every answer (the
  /// API is stateless and needs full context each call). `null` until the
  /// first submit, so follow-up resends are always paired with it.
  final String? initialSymptoms;

  /// Already-Bangla message shown verbatim, or `null` when all is well.
  final String? errorMessage;

  /// True while a follow-up answer is in flight to the AI.
  final bool isAnswerSubmitting;

  /// Follow-up-specific error message (the main submit keeps [errorMessage]).
  final String? answerError;

  /// Submit is disabled only while the field is empty or a request is in
  /// flight (prevents double submission).
  bool get canSubmit => symptoms.trim().isNotEmpty && !isSubmitting;

  /// True while there is an unanswered follow-up question and no request is
  /// in flight — the answer field + send button are shown only then.
  ///
  /// A pending question is signalled by `followupQuestionBn != null`; the
  /// `isComplete` flag only appears on `/triage/followup` responses (a first
  /// `/triage` never returns it, so it defaults to true without meaning the
  /// conversation is over).
  bool get awaitingAnswer =>
      result?.followupQuestionBn != null &&
      !isAnswerSubmitting &&
      !isSubmitting;

  TriageFormState copyWith({
    String? symptoms,
    bool? isSubmitting,
    TriageResult? result,
    String? errorMessage,
    Object? initialSymptoms = _sentinel,
    Object? isAnswerSubmitting = _sentinel,
    Object? answerError = _sentinel,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return TriageFormState(
      symptoms: symptoms ?? this.symptoms,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: clearResult ? null : result ?? this.result,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      initialSymptoms: identical(initialSymptoms, _sentinel)
          ? this.initialSymptoms
          : initialSymptoms as String?,
      isAnswerSubmitting: identical(isAnswerSubmitting, _sentinel)
          ? this.isAnswerSubmitting
          : isAnswerSubmitting! as bool,
      answerError: identical(answerError, _sentinel)
          ? this.answerError
          : answerError as String?,
    );
  }

  static const _sentinel = Object();
}

class TriageController extends Notifier<TriageFormState> {
  @override
  TriageFormState build() {
    // Cold start must not block on a network call — the cache read is local
    // and async, and the input field renders immediately regardless. A cached
    // result fills in as soon as the plugin store is ready.
    _restoreFromCache();
    return const TriageFormState();
  }

  /// Restores the most recent advice from cache so it is not lost when the
  /// connection drops. Best-effort: an absent, stale or unreadable cache is
  /// simply ignored.
  Future<void> _restoreFromCache() async {
    try {
      final cache = await ref.read(cacheServiceProvider.future);
      final cached = cache.readTriageResult();
      if (cached != null && state.result == null) {
        state = state.copyWith(result: cached);
      }
    } on Object {
      // A cache failure must never surface to the user at cold start.
    }
  }

  void onSymptomsChanged(String value) {
    state = state.copyWith(symptoms: value, clearError: true);
  }

  /// Starts a brand-new conversation: clears the current result, error and the
  /// symptom text so the initial home state is shown again (like a "new chat"
  /// button). The cached result is retained — it only re-hydrates when the
  /// conversation is truly empty, so it will not re-appear until the next
  /// cold start.
  void resetConversation() {
    state = const TriageFormState();
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    // Capture the original description before the request so it can be echoed
    // to /triage/followup for the rest of this conversation.
    final initialSymptoms = state.symptoms.trim();
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await ref
          .read(triageRepositoryProvider)
          .submitSymptoms(initialSymptoms);
      state = state.copyWith(
        isSubmitting: false,
        result: result,
        initialSymptoms: initialSymptoms,
      );
      await _persist(result);
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: BnStrings.genericError,
      );
    }
  }

  /// Sends the patient's [answer] to the current follow-up question, then
  /// replaces the result with the next server response. Level, banner and
  /// emergency number re-render automatically because the whole result is
  /// swapped. When the conversation completes (`isComplete`), no further
  /// question is shown.
  Future<void> submitAnswer(String answer) async {
    final trimmed = answer.trim();
    if (trimmed.isEmpty || !state.awaitingAnswer) return;
    final result = state.result;
    if (result == null) return;

    state = state.copyWith(isAnswerSubmitting: true, answerError: null);
    try {
      final next = await ref.read(triageRepositoryProvider).submitFollowUp(
            initialSymptoms: state.initialSymptoms ?? '',
            answer: trimmed,
            turns: result.turns,
            sessionId: result.sessionId,
          );
      state = state.copyWith(isAnswerSubmitting: false, result: next);
      await _persist(next);
    } on ApiException catch (e) {
      state =
          state.copyWith(isAnswerSubmitting: false, answerError: e.message);
    } catch (_) {
      state = state.copyWith(
        isAnswerSubmitting: false,
        answerError: BnStrings.genericError,
      );
    }
  }

  /// Persists the produced result for offline rendering. Symptom text never
  /// touches the cache — only the API's response does.
  Future<void> _persist(TriageResult result) async {
    try {
      final cache = await ref.read(cacheServiceProvider.future);
      await cache.saveTriageResult(result);
    } on Object {
      // Caching is best-effort; a failed write never fails the submit.
    }
  }
}

final triageControllerProvider =
    NotifierProvider<TriageController, TriageFormState>(TriageController.new);
