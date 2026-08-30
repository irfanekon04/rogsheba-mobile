import 'package:rogsheba_mobile/features/clinics/domain/clinics_response.dart';

/// Abstract contract for remote clinics data.
abstract interface class ClinicsRemoteDataSource {
  Future<ClinicsResponse> fetchNearby({double? lat, double? lon});
}
