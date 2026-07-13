import 'dart:async';

import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';
import 'package:care_platform_app/features/caregiver/presentation/caregiver_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hydrates editable controllers and skills from the loaded draft',
    (tester) async {
      final gateway = _Gateway(
        record: const CaregiverProfileRecord(
          id: 'draft-1',
          status: CaregiverProfileStatus.draft,
          draft: _draft,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
      );
      await tester.pumpAndSettle();

      expect(_field(tester, 'ФИО'), 'Ирина Петрова');
      expect(_field(tester, 'Город'), 'Челябинск');
      expect(_field(tester, 'Телефон'), '+79900000000');
      expect(_field(tester, 'Опыт работы'), '5 лет');
      expect(_field(tester, 'График'), 'Дневные смены');
      expect(_field(tester, 'О себе'), 'Организую уход.');
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(
              find.widgetWithText(
                FilterChip,
                'Уход при деменции',
                skipOffstage: false,
              ),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('disables saving while the initial load is unresolved', (
    tester,
  ) async {
    final gateway = _DeferredGateway();
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );

    expect(find.text('Загрузка анкеты…'), findsOneWidget);
    expect(find.text('Сохранить черновик'), findsNothing);
    gateway.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Сохранить черновик'), findsOneWidget);
  });

  testWidgets('preserves loaded optional fields when saving visible edits', (
    tester,
  ) async {
    final gateway = _Gateway(
      record: const CaregiverProfileRecord(
        id: 'draft-1',
        status: CaregiverProfileStatus.draft,
        draft: _draftWithOptionalFields,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('О себе'), skipOffstage: false),
      'Обновлённое описание',
    );
    await tester.tap(find.text('Сохранить черновик'));
    await tester.pumpAndSettle();

    expect(gateway.savedDraft?.description, 'Обновлённое описание');
    expect(gateway.savedDraft?.district, 'Центральный');
    expect(gateway.savedDraft?.education, 'Медицинский колледж');
    expect(gateway.savedDraft?.certificates, ['Первая помощь']);
    expect(gateway.savedDraft?.desiredPayment, 2500);
    expect(gateway.savedDraft?.readyForLiveIn, isTrue);
    expect(gateway.savedDraft?.dementiaExperience, isTrue);
  });

  testWidgets('does not expose edit actions for a moderated profile', (
    tester,
  ) async {
    final gateway = _Gateway(
      record: const CaregiverProfileRecord(
        id: 'approved-1',
        status: CaregiverProfileStatus.approved,
        draft: _draft,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Анкета одобрена и недоступна для редактирования.'),
      findsOneWidget,
    );
    expect(find.text('Сохранить черновик'), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('ФИО'))).enabled,
      isFalse,
    );
  });

  testWidgets('shows load failure, retries, and displays rejection reason', (
    tester,
  ) async {
    final gateway = _RetryGateway();
    await tester.pumpWidget(
      MaterialApp(home: CaregiverProfileScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить анкету'), findsOneWidget);
    expect(find.text('Сохранить черновик'), findsNothing);

    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();

    expect(gateway.loadCalls, 2);
    expect(
      find.text('Причина отклонения: Уточните опыт работы'),
      findsOneWidget,
    );
    expect(find.text('Сохранить черновик'), findsOneWidget);
  });
}

class _RetryGateway implements CaregiverProfileGateway {
  int loadCalls = 0;

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() async {
    loadCalls++;
    if (loadCalls == 1) throw StateError('offline');
    return const CaregiverProfileRecord(
      id: 'rejected-1',
      status: CaregiverProfileStatus.rejected,
      rejectionReason: 'Уточните опыт работы',
      draft: _draft,
    );
  }

  @override
  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  }) async => const CaregiverProfileRecord(
    id: 'rejected-1',
    status: CaregiverProfileStatus.rejected,
  );

  @override
  Future<void> submitForReview(String caregiverProfileId) async {}
}

String _field(WidgetTester tester, String label) => tester
    .widget<TextField>(find.byKey(ValueKey(label), skipOffstage: false))
    .controller!
    .text;

const _draft = CaregiverProfileDraft(
  fullName: 'Ирина Петрова',
  city: 'Челябинск',
  district: '',
  contactPhone: '+79900000000',
  experience: '5 лет',
  education: '',
  certificates: [],
  skills: ['Уход при деменции'],
  schedule: 'Дневные смены',
  description: 'Организую уход.',
  desiredPayment: null,
  readyForLiveIn: false,
  readyForNightShifts: false,
  dementiaExperience: false,
  bedriddenExperience: false,
  strokeExperience: false,
  heartAttackExperience: false,
  traumaExperience: false,
);

const _draftWithOptionalFields = CaregiverProfileDraft(
  fullName: 'Ирина Петрова',
  city: 'Челябинск',
  district: 'Центральный',
  contactPhone: '+799****0000',
  experience: '5 лет',
  education: 'Медицинский колледж',
  certificates: ['Первая помощь'],
  skills: ['Уход при деменции'],
  schedule: 'Дневные смены',
  description: 'Организую уход.',
  desiredPayment: 2500,
  readyForLiveIn: true,
  readyForNightShifts: true,
  dementiaExperience: true,
  bedriddenExperience: true,
  strokeExperience: true,
  heartAttackExperience: true,
  traumaExperience: true,
);

class _Gateway implements CaregiverProfileGateway {
  _Gateway({this.record});
  final CaregiverProfileRecord? record;
  CaregiverProfileDraft? savedDraft;

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() async => record;

  @override
  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  }) async {
    savedDraft = draft;
    return CaregiverProfileRecord(
      id: existingProfileId ?? 'new',
      status: CaregiverProfileStatus.draft,
      draft: draft,
    );
  }

  @override
  Future<void> submitForReview(String caregiverProfileId) async {}
}

class _DeferredGateway extends _Gateway {
  final _completer = Completer<CaregiverProfileRecord?>();

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() => _completer.future;

  void complete(CaregiverProfileRecord? record) => _completer.complete(record);
}
