import 'package:rogsheba_mobile/features/triage/data/triage_local_data_source.dart';
import 'package:rogsheba_mobile/features/triage/data/triage_remote_data_source.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_repository.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// Concrete repository implementing [TriageRepository]. Composes a remote
/// data source (API calls) and a local data source (cache persistence).
class TriageRepositoryImpl implements TriageRepository {
  const TriageRepositoryImpl({
    required this.remote,
    required this.local,
  });

  final TriageRemoteDataSource remote;
  final TriageLocalDataSource local;

  @override
  Future<TriageResult> submitSymptoms(String symptoms) async {
    final result = await remote.submitSymptoms(symptoms);
    await _persist(result);
    return result;
  }

  @override
  Future<TriageResult> submitFollowUp({
    required String initialSymptoms,
    required String answer,
    required List<TriageTurn> turns,
    String? sessionId,
  }) async {
    final result = await remote.submitFollowUp(
      initialSymptoms: initialSymptoms,
      answer: answer,
      turns: turns,
      sessionId: sessionId,
    );
    await _persist(result);
    return result;
  }

  /// Best-effort cache write; a failure never blocks the caller.
  Future<void> _persist(TriageResult result) async {
    try {
      await local.saveResult(result);
    } on Object {
      // Caching is best-effort.
    }
  }
}
