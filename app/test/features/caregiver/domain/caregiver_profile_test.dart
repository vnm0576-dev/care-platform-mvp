import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draft payload contains only writable caregiver fields', () {
    const draft = CaregiverProfileDraft(
      fullName: 'Ирина Петрова',
      city: 'Челябинск',
      district: 'Центральный',
      contactPhone: '+799****0000',
      experience: '5 лет работы сиделкой',
      education: 'Медицинский колледж',
      certificates: ['Первичная помощь'],
      skills: ['Уход за лежачими пациентами', 'Контроль приёма лекарств'],
      schedule: 'С проживанием или дневные смены',
      description: 'Внимательная и спокойная сиделка.',
      desiredPayment: 3500,
      readyForLiveIn: true,
      readyForNightShifts: false,
      dementiaExperience: true,
      bedriddenExperience: true,
      strokeExperience: false,
      heartAttackExperience: false,
      traumaExperience: false,
    );

    expect(draft.toWritePayload(), {
      'full_name': 'Ирина Петрова',
      'city': 'Челябинск',
      'district': 'Центральный',
      'contact_phone': '+799****0000',
      'experience': '5 лет работы сиделкой',
      'education': 'Медицинский колледж',
      'certificates': ['Первичная помощь'],
      'skills': ['Уход за лежачими пациентами', 'Контроль приёма лекарств'],
      'schedule': 'С проживанием или дневные смены',
      'description': 'Внимательная и спокойная сиделка.',
      'desired_payment': 3500,
      'ready_for_live_in': true,
      'ready_for_night_shifts': false,
      'dementia_experience': true,
      'bedridden_experience': true,
      'stroke_experience': false,
      'heart_attack_experience': false,
      'trauma_experience': false,
    });
  });

  test(
    'incomplete draft writes nullable text fields as null, never blanks',
    () {
      const draft = CaregiverProfileDraft(
        fullName: '  ',
        city: '',
        district: '',
        contactPhone: ' ',
        experience: '',
        education: '',
        certificates: [],
        skills: [],
        schedule: '',
        description: ' ',
        desiredPayment: null,
        readyForLiveIn: false,
        readyForNightShifts: false,
        dementiaExperience: false,
        bedriddenExperience: false,
        strokeExperience: false,
        heartAttackExperience: false,
        traumaExperience: false,
      );

      final payload = draft.toWritePayload();

      for (final field in [
        'full_name',
        'city',
        'contact_phone',
        'experience',
        'schedule',
        'description',
      ]) {
        expect(payload[field], isNull, reason: '$field must not be blank');
      }
    },
  );
}
