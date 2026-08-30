import 'package:rogsheba_mobile/features/clinics/data/clinics_remote_data_source.dart';
import 'package:rogsheba_mobile/features/clinics/domain/clinics_repository.dart';
import 'package:rogsheba_mobile/features/clinics/domain/clinics_response.dart';

/// Concrete repository implementing [ClinicsRepository].
class ClinicsRepositoryImpl implements ClinicsRepository {
  const ClinicsRepositoryImpl({required this.remote});

  final ClinicsRemoteDataSource remote;

  @override
  Future<ClinicsResponse> fetchNearby({double? lat, double? lon}) {
    return remote.fetchNearby(lat: lat, lon: lon);
  }
}
