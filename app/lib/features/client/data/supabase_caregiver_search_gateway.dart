import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCaregiverSearchGateway implements CaregiverSearchGateway {
  SupabaseCaregiverSearchGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<CaregiverSearchPage> loadApproved({
    required String city,
    required int page,
    required int pageSize,
  }) async {
    final range = CaregiverSearchRange.forPage(page: page, pageSize: pageSize);
    final rows = await _client
        .from('caregiver_profiles')
        .select(
          'id, full_name, city, experience, schedule, description, contact_phone',
        )
        .eq('status', 'approved')
        .eq('city', city.trim())
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(range.from, range.to);

    final hasMore = rows.length > pageSize;
    final pageRows = rows.take(pageSize);
    return CaregiverSearchPage(
      items: pageRows.map(_mapCard).toList(growable: false),
      hasMore: hasMore,
    );
  }

  CaregiverSearchCard _mapCard(Map<String, dynamic> row) {
    return CaregiverSearchCard(
      id: row['id'] as String,
      fullName: row['full_name'] as String,
      city: row['city'] as String,
      experience: row['experience'] as String,
      schedule: row['schedule'] as String,
      description: row['description'] as String? ?? '',
      contactPhone: row['contact_phone'] as String? ?? '',
    );
  }
}
