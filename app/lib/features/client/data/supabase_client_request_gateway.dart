import 'package:care_platform_app/features/client/domain/client_request.dart';
import 'package:care_platform_app/features/client/domain/client_request_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientRequestGateway implements ClientRequestGateway {
  SupabaseClientRequestGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ClientRequestRecord> create(ClientRequestDraft request) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Требуется авторизованный пользователь.');
    }
    final row = await _client
        .from('client_requests')
        .insert({...request.toWritePayload(), 'profile_id': userId})
        .select('id')
        .single();
    return ClientRequestRecord(id: row['id'] as String);
  }
}
