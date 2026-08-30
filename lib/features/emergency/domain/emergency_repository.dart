import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';

/// Abstract contract for the emergency data layer.
abstract interface class EmergencyRepository {
  Future<EmergencyContactsResponse> fetchContacts();
}
