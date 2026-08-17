import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/api_exception.dart';
import 'package:rogsheba_mobile/core/services/cache_service.dart';
import 'package:rogsheba_mobile/features/emergency/data/emergency_repository.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';

/// Drives the emergency sheet. Serves the cached contact list when it is
/// younger than 24h (the numbers the user most needs when nothing else works),
/// and refetches from the API when the cache is absent or stale. Exposes the
/// standard `AsyncValue` so the sheet can render loading/error/data branches
/// without bespoke state.
class EmergencyController
    extends AsyncNotifier<List<EmergencyContact>> {
  @override
  Future<List<EmergencyContact>> build() async {
    final cached = await _cachedContacts();
    if (cached != null) return cached;
    return _fetchAndCache();
  }

  Future<List<EmergencyContact>?> _cachedContacts() async {
    try {
      final cache = await ref.read(cacheServiceProvider.future);
      return cache.readEmergencyContacts();
    } on Object {
      return null; // unreadable cache → fall through to the network
    }
  }

  Future<List<EmergencyContact>> _fetchAndCache() async {
    final repo = ref.read(emergencyRepositoryProvider);
    final response = await repo.fetchContacts();
    await _persist(response.contacts);
    return response.contacts;
  }

  Future<void> _persist(List<EmergencyContact> contacts) async {
    try {
      final cache = await ref.read(cacheServiceProvider.future);
      await cache.saveEmergencyContacts(contacts);
    } on Object {
      // Best-effort; a failed cache write never fails the sheet.
    }
  }

  /// Retry path used by the sheet's error branch.
  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchAndCache);
  }
}

/// Maps the `AsyncValue` error into a Bangla line for the sheet. The API
/// error message is preserved when present so the user sees something
/// more specific than the generic copy, just like the rest of the app.
String emergencyErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return BnStrings.emergencyLoadFailed;
}

final emergencyControllerProvider = AsyncNotifierProvider<
  EmergencyController, List<EmergencyContact>>(
  EmergencyController.new,
  // Retry is the user's choice: the sheet has its own "আবার চেষ্টা করুন"
  // pill. Disabling the framework default (10 attempts with exponential
  // backoff, up to 6.4s) avoids silent re-fetches while the Bangla error
  // copy is rendered.
  retry: (_, _) => null,
);
