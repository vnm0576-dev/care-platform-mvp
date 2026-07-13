import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('card exposes a stable approved-at cursor', () {
    final approvedAt = DateTime.utc(2026, 7, 12, 10);
    final card = CaregiverSearchCard(
      id: 'caregiver-1',
      fullName: 'Ирина Петрова',
      city: 'Челябинск',
      experience: '7 лет',
      schedule: 'Дневные смены',
      description: 'Опыт ухода',
      approvedAt: approvedAt,
    );

    expect(
      card.cursor,
      CaregiverSearchCursor(approvedAt: approvedAt, id: 'caregiver-1'),
    );
  });
}
