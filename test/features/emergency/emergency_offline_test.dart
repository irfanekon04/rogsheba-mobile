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
import 'package:rogsheba_mobile/core/services/launcher_service.dart';
import 'package:rogsheba_mobile/core/services/speech_service.dart';
import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/fake_speech_service.dart';
import '../../helpers/fake_tts_service.dart';

const List<Map<String, dynamic>> cachedContacts = [
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
];

void main() {
  testWidgets(
    'with no connectivity the hotline list renders from a fresh cache '
    'without issuing a request',
    (tester) async {
      final connectivity = FakeConnectivityService(online: false);
      final adapter = FakeDioAdapter(
        (options) async => fail('no network call should be made offline'),
      );

      SharedPreferences.setMockInitialValues({
        CacheService.emergencyContactsKey: jsonEncode(cachedContacts),
        CacheService.emergencyCachedAtKey: DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWith(
              (ref) => Dio()..httpClientAdapter = adapter,
            ),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            speechServiceProvider.overrideWithValue(FakeSpeechService()),
            connectivityServiceProvider.overrideWithValue(connectivity),
            launcherServiceProvider.overrideWithValue((uri) async => true),
          ],
          child: const RogShebaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(BnStrings.hotline999));
      await tester.pumpAndSettle();

      // The cached numbers render — the one resource that must survive
      // offline is exactly what the user needs when offline.
      expect(find.text(BnStrings.emergencySheetTitle), findsOneWidget);
      expect(find.text('জাতীয় ইমার্জেন্সি সার্ভিস'), findsOneWidget);
      expect(find.text('স্বাস্থ্য বাতায়ন'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('৯৯৯'),
        ),
        findsOneWidget,
      );

      // Not one request went to the wire.
      expect(adapter.requests, isEmpty);
    },
  );

  testWidgets(
    'a cached hotline list older than 24h is refetched rather than shown',
    (tester) async {
      final connectivity = FakeConnectivityService();
      final adapter = FakeDioAdapter(
        (options) async => FakeDioAdapter.jsonBytes({
          'success': true,
          'data': {
            'country': 'BD',
            'contacts': cachedContacts,
          },
        }),
      );

      SharedPreferences.setMockInitialValues({
        CacheService.emergencyContactsKey: jsonEncode(cachedContacts),
        CacheService.emergencyCachedAtKey: DateTime.now()
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWith(
              (ref) => Dio()..httpClientAdapter = adapter,
            ),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            speechServiceProvider.overrideWithValue(FakeSpeechService()),
            connectivityServiceProvider.overrideWithValue(connectivity),
            launcherServiceProvider.overrideWithValue((uri) async => true),
          ],
          child: const RogShebaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(BnStrings.hotline999));
      await tester.pumpAndSettle();

      // The refetch path ran: exactly one /emergency request was issued and
      // the sheet still shows the contacts.
      final emergencyCalls = adapter.requests
          .where((o) => o.path == '/emergency')
          .toList();
      expect(emergencyCalls, hasLength(1));
      expect(find.text('জাতীয় ইমার্জেন্সি সার্ভিস'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed refetch shows the Bangla error copy, not stale numbers',
    (tester) async {
      final connectivity = FakeConnectivityService();
      final adapter = FakeDioAdapter(
        (options) async => FakeDioAdapter.jsonBytes(
          {
            'success': false,
            'error': {
              'code': 'server_error',
              'message': BnStrings.genericError,
            },
          },
          status: 500,
        ),
      );

      SharedPreferences.setMockInitialValues({
        CacheService.emergencyContactsKey: jsonEncode(cachedContacts),
        CacheService.emergencyCachedAtKey: DateTime.now()
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWith(
              (ref) => Dio()..httpClientAdapter = adapter,
            ),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            speechServiceProvider.overrideWithValue(FakeSpeechService()),
            connectivityServiceProvider.overrideWithValue(connectivity),
            launcherServiceProvider.overrideWithValue((uri) async => true),
          ],
          child: const RogShebaApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(BnStrings.hotline999));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text(BnStrings.genericError), findsOneWidget);
      expect(find.text(BnStrings.retry), findsOneWidget);
    },
  );
}
