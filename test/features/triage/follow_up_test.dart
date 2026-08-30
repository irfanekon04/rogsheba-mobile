import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogsheba_mobile/app.dart';
import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/core/services/connectivity_service.dart';
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

/// Pumps the real app with the same overrides as the home screen tests, plus
/// a transport handler that routes `/triage` and `/triage/followup` to
/// distinct fixtures so the multi-turn flow can be exercised end to end.
Future<FakeDioAdapter> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final adapter = FakeDioAdapter((options) async {
    if (options.path.contains('/followup')) {
      return FakeDioAdapter.jsonBytes(followUpContinueEnvelope);
    }
    return FakeDioAdapter.jsonBytes(triageEnvelope);
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWith((ref) => Dio()..httpClientAdapter = adapter),
        ttsServiceProvider.overrideWithValue(FakeTtsService()),
        speechServiceProvider.overrideWithValue(FakeSpeechService()),
        permissionServiceProvider.overrideWithValue(FakePermissionService()),
        connectivityServiceProvider.overrideWithValue(
          FakeConnectivityService(),
        ),
      ],
      child: const RogShebaApp(),
    ),
  );
  return adapter;
}

Future<void> submitSymptoms(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a follow-up question renders a single block and an answer box', (
    tester,
  ) async {
    await pumpApp(tester);
    await submitSymptoms(tester);

    // The current question appears once in its own bubble.
    expect(find.text('আপনার কি ঢোক গিলতে খুব কষ্ট হচ্ছে?'), findsOneWidget);
    expect(find.text(BnStrings.followUpTitle), findsOneWidget);

    // The answer input + send button are shown while awaiting an answer.
    expect(find.text(BnStrings.answerSend), findsOneWidget);
  });

  testWidgets('sending an answer posts /triage/followup with full context', (
    tester,
  ) async {
    final adapter = await pumpApp(tester);
    await submitSymptoms(tester);

    await tester.enterText(
      find.byType(TextField).last,
      'হ্যাঁ, ঢোক গিলতে খুব কষ্ট হচ্ছে',
    );
    await tester.pump();

    final sendButton = find.widgetWithText(FilledButton, BnStrings.answerSend);
    await tester.ensureVisible(sendButton);
    await tester.pumpAndSettle();
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    final followUpRequests = adapter.requests
        .where((r) => r.path.contains('/followup'))
        .toList();
    expect(followUpRequests, hasLength(1));

    final data = followUpRequests.single.data as Map<String, dynamic>;
    expect(data['initial_symptoms'], 'গলা ব্যথা আর জ্বর');
    expect(data['answer'], 'হ্যাঁ, ঢোক গিলতে খুব কষ্ট হচ্ছে');
    // The first `/triage` response carries no `turns`, so the first follow-up
    // correctly sends an empty conversation (valid per the API contract).
    expect(data['turns'], isA<List<dynamic>>());
    expect(data['turns'], isEmpty);
    // No session_id exists yet on the first follow-up — it must be omitted
    // from the body rather than sent as null (which the API rejects).
    expect(data.containsKey('session_id'), isFalse);

    // The response's next question replaces the old one in the single block.
    expect(find.text('শ্বাস নিতেও কি কষ্ট হচ্ছে?'), findsOneWidget);
    expect(find.text('আপনার কি ঢোক গিলতে খুব কষ্ট হচ্ছে?'), findsNothing);
  });

  testWidgets('a failed /triage/followup shows the answer error and keeps text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final adapter = FakeDioAdapter((options) async {
      if (options.path.contains('/followup')) {
        return FakeDioAdapter.jsonBytes(banglaErrorEnvelope, status: 422);
      }
      return FakeDioAdapter.jsonBytes(triageEnvelope);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWith((ref) => Dio()..httpClientAdapter = adapter),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          speechServiceProvider.overrideWithValue(FakeSpeechService()),
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          connectivityServiceProvider.overrideWithValue(
            FakeConnectivityService(),
          ),
        ],
        child: const RogShebaApp(),
      ),
    );

    await submitSymptoms(tester);

    await tester.enterText(find.byType(TextField).last, 'হ্যাঁ কষ্ট হচ্ছে');
    await tester.pump();
    final sendButton = find.widgetWithText(FilledButton, BnStrings.answerSend);
    await tester.ensureVisible(sendButton);
    await tester.pumpAndSettle();
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(find.text('অন্তত ৩টি অক্ষর লিখুন।'), findsOneWidget);
  });

  testWidgets('the new-chat floating button clears the conversation', (
    tester,
  ) async {
    await pumpApp(tester);
    await submitSymptoms(tester);

    // A result is showing with the follow-up FAB present.
    expect(find.text(BnStrings.newChatLabel), findsOneWidget);
    expect(find.text('আপনার কি ঢোক গিলতে খুব কষ্ট হচ্ছে?'), findsOneWidget);

    // Tapping it returns to the initial home entry: no result, no FAB.
    await tester.tap(find.text(BnStrings.newChatLabel));
    await tester.pumpAndSettle();
    expect(find.text(BnStrings.newChatLabel), findsNothing);
    expect(find.text('আপনার কি ঢোক গিলতে খুব কষ্ট হচ্ছে?'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
