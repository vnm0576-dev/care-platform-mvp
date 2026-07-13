import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';
import 'package:care_platform_app/features/client/presentation/client_caregiver_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the first approved caregiver page for the selected city', (
    tester,
  ) async {
    final gateway = _FakeCaregiverSearchGateway(
      pages: [
        const CaregiverSearchPage(
          items: [
            CaregiverSearchCard(
              id: 'caregiver-1',
              fullName: 'Ирина Петрова',
              city: 'Челябинск',
              experience: '7 лет',
              schedule: 'Дневные смены',
              description: 'Опыт ухода при деменции',
              contactPhone: '+799****1122',
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

    expect(gateway.calls, [(city: 'Челябинск', page: 0, pageSize: 20)]);
    expect(find.text('Ирина Петрова'), findsOneWidget);
    expect(find.text('Опыт: 7 лет'), findsOneWidget);
    expect(find.text('Дневные смены'), findsOneWidget);
    expect(find.text('Связаться: +799****1122'), findsOneWidget);
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

  testWidgets('loads the next caregiver page without repeating the first', (
    tester,
  ) async {
    final gateway = _FakeCaregiverSearchGateway(
      pages: [
        const CaregiverSearchPage(
          items: [
            CaregiverSearchCard(
              id: 'caregiver-1',
              fullName: 'Ирина Петрова',
              city: 'Челябинск',
              experience: '7 лет',
              schedule: 'Дневные смены',
              description: 'Первая анкета',
            ),
          ],
          hasMore: true,
        ),
        const CaregiverSearchPage(
          items: [
            CaregiverSearchCard(
              id: 'caregiver-2',
              fullName: 'Ольга Смирнова',
              city: 'Челябинск',
              experience: '5 лет',
              schedule: 'Ночные смены',
              description: 'Вторая анкета',
              contactPhone: '+799****2233',
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
      (city: 'Челябинск', page: 0, pageSize: 20),
      (city: 'Челябинск', page: 1, pageSize: 20),
    ]);
    expect(find.text('Ирина Петрова'), findsOneWidget);
    expect(find.text('Ольга Смирнова'), findsOneWidget);
    expect(find.text('Показать ещё'), findsNothing);
  });
}

class _FakeCaregiverSearchGateway implements CaregiverSearchGateway {
  _FakeCaregiverSearchGateway({required this.pages});

  final List<CaregiverSearchPage> pages;
  final List<({String city, int page, int pageSize})> calls = [];

  @override
  Future<CaregiverSearchPage> loadApproved({
    required String city,
    required int page,
    required int pageSize,
  }) async {
    calls.add((city: city, page: page, pageSize: pageSize));
    return pages[page];
  }
}
