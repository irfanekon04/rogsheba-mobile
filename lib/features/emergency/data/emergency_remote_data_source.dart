import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';

/// Abstract contract for remote emergency data.
abstract interface class EmergencyRemoteDataSource {
  Future<EmergencyContactsResponse> fetchContacts();
}
