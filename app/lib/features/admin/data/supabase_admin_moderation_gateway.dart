import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminModerationGateway implements AdminModerationGateway {
  SupabaseAdminModerationGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PendingCaregiverProfile>> loadPending() async {
    final rows = await _client
        .from('caregiver_profiles')
        .select('id,full_name,city,experience,schedule,description')
        .eq('status', 'pending_review')
        .order('submitted_at', ascending: true)
        .order('id', ascending: true);
    return rows.map(_toPendingProfile).toList(growable: false);
  }

  @override
  Future<void> moderate({
    required String caregiverProfileId,
    required ModerationStatus newStatus,
    required String reason,
    String? comment,
  }) async {
    await _client.rpc(
      'moderate_caregiver_profile',
      params: {
        'p_caregiver_profile_id': caregiverProfileId,
        'p_new_status': newStatus.databaseValue,
        'p_reason': reason.trim(),
        'p_comment': comment?.trim(),
      },
    );
  }

  PendingCaregiverProfile _toPendingProfile(Map<String, dynamic> row) =>
      PendingCaregiverProfile(
        id: row['id'] as String,
        fullName: row['full_name'] as String? ?? 'Без имени',
        city: row['city'] as String? ?? 'Город не указан',
        experience: row['experience'] as String? ?? 'Опыт не указан',
        schedule: row['schedule'] as String? ?? '',
        description: row['description'] as String? ?? '',
      );
}
