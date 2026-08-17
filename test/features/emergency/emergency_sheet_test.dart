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

/// `GET /emergency` payload, lifted verbatim from `docs/MOBILE_API.md` §4.
const Map<String, dynamic> emergencyEnvelope = {
  'success': true,
  'data': {
    'country': 'BD',
    'contacts': [
      {
        'label_bn': 'জাতীয় ইমার্জেন্সি সার্ভিস',
        'number': '999',
        'type': 'emergency',
      },
      {
        'label_bn': 'স্বাস্থ্য বাতায়ন',
        'number': '16263',
        'type': 'health_hotline',
      },
      {
        'label_bn': 'কোভিড / IEDCR',
        'number': '10655',
        'type': 'health_hotline',
      },
      {
        'label_bn': 'নারী ও শিশু সহায়তা',
        'number': '109',
        'type': 'support',
      },
      {
        'label_bn': 'ফায়ার সার্ভিস',
        'number': '102',
        'type': 'fire',
      },
    ],
  },
};

/// Minimal triage success envelope so the home screen has something for the
/// initial `GET /triage`-style ambient reads. None of these tests actually
/// submit symptoms, but the fixture keeps the response shape stable.
const Map<String, dynamic> triageEnvelope = {
  'success': true,
  'data': {
    'level': 'GREEN',
    'title_bn': 'হালকা সর্দি',
    'summary_bn': 'ঘরে যত্ন যথেষ্ট।',
    'advice_bn': ['প্রচুর পানি পান করুন'],
    'warning_signs_bn': ['শ্বাসকষ্ট হলে'],
    'followup_question_bn': null,
    'disclaimer_bn': 'এটি ডাক্তারের পরামর্শ নয়।',
    'emergency_number': null,
    'created_at': '2026-08-05T10:00:00.000Z',
  },
};

/// Minimal /clinics success envelope so we can drive to /clinics in the
/// parity test without an unmocked request reaching the wire.
const Map<String, dynamic> clinicsEnvelope = {
  'success': true,
  'data': {
    'source': 'openstreetmap',
    'origin': {'lat': 23.7806, 'lon': 90.4074},
    'count': 1,
    'clinics': [
      {
        'id': '1',
        'name': 'Square Hospitals',
        'lat': 23.7525,
        'lon': 90.3786,
        'distanceKm': 4.2,
        'type': 'hospital',
        'address': 'West Panthapath',
      },
    ],
  },
};

