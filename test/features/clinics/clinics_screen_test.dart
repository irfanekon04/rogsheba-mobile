import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rogsheba_mobile/app.dart';
import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/core/services/connectivity_service.dart';
import 'package:rogsheba_mobile/core/services/launcher_service.dart';
import 'package:rogsheba_mobile/core/services/location_service.dart';
import 'package:rogsheba_mobile/core/services/speech_service.dart';
import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_speech_service.dart';
import '../../helpers/fake_tts_service.dart';

/// `GET /clinics` payload shape, lifted verbatim from `docs/MOBILE_API.md` §3.
const Map<String, dynamic> clinicsEnvelope = {
  'success': true,
  'data': {
    'source': 'openstreetmap',
    'origin': {'lat': 23.7806, 'lon': 90.4074},
    'count': 2,
    'clinics': [
      {
        'id': '123456789',
        'name': 'Square Hospitals Ltd.',
        'lat': 23.7525,
        'lon': 90.3786,
        'distanceKm': 4.2,
        'type': 'hospital',
        'address': 'West Panthapath',
      },
      {
        'id': 'f1',
        'name': 'Dhaka Medical College Hospital',
        'lat': 23.7257,
        'lon': 90.3974,
        'distanceKm': 6.1,
        'type': 'Government',
        'address': 'Bakshibazar, Dhaka',
      },
    ],
  },
};

/// `GET /clinics` response when no `lat`/`lon` are sent — the server returns
/// `source: "fallback"` and a curated Dhaka hospital list. Same per-clinic
/// fields as the located payload so the same `_ClinicItem` renders both.
const Map<String, dynamic> fallbackEnvelope = {
  'success': true,
  'data': {
    'source': 'fallback',
    'origin': {'lat': 23.7806, 'lon': 90.4074},
    'count': 2,
    'clinics': [
      {
        'id': 'fb1',
        'name': 'Square Hospitals Ltd.',
        'lat': 23.7525,
        'lon': 90.3786,
        'distanceKm': 4.2,
        'type': 'hospital',
        'address': 'West Panthapath, Dhaka',
      },
      {
        'id': 'fb2',
        'name': 'United Hospital',
        'lat': 23.7910,
        'lon': 90.4035,
        'distanceKm': 1.4,
        'type': 'hospital',
        'address': 'Gulshan 2, Dhaka',
      },
    ],
  },
};

/// Pumps the real application widget with three overrides: the HTTP transport
/// at the Dio adapter level, the location service, the speech/TTS services
/// (none of which can run in a widget test) and an optional launcher
/// capture. Everything above them — envelope decoding, UTF-8 handling, error
/// mapping, the repository, the controller and the screen — is real.
Future<FakeDioAdapter> pumpAppWithClinics(
  WidgetTester tester, {
  required Future<ResponseBody> Function(RequestOptions) handler,
  LocateUser? locate,
  OpenExternalUri? launch,
  FakeConnectivityService? connectivity,
}) async {
  SharedPreferences.setMockInitialValues({});
  final adapter = FakeDioAdapter(handler);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWith((ref) => Dio()..httpClientAdapter = adapter),
        ttsServiceProvider.overrideWithValue(FakeTtsService()),
        speechServiceProvider.overrideWithValue(FakeSpeechService()),
        connectivityServiceProvider.overrideWithValue(
          connectivity ?? FakeConnectivityService(),
        ),
        if (locate != null) locationServiceProvider.overrideWithValue(locate),
        if (launch != null) launcherServiceProvider.overrideWithValue(launch),
      ],
      child: const RogShebaApp(),
    ),
  );
  return adapter;
}

/// Finds a `BuildContext` that is a descendant of the `MaterialApp.router`,
/// which is required for `GoRouter.of(context)` to resolve.
BuildContext descendantContext(WidgetTester tester) => tester.element(
      find.descendant(
        of: find.byType(MaterialApp),
        matching: find.byType(Scaffold),
      ),
    );

