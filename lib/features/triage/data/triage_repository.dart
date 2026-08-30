import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/network/api_client.dart';
import 'package:rogsheba_mobile/core/network/api_response.dart';
import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// Speaks only to the `/triage` endpoints. Feature code never sees the envelope.
class TriageRepository {
  const TriageRepository({required this.api});

  final ApiClient api;

  Future<TriageResult> submitSymptoms(String symptoms) async {
    final envelope = await api.post('/triage', {
      'symptoms': symptoms,
    }, timeout: api.triageTimeout);
    return TriageResult.fromJson(unwrapApiEnvelope(envelope));
  }

  /// Sends the patient's `answer` to the latest follow-up question together
  /// with the `initialSymptoms` and the conversation `turns` so far. The API
  /// is stateless: it re-evaluates using exactly what we send back and returns
  /// the next question (or marks the conversation complete). Like `/triage`,
  /// this hits a slow AI upstream, so it uses the same generous timeout.
  Future<TriageResult> submitFollowUp({
    required String initialSymptoms,
    required String answer,
    required List<TriageTurn> turns,
    String? sessionId,
  }) async {
    final envelope = await api.post('/triage/followup', {
      if (sessionId != null) 'session_id': sessionId,
      'initial_symptoms': initialSymptoms,
      'turns': [for (final t in turns) t.toJson()],
      'answer': answer,
    }, timeout: api.triageTimeout);
    return TriageResult.fromJson(unwrapApiEnvelope(envelope));
  }
}

final triageRepositoryProvider = Provider<TriageRepository>(
  (ref) => TriageRepository(api: ref.watch(apiClientProvider)),
);
