import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';

class UnavailableAdminModerationGateway implements AdminModerationGateway {
  const UnavailableAdminModerationGateway();

  @override
  Future<PendingCaregiverProfilesPage> loadPending({
    PendingCaregiverCursor? cursor,
    required int pageSize,
  }) {
    throw StateError('Supabase is not configured.');
  }

  @override
  Future<void> moderate({
    required String caregiverProfileId,
    required ModerationStatus newStatus,
    required String reason,
    String? comment,
  }) {
    throw StateError('Supabase is not configured.');
  }
}
