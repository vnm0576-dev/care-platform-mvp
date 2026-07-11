import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';

class UnavailableCaregiverSearchGateway implements CaregiverSearchGateway {
  const UnavailableCaregiverSearchGateway();

  @override
  Future<CaregiverSearchPage> loadApproved({
    required String city,
    required int page,
    required int pageSize,
  }) {
    throw StateError('Supabase is not configured.');
  }
}
