import 'package:rogsheba_mobile/core/network/api_client.dart';
import 'package:rogsheba_mobile/core/network/api_response.dart';
import 'package:rogsheba_mobile/features/emergency/data/emergency_remote_data_source.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';

/// Concrete remote data source wrapping [ApiClient].
class DioEmergencyRemoteDataSource implements EmergencyRemoteDataSource {
  const DioEmergencyRemoteDataSource({required this.api});

  final ApiClient api;

  @override
  Future<EmergencyContactsResponse> fetchContacts() async {
    final envelope = await api.get('/emergency');
    return EmergencyContactsResponse.fromJson(unwrapApiEnvelope(envelope));
  }
}
