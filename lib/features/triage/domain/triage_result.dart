import 'package:rogsheba_mobile/features/triage/domain/triage_level.dart';

/// One message in the follow-up conversation, as echoed back by the API.
///
/// The client owns the conversation and sends these turns back on the next
/// `/triage/followup` call. `assistant` turns are the follow-up questions the
/// app asked; `patient` turns are the user's answers.
class TriageTurn {
  const TriageTurn({required this.role, required this.text});

  factory TriageTurn.fromJson(Map<String, dynamic> json) => TriageTurn(
        role: json['role'] == 'assistant' ? 'assistant' : 'patient',
        text: json['text'] as String? ?? '',
      );

  /// `"assistant"` (a question the app asked) or `"patient"` (the user's
  /// answer). Anything else is normalised to `"patient"` so an unknown value
  /// never corrupts the payload.
  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

/// Immutable triage result mirroring the `POST /triage` contract exactly.
///
/// Parsed leniently per the API's versioning note: unknown fields are ignored
/// and never cause a decode failure, and a missing/unrecognised `level` falls
/// back to [TriageLevel.yellow].
class TriageResult {
  const TriageResult({
    required this.level,
    required this.titleBn,
    required this.summaryBn,
    required this.adviceBn,
    required this.warningSignsBn,
    required this.disclaimerBn,
    required this.createdAt,
    this.followupQuestionBn,
    this.emergencyNumber,
    this.sessionId,
    this.turn = 0,
    this.turns = const [],
    this.isComplete = true,
  });

  factory TriageResult.fromJson(Map<String, dynamic> json) {
    return TriageResult(
      level: triageLevelFrom(json['level']),
      titleBn: json['title_bn'] as String? ?? '',
      summaryBn: json['summary_bn'] as String? ?? '',
      adviceBn: _asStringList(json['advice_bn']),
      warningSignsBn: _asStringList(json['warning_signs_bn']),
      followupQuestionBn: json['followup_question_bn'] as String?,
      disclaimerBn: json['disclaimer_bn'] as String? ?? '',
      emergencyNumber: json['emergency_number'] as String?,
      sessionId: json['session_id'] as String?,
      turn: json['turn'] as int? ?? 0,
      turns: _asTurnList(json['turns']),
      isComplete: json['is_complete'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  final TriageLevel level;
  final String titleBn;
  final String summaryBn;
  final List<String> adviceBn;
  final List<String> warningSignsBn;

  /// One follow-up question, displayed for parity but not answerable in v1.
  final String? followupQuestionBn;

  /// Always render; this is preferred by the medical-app reviewers.
  final String disclaimerBn;

  /// `"999"` when [level] is red, otherwise `null`.
  final String? emergencyNumber;

  /// Client-generated id echoed back by `/triage/followup` so the app can
  /// group turns locally. `null` before any follow-up has been sent.
  final String? sessionId;

  /// Number of turns in [turns].
  final int turn;

  /// The conversation so far (assistant questions + patient answers).
  final List<TriageTurn> turns;

  /// `true` when there are no more follow-up questions (`followupQuestionBn`
  /// is `null`), so the multi-turn flow is finished.
  final bool isComplete;

  final String createdAt;

  /// Mirror of [TriageResult.fromJson]: round-trips the cached JSON exactly.
  ///
  /// Note the deliberate absence of any symptom text — the model only carries
  /// what the API returned, so serialising it can never persist what the user
  /// typed. That is what the offline slice's storage assertion leans on.
  Map<String, dynamic> toJson() {
    return {
      'level': level.name.toUpperCase(),
      'title_bn': titleBn,
      'summary_bn': summaryBn,
      'advice_bn': adviceBn,
      'warning_signs_bn': warningSignsBn,
      'followup_question_bn': followupQuestionBn,
      'disclaimer_bn': disclaimerBn,
      'emergency_number': emergencyNumber,
      'session_id': sessionId,
      'turn': turn,
      'turns': [for (final t in turns) t.toJson()],
      'is_complete': isComplete,
      'created_at': createdAt,
    };
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  static List<TriageTurn> _asTurnList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value.whereType<Map<String, dynamic>>())
        TriageTurn.fromJson(entry),
    ];
  }
}
