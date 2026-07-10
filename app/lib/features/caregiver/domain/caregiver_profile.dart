enum CaregiverProfileStatus {
  draft,
  pendingReview,
  approved,
  rejected,
  hidden;

  String get databaseValue => switch (this) {
    CaregiverProfileStatus.draft => 'draft',
    CaregiverProfileStatus.pendingReview => 'pending_review',
    CaregiverProfileStatus.approved => 'approved',
    CaregiverProfileStatus.rejected => 'rejected',
    CaregiverProfileStatus.hidden => 'hidden',
  };

  static CaregiverProfileStatus fromDatabaseValue(String value) =>
      switch (value) {
        'draft' => CaregiverProfileStatus.draft,
        'pending_review' => CaregiverProfileStatus.pendingReview,
        'approved' => CaregiverProfileStatus.approved,
        'rejected' => CaregiverProfileStatus.rejected,
        'hidden' => CaregiverProfileStatus.hidden,
        _ => throw ArgumentError.value(
          value,
          'value',
          'Unsupported profile status',
        ),
      };
}

class CaregiverProfileDraft {
  const CaregiverProfileDraft({
    required this.fullName,
    required this.city,
    required this.district,
    required this.contactPhone,
    required this.experience,
    required this.education,
    required this.certificates,
    required this.skills,
    required this.schedule,
    required this.description,
    required this.desiredPayment,
    required this.readyForLiveIn,
    required this.readyForNightShifts,
    required this.dementiaExperience,
    required this.bedriddenExperience,
    required this.strokeExperience,
    required this.heartAttackExperience,
    required this.traumaExperience,
  });

  final String fullName;
  final String city;
  final String district;
  final String contactPhone;
  final String experience;
  final String education;
  final List<String> certificates;
  final List<String> skills;
  final String schedule;
  final String description;
  final num? desiredPayment;
  final bool readyForLiveIn;
  final bool readyForNightShifts;
  final bool dementiaExperience;
  final bool bedriddenExperience;
  final bool strokeExperience;
  final bool heartAttackExperience;
  final bool traumaExperience;

  Map<String, dynamic> toWritePayload() => {
    'full_name': fullName.trim(),
    'city': city.trim(),
    if (district.trim().isNotEmpty) 'district': district.trim(),
    'contact_phone': contactPhone.trim(),
    'experience': experience.trim(),
    if (education.trim().isNotEmpty) 'education': education.trim(),
    'certificates': certificates
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(),
    'skills': skills
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(),
    'schedule': schedule.trim(),
    'description': description.trim(),
    if (desiredPayment != null) 'desired_payment': desiredPayment,
    'ready_for_live_in': readyForLiveIn,
    'ready_for_night_shifts': readyForNightShifts,
    'dementia_experience': dementiaExperience,
    'bedridden_experience': bedriddenExperience,
    'stroke_experience': strokeExperience,
    'heart_attack_experience': heartAttackExperience,
    'trauma_experience': traumaExperience,
  };
}
