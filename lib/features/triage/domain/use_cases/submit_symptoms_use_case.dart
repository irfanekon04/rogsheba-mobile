import 'package:rogsheba_mobile/features/triage/domain/triage_repository.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// Orchestrates symptom submission: calls the repository and returns the
/// triage result. The repository handles persistence internally.
class SubmitSymptomsUseCase {
  const SubmitSymptomsUseCase({required this.repository});

  final TriageRepository repository;

  Future<TriageResult> call(String symptoms) {
    return repository.submitSymptoms(symptoms);
  }
}
