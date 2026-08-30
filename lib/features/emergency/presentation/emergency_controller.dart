import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/api_exception.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';
import 'package:rogsheba_mobile/features/emergency/emergency_providers.dart';

/// Drives the emergency sheet. Depends only on use cases — never on
/// repositories, data sources, or infrastructure directly.
class EmergencyController
    extends AsyncNotifier<List<EmergencyContact>> {
  @override
  Future<List<EmergencyContact>> build() async {
    final useCase =
        await ref.read(fetchEmergencyContactsUseCaseProvider.future);
    final response = await useCase();
    return response.contacts;
  }

  /// Retry path used by the sheet's error branch.
  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final useCase =
          await ref.read(fetchEmergencyContactsUseCaseProvider.future);
      final response = await useCase();
      return response.contacts;
    });
  }
}

String emergencyErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return BnStrings.emergencyLoadFailed;
}

final emergencyControllerProvider = AsyncNotifierProvider<
  EmergencyController, List<EmergencyContact>>(
  EmergencyController.new,
  retry: (_, _) => null,
);
