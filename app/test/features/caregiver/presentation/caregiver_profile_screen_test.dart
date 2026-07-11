import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';
import 'package:care_platform_app/features/caregiver/presentation/caregiver_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves the required caregiver profile fields as a draft', (
    tester,
  ) async {
    final gateway = _FakeCaregiverProfileGateway();

    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );

    expect(find.text('Черновик анкеты сиделки'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ФИО')), 'Ирина Петрова');
    await tester.enterText(find.byKey(const ValueKey('Город')), 'Челябинск');
    await tester.enterText(
      find.byKey(const ValueKey('Телефон')),
      '+79990000000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('Опыт работы')),
      '5 лет работы сиделкой',
    );
    final scheduleField = find.byKey(
      const ValueKey('График'),
      skipOffstage: false,
    );
    await tester.ensureVisible(scheduleField);
    await tester.enterText(scheduleField, 'Дневные и ночные смены');
    final descriptionField = find.byKey(
      const ValueKey('О себе'),
      skipOffstage: false,
    );
    await tester.ensureVisible(descriptionField);
    await tester.enterText(descriptionField, 'Спокойно организую уход и быт.');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final dementiaSkill = find.widgetWithText(
      FilterChip,
      'Уход при деменции',
      skipOffstage: false,
    );
    await tester.ensureVisible(dementiaSkill);
    await tester.tap(dementiaSkill);

    final saveButton = find.widgetWithText(
      FilledButton,
      'Сохранить черновик',
      skipOffstage: false,
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(gateway.savedDraft?.fullName, 'Ирина Петрова');
    expect(gateway.savedDraft?.city, 'Челябинск');
    expect(gateway.savedDraft?.contactPhone, isNotEmpty);
    expect(gateway.savedDraft?.experience, '5 лет работы сиделкой');
    expect(gateway.savedDraft?.skills, ['Уход при деменции']);
    expect(gateway.savedDraft?.schedule, 'Дневные и ночные смены');
    expect(gateway.savedDraft?.description, 'Спокойно организую уход и быт.');
    expect(find.text('Черновик сохранён'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    final submitButton = find.text(
      'Отправить на модерацию',
      skipOffstage: false,
    );
    expect(submitButton, findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(gateway.submittedProfileId, 'caregiver-profile-1');
    expect(find.text('Анкета отправлена на модерацию'), findsOneWidget);
  });
  testWidgets('does not allow moderation submission without a selected skill', (
    tester,
  ) async {
    final gateway = _FakeCaregiverProfileGateway();
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );

    await tester.enterText(find.byKey(const ValueKey('ФИО')), 'Ирина Петрова');
    await tester.enterText(find.byKey(const ValueKey('Город')), 'Челябинск');
    await tester.enterText(
      find.byKey(const ValueKey('Телефон')),
      '+799****0000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('Опыт работы')),
      '5 лет работы сиделкой',
    );
    final scheduleField = find.byKey(
      const ValueKey('График'),
      skipOffstage: false,
    );
    await tester.ensureVisible(scheduleField);
    await tester.enterText(scheduleField, 'Дневные смены');
    final descriptionField = find.byKey(
      const ValueKey('О себе'),
      skipOffstage: false,
    );
    await tester.ensureVisible(descriptionField);
    await tester.enterText(descriptionField, 'Организую уход и быт.');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(
      FilledButton,
      'Сохранить черновик',
      skipOffstage: false,
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    final submitButton = find.widgetWithText(
      OutlinedButton,
      'Отправить на модерацию',
      skipOffstage: false,
    );
    await tester.ensureVisible(submitButton);
    expect(tester.widget<OutlinedButton>(submitButton).onPressed, isNull);
  });
}

class _FakeCaregiverProfileGateway implements CaregiverProfileGateway {
  CaregiverProfileDraft? savedDraft;
  String? submittedProfileId;

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() async => null;

  @override
  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  }) async {
    savedDraft = draft;
    return const CaregiverProfileRecord(
      id: 'caregiver-profile-1',
      status: CaregiverProfileStatus.draft,
    );
  }

  @override
  Future<void> submitForReview(String caregiverProfileId) async {
    submittedProfileId = caregiverProfileId;
  }
}