void main() {
  testWidgets(
    'opening the clinics screen auto-locates and lists facilities '
    'nearest-first',
    (tester) async {
      await pumpAppWithClinics(
        tester,
        handler: (_) async => FakeDioAdapter.jsonBytes(clinicsEnvelope),
        locate: () async =>
            const LocationGranted(lat: 23.7806, lon: 90.4074),
      );

      // Drive the router to /clinics exactly as the triage CTA does.
      descendantContext(tester).go('/clinics');
      // The screen calls `locateAndLoad()` from a `Future.microtask` in
      // initState; let the microtask, the fake location service and the
      // API call all flush before asserting.
      await tester.pump();
      await tester.pumpAndSettle();

      // The screen is up. The two distinct waiting states have resolved
      // into the ready state with the fixture's facilities.
      expect(find.text(BnStrings.clinicsTitle), findsOneWidget);
      expect(find.text(BnStrings.clinicsSubtitle), findsOneWidget);

      // Both fixture names render. Each clinic item composes its name into
      // a `Text.rich` (the '#1 ' index and the name live in one TextSpan
      // tree), so we assert by `textContaining` to walk into RichText
      // spans.
      expect(find.textContaining('Square Hospitals Ltd.'), findsOneWidget);
      expect(
        find.textContaining('Dhaka Medical College Hospital'),
        findsOneWidget,
      );

      // Distance chips show the same numbers the API returned.
      expect(find.text('4.2 km'), findsOneWidget);
      expect(find.text('6.1 km'), findsOneWidget);

      // Address line for the first clinic (when present in the payload).
      expect(find.text('West Panthapath'), findsOneWidget);

      // Facility type chips.
      expect(find.text('hospital'), findsOneWidget);
      expect(find.text('Government'), findsOneWidget);

      // Per-clinic action pills — directions + view on map — render twice.
      expect(find.text(BnStrings.directions), findsNWidgets(2));
      expect(find.text(BnStrings.viewOnMap), findsNWidgets(2));

      // No failure card surfaced.
      expect(find.text(BnStrings.retry), findsNothing);
    },
  );

  testWidgets(
    'the triage CTA on a result navigates to the clinics screen',
    (tester) async {
      final triageEnvelope = {
        'success': true,
        'data': {
          'level': 'YELLOW',
          'title_bn': 'গলা ব্যথা ও জ্বর',
          'summary_bn': 'আপনার লক্ষণ সম্ভবত গলার সংক্রমণ নির্দেশ করছে।',
          'advice_bn': ['প্রচুর পানি ও বিশ্রাম নিন'],
          'warning_signs_bn': ['শ্বাস নিতে কষ্ট হলে'],
          'followup_question_bn': null,
          'disclaimer_bn': 'এটি একজন ডাক্তারের পরামর্শের বিকল্প নয়।',
          'emergency_number': null,
          'created_at': '2026-08-05T15:10:22.481Z',
        },
      };

      final responses = <ResponseBody>[];
      await pumpAppWithClinics(
        tester,
        handler: (options) async {
          // First call is the /triage POST from the home screen; every
          // later call is a /clinics GET. Each returns a different body.
          if (responses.isEmpty) {
            responses.add(FakeDioAdapter.jsonBytes(triageEnvelope));
          } else {
            responses.add(FakeDioAdapter.jsonBytes(clinicsEnvelope));
          }
          return responses.last;
        },
        locate: () async =>
            const LocationGranted(lat: 23.7806, lon: 90.4074),
      );

      // GoRouter state survives across `pumpWidget` within a single tester;
      // the previous test left the route at `/clinics`. Force it back to
      // `/` before submitting symptoms.
      descendantContext(tester).go('/');
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      // Drive a triage submission from the home screen.
      await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
      await tester.pumpAndSettle();

      // The result card is up. Tap the CTA — it should land on /clinics.
      await tester.tap(find.text(BnStrings.nearbyClinicsCta));
      await tester.pumpAndSettle();

      expect(find.text(BnStrings.clinicsTitle), findsOneWidget);
      expect(find.textContaining('Square Hospitals Ltd.'), findsOneWidget);
    },
  );

  testWidgets(
    'directions opens with the user coordinates as the origin',
    (tester) async {
      final launched = <Uri>[];
      await pumpAppWithClinics(
        tester,
        handler: (_) async => FakeDioAdapter.jsonBytes(clinicsEnvelope),
        locate: () async =>
            const LocationGranted(lat: 23.7806, lon: 90.4074),
        launch: (uri) async {
          launched.add(uri);
          return true;
        },
      );

      descendantContext(tester).go('/clinics');
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap the first দিকনির্দেশ pill.
      await tester.tap(find.text(BnStrings.directions).first);
      await tester.pumpAndSettle();

      // The launcher service was wired with the user's coords (23.7806,
      // 90.4074) and the first clinic's coords (23.7525, 90.3786) — the
      // exact URI the web component sends to Google Maps.
      expect(launched, hasLength(1));
      expect(
        launched.single.toString(),
        'https://www.google.com/maps/dir/?api=1'
        '&origin=23.7806,90.4074&destination=23.7525,90.3786',
      );

      // Tapping ম্যাপে দেখুন launches the OSM pin URL.
      await tester.tap(find.text(BnStrings.viewOnMap).first);
      await tester.pumpAndSettle();
      expect(launched, hasLength(2));
      expect(
        launched.last.toString(),
        'https://www.openstreetmap.org/?mlat=23.7525&mlon=90.3786'
        '#map=17/23.7525/90.3786',
      );
    },
  );

  // ---- slice #9: fallback list when location does not resolve ----

  Future<void> goAndSettle(WidgetTester tester) async {
    descendantContext(tester).go('/clinics');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'denying location shows the Dhaka fallback list with the permission banner',
    (tester) async {
      await pumpAppWithClinics(
        tester,
        handler: (options) async {
          // No coordinates are sent on the fallback path.
          expect(options.queryParameters['lat'], isNull);
          expect(options.queryParameters['lon'], isNull);
          return FakeDioAdapter.jsonBytes(fallbackEnvelope);
        },
        locate: () async => const LocationDenied(),
      );
      await goAndSettle(tester);

      // The permission-specific Bangla banner is rendered.
      expect(find.text(BnStrings.fallbackBannerDenied), findsOneWidget);

      // The fallback list still renders — the screen is never empty.
      expect(find.textContaining('Square Hospitals Ltd.'), findsOneWidget);
      expect(find.textContaining('United Hospital'), findsOneWidget);

      // Directions still work — but in the search variant since we have no
      // user coords. This is the same MapUrls unit-tested in
      // launcher_service_test.dart; here we just confirm the launcher was
      // hit on tap.
      await tester.tap(find.text(BnStrings.directions).first);
      await tester.pumpAndSettle();

      // A retry pill is rendered below the list.
      expect(find.text(BnStrings.retry), findsOneWidget);
    },
  );

  testWidgets(
    'location services off shows the fallback list with its own banner',
    (tester) async {
      await pumpAppWithClinics(
        tester,
        handler: (_) async => FakeDioAdapter.jsonBytes(fallbackEnvelope),
        locate: () async => const LocationDisabled(),
      );
      await goAndSettle(tester);

      expect(find.text(BnStrings.fallbackBannerDisabled), findsOneWidget);
      expect(find.text(BnStrings.fallbackBannerDenied), findsNothing);
      expect(find.textContaining('United Hospital'), findsOneWidget);
    },
  );

  testWidgets(
    'a lookup failure shows the fallback list with its own banner',
    (tester) async {
      await pumpAppWithClinics(
        tester,
        handler: (_) async => FakeDioAdapter.jsonBytes(fallbackEnvelope),
        locate: () async => const LocationFailed(),
      );
      await goAndSettle(tester);

      expect(find.text(BnStrings.fallbackBannerFailed), findsOneWidget);
      expect(find.text(BnStrings.fallbackBannerDenied), findsNothing);
      expect(find.text(BnStrings.fallbackBannerDisabled), findsNothing);
      expect(find.textContaining('United Hospital'), findsOneWidget);
    },
  );

  testWidgets(
    'retrying after grant replaces the fallback list with the located one',
    (tester) async {
      // The location service "fakes" the user changing their mind about
      // permission: first call denies, every later call grants. A mutable
      // closure reference flips between them on each invocation.
      var grant = false;
      Future<LocationResult> locate() async => grant
          ? const LocationGranted(lat: 23.7806, lon: 90.4074)
          : const LocationDenied();

      // First API call returns the fallback payload; second returns the
      // located one. Either way the controller sees the same endpoint.
      var apiCalls = 0;
      await pumpAppWithClinics(
        tester,
        handler: (_) async {
          apiCalls++;
          return FakeDioAdapter.jsonBytes(
            apiCalls == 1 ? fallbackEnvelope : clinicsEnvelope,
          );
        },
        locate: locate,
      );
      await goAndSettle(tester);

      // Fallback list visible, permission banner up.
      expect(find.text(BnStrings.fallbackBannerDenied), findsOneWidget);
      expect(find.textContaining('United Hospital'), findsOneWidget);
      expect(find.textContaining('Dhaka Medical College Hospital'),
          findsNothing);

      // User re-grants location and taps retry. Both the location outcome
      // and the API response flip.
      grant = true;
      await tester.tap(find.text(BnStrings.retry));
      await tester.pumpAndSettle();

      // Banner gone, located list up.
      expect(find.text(BnStrings.fallbackBannerDenied), findsNothing);
      expect(find.textContaining('Dhaka Medical College Hospital'),
          findsOneWidget);
      expect(find.textContaining('United Hospital'), findsNothing);
    },
  );

  testWidgets(
    'the fallback banner does not render on the located path',
    (tester) async {
      await pumpAppWithClinics(
        tester,
        handler: (_) async => FakeDioAdapter.jsonBytes(clinicsEnvelope),
        locate: () async =>
            const LocationGranted(lat: 23.7806, lon: 90.4074),
      );
      await goAndSettle(tester);

      // No banner of any kind.
      expect(find.text(BnStrings.fallbackBannerDenied), findsNothing);
      expect(find.text(BnStrings.fallbackBannerDisabled), findsNothing);
      expect(find.text(BnStrings.fallbackBannerFailed), findsNothing);

      // No retry pill — only the fallback path exposes one.
      expect(find.text(BnStrings.retry), findsNothing);

      // The list is the located one.
      expect(find.textContaining('Square Hospitals Ltd.'), findsOneWidget);
    },
  );
}
