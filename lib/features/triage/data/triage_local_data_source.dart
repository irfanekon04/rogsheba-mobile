import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

/// Abstract contract for local triage persistence. The concrete implementation
/// wraps SharedPreferences; tests substitute a fake.
abstract interface class TriageLocalDataSource {
  Future<void> saveResult(TriageResult result);
  TriageResult? readResult();
}
