import 'package:care_platform_app/features/client/data/supabase_caregiver_search_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('city filter preserves case-insensitive exact matching', () {
    expect(
      SupabaseCaregiverSearchGateway.exactCityPattern(r' Че%_*ля\бинск '),
      r'Че\%\_\*ля\\бинск',
    );
  });
}
