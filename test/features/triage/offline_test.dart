import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogsheba_mobile/app.dart';
import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/network_providers.dart';
import 'package:rogsheba_mobile/core/services/cache_service.dart';
import 'package:rogsheba_mobile/core/services/connectivity_service.dart';
import 'package:rogsheba_mobile/core/services/speech_service.dart';
import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_level.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_speech_service.dart';
import '../../helpers/fake_tts_service.dart';
import '../../helpers/fixtures.dart';

/// A cached result, serialised exactly as `CacheService` would have written it
/// from a previous session's `POST /triage` response.
Map<String, dynamic> cachedResultJson() => {
  'level': 'YELLOW',
  'title_bn': 'গলা ব্যথা ও জ্বর',
  'summary_bn': 'আপনার লক্ষণ সম্ভবত গলার সংক্রমণ নির্দেশ করছে।',
  'advice_bn': ['প্রচুর কুসুম গরম পানি ও তরল খান'],
  'warning_signs_bn': ['শ্বাস নিতে কষ্ট হলে'],
  'followup_question_bn': 'আপনার কি ঢোক গিলতে খুব কষ্ট হচ্ছে?',
  'disclaimer_bn': 'এটি একজন ডাক্তারের পরামর্শের বিকল্প নয়।',
  'emergency_number': null,
  'created_at': '2026-08-05T15:10:22.481Z',
};

void main() {
  /// Pumps the real app. `prefs` seeds the in-memory `shared_preferences`
  /// store, which is the same store the real `CacheService` reads — so the
  /// cached-result tests drive the production restore path, not a stub.
  Future<FakeDioAdapter> pumpOfflineApp(
    WidgetTester tester, {
    required Future<ResponseBody> Function(RequestOptions) handler,
    required FakeConnectivityService connectivity,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final adapter = FakeDioAdapter(handler);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWith((ref) => Dio()..httpClientAdapter = adapter),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          speechServiceProvider.overrideWithValue(FakeSpeechService()),
          connectivityServiceProvider.overrideWithValue(connectivity),
        ],
        child: const RogShebaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets(
    'a cached triage result renders read-only with no connectivity',
    (tester) async {
      final connectivity = FakeConnectivityService(online: false);
      final adapter = await pumpOfflineApp(
        tester,
        handler: (_) async => fail('no network call should be made offline'),
        connectivity: connectivity,
        prefs: {
          CacheService.triageResultKey: jsonEncode(cachedResultJson()),
        },
      );

      // The cached result renders — nothing lost just because the connection
      // dropped since the previous session.
      expect(find.text('গলা ব্যথা ও জ্বর'), findsOneWidget);
      expect(
        find.text('আপনার লক্ষণ সম্ভবত গলার সংক্রমণ নির্দেশ করছে।'),
        findsOneWidget,
      );

      // The offline banner explains why a new request will not work.
      expect(find.text(BnStrings.offlineBanner), findsOneWidget);

      // Zero requests hit the wire for the whole pump.
      expect(adapter.requests, isEmpty);
    },
  );

  testWidgets('the offline banner appears and disappears with connectivity', (
    tester,
  ) async {
    final connectivity = FakeConnectivityService();
    await pumpOfflineApp(
      tester,
      handler: (_) async => FakeDioAdapter.jsonBytes(triageEnvelope),
      connectivity: connectivity,
    );

    // Online: no banner, no vertical space reserved for one.
    expect(find.text(BnStrings.offlineBanner), findsNothing);

    // Connection drops → banner appears immediately.
    connectivity.setOnline(online: false);
    await tester.pump();
    await tester.pump();
    expect(find.text(BnStrings.offlineBanner), findsOneWidget);

    // Connection returns → banner disappears.
    connectivity.setOnline(online: true);
    await tester.pump();
    await tester.pump();
    expect(find.text(BnStrings.offlineBanner), findsNothing);
  });

  testWidgets(
    'cold start renders an interactive input without waiting on the network',
    (tester) async {
      final connectivity = FakeConnectivityService(online: false);
      final adapter = await pumpOfflineApp(
        tester,
        handler: (_) async => fail('no network call should be made offline'),
        connectivity: connectivity,
      );

      // The text field is interactive immediately — no spinner, no blocked
      // build while a request would be in flight.
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      await tester.enterText(field, 'বুকে ব্যথা');
      await tester.pump();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'বুকে ব্যথা',
      );

      // The submit button is enabled (input works), but offline nothing is
      // sent until the user asks.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, BnStrings.submit),
            )
            .onPressed,
        isNotNull,
      );
      expect(adapter.requests, isEmpty);
    },
  );

  testWidgets(
    'submitting online persists the result; symptom text is never written',
    (tester) async {
      final connectivity = FakeConnectivityService();
      await pumpOfflineApp(
        tester,
        handler: (_) async => FakeDioAdapter.jsonBytes(triageEnvelope),
        connectivity: connectivity,
      );

      await tester.enterText(find.byType(TextField), 'গলা ব্যথা আর জ্বর');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, BnStrings.submit));
      await tester.pumpAndSettle();

      expect(find.text('গলা ব্যথা ও জ্বর'), findsOneWidget);

      // The result made it into storage for offline reuse…
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(CacheService.triageResultKey);
      expect(raw, isNotNull);

      // …and the raw symptoms never did. Everything stored under the cache
      // keys is API-shaped JSON; the typed text is absent from every value.
      final allStored = prefs
          .getKeys()
          .map((k) => '${prefs.get(k)}')
          .join('\n');
      expect(allStored, isNot(contains('গলা ব্যথা আর জ্বর')));
    },
  );

  test(
    'TriageResult serialisation carries no symptom field',
    () {
      const result = TriageResult(
        level: TriageLevel.yellow,
        titleBn: 'গলা ব্যথা ও জ্বর',
        summaryBn: 'সারাংশ',
        adviceBn: [],
        warningSignsBn: [],
        disclaimerBn: 'দাবিত্যাগ',
        createdAt: '2026-08-05T15:10:22.481Z',
      );
      final json = result.toJson();
      expect(json.containsKey('symptoms'), isFalse);
      expect(
        json.values.map((v) => '$v').join(),
        isNot(contains('গলা ব্যথা আর জ্বর')),
      );
    },
  );
}
