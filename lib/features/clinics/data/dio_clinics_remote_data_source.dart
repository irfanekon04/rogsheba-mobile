import 'package:rogsheba_mobile/core/network/api_client.dart';
import 'package:rogsheba_mobile/core/network/api_response.dart';
import 'package:rogsheba_mobile/features/clinics/data/clinics_remote_data_source.dart';
import 'package:rogsheba_mobile/features/clinics/domain/clinics_response.dart';

/// Concrete remote data source wrapping [ApiClient].
class DioClinicsRemoteDataSource implements ClinicsRemoteDataSource {
  const DioClinicsRemoteDataSource({required this.api});

  final ApiClient api;

  @override
  Future<ClinicsResponse> fetchNearby({double? lat, double? lon}) async {
    final envelope = await api.get('/clinics', queryParameters: {
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
    });
    return ClinicsResponse.fromJson(unwrapApiEnvelope(envelope));
  }
}
