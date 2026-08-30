import 'package:rogsheba_mobile/features/triage/domain/triage_repository.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// Orchestrates follow-up answer submission: calls the repository and returns
/// the next triage result. The repository handles persistence internally.
class SubmitFollowUpUseCase {
  const SubmitFollowUpUseCase({required this.repository});

  final TriageRepository repository;

  Future<TriageResult> call({
    required String initialSymptoms,
    required String answer,
    required List<TriageTurn> turns,
    String? sessionId,
  }) {
    return repository.submitFollowUp(
      initialSymptoms: initialSymptoms,
      answer: answer,
      turns: turns,
      sessionId: sessionId,
    );
  }
}
