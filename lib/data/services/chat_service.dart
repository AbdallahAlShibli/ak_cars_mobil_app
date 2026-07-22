import '../../config/app_config.dart';
import '../datasources/mock/mock_chat_data.dart';
import '../models/chat_message.dart';
import 'mock_service_base.dart';

/// The customer ↔ provider thread attached to a service request.
///
/// Phase 2: implement `RestChatService` against `/chat/requests/{id}`, backed
/// by a websocket/SignalR subscription. [awaitProviderReply] is deliberately
/// shaped as "resolve when the provider next replies" so that swap does not
/// change the screen: today a canned answer completes it, tomorrow an
/// inbound socket frame does.
abstract interface class ChatService {
  Future<List<ChatMessage>> fetchMessages(String requestId);

  Future<ChatMessage> sendMessage(String requestId, String text);

  /// Completes with the provider's next message on this thread.
  ///
  /// [isArabic] exists only for the staging build, whose canned replies are
  /// bilingual. A real thread carries the sender's own words and ignores it.
  Future<ChatMessage> awaitProviderReply(
    String requestId, {
    required bool isArabic,
  });
}

class MockChatService with MockServiceBase implements ChatService {
  MockChatService({required this.config});

  @override
  final AppConfig config;

  final Map<String, List<ChatMessage>> _threads = {};

  /// Rotates through the canned replies per thread.
  final Map<String, int> _replyCursors = {};

  @override
  Future<List<ChatMessage>> fetchMessages(String requestId) =>
      respond(List<ChatMessage>.unmodifiable(_threads[requestId] ?? const []));

  @override
  Future<ChatMessage> sendMessage(String requestId, String text) =>
      respond(_append(requestId, fromUser: true, text: text));

  @override
  Future<ChatMessage> awaitProviderReply(
    String requestId, {
    required bool isArabic,
  }) async {
    await Future<void>.delayed(MockChatData.replyDelay);

    final cursor = _replyCursors[requestId] ?? 0;
    _replyCursors[requestId] = cursor + 1;
    final reply = MockChatData.providerReplies[
        cursor % MockChatData.providerReplies.length];

    return _append(
      requestId,
      fromUser: false,
      text: isArabic ? reply.ar : reply.en,
    );
  }

  ChatMessage _append(
    String requestId, {
    required bool fromUser,
    required String text,
  }) {
    final message = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fromUser: fromUser,
      text: text,
      time: DateTime.now(),
    );
    _threads.putIfAbsent(requestId, () => []).add(message);
    return message;
  }
}
