import '../models/chat_message.dart';
import '../services/chat_service.dart';

/// The per-request customer ↔ provider thread.
abstract interface class ChatRepository {
  Future<List<ChatMessage>> fetchMessages(String threadId);

  Future<ChatMessage> sendMessage(String threadId, String text);

  /// Completes with the provider's next message on this thread.
  Future<ChatMessage> awaitProviderReply(
    String threadId, {
    required bool isArabic,
  });
}

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._service);

  final ChatService _service;

  @override
  Future<List<ChatMessage>> fetchMessages(String threadId) =>
      _service.fetchMessages(threadId);

  @override
  Future<ChatMessage> sendMessage(String threadId, String text) =>
      _service.sendMessage(threadId, text);

  @override
  Future<ChatMessage> awaitProviderReply(
    String threadId, {
    required bool isArabic,
  }) =>
      _service.awaitProviderReply(threadId, isArabic: isArabic);
}
