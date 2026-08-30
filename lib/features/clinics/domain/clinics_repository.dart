import 'package:rogsheba_mobile/features/clinics/domain/clinics_response.dart';

/// Abstract contract for the clinics data layer.
abstract interface class ClinicsRepository {
  Future<ClinicsResponse> fetchNearby({double? lat, double? lon});
}
