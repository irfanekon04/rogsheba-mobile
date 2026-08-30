import 'package:rogsheba_mobile/core/network/api_client.dart';
import 'package:rogsheba_mobile/core/network/api_response.dart';
import 'package:rogsheba_mobile/features/triage/data/triage_remote_data_source.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// Concrete remote data source wrapping [ApiClient]. Translates HTTP calls
/// into domain models via JSON deserialisation.
class DioTriageRemoteDataSource implements TriageRemoteDataSource {
  const DioTriageRemoteDataSource({required this.api});

  final ApiClient api;

  @override
  Future<TriageResult> submitSymptoms(String symptoms) async {
    final envelope = await api.post(
      '/triage',
      {'symptoms': symptoms},
      timeout: api.triageTimeout,
    );
    return TriageResult.fromJson(unwrapApiEnvelope(envelope));
  }

  @override
  Future<TriageResult> submitFollowUp({
    required String initialSymptoms,
    required String answer,
    required List<TriageTurn> turns,
    String? sessionId,
  }) async {
    final envelope = await api.post(
      '/triage/followup',
      {
        if (sessionId != null) 'session_id': sessionId,
        'initial_symptoms': initialSymptoms,
        'turns': [for (final t in turns) t.toJson()],
        'answer': answer,
      },
      timeout: api.triageTimeout,
    );
    return TriageResult.fromJson(unwrapApiEnvelope(envelope));
  }
}
