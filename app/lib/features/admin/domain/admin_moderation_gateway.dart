import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';

abstract interface class AdminModerationGateway {
  Future<PendingCaregiverProfilesPage> loadPending({
    PendingCaregiverCursor? cursor,
    required int pageSize,
  });

  Future<void> moderate({
    required String caregiverProfileId,
    required ModerationStatus newStatus,
    required String reason,
    String? comment,
  });
}
