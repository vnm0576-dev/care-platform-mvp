import 'package:care_platform_app/features/client/domain/caregiver_search.dart';

abstract interface class CaregiverSearchGateway {
  Future<CaregiverSearchPage> loadApproved({
    required String city,
    CaregiverSearchCursor? cursor,
    required int pageSize,
  });
}
