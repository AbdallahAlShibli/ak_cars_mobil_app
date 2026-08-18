import '../models/chat_message.dart';

// `providerThreadId` / `isProviderThread` come from `chat_message.dart`.

/// The customer ↔ provider thread attached to a service request.
///
/// Phase 2: implement `RestChatService` against `/chat/requests/{id}`, backed
/// by a websocket/SignalR subscription. [awaitProviderReply] is deliberately
/// shaped as "resolve when the provider next replies" so that swap does not
/// change the screen: today a canned answer completes it, tomorrow an
/// inbound socket frame does.
abstract interface class ChatService {
  Future<List<ChatMessage>> fetchMessages(String threadId);

  Future<ChatMessage> sendMessage(String threadId, String text);

  /// Completes with the provider's next message on this thread.
  ///
  /// [isArabic] exists only for the staging build, whose canned replies are
  /// bilingual. A real thread carries the sender's own words and ignores it.
  Future<ChatMessage> awaitProviderReply(
    String threadId, {
    required bool isArabic,
  });
}
