import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCaregiverProfileGateway implements CaregiverProfileGateway {
  SupabaseCaregiverProfileGateway(this._client);

  final SupabaseClient _client;

  static const _readFields =
      'id,status,rejection_reason,full_name,city,district,contact_phone,'
      'experience,education,certificates,skills,schedule,description,'
      'desired_payment,ready_for_live_in,ready_for_night_shifts,'
      'dementia_experience,bedridden_experience,stroke_experience,'
      'heart_attack_experience,trauma_experience';

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() async {
    final userId = _requireUserId();
    final row = await _client
        .from('caregiver_profiles')
        .select(_readFields)
        .eq('profile_id', userId)
        .maybeSingle();
    return row == null ? null : _toRecord(row);
  }

  @override
  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  }) async {
    final payload = draft.toWritePayload();
    final Map<String, dynamic> row;
    if (existingProfileId == null) {
      row = await _client
          .from('caregiver_profiles')
          .insert({...payload, 'profile_id': _requireUserId()})
          .select(_readFields)
          .single();
    } else {
      row = await _client
          .from('caregiver_profiles')
          .update(payload)
          .eq('id', existingProfileId)
          .select(_readFields)
          .single();
    }
    return _toRecord(row);
  }

  @override
  Future<void> submitForReview(String caregiverProfileId) async {
    await _client.rpc(
      'submit_caregiver_profile',
      params: {'p_caregiver_profile_id': caregiverProfileId},
    );
  }

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Требуется авторизованный пользователь.');
    return id;
  }

  CaregiverProfileRecord _toRecord(
    Map<String, dynamic> row,
  ) => CaregiverProfileRecord(
    id: row['id'] as String,
    status: CaregiverProfileStatus.fromDatabaseValue(row['status'] as String),
    rejectionReason: row['rejection_reason'] as String?,
    draft: CaregiverProfileDraft(
      fullName: row['full_name'] as String? ?? '',
      city: row['city'] as String? ?? '',
      district: row['district'] as String? ?? '',
      contactPhone: row['contact_phone'] as String? ?? '',
      experience: row['experience'] as String? ?? '',
      education: row['education'] as String? ?? '',
      certificates: List<String>.from(row['certificates'] as List? ?? []),
      skills: List<String>.from(row['skills'] as List? ?? []),
      schedule: row['schedule'] as String? ?? '',
      description: row['description'] as String? ?? '',
      desiredPayment: row['desired_payment'] as num?,
      readyForLiveIn: row['ready_for_live_in'] as bool? ?? false,
      readyForNightShifts: row['ready_for_night_shifts'] as bool? ?? false,
      dementiaExperience: row['dementia_experience'] as bool? ?? false,
      bedriddenExperience: row['bedridden_experience'] as bool? ?? false,
      strokeExperience: row['stroke_experience'] as bool? ?? false,
      heartAttackExperience: row['heart_attack_experience'] as bool? ?? false,
      traumaExperience: row['trauma_experience'] as bool? ?? false,
    ),
  );
}
