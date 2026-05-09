import '../../core/network/api_client.dart';
import '../models/chat_model.dart';

class ChatRepository {
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/chat',
        data: {
          'message': message,
          'history': history.map((m) => m.toJson()).toList(),
        },
      );
      return response.data['reply'] as String;
    } catch (e) {
      throw Exception('Asistan şu an yanıt veremiyor. Lütfen tekrar dene.');
    }
  }
}
