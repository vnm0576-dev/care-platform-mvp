import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCaregiverProfileGateway implements CaregiverProfileGateway {
  SupabaseCaregiverProfileGateway(this._client);

  final SupabaseClient _client;

  static const _readFields = 'id,status,rejection_reason';

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

  CaregiverProfileRecord _toRecord(Map<String, dynamic> row) =>
      CaregiverProfileRecord(
        id: row['id'] as String,
        status: CaregiverProfileStatus.fromDatabaseValue(
          row['status'] as String,
        ),
        rejectionReason: row['rejection_reason'] as String?,
      );
}
