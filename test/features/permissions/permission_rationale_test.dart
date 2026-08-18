import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rogsheba_mobile/app.dart';
import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/core/router/app_router.dart';
import 'package:rogsheba_mobile/core/services/connectivity_service.dart';
import 'package:rogsheba_mobile/core/services/location_service.dart';
import 'package:rogsheba_mobile/core/services/permission_service.dart';
import 'package:rogsheba_mobile/core/services/speech_service.dart';
import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_permission_service.dart';
import '../../helpers/fake_speech_service.dart';
import '../../helpers/fake_tts_service.dart';
import '../../helpers/fixtures.dart';

/// `GET /clinics` fallback payload, lifted from `docs/MOBILE_API.md` §3.
const Map<String, dynamic> fallbackEnvelope = {
  'success': true,
  'data': {
    'source': 'fallback',
    'count': 2,
    'clinics': [
      {
        'id': '1',
        'name': 'Square Hospitals Ltd.',
        'distance_km': 1.2,
        'lat': 23.7525,
        'lon': 90.3786,
        'address': 'West Panthapath',
        'type': 'hospital',
      },
      {
        'id': '2',
        'name': 'United Hospital',
        'distance_km': 2.4,
        'lat': 23.7495,
        'lon': 90.3786,
        'address': null,
        'type': null,
      },
    ],
  },
};

Future<FakeSpeechService> pumpApp(
  WidgetTester tester, {
  FakePermissionService? permission,
  bool voiceAvailable = true,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  // The app router is a process-wide singleton; a prior test may have left it
  // on /clinics, which would re-mount the clinics screen on this pump.
  appRouter.go('/');
  final speech = FakeSpeechService(banglaAvailable: voiceAvailable);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        speechServiceProvider.overrideWithValue(speech),
        permissionServiceProvider.overrideWithValue(
          permission ?? FakePermissionService(),
        ),
        ttsServiceProvider.overrideWithValue(FakeTtsService()),
        connectivityServiceProvider.overrideWithValue(
          FakeConnectivityService(),
        ),
        dioProvider.overrideWith(
          (ref) =>
              Dio()..httpClientAdapter = FakeDioAdapter(
                (_) async => FakeDioAdapter.jsonBytes(triageEnvelope),
              ),
        ),
      ],
      child: const RogShebaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return speech;
}

Finder micButton() => find.byTooltip(BnStrings.micLabel);

BuildContext descendantContext(WidgetTester tester) => tester.element(
  find.descendant(
    of: find.byType(MaterialApp),
    matching: find.byType(Scaffold),
  ),
);

