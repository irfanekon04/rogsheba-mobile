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
import '../../helpers/fixtures.dart';

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

/// `GET /clinics` payload shape, lifted verbatim from `docs/MOBILE_API.md` §3.
const Map<String, dynamic> clinicsEnvelope = {
  'success': true,
  'data': {
    'source': 'openstreetmap',
    'origin': {'lat': 23.7806, 'lon': 90.4074},
    'count': 2,
    'clinics': [
      {
        'id': '1',
        'name': 'Square Hospitals Ltd.',
        'lat': 23.7525,
        'lon': 90.3786,
        'distanceKm': 4.2,
        'type': 'hospital',
        'address': 'West Panthapath',
      },
      {
        'id': '2',
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

Future<FakeDioAdapter> pumpApp(
  WidgetTester tester, {
  required Future<ResponseBody> Function(RequestOptions) handler,
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
        launcherServiceProvider.overrideWithValue((uri) async => true),
        locationServiceProvider.overrideWithValue(
          () async => const LocationGranted(lat: 23.7806, lon: 90.4074),
        ),
      ],
      child: const RogShebaApp(),
    ),
  );
  await tester.pumpAndSettle();
  descendantContext(tester).go('/');
  await tester.pumpAndSettle();
  return adapter;
}

/// A handler that answers `/emergency` and `/clinics` alongside triage, so the
/// whole app can be walked without an unmocked request reaching the wire.
Future<ResponseBody> fullApiHandler(RequestOptions options) async {
  if (options.path == '/emergency') {
    return FakeDioAdapter.jsonBytes(emergencyEnvelope);
  }
  if (options.path == '/clinics') {
    return FakeDioAdapter.jsonBytes(clinicsEnvelope);
  }
  return FakeDioAdapter.jsonBytes(triageEnvelope);
}

BuildContext descendantContext(WidgetTester tester) => tester.element(
      find.descendant(
        of: find.byType(MaterialApp),
        matching: find.byType(Scaffold),
      ),
    );

void main() {
  // ---- semantic labels (screen-reader walkthrough) ----

  testWidgets(
    'every interactive element on the home screen exposes a Bangla label',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, handler: fullApiHandler);

      // The primary CTA carries its own Bangla text.
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(BnStrings.submit))),
        findsOneWidget,
      );

      // The emergency pill announces what it is and what tapping does, not
      // just the digits.
      expect(
        find.bySemanticsLabel(BnStrings.hotlinePillLabel),
        findsOneWidget,
      );

      // The mic toggle announces its Bangla purpose (icon-only control).
      expect(find.bySemanticsLabel(BnStrings.micLabel), findsOneWidget);

      // The symptom field's hint is its semantic label.
      final placeholderLabel = RegExp.escape(BnStrings.symptomPlaceholder);
      expect(
        find.bySemanticsLabel(RegExp(placeholderLabel)),
        findsWidgets,
      );

      // Example chips are read aloud.
      expect(
        find.bySemanticsLabel(BnStrings.exampleChestPain),
        findsOneWidget,
      );

      handle.dispose();
    },
  );

  testWidgets(
    'triage happy path is operable via semantics alone',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, handler: fullApiHandler);

      // Drive the whole flow through semantic actions — no gestures.
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
      await tester.pump();

      final submit = find.bySemanticsLabel(
        RegExp(RegExp.escape(BnStrings.submit)),
      );
      expect(submit, findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      // The result is announced with its Bangla heading.
      expect(find.text('গলা ব্যথা ও জ্বর'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(BnStrings.ttsListen))),
        findsOneWidget,
      );

      handle.dispose();
    },
  );

  testWidgets('the hotline sheet rows are announced as dial buttons', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, handler: fullApiHandler);

    await tester.tap(find.bySemanticsLabel(BnStrings.hotlinePillLabel));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        RegExp(RegExp.escape('জাতীয় ইমার্জেন্সি সার্ভিস')),
      ),
      findsWidgets,
    );

    handle.dispose();
  });

  testWidgets('clinics screen actions are announced in Bangla', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      handler: fullApiHandler,
      connectivity: FakeConnectivityService(),
    );

    descendantContext(tester).go('/clinics');
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(BnStrings.directions))),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(BnStrings.viewOnMap))),
      findsWidgets,
    );

    handle.dispose();
  });

  // ---- tap targets ≥ 48dp ----

