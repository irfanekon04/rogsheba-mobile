import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogsheba_mobile/app.dart';
import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/core/services/connectivity_service.dart';
import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_tts_service.dart';
import '../../helpers/fixtures.dart';

void main() {
  Future<FakeTtsService> pumpApp(
    WidgetTester tester, {
    bool voiceAvailable = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final tts = FakeTtsService(banglaVoiceAvailable: voiceAvailable);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServiceProvider.overrideWithValue(tts),
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
    return tts;
  }

  Finder speakerButton() =>
      find.widgetWithText(TextButton, BnStrings.ttsListen);

  testWidgets('tapping the speaker reads the assembled Bangla script', (
    tester,
  ) async {
    final tts = await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
    await tester.pumpAndSettle();

    expect(speakerButton(), findsOneWidget);

    await tester.tap(speakerButton());
    await tester.pump();

    // One script per tap, exactly as the web reads it (title, summary, advice,
    // warning signs).
    expect(tts.spokenTexts, hasLength(1));
    expect(
      tts.spokenTexts.single,
      'গলা ব্যথা ও জ্বর। '
      'আপনার লক্ষণ সম্ভবত গলার সংক্রমণ নির্দেশ করছে। '
      'করণীয়: প্রচুর কুসুম গরম পানি ও তরল খান। পর্যাপ্ত বিশ্রাম নিন। '
      'বিপদ-সংকেত: শ্বাস নিতে কষ্ট হলে। জ্বর ১০৩°F এর বেশি হলে।',
    );
  });

  testWidgets('speaker toggles to stop while playing and back to listen', (
    tester,
  ) async {
    final tts = await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
    await tester.pumpAndSettle();

    await tester.tap(speakerButton());
    await tester.pump();
    expect(find.text(BnStrings.ttsStop), findsOneWidget);
    expect(speakerButton(), findsNothing);

    await tester.tap(find.text(BnStrings.ttsStop));
    await tester.pump();
    expect(speakerButton(), findsOneWidget);
    expect(tts.stopCalls, 1);
  });

  testWidgets('speaker is hidden when no bn-BD voice is installed', (
    tester,
  ) async {
    await pumpApp(tester, voiceAvailable: false);

    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
    await tester.pumpAndSettle();

    expect(speakerButton(), findsNothing);
    expect(find.text(BnStrings.ttsStop), findsNothing);
  });

  testWidgets('stopping stops the engine', (tester) async {
    final tts = await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
    await tester.pumpAndSettle();

    await tester.tap(speakerButton());
    await tester.pump();
    await tester.tap(find.text(BnStrings.ttsStop));
    await tester.pump();

    expect(tts.stopCalls, 1);
  });
}
