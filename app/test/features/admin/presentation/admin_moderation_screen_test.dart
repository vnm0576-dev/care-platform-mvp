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
}

class _FakeAdminModerationGateway implements AdminModerationGateway {
  _FakeAdminModerationGateway({this.failFirstLoad = false});

  final bool failFirstLoad;
  int loadCalls = 0;
  final List<({String profileId, ModerationStatus status, String reason})>
  moderationCalls = [];

  @override
  Future<List<PendingCaregiverProfile>> loadPending() async {
    loadCalls++;
    if (failFirstLoad && loadCalls == 1) throw StateError('offline');
    return const [
      PendingCaregiverProfile(
        id: 'profile-1',
        fullName: 'Ирина Петрова',
        city: 'Челябинск',
        experience: '7 лет',
        schedule: 'Дневные смены',
        description: 'Опыт ухода при деменции',
      ),
    ];
  }

  @override
  Future<void> moderate({
    required String caregiverProfileId,
    required ModerationStatus newStatus,
    required String reason,
    String? comment,
  }) async {
    moderationCalls.add((
      profileId: caregiverProfileId,
      status: newStatus,
      reason: reason,
    ));
  }
}
