import 'package:rogsheba_mobile/features/clinics/domain/clinics_repository.dart';
import 'package:rogsheba_mobile/features/clinics/domain/clinics_response.dart';

/// Orchestrates fetching nearby clinics. Optionally includes user coordinates
/// for distance-sorted results; omitting them returns the curated fallback list.
class FetchNearbyClinicsUseCase {
  const FetchNearbyClinicsUseCase({required this.repository});

  final ClinicsRepository repository;

  Future<ClinicsResponse> call({double? lat, double? lon}) {
    return repository.fetchNearby(lat: lat, lon: lon);
  }
}
