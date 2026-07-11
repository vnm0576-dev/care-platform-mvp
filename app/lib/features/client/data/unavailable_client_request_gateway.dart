import 'package:care_platform_app/features/client/domain/client_request.dart';
import 'package:care_platform_app/features/client/domain/client_request_gateway.dart';

class UnavailableClientRequestGateway implements ClientRequestGateway {
  const UnavailableClientRequestGateway();

  @override
  Future<ClientRequestRecord> create(ClientRequestDraft request) {
    throw StateError('Supabase is not configured');
  }
}
