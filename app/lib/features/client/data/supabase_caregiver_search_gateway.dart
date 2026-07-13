import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCaregiverSearchGateway implements CaregiverSearchGateway {
  SupabaseCaregiverSearchGateway(this._client);

  final SupabaseClient _client;

  static String exactCityPattern(String city) => city
      .trim()
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_')
      .replaceAll('*', r'\*');

  @override
  Future<CaregiverSearchPage> loadApproved({
    required String city,
    CaregiverSearchCursor? cursor,
    required int pageSize,
  }) async {
    var query = _client
        .from('approved_caregiver_profiles')
        .select(
          'id,full_name,city,experience,schedule,description,contact_phone,approved_at',
        )
        .ilike('city', exactCityPattern(city))
        .not('approved_at', 'is', null);
    if (cursor != null) {
      final timestamp = cursor.approvedAt.toUtc().toIso8601String();
      query = query.or(
        'approved_at.lt.$timestamp,and(approved_at.eq.$timestamp,id.lt.${cursor.id})',
      );
    }

    final rows = await query
        .order('approved_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize + 1);
    final pageRows = rows.take(pageSize).toList(growable: false);
    final items = pageRows.map(_mapCard).toList(growable: false);
    final hasMore = rows.length > pageSize;
    return CaregiverSearchPage(
      items: items,
      hasMore: hasMore,
      nextCursor: hasMore ? items.last.cursor : null,
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
      approvedAt: DateTime.parse(row['approved_at'] as String),
    );
  }
}
