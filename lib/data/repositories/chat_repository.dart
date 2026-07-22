import '../models/chat_message.dart';
import '../services/chat_service.dart';

/// The per-request customer ↔ provider thread.
abstract interface class ChatRepository {
  Future<List<ChatMessage>> fetchMessages(String requestId);

  Future<ChatMessage> sendMessage(String requestId, String text);

  /// Completes with the provider's next message on this thread.
  Future<ChatMessage> awaitProviderReply(
    String requestId, {
    required bool isArabic,
  });
}

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._service);

  final ChatService _service;

  @override
  Future<List<ChatMessage>> fetchMessages(String requestId) =>
      _service.fetchMessages(requestId);

  @override
  Future<ChatMessage> sendMessage(String requestId, String text) =>
      _service.sendMessage(requestId, text);

  @override
  Future<ChatMessage> awaitProviderReply(
    String requestId, {
    required bool isArabic,
  }) =>
      _service.awaitProviderReply(requestId, isArabic: isArabic);
}
