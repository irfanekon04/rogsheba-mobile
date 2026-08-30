import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_repository.dart';

/// Orchestrates fetching emergency contacts: checks cache, fetches from
/// network if stale, and persists the result.
class FetchEmergencyContactsUseCase {
  const FetchEmergencyContactsUseCase({required this.repository});

  final EmergencyRepository repository;

  Future<EmergencyContactsResponse> call() {
    return repository.fetchContacts();
  }
}
