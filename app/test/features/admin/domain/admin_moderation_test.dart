import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending profile retains all details required for moderation', () {
    const profile = PendingCaregiverProfile(
      id: 'profile-1',
      fullName: 'Ирина Петрова',
      city: 'Челябинск',
      contactPhone: '+799****1122',
      experience: '7 лет',
      certificates: ['Первая помощь'],
      skills: ['Уход при деменции'],
      schedule: 'Дневные смены',
      description: 'Опыт ухода при деменции',
      desiredPayment: 2500,
      readyForLiveIn: true,
      readyForNightShifts: true,
      dementiaExperience: true,
      bedriddenExperience: true,
      strokeExperience: true,
      heartAttackExperience: true,
      traumaExperience: true,
    );

    expect(profile.contactPhone, '+799****1122');
    expect(profile.skills, ['Уход при деменции']);
    expect(profile.certificates, ['Первая помощь']);
    expect(profile.desiredPayment, 2500);
    expect(profile.readyForLiveIn, isTrue);
    expect(profile.readyForNightShifts, isTrue);
    expect(profile.dementiaExperience, isTrue);
    expect(profile.bedriddenExperience, isTrue);
    expect(profile.strokeExperience, isTrue);
    expect(profile.heartAttackExperience, isTrue);
    expect(profile.traumaExperience, isTrue);
  });

  test('pending profiles page indicates whether another page is available', () {
    const page = PendingCaregiverProfilesPage(items: [], hasMore: true);

    expect(page.hasMore, isTrue);
  });
}