void main() {
  group('microphone rationale', () {
    testWidgets(
      'the rationale is shown before the first prompt, and accepting it '
      'starts listening',
      (tester) async {
        final permission = FakePermissionService(
          microphone: PermissionState.notDetermined,
        );
        final speech = await pumpApp(tester, permission: permission);

        // Mic button is shown optimistically before any OS decision.
        expect(micButton(), findsOneWidget);

        await tester.tap(micButton());
        await tester.pumpAndSettle();

        // The rationale dialog appears; the OS prompt has NOT fired yet (the
        // recogniser has not been probed, so `startCalls` is still 0).
        expect(find.text(BnStrings.micRationaleTitle), findsOneWidget);
        expect(speech.startCalls, 0);

        // Accept the rationale, then the mic request proceeds. (No
        // pumpAndSettle here — the pulse animation runs while listening.)
        await tester.tap(find.text(BnStrings.rationaleContinue));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(speech.isListening, isTrue);
        expect(speech.startCalls, 1);
        // The acceptance is persisted so the dialog never reappears.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(PermissionRationaleStore.micKey), isTrue);
      },
    );

    testWidgets(
      'declining the rationale leaves typing fully functional and skips '
      'the prompt',
      (tester) async {
        final permission = FakePermissionService(
          microphone: PermissionState.notDetermined,
        );
        final speech = await pumpApp(tester, permission: permission);

        await tester.tap(micButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text(BnStrings.rationaleCancel));
        await tester.pumpAndSettle();

        // No OS prompt was ever triggered.
        expect(speech.startCalls, 0);
        expect(find.text(BnStrings.micRationaleTitle), findsNothing);

        // The field still accepts input and submits.
        await tester.enterText(find.byType(TextField), 'পেট খারাপ');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
        await tester.pumpAndSettle();
        expect(find.text('গলা ব্যথা ও জ্বর'), findsOneWidget);
      },
    );

    testWidgets(
      'a repeat tap after the rationale was accepted skips the dialog',
      (tester) async {
        final permission = FakePermissionService(
          microphone: PermissionState.notDetermined,
        );
        final speech = await pumpApp(
          tester,
          permission: permission,
          prefs: {PermissionRationaleStore.micKey: true},
        );

        await tester.tap(micButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text(BnStrings.micRationaleTitle), findsNothing);
        expect(speech.isListening, isTrue);
      },
    );

    testWidgets(
      'a permanent mic denial hides the mic and offers the settings route '
      'instead of re-prompting',
      (tester) async {
        final permission = FakePermissionService(
          microphone: PermissionState.deniedForever,
        );
        await pumpApp(
          tester,
          permission: permission,
          prefs: {PermissionRationaleStore.micKey: true},
        );

        // The mic is hidden and the denied message + settings route render.
        expect(micButton(), findsNothing);
        expect(find.text(BnStrings.micPermissionDenied), findsOneWidget);
        expect(find.text(BnStrings.openSettings), findsOneWidget);

        await tester.tap(find.text(BnStrings.openSettings));
        await tester.pump();
        expect(permission.settingsCalls, 1);
      },
    );

    testWidgets(
      'a denial that arrives mid-session routes to settings instead of '
      're-prompting',
      (tester) async {
        final permission = FakePermissionService();
        final speech = await pumpApp(
          tester,
          permission: permission,
          prefs: {PermissionRationaleStore.micKey: true},
        );

        // The recogniser was already probed as available.
        expect(micButton(), findsOneWidget);

        // Permission is revoked while the app is open (e.g. from settings).
        permission.microphone = PermissionState.denied;
        await tester.tap(micButton());
        await tester.pumpAndSettle();

        expect(find.text(BnStrings.micPermissionDenied), findsOneWidget);
        expect(speech.startCalls, 0);

        await tester.tap(find.text(BnStrings.openSettings));
        await tester.pumpAndSettle();
        expect(permission.settingsCalls, 1);
      },
    );
  });

  group('location rationale', () {
    Future<void> pumpClinics(
      WidgetTester tester, {
      required FakePermissionService permission,
      LocateUser? locate,
      Map<String, Object> prefs = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      appRouter.go('/');
      final adapter = FakeDioAdapter(
        (_) async => FakeDioAdapter.jsonBytes(fallbackEnvelope),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWith(
              (ref) => Dio()..httpClientAdapter = adapter,
            ),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            speechServiceProvider.overrideWithValue(FakeSpeechService()),
            permissionServiceProvider.overrideWithValue(permission),
            connectivityServiceProvider.overrideWithValue(
              FakeConnectivityService(),
            ),
            if (locate != null)
              locationServiceProvider.overrideWithValue(locate),
          ],
          child: const RogShebaApp(),
        ),
      );
      await tester.pumpAndSettle();
      descendantContext(tester).go('/clinics');
      await tester.pump();
    }

    testWidgets(
      'the rationale is shown before the location prompt and accepting it '
      'locates',
      (tester) async {
        var located = false;
        await pumpClinics(
          tester,
          permission: FakePermissionService(
            location: PermissionState.notDetermined,
          ),
          locate: () async {
            located = true;
            return const LocationGranted(lat: 23.7806, lon: 90.4074);
          },
        );
        await tester.pump(const Duration(milliseconds: 300));

        // The rationale gate runs before the location service is invoked.
        expect(find.text(BnStrings.locationRationaleTitle), findsOneWidget);
        expect(located, isFalse);

        await tester.tap(find.text(BnStrings.rationaleContinue));
        await tester.pumpAndSettle();

        expect(located, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(PermissionRationaleStore.locationKey), isTrue);
      },
    );

    testWidgets(
      'declining the location rationale loads the fallback list with no '
      'prompt',
      (tester) async {
        var located = false;
        await pumpClinics(
          tester,
          permission: FakePermissionService(
            location: PermissionState.notDetermined,
          ),
          locate: () async {
            located = true;
            return const LocationGranted(lat: 23.7806, lon: 90.4074);
          },
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text(BnStrings.rationaleCancel));
        await tester.pumpAndSettle();

        expect(located, isFalse);
        expect(find.text(BnStrings.fallbackBannerDenied), findsOneWidget);
        expect(find.textContaining('Square Hospitals Ltd.'), findsOneWidget);
      },
    );

    testWidgets(
      'a prior location denial loads the fallback list and offers the '
      'settings route without re-prompting',
      (tester) async {
        var located = false;
        final permission = FakePermissionService(
          location: PermissionState.denied,
        );
        await pumpClinics(
          tester,
          permission: permission,
          locate: () async {
            located = true;
            return const LocationGranted(lat: 23.7806, lon: 90.4074);
          },
        );
        await tester.pumpAndSettle();

        // Never reached the geolocator; the fallback list renders instead.
        expect(located, isFalse);
        expect(find.text(BnStrings.fallbackBannerDenied), findsOneWidget);
        expect(find.textContaining('Square Hospitals Ltd.'), findsOneWidget);

        // The settings pill routes out to app settings.
        await tester.ensureVisible(find.text(BnStrings.openSettings));
        await tester.tap(find.text(BnStrings.openSettings));
        await tester.pump();
        expect(permission.settingsCalls, 1);
      },
    );
  });
}
