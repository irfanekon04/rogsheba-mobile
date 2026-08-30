import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';

/// Abstract contract for local emergency data persistence.
abstract interface class EmergencyLocalDataSource {
  Future<void> saveContacts(List<EmergencyContact> contacts);
  List<EmergencyContact>? readContacts();
}
