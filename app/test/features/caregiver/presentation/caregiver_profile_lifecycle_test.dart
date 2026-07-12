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

class _Gateway implements CaregiverProfileGateway {
  _Gateway({this.record});
  final CaregiverProfileRecord? record;

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() async => record;

  @override
  Future<CaregiverProfileRecord> saveDraft({
    required CaregiverProfileDraft draft,
    String? existingProfileId,
  }) async => CaregiverProfileRecord(
    id: existingProfileId ?? 'new',
    status: CaregiverProfileStatus.draft,
    draft: draft,
  );

  @override
  Future<void> submitForReview(String caregiverProfileId) async {}
}

class _DeferredGateway extends _Gateway {
  final _completer = Completer<CaregiverProfileRecord?>();

  @override
  Future<CaregiverProfileRecord?> loadOwnProfile() => _completer.future;

  void complete(CaregiverProfileRecord? record) => _completer.complete(record);
}