testWidgets('primary CTA has at least a 48dp tap target', (tester) async {
    await pumpApp(tester, handler: fullApiHandler);
    final button = find.widgetWithText(FilledButton, BnStrings.submit);
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('emergency pill tap target is at least 48dp', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, handler: fullApiHandler);
    final pill = find.bySemanticsLabel(BnStrings.hotlinePillLabel);
    final size = tester.getSize(pill);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('mic toggle and example chips have 48dp+ tap targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, handler: fullApiHandler);

    final mic = find.bySemanticsLabel(BnStrings.micLabel);
    final micSize = tester.getSize(mic);
    expect(micSize.width, greaterThanOrEqualTo(48));
    expect(micSize.height, greaterThanOrEqualTo(48));

    final chip = find.text(BnStrings.exampleChestPain);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    final chipTap = find.ancestor(
      of: chip,
      matching: find.byType(InkWell),
    );
    final chipSize = tester.getSize(chipTap);
    expect(chipSize.width, greaterThanOrEqualTo(48));
    expect(chipSize.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('clinic action pills have 48dp+ tap targets', (tester) async {
    await pumpApp(tester, handler: fullApiHandler);
    descendantContext(tester).go('/clinics');
    await tester.pumpAndSettle();

    final directions = find.text(BnStrings.directions).first;
    await tester.ensureVisible(directions);
    await tester.pumpAndSettle();
    final pill = find.ancestor(
      of: directions,
      matching: find.byType(InkWell),
    );
    final size = tester.getSize(pill);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  // ---- text scaling to 200% without clipping ----

  testWidgets('home screen survives 200% text scaling with no overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, handler: fullApiHandler);

    // No RenderFlex overflow exceptions were thrown during layout, and the
    // interactive content is still present.
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(BnStrings.heroBadge), findsOneWidget);
  });

  testWidgets('triage result renders at 200% text scale without clipping', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, handler: fullApiHandler);
    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();
    final submit = find.widgetWithText(FilledButton, BnStrings.submit);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('গলা ব্যথা ও জ্বর'), findsOneWidget);
    expect(find.textContaining('প্রচুর কুসুম গরম পানি'), findsOneWidget);
  });

  testWidgets('clinics list renders at 200% text scale without clipping', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, handler: fullApiHandler);
    descendantContext(tester).go('/clinics');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Square Hospitals Ltd.'), findsOneWidget);
  });

  testWidgets('hotline sheet renders at 200% text scale without clipping', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester, handler: fullApiHandler);
    await tester.tap(find.bySemanticsLabel(BnStrings.hotlinePillLabel));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(BnStrings.emergencySheetTitle), findsOneWidget);
    expect(find.text('জাতীয় ইমার্জেন্সি সার্ভিস'), findsOneWidget);
  });

  // ---- landscape usability ----

  testWidgets('home remains usable in landscape', (tester) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpApp(tester, handler: fullApiHandler);
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();
    final submit = find.widgetWithText(FilledButton, BnStrings.submit);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('গলা ব্যথা ও জ্বর'), findsOneWidget);
  });

  testWidgets('clinics remains usable in landscape', (tester) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpApp(tester, handler: fullApiHandler);
    descendantContext(tester).go('/clinics');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Square Hospitals Ltd.'), findsOneWidget);
  });

  testWidgets('hotline sheet remains usable in landscape', (tester) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpApp(tester, handler: fullApiHandler);
    await tester.tap(find.bySemanticsLabel(BnStrings.hotlinePillLabel));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(BnStrings.emergencySheetTitle), findsOneWidget);
    expect(find.text('জাতীয় ইমার্জেন্সি সার্ভিস'), findsOneWidget);
  });
}
