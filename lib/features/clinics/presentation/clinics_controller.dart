import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/api_exception.dart';
import 'package:rogsheba_mobile/core/services/location_service.dart';
import 'package:rogsheba_mobile/features/clinics/clinics_providers.dart';
import 'package:rogsheba_mobile/features/clinics/domain/clinic.dart';

enum ClinicsPhase { locating, loading, ready, failed }

class ClinicsViewState {
  const ClinicsViewState({
    this.phase = ClinicsPhase.locating,
    this.errorMessage,
    this.fallbackReason,
    this.userLat,
    this.userLon,
    this.clinics = const [],
  });

  final ClinicsPhase phase;
  final String? errorMessage;
  final String? fallbackReason;
  final double? userLat;
  final double? userLon;
  final List<Clinic> clinics;

  bool get usingFallback =>
      phase == ClinicsPhase.ready && userLat == null && userLon == null;

  bool get permissionDenied =>
      fallbackReason == BnStrings.fallbackBannerDenied;
}

class ClinicsController extends Notifier<ClinicsViewState> {
  @override
  ClinicsViewState build() => const ClinicsViewState();

  Future<void> locateAndLoad() async {
    state = const ClinicsViewState();
    final location = await ref.read(locationServiceProvider)();

    final fallbackBanner = switch (location) {
      LocationGranted() => null,
      LocationDenied() => BnStrings.fallbackBannerDenied,
      LocationDisabled() => BnStrings.fallbackBannerDisabled,
      LocationFailed() => BnStrings.fallbackBannerFailed,
    };

    final granted = location is LocationGranted;
    await _fetchNearby(
      lat: granted ? location.lat : null,
      lon: granted ? location.lon : null,
      fallbackBanner: fallbackBanner,
    );
  }

  Future<void> loadFallback() async {
    state = const ClinicsViewState();
    await _fetchNearby(
      lat: null,
      lon: null,
      fallbackBanner: BnStrings.fallbackBannerDenied,
    );
  }

  Future<void> _fetchNearby({
    required double? lat,
    required double? lon,
    required String? fallbackBanner,
  }) async {
    state = ClinicsViewState(
      phase: ClinicsPhase.loading,
      userLat: lat,
      userLon: lon,
    );

    try {
      final useCase = ref.read(fetchNearbyClinicsUseCaseProvider);
      final data = await useCase(lat: lat, lon: lon);
      final sorted = [...data.clinics]
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      final isFallback = data.source == 'fallback' || lat == null;

      state = ClinicsViewState(
        phase: ClinicsPhase.ready,
        userLat: lat,
        userLon: lon,
        fallbackReason: isFallback ? fallbackBanner : null,
        clinics: sorted,
      );
    } on ApiException catch (e) {
      state = ClinicsViewState(
        phase: ClinicsPhase.failed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = const ClinicsViewState(
        phase: ClinicsPhase.failed,
        errorMessage: BnStrings.fallbackUnavailable,
      );
    }
  }
}

final clinicsControllerProvider =
    NotifierProvider.autoDispose<ClinicsController, ClinicsViewState>(
      ClinicsController.new,
    );
