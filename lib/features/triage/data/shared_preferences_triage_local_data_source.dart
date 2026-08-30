import 'dart:convert';

import 'package:rogsheba_mobile/features/triage/data/triage_local_data_source.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed local data source for triage results.
class SharedPreferencesTriageLocalDataSource implements TriageLocalDataSource {
  const SharedPreferencesTriageLocalDataSource({required this.prefs});

  final SharedPreferences prefs;

  static const _key = 'cache.triage_result';

  @override
  Future<void> saveResult(TriageResult result) {
    return prefs.setString(_key, jsonEncode(result.toJson()));
  }

  @override
  TriageResult? readResult() {
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return TriageResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}
