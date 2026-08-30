import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// Abstract contract for the triage data layer. Domain and presentation depend
/// only on this interface — the concrete implementation lives in data/.
abstract interface class TriageRepository {
  Future<TriageResult> submitSymptoms(String symptoms);

  Future<TriageResult> submitFollowUp({
    required String initialSymptoms,
    required String answer,
    required List<TriageTurn> turns,
    String? sessionId,
  });
}
