import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pure URL construction for the clinics deep links. Kept deliberately free of
/// any IO so the exact strings are unit-testable without launching anything.
abstract final class MapUrls {
  /// Google Maps turn-by-turn directions from the user's position.
  ///
  /// Falls back to the Maps `search` variant when the origin (the user's own
  /// coordinates) is unknown — same degradation as on the web.
  static Uri directions({
    required double destinationLat,
    required double destinationLon,
    double? originLat,
    double? originLon,
  }) {
    if (originLat != null && originLon != null) {
      return Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=$originLat,$originLon'
        '&destination=$destinationLat,$destinationLon',
      );
    }
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=$destinationLat,$destinationLon',
    );
  }

  /// Opens the facility's location at level 17 on OpenStreetMap.
  static Uri osmLocation({required double lat, required double lon}) {
    return Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon',
    );
  }
}

/// Pure URL construction for the `tel:` dialer. Kept next to [MapUrls] so
/// every external URI the app launches is unit-testable without a real
/// platform channel.
abstract final class TelUrls {
  /// `tel:` URI for the dialer. The number is taken verbatim — Arabic-to-
  /// Bengali numeral conversion is the UI's job, not the URL builder's.
  static Uri dial(String number) => Uri.parse('tel:$number');
}

/// Opens external apps (maps deep links here, `tel:` for emergency numbers).
/// A function type keeps the seam injectable for tests without a launched
/// platform channel: [launcherServiceProvider] is overridden with a closure
/// that records the URIs.
typedef OpenExternalUri = Future<bool> Function(Uri uri);

/// Real launcher. [launchUrl] returns `false` for most failures, but on
/// Android the platform plugin throws `PlatformException(ACTIVITY_NOT_FOUND)`
/// when no installed app claims the scheme (a fresh emulator with no
/// browser, an unmapped deep link, etc.). Without this catch the exception
/// bubbles up as an `Unhandled Exception` and Flutter prints a stack —
/// the symptom this fix targets.
///
/// We swallow the failure and return `false`. A future caller-facing
/// improvement is to surface a Bangla snackbar when the launch fails; for
/// now the same `false` return lets the existing widgets continue.
Future<bool> _launchExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException catch (e, stack) {
    // Most commonly "ACTIVITY_NOT_FOUND" on Android when no browser /
    // maps app is installed; also covers `MissingPluginException` (it's
    // a subtype of PlatformException). Logged only in debug; production
    // goes silent.
    debugPrint('launcher_service: failed to launch $uri: $e');
    debugPrintStack(stackTrace: stack);
    return false;
  }
}

final launcherServiceProvider = Provider<OpenExternalUri>(
  (_) => _launchExternal,
);
