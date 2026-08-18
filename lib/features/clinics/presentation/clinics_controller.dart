import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/api_exception.dart';
import 'package:rogsheba_mobile/core/services/location_service.dart';
import 'package:rogsheba_mobile/features/clinics/data/clinics_repository.dart';
import 'package:rogsheba_mobile/features/clinics/domain/clinic.dart';

/// Which state the clinics screen is in.
enum ClinicsPhase {
  /// Still asking for permission / waiting on geolocator.
  locating,

  /// Have permission (or have given up on it); talking to `/clinics`.
  loading,

  /// A list is rendered (located or fallback). `usingFallback` on
  /// `ClinicsViewState` tells them apart — when true, `fallbackReason` is
  /// the Bangla banner above the list.
  ready,

  /// No list to render at all — network failure on either branch. Retry-only.
  failed,
}

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

  /// Already-Bangla message shown only when [phase] is `failed`.
  final String? errorMessage;

  /// Bangla prose banner shown above the list when [usingFallback] is true.
  final String? fallbackReason;

  /// User position once granted, used as the maps-directions origin.
  final double? userLat;
  final double? userLon;
  final List<Clinic> clinics;

  /// The ready state was reached via the `GET /clinics` fallback path —
  /// the server returned `source: "fallback"` because we did not have a
  /// position to send. The banner above the list is non-optional in v1.
  bool get usingFallback =>
      phase == ClinicsPhase.ready && userLat == null && userLon == null;

  /// The fallback was caused by a denied location permission (rather than
  /// disabled services or a failed lookup), so the screen offers a settings
  /// route in addition to retry.
  bool get permissionDenied => fallbackReason == BnStrings.fallbackBannerDenied;
}

/// Drives the clinics screen: locate on open, then fetch nearby facilities.
/// On any of the three location failure modes (denied / disabled / failed)
/// the controller falls through to `GET /clinics` with no coordinates and
/// renders the curated Dhaka list with a Bangla banner explaining why.
class ClinicsController extends Notifier<ClinicsViewState> {
  @override
  ClinicsViewState build() => const ClinicsViewState();

  /// Auto-locate (no button press needed), then load. Idempotent per screen
  /// visit because the provider is auto-disposed when the route is popped.
  Future<void> locateAndLoad() async {
    state = const ClinicsViewState();
    final location = await ref.read(locationServiceProvider)();

    // Mapped once so both branches below can fall through to the API call.
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

  /// Loads the curated Dhaka fallback list directly, without asking the OS
  /// for a position — used when permission is already denied (or the rationale
  /// was declined) so no system prompt fires. Renders the denied banner so the
  /// screen can offer the settings route.
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
    // Both paths go through /clinics: granted sends lat/lon, the others
    // omit them and get the server's curated Dhaka list back.
    state = ClinicsViewState(
      phase: ClinicsPhase.loading,
      userLat: lat,
      userLon: lon,
    );

    try {
      final data = await ref.read(
        clinicsRepositoryProvider,
      ).fetchNearby(lat: lat, lon: lon);
      // The server already sorts by distance, but re-sort client-side like
      // the web does so "nearest first" holds even past a reordering proxy.
      final sorted = [...data.clinics]
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      // The source field is authoritative: even if the caller thought it
      // had coordinates, an empty/fallback server response should still
      // surface as the fallback UX, not as a "we located you" empty list.
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
      // Even the fallback path's API call can fail (network down). Surface
      // the Bangla last-resort copy instead of the generic error so the user
      // knows there's a problem with the data, not with them.
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
