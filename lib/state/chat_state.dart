import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_message.dart';
import '../di/providers.dart';

/// Per-request chat threads, keyed by request id.
class ChatNotifier extends Notifier<Map<String, List<ChatMessage>>> {
  @override
  Map<String, List<ChatMessage>> build() => const {};

  /// Sends the customer's message and mirrors it into the thread.
  Future<void> send(String requestId, String text) async {
    final message =
        await ref.read(chatRepositoryProvider).sendMessage(requestId, text);
    _append(requestId, message);
  }

  /// Waits for the provider's next reply and appends it.
  ///
  /// The screen awaits this to drive its "typing…" indicator, so the swap to
  /// a real socket subscription needs no change above this line.
  Future<void> awaitProviderReply(
    String requestId, {
    required bool isArabic,
  }) async {
    final reply = await ref
        .read(chatRepositoryProvider)
        .awaitProviderReply(requestId, isArabic: isArabic);
    _append(requestId, reply);
  }

  void _append(String requestId, ChatMessage message) {
    state = {
      ...state,
      requestId: [...(state[requestId] ?? const []), message],
    };
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, Map<String, List<ChatMessage>>>(
        ChatNotifier.new);
