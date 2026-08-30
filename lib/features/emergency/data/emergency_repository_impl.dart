import 'package:rogsheba_mobile/features/emergency/data/emergency_local_data_source.dart';
import 'package:rogsheba_mobile/features/emergency/data/emergency_remote_data_source.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_repository.dart';

/// Concrete repository implementing [EmergencyRepository].
class EmergencyRepositoryImpl implements EmergencyRepository {
  const EmergencyRepositoryImpl({
    required this.remote,
    required this.local,
  });

  final EmergencyRemoteDataSource remote;
  final EmergencyLocalDataSource local;

  @override
  Future<EmergencyContactsResponse> fetchContacts() async {
    // Try cache first.
    final cached = local.readContacts();
    if (cached != null) {
      return EmergencyContactsResponse(
        country: '',
        contacts: cached,
      );
    }
    // Fetch from network and persist.
    final response = await remote.fetchContacts();
    await _persist(response.contacts);
    return response;
  }

  Future<void> _persist(List<EmergencyContact> contacts) async {
    try {
      await local.saveContacts(contacts);
    } on Object {
      // Best-effort cache write.
    }
  }
}
