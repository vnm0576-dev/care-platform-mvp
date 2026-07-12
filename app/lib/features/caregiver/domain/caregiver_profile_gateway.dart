import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';

abstract interface class CaregiverProfileGateway {
  Future<CaregiverProfileRecord?> loadOwnProfile();

  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  });

  Future<void> submitForReview(String caregiverProfileId);
}

class CaregiverProfileRecord {
  const CaregiverProfileRecord({
    required this.id,
    required this.status,
    this.rejectionReason,
    this.draft,
  });

  final String id;
  final CaregiverProfileStatus status;
  final String? rejectionReason;
  final CaregiverProfileDraft? draft;
}
