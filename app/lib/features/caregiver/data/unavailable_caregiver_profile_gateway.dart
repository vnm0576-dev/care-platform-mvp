import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';

class UnavailableCaregiverProfileGateway implements CaregiverProfileGateway {
  const UnavailableCaregiverProfileGateway();

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() {
    throw StateError('Supabase is not configured');
  }

  @override
  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  }) {
    throw StateError('Supabase is not configured');
  }

  @override
  Future<void> submitForReview(String caregiverProfileId) {
    throw StateError('Supabase is not configured');
  }
}
