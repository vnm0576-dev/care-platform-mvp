import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminModerationGateway implements AdminModerationGateway {
  SupabaseAdminModerationGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<PendingCaregiverProfilesPage> loadPending({
    PendingCaregiverCursor? cursor,
    required int pageSize,
  }) async {
    var query = _client
        .from('caregiver_profiles')
        .select(
          'id,full_name,city,contact_phone,experience,certificates,skills,'
          'schedule,description,desired_payment,ready_for_live_in,'
          'ready_for_night_shifts,dementia_experience,bedridden_experience,'
          'stroke_experience,heart_attack_experience,trauma_experience,'
          'district,education,photo_url,submitted_at',
        )
        .eq('status', 'pending_review')
        .order('submitted_at', ascending: true)
        .order('id', ascending: true);
    if (cursor != null) {
      final timestamp = cursor.submittedAt.toUtc().toIso8601String();
      query = query.or(
        'submitted_at.gt.$timestamp,and(submitted_at.eq.$timestamp,id.gt.${cursor.id})',
      );
    }
    final rows = await query.limit(pageSize + 1);
    final pageRows = rows.take(pageSize).toList(growable: false);
    return PendingCaregiverProfilesPage(
      items: pageRows.map(_toPendingProfile).toList(growable: false),
      hasMore: rows.length > pageSize,
      nextCursor: rows.length > pageSize ? _toPendingProfile(pageRows.last).cursor : null,
    );
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
        contactPhone: row['contact_phone'] as String? ?? '',
        experience: row['experience'] as String? ?? 'Опыт не указан',
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
        district: row['district'] as String?,
        education: row['education'] as String?,
        photoUrl: row['photo_url'] as String?,
        submittedAt: DateTime.parse(row['submitted_at'] as String),
      );
}
