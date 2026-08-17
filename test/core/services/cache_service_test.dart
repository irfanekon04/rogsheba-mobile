import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rogsheba_mobile/core/services/cache_service.dart';
import 'package:rogsheba_mobile/features/emergency/domain/emergency_contact.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_level.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A result-shaped value lifted from the API's `POST /triage` contract. It has
/// no symptom field — by design the model only carries what the API returned.
TriageResult sampleTriageResult() => const TriageResult(
      level: TriageLevel.yellow,
      titleBn: 'গলা ব্যথা ও জ্বর',
      summaryBn: 'আপনার লক্ষণ সম্ভবত গলার সংক্রমণ নির্দেশ করছে।',
      adviceBn: ['প্রচুর কুসুম গরম পানি খান'],
      warningSignsBn: ['শ্বাস নিতে কষ্ট হলে'],
      followupQuestionBn: 'ঢোক গিলতে কষ্ট হচ্ছে?',
      disclaimerBn: 'এটি ডাক্তারের পরামর্শ নয়।',
      createdAt: '2026-08-05T15:10:22.481Z',
    );

const List<EmergencyContact> sampleContacts = [
  EmergencyContact(labelBn: 'জাতীয় ইমার্জেন্সি সার্ভিস', number: '999'),
  EmergencyContact(labelBn: 'স্বাস্থ্য বাতায়ন', number: '16263'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CacheService> buildCache([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    return CacheService(prefs: prefs);
  }

  group('triage result cache', () {
    test('round-trips a result through the real store', () async {
      final cache = await buildCache();

      expect(cache.readTriageResult(), isNull);

      await cache.saveTriageResult(sampleTriageResult());

      final restored = cache.readTriageResult();
      expect(restored, isNotNull);
      expect(restored!.level, TriageLevel.yellow);
      expect(restored.titleBn, 'গলা ব্যথা ও জ্বর');
      expect(restored.summaryBn, sampleTriageResult().summaryBn);
      expect(restored.adviceBn, ['প্রচুর কুসুম গরম পানি খান']);
      expect(restored.warningSignsBn, ['শ্বাস নিতে কষ্ট হলে']);
      expect(restored.followupQuestionBn, 'ঢোক গিলতে কষ্ট হচ্ছে?');
      expect(restored.disclaimerBn, 'এটি ডাক্তারের পরামর্শ নয়।');
      expect(restored.createdAt, '2026-08-05T15:10:22.481Z');
    });

    test('a corrupt cache entry reads back as absent', () async {
      final cache = await buildCache({
        CacheService.triageResultKey: 'not json {',
      });

      expect(cache.readTriageResult(), isNull);
    });

    test('never persists symptom text', () async {
      final cache = await buildCache();
      await cache.saveTriageResult(sampleTriageResult());

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getKeys().map((k) => '${prefs.get(k)}').join('\n');

      expect(stored, isNot(contains('গলা ব্যথা আর জ্বর')));
    });
  });

  group('emergency contact cache', () {
    test('round-trips the list and stamps a timestamp', () async {
      final cache = await buildCache();

      expect(cache.readEmergencyContacts(), isNull);

      await cache.saveEmergencyContacts(sampleContacts);

      final restored = cache.readEmergencyContacts();
      expect(restored, isNotNull);
      expect(restored, hasLength(2));
      expect(restored![0].labelBn, 'জাতীয় ইমার্জেন্সি সার্ভিস');
      expect(restored[0].number, '999');
      expect(restored[1].labelBn, 'স্বাস্থ্য বাতায়ন');
      expect(restored[1].number, '16263');
    });

    test('fresh contacts within the TTL are served', () async {
      final fresh = DateTime.now()
          .subtract(CacheService.emergencyCacheTtl ~/ 2);
      final cache = await buildCache({
        CacheService.emergencyContactsKey: jsonEncode([
          for (final c in sampleContacts) c.toJson(),
        ]),
        CacheService.emergencyCachedAtKey: fresh.millisecondsSinceEpoch,
      });

      final restored = cache.readEmergencyContacts();
      expect(restored, isNotNull);
      expect(restored, hasLength(2));
    });

    test('contacts older than the 24h TTL read back as absent', () async {
      final stale = DateTime.now().subtract(
        CacheService.emergencyCacheTtl + const Duration(hours: 1),
      );
      final cache = await buildCache({
        CacheService.emergencyContactsKey: jsonEncode([
          for (final c in sampleContacts) c.toJson(),
        ]),
        CacheService.emergencyCachedAtKey: stale.millisecondsSinceEpoch,
      });

      expect(cache.readEmergencyContacts(), isNull);
    });

    test('corrupt or missing data reads back as absent', () async {
      final cache = await buildCache({
        CacheService.emergencyContactsKey: 'not json [',
        CacheService.emergencyCachedAtKey:
            DateTime.now().millisecondsSinceEpoch,
      });

      expect(cache.readEmergencyContacts(), isNull);
    });
  });
}
