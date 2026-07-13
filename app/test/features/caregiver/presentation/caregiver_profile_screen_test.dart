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
  await _enterField(tester, 'ФИО', 'Ирина Петрова');
  await _enterField(tester, 'Город', 'Челябинск');
  await _enterField(tester, 'Телефон', '+799****0000');
  await _enterField(tester, 'Опыт работы', '5 лет работы сиделкой');
  await _enterField(tester, 'График', 'Дневные смены');
  await _enterField(tester, 'О себе', 'Организую уход и быт.');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byKey(ValueKey(label), skipOffstage: false);
  await tester.scrollUntilVisible(
    field,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(field, value);
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
