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
    required this.experience,
    required this.schedule,
    required this.description,
  });

  final String id;
  final String fullName;
  final String city;
  final String experience;
  final String schedule;
  final String description;
}
