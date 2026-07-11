import 'package:care_platform_app/features/client/domain/client_request.dart';
import 'package:care_platform_app/features/client/domain/client_request_gateway.dart';
import 'package:care_platform_app/features/client/presentation/client_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves a client request with the required care details', (
    tester,
  ) async {
    final gateway = _FakeClientRequestGateway();

    await tester.pumpWidget(
      MaterialApp(home: ClientRequestScreen(gateway: gateway)),
    );

    expect(find.text('Заявка на подбор сиделки'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('Город')), 'Челябинск');
    await tester.enterText(
      find.byKey(const ValueKey('Тип ухода')),
      'Уход за пожилым человеком',
    );
    await tester.enterText(
      find.byKey(const ValueKey('Описание ситуации')),
      'Нужна сиделка для ежедневной помощи дома.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('Телефон')),
      '+79990000000',
    );

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    final saveButton = find.text('Сохранить заявку', skipOffstage: false);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(gateway.savedRequest?.city, 'Челябинск');
    expect(gateway.savedRequest?.careType, 'Уход за пожилым человеком');
    expect(
      gateway.savedRequest?.description,
      'Нужна сиделка для ежедневной помощи дома.',
    );
    expect(gateway.savedRequest?.contactPhone, isNotEmpty);
    expect(find.text('Заявка сохранена'), findsOneWidget);
  });
}

class _FakeClientRequestGateway implements ClientRequestGateway {
  ClientRequestDraft? savedRequest;

  @override
  Future<ClientRequestRecord> create(ClientRequestDraft request) async {
    savedRequest = request;
    return const ClientRequestRecord(id: 'request-1');
  }
}
