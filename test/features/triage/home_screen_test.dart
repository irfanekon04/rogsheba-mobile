import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogsheba_mobile/app.dart';
import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/core/services/connectivity_service.dart';
import 'package:rogsheba_mobile/core/services/speech_service.dart';
import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_speech_service.dart';
import '../../helpers/fake_tts_service.dart';
import '../../helpers/fixtures.dart';

/// Pumps the real application widget with four overrides: the HTTP transport
/// at the Dio adapter level, the speech engine, the TTS engine and the
/// connectivity service (all of which cross platform channels that cannot run
/// in a widget test). Everything above them — UTF-8 handling, envelope
/// decoding, error mapping, the repository, the screen, the mic and the
/// speaker button — is real. `shared_preferences` runs on its in-memory mock
/// so the real cache code executes without platform channels.
Future<FakeDioAdapter> pumpAppWithTransport(
  WidgetTester tester,
  Future<ResponseBody> Function(RequestOptions) handler, {
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
      ],
      child: const RogShebaApp(),
    ),
  );
  return adapter;
}

void main() {
  testWidgets('app bar shows the RogSheba lockup and the ৯৯৯ hotline pill', (
    tester,
  ) async {
    await pumpAppWithTransport(
      tester,
      (_) async => FakeDioAdapter.jsonBytes(triageEnvelope),
    );

    expect(find.text('${BnStrings.appBrand} ${BnStrings.appTitle}'), findsOne);
    expect(find.text(BnStrings.hotline999), findsOneWidget);
    expect(find.text(BnStrings.heroBadge), findsOneWidget);
  });

  testWidgets('tapping an example chip fills the field and enables submit', (
    tester,
  ) async {
    await pumpAppWithTransport(
      tester,
      (_) async => FakeDioAdapter.jsonBytes(triageEnvelope),
    );

    final submitButtonFinder = find.widgetWithText(
      FilledButton,
      BnStrings.submit,
    );
    expect(tester.widget<FilledButton>(submitButtonFinder).onPressed, isNull);

    final chip = find.text(BnStrings.exampleChestPain);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pump();

    expect(
      tester.widget<FilledButton>(submitButtonFinder).onPressed,
      isNotNull,
    );
  });

  testWidgets('submit is disabled while the field is empty', (tester) async {
    final adapter = await pumpAppWithTransport(
      tester,
      (_) async => FakeDioAdapter.jsonBytes(triageEnvelope),
    );

    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, BnStrings.submit),
    );
    expect(submitButton.onPressed, isNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(adapter.requests, isEmpty);
  });

  testWidgets(
    'in-flight state shows Bangla progress and rejects a second tap',
    (tester) async {
      final gate = Completer<void>();
      final adapter = await pumpAppWithTransport(tester, (options) async {
        await gate.future;
        return FakeDioAdapter.jsonBytes(triageEnvelope);
      });

      await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
      await tester.pump();

      expect(find.text(BnStrings.submitting), findsOneWidget);

      // Both the example chips and the feature strip hide while in-flight.
      expect(find.text(BnStrings.exampleHeader), findsNothing);
      expect(find.text(BnStrings.featureTriageTitle), findsNothing);

      // A second submission attempt must be ignored.
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // Dio reaches the adapter asynchronously; let pending microtasks run.
      await tester.idle();
      expect(adapter.requests, hasLength(1));

      final request = adapter.requests.single;
      expect(request.path, endsWith('/triage'));
      expect(
        (request.data as Map<String, dynamic>)['symptoms'],
        'গলা ব্যথা আর জ্বর',
      );

      gate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'typed symptoms produce a rendered triage result through the real path',
    (tester) async {
      await pumpAppWithTransport(
        tester,
        (_) async => FakeDioAdapter.jsonBytes(triageEnvelope),
      );

      await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
      await tester.pumpAndSettle();

      expect(find.text('গলা ব্যথা ও জ্বর'), findsOneWidget);
      expect(find.textContaining('প্রচুর কুসুম গরম পানি'), findsOneWidget);
      expect(find.textContaining('শ্বাস নিতে কষ্ট হলে'), findsOneWidget);
      expect(
        find.text('এটি একজন ডাক্তারের পরামর্শের বিকল্প নয়।'),
        findsOneWidget,
      );

      // Once a result is shown, the on-boarding aids (chips + feature strip)
      // are hidden — nothing to distract from the outcome.
      expect(find.text(BnStrings.exampleHeader), findsNothing);
      expect(find.text(BnStrings.featureTriageTitle), findsNothing);
    },
  );

  testWidgets('a validation error from the API reaches the user verbatim', (
    tester,
  ) async {
    await pumpAppWithTransport(
      tester,
      (_) async =>
          FakeDioAdapter.jsonBytes(validationErrorEnvelope, status: 422),
    );

    await tester.enterText(find.byType(TextField), 'যা');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
    await tester.pumpAndSettle();

    expect(find.text('Invalid request body.'), findsOneWidget);
    expect(find.text('গলা ব্যথা ও জ্বর'), findsNothing);
  });

  testWidgets('submitting scrolls the freshly produced result into view', (
    tester,
  ) async {
    // Narrow the viewport so the result card starts below the fold, forcing
    // the auto-scroll to do real work.
    tester.view.physicalSize = const Size(500, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpAppWithTransport(
      tester,
      (_) async => FakeDioAdapter.jsonBytes(triageEnvelope),
    );

    final resultTitle = find.text('গলা ব্যথা ও জ্বর');
    // Assert no result exists yet (and by extension is below the fold).
    expect(resultTitle, findsNothing);

    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, BnStrings.submit);
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(resultTitle, findsOneWidget);
    final titleRect = tester.getRect(resultTitle);
    expect(titleRect.top, greaterThan(0));
    expect(titleRect.bottom, lessThan(tester.view.physicalSize.height));
  });

  testWidgets('a failing request renders the Bangla error banner verbatim', (
    tester,
  ) async {
    await pumpAppWithTransport(
      tester,
      (_) async => FakeDioAdapter.jsonBytes(banglaErrorEnvelope, status: 422),
    );

    await tester.enterText(find.byType(TextField), 'জ্বর');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
    await tester.pumpAndSettle();

    expect(find.text('অন্তত ৩টি অক্ষর লিখুন।'), findsOneWidget);
    expect(find.text('গলা ব্যথা ও জ্বর'), findsNothing);
  });
}
