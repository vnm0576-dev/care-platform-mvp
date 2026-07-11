class ClientRequestDraft {
  const ClientRequestDraft({
    required this.city,
    required this.careType,
    required this.description,
    required this.contactPhone,
    required this.needsLiveIn,
    required this.needsNightShifts,
    required this.dementiaCase,
    required this.bedriddenCase,
    required this.strokeCase,
    required this.heartAttackCase,
    required this.traumaCase,
  });

  final String city;
  final String careType;
  final String description;
  final String contactPhone;
  final bool needsLiveIn;
  final bool needsNightShifts;
  final bool dementiaCase;
  final bool bedriddenCase;
  final bool strokeCase;
  final bool heartAttackCase;
  final bool traumaCase;

  Map<String, dynamic> toWritePayload() => {
    'city': city.trim(),
    'care_type': careType.trim(),
    'description': description.trim(),
    'contact_phone': contactPhone.trim(),
    'needs_live_in': needsLiveIn,
    'needs_night_shifts': needsNightShifts,
    'dementia_case': dementiaCase,
    'bedridden_case': bedriddenCase,
    'stroke_case': strokeCase,
    'heart_attack_case': heartAttackCase,
    'trauma_case': traumaCase,
  };
}
