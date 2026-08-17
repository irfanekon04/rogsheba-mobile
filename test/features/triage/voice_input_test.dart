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

void main() {
  Future<FakeSpeechService> pumpApp(
    WidgetTester tester, {
    bool voiceAvailable = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final speech = FakeSpeechService(banglaAvailable: voiceAvailable);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechServiceProvider.overrideWithValue(speech),
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
  Finder stopButton() => find.byTooltip(BnStrings.stopListening);
  Finder clearButton() => find.byTooltip(BnStrings.clearField);

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets(
    'an interim transcript appears live with the listening indicator, then '
    'the final transcript lands in the editable field',
    (tester) async {
      final speech = await pumpApp(tester);

      await tester.tap(micButton());
      await tester.pump();

      expect(find.text(BnStrings.listeningIndicator), findsOneWidget);

      // Stage 1: partial result renders live while listening.
      speech.emit('গলা');
      await tester.pump();
      expect(
        find.text('${BnStrings.listeningIndicator} গলা'),
        findsOneWidget,
      );
      expect(find.byType(IconButton), findsNothing);

      // Stage 2: final result is committed to the field and the mic returns
      // to its idle (tappable, "বাংলায় বলুন") state.
      speech.emit('গলা ব্যথা', isFinal: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(fieldText(tester), 'গলা ব্যথা');
      expect(find.text(BnStrings.listeningIndicator), findsNothing);
      expect(micButton(), findsOneWidget);
    },
  );

  testWidgets('a spoken transcript can be edited and submitted for triage', (
    tester,
  ) async {
    final speech = await pumpApp(tester);

    await tester.tap(micButton());
    await tester.pump();
    speech.emit('গলা ব্যথা', isFinal: true);
    await tester.pump(const Duration(milliseconds: 250));

    // Transcript is editable: append a correction before submitting.
    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
    await tester.pumpAndSettle();

    expect(find.text('গলা ব্যথা ও জ্বর'), findsOneWidget);
  });

  testWidgets('tapping the mic a second time stops listening', (tester) async {
    final speech = await pumpApp(tester);

    await tester.tap(micButton());
    await tester.pump();

    expect(speech.isListening, isTrue);
    expect(stopButton(), findsOneWidget);

    await tester.tap(stopButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(speech.isListening, isFalse);
    expect(speech.stopCalls, 1);
    expect(micButton(), findsOneWidget);
    expect(find.text(BnStrings.listeningIndicator), findsNothing);
  });

  testWidgets('the clear button empties the field in one tap', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'গলা ব্যথা');
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, BnStrings.submit);
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNotNull);

    await tester.tap(clearButton());
    await tester.pump();

    expect(fieldText(tester), isEmpty);
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);
  });

  testWidgets(
    'without bn-BD recognition the mic is hidden, a Bangla message shows '
    'and typing still submits',
    (tester) async {
      await pumpApp(tester, voiceAvailable: false);

      expect(micButton(), findsNothing);
      expect(find.text(BnStrings.voiceUnavailable), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'পেট খারাপ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
      await tester.pumpAndSettle();

      // The message stays but the triage request still goes through.
      expect(find.text(BnStrings.voiceUnavailable), findsOneWidget);
      expect(find.text('গলা ব্যথা ও জ্বর'), findsWidgets);
    },
  );

  testWidgets('the speaker button and mic stand apart', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
    await tester.pumpAndSettle();

    // Result card shows its own TTS toggle; the field's mic remains.
    expect(
      find.widgetWithText(TextButton, BnStrings.ttsListen),
      findsOneWidget,
    );
    expect(micButton(), findsOneWidget);
  });
}
