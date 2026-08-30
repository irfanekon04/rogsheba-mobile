import 'dart:convert';

import 'package:rogsheba_mobile/features/emergency/data/emergency_local_data_source.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed local data source for emergency contacts.
/// Includes a 24-hour TTL so stale data is never served.
class SharedPreferencesEmergencyLocalDataSource
    implements EmergencyLocalDataSource {
  const SharedPreferencesEmergencyLocalDataSource({required this.prefs});

  final SharedPreferences prefs;

  static const _contactsKey = 'cache.emergency_contacts';
  static const _cachedAtKey = 'cache.emergency_contacts_cached_at';
  static const _ttl = Duration(hours: 24);

  @override
  Future<void> saveContacts(List<EmergencyContact> contacts) {
    final encoded = jsonEncode([for (final c in contacts) c.toJson()]);
    return Future.wait([
      prefs.setString(_contactsKey, encoded),
      prefs.setInt(_cachedAtKey, DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  @override
  List<EmergencyContact>? readContacts() {
    final cachedAt = prefs.getInt(_cachedAtKey);
    if (cachedAt == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
    if (age > _ttl.inMilliseconds) return null;
    final raw = prefs.getString(_contactsKey);
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
