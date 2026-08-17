/// One hotline from `GET /emergency`.
///
/// The number is kept in **Arabic** form (`"999"`) — the API wire format.
/// Bengali-numerals rendering (`৯৯৯`) is the UI's job, done at draw time by
/// `toBengaliDigits`. Keeping the canonical Arabic value lets the `tel:`
/// URL builder stay format-agnostic.
class EmergencyContact {
  const EmergencyContact({
    required this.labelBn,
    required this.number,
    this.type,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      labelBn: json['label_bn'] as String? ?? '',
      number: json['number']?.toString() ?? '',
      type: json['type'] as String?,
    );
  }

  /// Bangla label rendered directly — already in script, no conversion needed.
  final String labelBn;

  /// The digits the dialer sees. Always ASCII (the API's contract).
  final String number;

  /// Coarse classification from the API (`emergency | health_hotline |
  /// support | fire`). Unused by the v1 chrome but kept so future styling can
  /// branch on it without re-decoding the JSON.
  final String? type;

  /// Mirror of [EmergencyContact.fromJson], used by `CacheService` to persist
  /// the hotline list for offline rendering.
  Map<String, dynamic> toJson() {
    return {
      'label_bn': labelBn,
      'number': number,
      if (type != null) 'type': type,
    };
  }
}

/// Envelope for the `data.contacts` array returned by `/emergency` — also
/// carries the ISO country code so the same parser can later branch on
/// geography without changing the sheet.
class EmergencyContactsResponse {
  const EmergencyContactsResponse({
    required this.country,
    required this.contacts,
  });

  factory EmergencyContactsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['contacts'];
    return EmergencyContactsResponse(
      country: json['country'] as String? ?? 'BD',
      contacts: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(EmergencyContact.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final String country;
  final List<EmergencyContact> contacts;
}
