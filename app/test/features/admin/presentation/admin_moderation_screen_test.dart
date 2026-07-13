import 'dart:async';

import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';
import 'package:care_platform_app/features/admin/presentation/admin_moderation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads pending profiles and approves a profile with a reason', (
    tester,
  ) async {
    final gateway = _FakeAdminModerationGateway();
    await tester.pumpWidget(
      MaterialApp(home: AdminModerationScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ирина Петрова'), findsOneWidget);
    expect(find.text('Челябинск · 7 лет'), findsOneWidget);
    expect(find.text('Телефон: +79990001122'), findsOneWidget);
    expect(find.text('Навыки: Уход при деменции, ЛФК'), findsOneWidget);
    expect(find.text('Сертификаты: Первая помощь'), findsOneWidget);
    expect(find.text('Желаемая оплата: 2500'), findsOneWidget);
    expect(find.text('Район: Центральный'), findsOneWidget);
    expect(find.text('Образование: Медицинский колледж'), findsOneWidget);
    expect(find.text('Фото: https://example.test/irina.jpg'), findsOneWidget);
    expect(find.text('Отправлено: 2026-07-12 10:00'), findsOneWidget);
    expect(find.text('С проживанием: Да'), findsOneWidget);
    expect(find.text('Ночные смены: Да'), findsOneWidget);
    expect(
      find.text(
        'Опыт: деменция — Да; лежачие пациенты — Да; инсульт — Да; инфаркт — Да; травмы — Да',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('moderation-reason-profile-1')),
      'Анкета проверена',
    );
    await tester.tap(find.byKey(const ValueKey('approve-profile-1')));
    await tester.pumpAndSettle();

    expect(gateway.moderationCalls, [
      (
        profileId: 'profile-1',
        status: ModerationStatus.approved,
        reason: 'Анкета проверена',
      ),
    ]);
    expect(find.text('Ирина Петрова'), findsNothing);
    expect(find.text('Анкеты ожидают модерации'), findsOneWidget);
  });

  testWidgets('does not reject a profile without a reason', (tester) async {
    final gateway = _FakeAdminModerationGateway();
    await tester.pumpWidget(
      MaterialApp(home: AdminModerationScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reject-profile-1')));
    await tester.pump();

    expect(find.text('Укажите причину решения'), findsOneWidget);
    expect(gateway.moderationCalls, isEmpty);
  });

  testWidgets('shows loading failure and allows retry', (tester) async {
    final gateway = _FakeAdminModerationGateway(failFirstLoad: true);
    await tester.pumpWidget(
      MaterialApp(home: AdminModerationScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить анкеты'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(gateway.loadCalls, 2);
    expect(find.text('Ирина Петрова'), findsOneWidget);
  });

  testWidgets('loads the next moderation page on demand', (tester) async {
    final gateway = _FakeAdminModerationGateway(
      pages: [
        PendingCaregiverProfilesPage(
          items: [_firstProfile],
          hasMore: true,
          nextCursor: PendingCaregiverCursor(
            submittedAt: DateTime.utc(2026, 7, 12, 10),
            id: 'profile-1',
          ),
        ),
        PendingCaregiverProfilesPage(items: [_secondProfile], hasMore: false),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminModerationScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    final loadMoreButton = find.widgetWithText(OutlinedButton, 'Загрузить ещё');
    expect(loadMoreButton, findsOneWidget);
    await tester.scrollUntilVisible(
      loadMoreButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(loadMoreButton);
    await tester.pumpAndSettle();

    expect(gateway.cursorRequests, [null, _firstProfile.cursor]);
    expect(find.text('Ирина Петрова'), findsOneWidget);
    expect(find.text('Ольга Смирнова'), findsOneWidget);
  });

  testWidgets(
    'reloads the first page after moderation instead of claiming empty',
    (tester) async {
      final gateway = _FakeAdminModerationGateway(
        pages: [
          PendingCaregiverProfilesPage(items: [_firstProfile], hasMore: true),
          PendingCaregiverProfilesPage(items: [_secondProfile], hasMore: false),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: AdminModerationScreen(gateway: gateway)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('moderation-reason-profile-1')),
        'Анкета проверена',
      );
      await tester.tap(find.byKey(const ValueKey('approve-profile-1')));
      await tester.pumpAndSettle();

      expect(gateway.loadCalls, 2);
      expect(gateway.cursorRequests, [null, null]);
      expect(find.text('Ольга Смирнова'), findsOneWidget);
      expect(find.text('Анкеты ожидают модерации'), findsNothing);
    },
  );

  testWidgets('ignores stale load-more results after moderation reset', (
    tester,
  ) async {
    final gateway = _RacingGateway();
    await tester.pumpWidget(
      MaterialApp(home: AdminModerationScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('moderation-reason-profile-1')),
      'Проверено',
    );
    final loadMore = find.widgetWithText(OutlinedButton, 'Загрузить ещё');
    await tester.scrollUntilVisible(
      loadMore,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<OutlinedButton>(loadMore).onPressed!.call();
    await tester.pump();

    final approve = find.byKey(
      const ValueKey('approve-profile-1'),
      skipOffstage: false,
    );
    tester.widget<FilledButton>(approve).onPressed!.call();
    await tester.pump();
    await tester.pump();

    gateway.completeStale(
      PendingCaregiverProfilesPage(items: [_firstProfile], hasMore: false),
    );
    await tester.pumpAndSettle();

    expect(gateway.loadCalls, 3);
    expect(find.text('Ольга Смирнова'), findsOneWidget);
    expect(find.text('Ирина Петрова'), findsNothing);
  });
}

class _RacingGateway implements AdminModerationGateway {
  final _stalePage = Completer<PendingCaregiverProfilesPage>();
  int loadCalls = 0;

  void completeStale(PendingCaregiverProfilesPage page) =>
      _stalePage.complete(page);

  @override
  Future<PendingCaregiverProfilesPage> loadPending({
    PendingCaregiverCursor? cursor,
    required int pageSize,
  }) {
    loadCalls++;
    if (loadCalls == 1) {
      return Future.value(
        PendingCaregiverProfilesPage(
          items: [_firstProfile],
          hasMore: true,
          nextCursor: _firstProfile.cursor,
        ),
      );
    }
    if (loadCalls == 2) return _stalePage.future;
    return Future.value(
      PendingCaregiverProfilesPage(items: [_secondProfile], hasMore: false),
    );
  }

  @override
  Future<void> moderate({
    required String caregiverProfileId,
    required ModerationStatus newStatus,
    required String reason,
    String? comment,
  }) async {}
}

class _FakeAdminModerationGateway implements AdminModerationGateway {
  _FakeAdminModerationGateway({this.failFirstLoad = false, this.pages});

  final bool failFirstLoad;
  final List<PendingCaregiverProfilesPage>? pages;
  bool _moderated = false;
  int loadCalls = 0;
  final List<PendingCaregiverCursor?> cursorRequests = [];
  final List<({String profileId, ModerationStatus status, String reason})>
  moderationCalls = [];

  @override
  Future<PendingCaregiverProfilesPage> loadPending({
    PendingCaregiverCursor? cursor,
    required int pageSize,
  }) async {
    loadCalls++;
    cursorRequests.add(cursor);
    if (failFirstLoad && loadCalls == 1) throw StateError('offline');
    if (pages case final configuredPages?) {
      final index = loadCalls - 1;
      return configuredPages[index < configuredPages.length
          ? index
          : configuredPages.length - 1];
    }
    return _moderated
        ? const PendingCaregiverProfilesPage(items: [], hasMore: false)
        : PendingCaregiverProfilesPage(items: [_firstProfile], hasMore: false);
  }

  @override
  Future<void> moderate({
    required String caregiverProfileId,
    required ModerationStatus newStatus,
    required String reason,
    String? comment,
  }) async {
    _moderated = true;
    moderationCalls.add((
      profileId: caregiverProfileId,
      status: newStatus,
      reason: reason,
    ));
  }
}

final _firstProfile = PendingCaregiverProfile(
  id: 'profile-1',
  fullName: 'Ирина Петрова',
  city: 'Челябинск',
  contactPhone: '+79990001122',
  experience: '7 лет',
  certificates: ['Первая помощь'],
  skills: ['Уход при деменции', 'ЛФК'],
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
  district: 'Центральный',
  education: 'Медицинский колледж',
  photoUrl: 'https://example.test/irina.jpg',
  submittedAt: DateTime.utc(2026, 7, 12, 10),
);

final _secondProfile = PendingCaregiverProfile(
  id: 'profile-2',
  fullName: 'Ольга Смирнова',
  city: 'Миасс',
  contactPhone: '+79990002233',
  experience: '5 лет',
  certificates: [],
  skills: ['Уход'],
  schedule: 'Сутки через двое',
  description: 'Опыт работы в семье',
  desiredPayment: null,
  readyForLiveIn: false,
  readyForNightShifts: false,
  dementiaExperience: false,
  bedriddenExperience: false,
  strokeExperience: false,
  heartAttackExperience: false,
  traumaExperience: false,
  district: null,
  education: null,
  photoUrl: null,
  submittedAt: DateTime.utc(2026, 7, 12, 11),
);
