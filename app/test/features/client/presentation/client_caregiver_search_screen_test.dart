import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';
import 'package:care_platform_app/features/client/presentation/client_caregiver_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the first approved caregiver page for the selected city', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
    final gateway = _FakeCaregiverSearchGateway(
      pages: [
        CaregiverSearchPage(
          items: [
            CaregiverSearchCard(
              id: 'caregiver-1',
              fullName: 'Ирина Петрова',
              city: 'Челябинск',
              experience: '7 лет',
              schedule: 'Дневные смены',
              description: 'Опыт ухода при деменции',
              contactPhone: '+799****1122',
              approvedAt: DateTime.utc(2026, 7, 12, 10),
            ),
          ],
          hasMore: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientCaregiverSearchScreen(
          gateway: gateway,
          onLeaveRequest: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('client-search-city')),
      'Челябинск',
    );
    await tester.tap(find.text('Найти сиделку'));
    await tester.pumpAndSettle();

    expect(gateway.calls, [(city: 'Челябинск', cursor: null, pageSize: 20)]);
    expect(find.text('Ирина Петрова'), findsOneWidget);
    expect(find.text('Опыт: 7 лет'), findsOneWidget);
    expect(find.text('Дневные смены'), findsOneWidget);
    expect(find.text('Связаться: +799****1122'), findsOneWidget);
    await tester.tap(find.byTooltip('Скопировать телефон'));
    await tester.pump();
    expect(find.text('Телефон скопирован'), findsOneWidget);
  });

  testWidgets('offers a client request when no caregivers are available', (
    tester,
  ) async {
    var leaveRequestCalls = 0;
    final gateway = _FakeCaregiverSearchGateway(
      pages: const [CaregiverSearchPage(items: [], hasMore: false)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientCaregiverSearchScreen(
          gateway: gateway,
          onLeaveRequest: () => leaveRequestCalls++,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-search-city')),
      'Миасс',
    );
    await tester.tap(find.text('Найти сиделку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оставить заявку'));

    expect(find.text('По вашему запросу сиделок пока нет'), findsOneWidget);
    expect(leaveRequestCalls, 1);
  });

  testWidgets('loads the next caregiver page using a stable cursor', (
    tester,
  ) async {
    final firstCursor = CaregiverSearchCursor(
      approvedAt: DateTime.utc(2026, 7, 12, 10),
      id: 'caregiver-1',
    );
    final gateway = _FakeCaregiverSearchGateway(
      pages: [
        CaregiverSearchPage(
          items: [
            CaregiverSearchCard(
              id: 'caregiver-1',
              fullName: 'Ирина Петрова',
              city: 'Челябинск',
              experience: '7 лет',
              schedule: 'Дневные смены',
              description: 'Первая анкета',
              approvedAt: DateTime.utc(2026, 7, 12, 10),
            ),
          ],
          hasMore: true,
          nextCursor: firstCursor,
        ),
        CaregiverSearchPage(
          items: [
            CaregiverSearchCard(
              id: 'caregiver-2',
              fullName: 'Ольга Смирнова',
              city: 'Челябинск',
              experience: '5 лет',
              schedule: 'Ночные смены',
              description: 'Вторая анкета',
              contactPhone: '+799****2233',
              approvedAt: DateTime.utc(2026, 7, 11, 10),
            ),
          ],
          hasMore: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientCaregiverSearchScreen(
          gateway: gateway,
          onLeaveRequest: () {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('client-search-city')),
      'Челябинск',
    );
    await tester.tap(find.text('Найти сиделку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать ещё'));
    await tester.pumpAndSettle();

    expect(gateway.calls, [
      (city: 'Челябинск', cursor: null, pageSize: 20),
      (city: 'Челябинск', cursor: firstCursor, pageSize: 20),
    ]);
    expect(find.text('Ирина Петрова'), findsOneWidget);
    expect(find.text('Ольга Смирнова'), findsOneWidget);
    expect(find.text('Показать ещё'), findsNothing);
  });

  testWidgets('clears stale results and cursor when a new search fails', (
    tester,
  ) async {
    final gateway = _SearchSequenceGateway([
      CaregiverSearchPage(
        items: [
          CaregiverSearchCard(
            id: 'caregiver-a',
            fullName: 'Сиделка из города A',
            city: 'Город A',
            experience: '5 лет',
            schedule: 'Днём',
            description: 'Описание',
            approvedAt: DateTime.utc(2026, 7, 12, 10),
          ),
        ],
        hasMore: true,
        nextCursor: CaregiverSearchCursor(
          approvedAt: DateTime.utc(2026, 7, 12, 10),
          id: 'caregiver-a',
        ),
      ),
      StateError('offline'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ClientCaregiverSearchScreen(
          gateway: gateway,
          onLeaveRequest: () {},
        ),
      ),
    );
    final cityField = find.byKey(const ValueKey('client-search-city'));
    await tester.enterText(cityField, 'Город A');
    await tester.tap(find.text('Найти сиделку'));
    await tester.pumpAndSettle();
    expect(find.text('Сиделка из города A'), findsOneWidget);

    await tester.enterText(cityField, 'Город B');
    await tester.tap(find.text('Найти сиделку'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить анкеты'), findsOneWidget);
    expect(find.text('Сиделка из города A'), findsNothing);
    expect(find.text('Показать ещё'), findsNothing);
    expect(gateway.calls.last.cursor, isNull);
  });
}

class _SearchSequenceGateway implements CaregiverSearchGateway {
  _SearchSequenceGateway(this.responses);

  final List<Object> responses;
  final List<({String city, CaregiverSearchCursor? cursor, int pageSize})>
  calls = [];

  @override
  Future<CaregiverSearchPage> loadApproved({
    required String city,
    CaregiverSearchCursor? cursor,
    required int pageSize,
  }) async {
    calls.add((city: city, cursor: cursor, pageSize: pageSize));
    final response = responses[calls.length - 1];
    if (response is CaregiverSearchPage) return response;
    throw response;
  }
}

class _FakeCaregiverSearchGateway implements CaregiverSearchGateway {
  _FakeCaregiverSearchGateway({required this.pages});

  final List<CaregiverSearchPage> pages;
  final List<({String city, CaregiverSearchCursor? cursor, int pageSize})>
  calls = [];

  @override
  Future<CaregiverSearchPage> loadApproved({
    required String city,
    CaregiverSearchCursor? cursor,
    required int pageSize,
  }) async {
    calls.add((city: city, cursor: cursor, pageSize: pageSize));
    return pages[calls.length - 1];
  }
}