/// Pumps the real app with the Dio adapter + speech + TTS stubbed. An
/// optional [launch] capture substitutes the URL-launcher platform channel
/// so we can record every `tel:` URI without leaving the widget test. An
/// optional [locate] override is required when the test exercises the
/// clinics screen — geolocator's real platform channels time out in a
/// widget test.
Future<({FakeDioAdapter adapter, List<Uri> launched})> pumpAppForEmergency(
  WidgetTester tester, {
  required Future<ResponseBody> Function(RequestOptions) handler,
  OpenExternalUri? launch,
  LocateUser? locate,
  FakeConnectivityService? connectivity,
}) async {
  SharedPreferences.setMockInitialValues({});
  final adapter = FakeDioAdapter(handler);
  final launched = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWith((ref) => Dio()..httpClientAdapter = adapter),
        ttsServiceProvider.overrideWithValue(FakeTtsService()),
        speechServiceProvider.overrideWithValue(FakeSpeechService()),
        connectivityServiceProvider.overrideWithValue(
          connectivity ?? FakeConnectivityService(),
        ),
        launcherServiceProvider.overrideWithValue(
          launch ?? (uri) async {
            launched.add(uri);
            return true;
          },
        ),
        if (locate != null) locationServiceProvider.overrideWithValue(locate),
      ],
      child: const RogShebaApp(),
    ),
  );
  return (adapter: adapter, launched: launched);
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
    'tapping the ৯৯৯ pill on the home screen opens the emergency sheet '
    'with all five Bangla contacts',
    (tester) async {
      final ctx = await pumpAppForEmergency(
        tester,
        handler: (options) async {
          if (options.path == '/emergency') {
            return FakeDioAdapter.jsonBytes(emergencyEnvelope);
          }
          return FakeDioAdapter.jsonBytes(triageEnvelope);
        },
      );

      // The home screen is the root. The hotline pill is in the AppBar.
      expect(find.text(BnStrings.hotline999), findsOneWidget);

      await tester.tap(find.text(BnStrings.hotline999));
      await tester.pumpAndSettle();

      // Sheet title and subtitle render.
      expect(find.text(BnStrings.emergencySheetTitle), findsOneWidget);
      expect(find.text(BnStrings.emergencySheetSubtitle), findsOneWidget);

      // All five Bangla labels render.
      expect(find.text('জাতীয় ইমার্জেন্সি সার্ভিস'), findsOneWidget);
      expect(find.text('স্বাস্থ্য বাতায়ন'), findsOneWidget);
      expect(find.text('কোভিড / IEDCR'), findsOneWidget);
      expect(find.text('নারী ও শিশু সহায়তা'), findsOneWidget);
      expect(find.text('ফায়ার সার্ভিস'), findsOneWidget);

      // Numbers render in Bengali numerals, not the API's ASCII digits.
      // Scope to the bottom sheet so the AppBar's ৯৯৯ pill doesn't match.
      final inSheet = find.byType(BottomSheet);
      expect(find.descendant(of: inSheet, matching: find.text('৯৯৯')),
          findsOneWidget);
      expect(find.descendant(of: inSheet, matching: find.text('১৬২৬৩')),
          findsOneWidget);
      expect(find.descendant(of: inSheet, matching: find.text('১০৬৫৫')),
          findsOneWidget);
      expect(find.descendant(of: inSheet, matching: find.text('১০৯')),
          findsOneWidget);
      expect(find.descendant(of: inSheet, matching: find.text('১০২')),
          findsOneWidget);

      // One GET /emergency was issued.
      final emergencyCalls = ctx.adapter.requests
          .where((o) => o.path == '/emergency')
          .toList();
      expect(emergencyCalls, hasLength(1));
    },
  );

  testWidgets(
    'tapping a contact row launches the right tel: URI for that number',
    (tester) async {
      final ctx = await pumpAppForEmergency(
        tester,
        handler: (options) async {
          if (options.path == '/emergency') {
            return FakeDioAdapter.jsonBytes(emergencyEnvelope);
          }
          return FakeDioAdapter.jsonBytes(triageEnvelope);
        },
      );

      await tester.tap(find.text(BnStrings.hotline999));
      await tester.pumpAndSettle();

      // Tap the ৯৯৯ row → tel:999 must be launched.
      await tester.tap(find.text('জাতীয় ইমার্জেন্সি সার্ভিস'));
      await tester.pumpAndSettle();

      expect(ctx.launched, hasLength(1));
      expect(ctx.launched.single.toString(), 'tel:999');

      // The sheet stays open so the user can pick another number if the
      // OS dialer is cancelled.
      expect(find.text(BnStrings.emergencySheetTitle), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the ১৬২৬৩ health hotline launches tel:16263',
    (tester) async {
      final ctx = await pumpAppForEmergency(
        tester,
        handler: (options) async {
          if (options.path == '/emergency') {
            return FakeDioAdapter.jsonBytes(emergencyEnvelope);
          }
          return FakeDioAdapter.jsonBytes(triageEnvelope);
        },
      );

      await tester.tap(find.text(BnStrings.hotline999));
      await tester.pumpAndSettle();

      await tester.tap(find.text('স্বাস্থ্য বাতায়ন'));
      await tester.pumpAndSettle();

      expect(ctx.launched, hasLength(1));
      expect(ctx.launched.single.toString(), 'tel:16263');
    },
  );

  testWidgets(
    'the hotline pill on the clinics screen opens the same sheet',
    (tester) async {
      await pumpAppForEmergency(
        tester,
        locate: () async => const LocationGranted(
          lat: 23.7806,
          lon: 90.4074,
        ),
        handler: (options) async {
          if (options.path == '/emergency') {
            return FakeDioAdapter.jsonBytes(emergencyEnvelope);
          }
          if (options.path == '/clinics') {
            return FakeDioAdapter.jsonBytes(clinicsEnvelope);
          }
          return FakeDioAdapter.jsonBytes(triageEnvelope);
        },
      );

      // Navigate to /clinics through the descendant context.
      descendantContext(tester).go('/clinics');
      await tester.pumpAndSettle();

      // The clinics screen has the same hotline pill in its AppBar.
      expect(find.text(BnStrings.hotline999), findsOneWidget);

      await tester.tap(find.text(BnStrings.hotline999));
      await tester.pumpAndSettle();

      // Same sheet opens with all five contacts. Scope to the sheet so
      // the AppBar's ৯৯৯ pill doesn't collide with the sheet row.
      expect(find.text(BnStrings.emergencySheetTitle), findsOneWidget);
      expect(find.text('জাতীয় ইমার্জেন্সি সার্ভিস'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('৯৯৯'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an API failure shows the Bangla error copy and a retry button',
    (tester) async {
      await pumpAppForEmergency(
        tester,
        handler: (options) async {
          if (options.path == '/emergency') {
            return FakeDioAdapter.jsonBytes(
              {'success': false, 'error': {
                'code': 'server_error',
                'message': BnStrings.genericError,
              }},
              status: 500,
            );
          }
          return FakeDioAdapter.jsonBytes(triageEnvelope);
        },
      );

      await tester.tap(find.text(BnStrings.hotline999));
      // Drive the modal slide-up animation manually — pumpAndSettle can
      // hang on inherited animations from the previous test (the bottom
      // sheet route is created on a global Navigator, so its state
      // survives the widget tree rebuild).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Bangla error copy and the retry pill are rendered.
      expect(find.text(BnStrings.genericError), findsOneWidget);
      expect(find.text(BnStrings.retry), findsOneWidget);
    },
  );
}
