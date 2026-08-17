import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds exactly two things for offline use: the most recent [TriageResult]
/// and the `/emergency` contact list with a 24-hour TTL.
///
/// Deliberately **not** behind an interface — per the offline slice, the real
/// cache code must run in tests through `shared_preferences`' mock
/// initial-values hook so serialisation itself stays under test. The plugin's
/// in-memory store keeps reads cheap, so a cold start never blocks on it.
///
/// Symptom text is never written here: [TriageResult] carries no symptom field
/// by design, so there is nothing sensitive to persist.
class CacheService {
  const CacheService({required this.prefs});

  final SharedPreferences prefs;

  static const triageResultKey = 'cache.triage_result';
  static const emergencyContactsKey = 'cache.emergency_contacts';
  static const emergencyCachedAtKey = 'cache.emergency_contacts_cached_at';

  /// The `/emergency` list is served from cache for at most this long; after
  /// that the caller must refetch rather than show stale numbers.
  static const emergencyCacheTtl = Duration(hours: 24);

  Future<void> saveTriageResult(TriageResult result) {
    return prefs.setString(triageResultKey, jsonEncode(result.toJson()));
  }

  /// The most recent triage result, or `null` when none has been cached.
  /// Corrupt JSON is treated as absent — a bad cache must never crash the app.
  TriageResult? readTriageResult() {
    final raw = prefs.getString(triageResultKey);
    if (raw == null) return null;
    try {
      return TriageResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) {
    final encoded = jsonEncode([for (final c in contacts) c.toJson()]);
    return Future.wait([
      prefs.setString(emergencyContactsKey, encoded),
      prefs.setInt(emergencyCachedAtKey, DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  /// Cached contacts only while they are younger than [emergencyCacheTtl].
  /// Missing, stale or corrupt data all return `null` so the caller refetches
  /// rather than showing numbers that may be outdated.
  List<EmergencyContact>? readEmergencyContacts() {
    final cachedAt = prefs.getInt(emergencyCachedAtKey);
    if (cachedAt == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
    if (age > emergencyCacheTtl.inMilliseconds) return null;
    final raw = prefs.getString(emergencyContactsKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in decoded.whereType<Map<String, dynamic>>())
          EmergencyContact.fromJson(entry),
      ];
    } on Object {
      return null;
    }
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// Composition root. `shared_preferences`' mock initial-values hook lets tests
/// drive the real [CacheService] with no interface in between.
final cacheServiceProvider = FutureProvider<CacheService>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return CacheService(prefs: prefs);
});
