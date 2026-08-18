import 'package:ak_cars_mobil_app/data/models/chat_message.dart';
import 'package:ak_cars_mobil_app/data/services/chat_service.dart';

import 'data/mock_chat_data.dart';
import 'fake_service_base.dart';

class MockChatService with MockServiceBase implements ChatService {
  final Map<String, List<ChatMessage>> _threads = {};

  /// Rotates through the canned replies per thread.
  final Map<String, int> _replyCursors = {};

  @override
  Future<List<ChatMessage>> fetchMessages(String threadId) =>
      respond(List<ChatMessage>.unmodifiable(_threads[threadId] ?? const []));

  @override
  Future<ChatMessage> sendMessage(String threadId, String text) =>
      respond(_append(threadId, fromUser: true, text: text));

  @override
  Future<ChatMessage> awaitProviderReply(
    String threadId, {
    required bool isArabic,
  }) async {
    await Future<void>.delayed(MockChatData.replyDelay);

    final cursor = _replyCursors[threadId] ?? 0;
    _replyCursors[threadId] = cursor + 1;
    // An enquiry thread has no booking behind it, so it gets answers that do
    // not claim one.
    final replies = isProviderThread(threadId)
        ? MockChatData.enquiryReplies
        : MockChatData.providerReplies;
    final reply = replies[cursor % replies.length];

    return _append(
      threadId,
      fromUser: false,
      text: isArabic ? reply.ar : reply.en,
    );
  }

  ChatMessage _append(
    String threadId, {
    required bool fromUser,
    required String text,
  }) {
    final message = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fromUser: fromUser,
      text: text,
      time: DateTime.now(),
    );
    _threads.putIfAbsent(threadId, () => []).add(message);
    return message;
  }
}
