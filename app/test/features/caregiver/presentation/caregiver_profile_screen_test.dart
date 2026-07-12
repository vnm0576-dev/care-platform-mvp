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
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await _selectSkillAndSave(tester);

    expect(gateway.savedDraft?.fullName, 'Ирина Петрова');
    expect(gateway.savedDraft?.city, 'Челябинск');
    expect(gateway.savedDraft?.contactPhone, isNotEmpty);
    expect(gateway.savedDraft?.experience, '5 лет работы сиделкой');
    expect(gateway.savedDraft?.skills, ['Уход при деменции']);
    expect(gateway.savedDraft?.schedule, 'Дневные смены');
    expect(gateway.savedDraft?.description, 'Организую уход и быт.');
    expect(find.text('Черновик сохранён'), findsOneWidget);
  });

  testWidgets('does not allow moderation submission without a selected skill', (
    tester,
  ) async {
    final gateway = _FakeCaregiverProfileGateway();
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        'Сохранить черновик',
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();

    final submitButton = find.widgetWithText(
      OutlinedButton,
      'Отправить на модерацию',
    );
    expect(tester.widget<OutlinedButton>(submitButton).onPressed, isNull);
  });

  testWidgets(
    'saves a locally selected skill before submitting it for review',
    (tester) async {
      final gateway = _FakeCaregiverProfileGateway();
      await tester.pumpWidget(
        MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
      );
      await tester.pumpAndSettle();

      await _fillRequiredFields(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          'Сохранить черновик',
          skipOffstage: false,
        ),
      );
      await tester.pumpAndSettle();
      final skill = find.widgetWithText(FilterChip, 'Уход при деменции');
      await tester.ensureVisible(skill);
      await tester.tap(skill);
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(
        OutlinedButton,
        'Отправить на модерацию',
        skipOffstage: false,
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(gateway.savedDrafts, hasLength(2));
      expect(gateway.savedDrafts.last.skills, ['Уход при деменции']);
      expect(gateway.submittedProfileId, 'caregiver-profile-1');
    },
  );

  testWidgets('updates the same record on repeated saves', (tester) async {
    final gateway = _FakeCaregiverProfileGateway();
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    final save = find.widgetWithText(
      FilledButton,
      'Сохранить черновик',
      skipOffstage: false,
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(gateway.existingProfileIds, [null, 'caregiver-profile-1']);
  });

  testWidgets('allows an incomplete draft to be saved', (tester) async {
    final gateway = _FakeCaregiverProfileGateway();
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    final save = find.widgetWithText(
      FilledButton,
      'Сохранить черновик',
      skipOffstage: false,
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(gateway.savedDrafts, hasLength(1));
  });

  testWidgets('updates the loaded rejected profile and submits it again', (
    tester,
  ) async {
    final gateway = _FakeCaregiverProfileGateway(
      loadedRecord: const CaregiverProfileRecord(
        id: 'rejected-profile',
        status: CaregiverProfileStatus.rejected,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await _fillRequiredFields(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final skill = find.widgetWithText(FilterChip, 'Уход при деменции');
    await tester.ensureVisible(skill);
    await tester.tap(skill);
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(
      OutlinedButton,
      'Отправить на модерацию',
      skipOffstage: false,
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(gateway.existingProfileIds, ['rejected-profile']);
    expect(gateway.submittedProfileId, 'rejected-profile');
  });
}

Future<void> _fillRequiredFields(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('ФИО')), 'Ирина Петрова');
  await tester.enterText(find.byKey(const ValueKey('Город')), 'Челябинск');
  await tester.enterText(find.byKey(const ValueKey('Телефон')), '+799****0000');
  await tester.enterText(
    find.byKey(const ValueKey('Опыт работы')),
    '5 лет работы сиделкой',
  );
  final schedule = find.byKey(const ValueKey('График'), skipOffstage: false);
  await tester.ensureVisible(schedule);
  await tester.enterText(schedule, 'Дневные смены');
  final description = find.byKey(const ValueKey('О себе'), skipOffstage: false);
  await tester.ensureVisible(description);
  await tester.enterText(description, 'Организую уход и быт.');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _selectSkillAndSave(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -600));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilterChip, 'Уход при деменции'));
  await tester.tap(
    find.widgetWithText(
      FilledButton,
      'Сохранить черновик',
      skipOffstage: false,
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeCaregiverProfileGateway implements CaregiverProfileGateway {
  _FakeCaregiverProfileGateway({this.loadedRecord});

  CaregiverProfileDraft? savedDraft;
  final List<CaregiverProfileDraft> savedDrafts = [];
  final List<String?> existingProfileIds = [];
  final CaregiverProfileRecord? loadedRecord;
  String? submittedProfileId;

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() async => loadedRecord;

  @override
  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  }) async {
    savedDraft = draft;
    savedDrafts.add(draft);
    existingProfileIds.add(existingProfileId);
    return CaregiverProfileRecord(
      id: existingProfileId ?? 'caregiver-profile-1',
      status: loadedRecord?.status ?? CaregiverProfileStatus.draft,
    );
  }

  @override
  Future<void> submitForReview(String caregiverProfileId) async {
    submittedProfileId = caregiverProfileId;
  }
}
