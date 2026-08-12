import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogsheba_mobile/core/services/launcher_service.dart';

/// Pure-Dart URL construction tests for issue #8 acceptance criterion 7:
/// "URL construction is unit-tested independently of launching anything."
///
/// These tests assert the **exact** strings the web component produces,
/// lifted from `docs/MOBILE_API.md` §3 and `MOBILE_PLAN.md` §4.9. They do
/// not touch `url_launcher` or any platform channel.
void main() {
  group('MapUrls.directions', () {
    test(
      'builds the Google Maps directions URL with both origin and destination',
      () {
        final uri = MapUrls.directions(
          destinationLat: 23.7525,
          destinationLon: 90.3786,
          originLat: 23.7806,
          originLon: 90.4074,
        );

        expect(
          uri.toString(),
          'https://www.google.com/maps/dir/?api=1'
          '&origin=23.7806,90.4074'
          '&destination=23.7525,90.3786',
        );
      },
    );

    test('falls back to the search variant when the origin is unknown', () {
      final uri = MapUrls.directions(
        destinationLat: 23.7525,
        destinationLon: 90.3786,
      );

      expect(
        uri.toString(),
        'https://www.google.com/maps/search/?api=1'
        '&query=23.7525,90.3786',
      );
    });

    test(
      'search variant is used when only one of originLat/originLon is null',
      () {
        // Both halves must be present for the directions variant. Half-given
        // coordinates would build an invalid directions URL.
        final uriMissingLat = MapUrls.directions(
          destinationLat: 23.7525,
          destinationLon: 90.3786,
          originLon: 90.4074,
        );
        expect(
          uriMissingLat.toString(),
          startsWith('https://www.google.com/maps/search/'),
        );

        final uriMissingLon = MapUrls.directions(
          destinationLat: 23.7525,
          destinationLon: 90.3786,
          originLat: 23.7806,
        );
        expect(
          uriMissingLon.toString(),
          startsWith('https://www.google.com/maps/search/'),
        );
      },
    );

    test('emits no origin when it is absent', () {
      // Regression guard: the old `&origin=23.7525,90.3786` form (where the
      // destination was accidentally used as the origin) would have routed
      // the user from the clinic instead of from themselves.
      final uri = MapUrls.directions(
        destinationLat: 23.7525,
        destinationLon: 90.3786,
      );
      expect(uri.toString(), isNot(contains('origin=')));
    });
  });

  group('MapUrls.osmLocation', () {
    test('builds the OpenStreetMap pin URL at zoom 17', () {
      final uri = MapUrls.osmLocation(lat: 23.7525, lon: 90.3786);

      expect(
        uri.toString(),
        'https://www.openstreetmap.org/?mlat=23.7525&mlon=90.3786'
        '#map=17/23.7525/90.3786',
      );
    });
  });

  group('TelUrls.dial', () {
    test('emits the canonical tel: scheme for the 999 hotline', () {
      // Issue #10 acceptance: "Tapping ৯৯৯ calls tel:999". The URL builder
      // is Arabic-format-only — Bengali-numerals conversion is the widget's
      // job, so this URL is exactly what the OS dialer receives.
      expect(TelUrls.dial('999').toString(), 'tel:999');
    });

    test('preserves multi-digit numbers as-is', () {
      expect(TelUrls.dial('16263').toString(), 'tel:16263');
    });

    test('does not add an origin or any other query parameters', () {
      // Regression guard: any extra data on a `tel:` URI is invalid and the
      // dialer ignores it. The builder must produce exactly `tel:<digits>`.
      final uri = TelUrls.dial('999');
      expect(uri.scheme, 'tel');
      expect(uri.path, '999');
      expect(uri.hasQuery, isFalse);
      expect(uri.queryParameters, isEmpty);
    });
  });

  group('launcherServiceProvider', () {
    testWidgets(
      'the production launcher returns false — instead of crashing — when '
      'the platform channel throws PlatformException',
      (tester) async {
        // The bug being regression-tested: on a fresh Android emulator with
        // no browser installed, tapping "ম্যাপে দেখুন" raises
        // PlatformException(ACTIVITY_NOT_FOUND) on the url_launcher
        // channel. The production wrapper must catch that and return false
        // so the app doesn't print "Unhandled Exception" stack traces.
        //
        // We exercise the wrapper by binding the url_launcher channel to a
        // handler that throws the same exception the platform does. The
        // production `_launchExternal` then runs the same code path it
        // would on the device.
        TestWidgetsFlutterBinding.ensureInitialized();
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'canLaunch') return true;
          throw PlatformException(
            code: 'ACTIVITY_NOT_FOUND',
            message: 'No Activity found to handle intent',
          );
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final launch = container.read(launcherServiceProvider);

        final result = await launch(
          MapUrls.osmLocation(lat: 23.8141, lon: 90.4282),
        );

        expect(result, isFalse);
      },
    );
  });
}
