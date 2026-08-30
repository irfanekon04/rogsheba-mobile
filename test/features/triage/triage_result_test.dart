import 'package:flutter_test/flutter_test.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_level.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';

void main() {
  group('TriageResult.fromJson', () {
    test('parses a full response, ignoring unknown fields', () {
      final result = TriageResult.fromJson(const {
        'level': 'YELLOW',
        'title_bn': 'গলা ব্যথা ও জ্বর',
        'summary_bn': 'গলার সংক্রমণ',
        'advice_bn': ['বিশ্রাম নিন'],
        'warning_signs_bn': ['শ্বাস কষ্ট'],
        'followup_question_bn': 'আর কোন লক্ষণ?',
        'disclaimer_bn': 'এটি ডাক্তারের পরামর্শ নয়।',
        'emergency_number': null,
        'created_at': '2026-08-05T15:10:22.481Z',
        'unknown_field_that_must_not_break': {'whatever': 1},
      });

      expect(result.level, TriageLevel.yellow);
      expect(result.titleBn, 'গলা ব্যথা ও জ্বর');
      expect(result.summaryBn, 'গলার সংক্রমণ');
      expect(result.adviceBn, ['বিশ্রাম নিন']);
      expect(result.warningSignsBn, ['শ্বাস কষ্ট']);
      expect(result.followupQuestionBn, 'আর কোন লক্ষণ?');
      expect(result.disclaimerBn, 'এটি ডাক্তারের পরামর্শ নয়।');
      expect(result.emergencyNumber, isNull);
      expect(result.createdAt, '2026-08-05T15:10:22.481Z');
    });

    test('missing or unknown level falls back to YELLOW, never GREEN', () {
      expect(TriageResult.fromJson(const {}).level, TriageLevel.yellow);
      expect(
        TriageResult.fromJson(const {'level': 'BANANA'}).level,
        TriageLevel.yellow,
      );
      expect(
        TriageResult.fromJson(const {'level': null}).level,
        TriageLevel.yellow,
      );
    });

    test('maps GREEN and RED to their levels', () {
      expect(
        TriageResult.fromJson(const {'level': 'GREEN'}).level,
        TriageLevel.green,
      );
      expect(
        TriageResult.fromJson(const {'level': 'RED'}).level,
        TriageLevel.red,
      );
    });

    test('missing lists decode as empty rather than failing', () {
      final result = TriageResult.fromJson(const {'level': 'GREEN'});
      expect(result.adviceBn, isEmpty);
      expect(result.warningSignsBn, isEmpty);
    });

    test('parses follow-up conversation fields leniently', () {
      final result = TriageResult.fromJson(const {
        'level': 'RED',
        'session_id': 'b4b2f0d2-1c9a-4a1f-9f0f-1a2b3c4d5e6f',
        'turn': 2,
        'turns': [
          {'role': 'assistant', 'text': 'আপনার কি ঢোক গিলতে খুব কষ্ট হচ্ছে?'},
          {'role': 'patient', 'text': 'হ্যাঁ, ঢোক গিলতে খুব কষ্ট হচ্ছে'},
        ],
        'is_complete': true,
      });

      expect(result.sessionId, 'b4b2f0d2-1c9a-4a1f-9f0f-1a2b3c4d5e6f');
      expect(result.turn, 2);
      expect(result.turns, hasLength(2));
      expect(result.turns.first.role, 'assistant');
      expect(result.turns.first.text, 'আপনার কি ঢোক গিলতে খুব কষ্ট হচ্ছে?');
      expect(result.turns.last.role, 'patient');
      expect(result.isComplete, isTrue);
    });

    test('missing follow-up fields default safely', () {
      final result = TriageResult.fromJson(const {'level': 'YELLOW'});
      expect(result.sessionId, isNull);
      expect(result.turn, 0);
      expect(result.turns, isEmpty);
      expect(result.isComplete, isTrue);
    });

    test('TriageTurn.fromJson normalises unknown roles to patient', () {
      final turn = TriageTurn.fromJson(const {'role': 'weird', 'text': 'কিছু'});
      expect(turn.role, 'patient');
      expect(turn.text, 'কিছু');
    });
  });
}
