import 'package:care_platform_app/features/client/domain/client_request.dart';

abstract interface class ClientRequestGateway {
  Future<ClientRequestRecord> create(ClientRequestDraft request);
}

class ClientRequestRecord {
  const ClientRequestRecord({required this.id});

  final String id;
}
