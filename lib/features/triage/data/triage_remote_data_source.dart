import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// Abstract contract for remote triage data. The concrete implementation
/// wraps ApiClient; tests substitute a fake.
abstract interface class TriageRemoteDataSource {
  Future<TriageResult> submitSymptoms(String symptoms);

  Future<TriageResult> submitFollowUp({
    required String initialSymptoms,
    required String answer,
    required List<TriageTurn> turns,
    String? sessionId,
  });
}
