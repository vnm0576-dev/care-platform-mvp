enum ModerationStatus {
  approved('approved'),
  rejected('rejected');

  const ModerationStatus(this.databaseValue);

  final String databaseValue;
}

class PendingCaregiverProfile {
  const PendingCaregiverProfile({
    required this.id,
    required this.fullName,
    required this.city,
    required this.contactPhone,
    required this.experience,
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

  final String id;
  final String fullName;
  final String city;
  final String contactPhone;
  final String experience;
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
}

class PendingCaregiverProfilesPage {
  const PendingCaregiverProfilesPage({
    required this.items,
    required this.hasMore,
  });

  final List<PendingCaregiverProfile> items;
  final bool hasMore;
}
