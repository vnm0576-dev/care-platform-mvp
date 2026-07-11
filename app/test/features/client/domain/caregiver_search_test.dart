import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds non-overlapping Supabase ranges with one lookahead row', () {
    expect(
      CaregiverSearchRange.forPage(page: 0, pageSize: 20),
      const CaregiverSearchRange(from: 0, to: 20),
    );
    expect(
      CaregiverSearchRange.forPage(page: 1, pageSize: 20),
      const CaregiverSearchRange(from: 20, to: 40),
    );
  });
}
