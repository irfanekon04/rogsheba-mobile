import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/api_exception.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:rogsheba_mobile/features/triage/triage_providers.dart';

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
  /// the conversation and echoed to `/triage/followup` on every answer.
  final String? initialSymptoms;

  /// Already-Bangla message shown verbatim, or `null` when all is well.
  final String? errorMessage;

  /// True while a follow-up answer is in flight to the AI.
  final bool isAnswerSubmitting;

  /// Follow-up-specific error message.
  final String? answerError;

  bool get canSubmit => symptoms.trim().isNotEmpty && !isSubmitting;

  bool get awaitingAnswer =>
      result?.followupQuestionBn != null &&
      !isAnswerSubmitting &&
      !isSubmitting;

  bool get hasPendingQuestion => result?.followupQuestionBn != null;

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

/// Orchestrates triage form state. Depends only on use cases — never on
/// repositories, data sources, or infrastructure directly.
class TriageController extends Notifier<TriageFormState> {
  @override
  TriageFormState build() => const TriageFormState();

  void onSymptomsChanged(String value) {
    state = state.copyWith(symptoms: value, clearError: true);
  }

  void resetConversation() {
    state = const TriageFormState();
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    final initialSymptoms = state.symptoms.trim();
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final useCase = await ref.read(submitSymptomsUseCaseProvider.future);
      final result = await useCase(initialSymptoms);
      state = state.copyWith(
        isSubmitting: false,
        result: result,
        initialSymptoms: initialSymptoms,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: BnStrings.genericError,
      );
    }
  }

  Future<void> submitAnswer(String answer) async {
    final trimmed = answer.trim();
    if (trimmed.isEmpty || !state.awaitingAnswer) return;
    final result = state.result;
    if (result == null) return;

    state = state.copyWith(isAnswerSubmitting: true, answerError: null);
    try {
      final useCase = await ref.read(submitFollowUpUseCaseProvider.future);
      final next = await useCase(
        initialSymptoms: state.initialSymptoms ?? '',
        answer: trimmed,
        turns: result.turns,
        sessionId: result.sessionId,
      );
      state = state.copyWith(isAnswerSubmitting: false, result: next);
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
}

final triageControllerProvider =
    NotifierProvider<TriageController, TriageFormState>(TriageController.new);
