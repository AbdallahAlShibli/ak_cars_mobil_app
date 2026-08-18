import 'dart:async';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/chat_hub.dart';
import '../../models/chat_message.dart';
import '../chat_service.dart';

/// The customer ↔ provider thread over REST + SignalR (§chat).
///
/// REST is the whole truth; the hub is a delivery optimisation, and a client
/// that misses a frame catches up on the next [fetchMessages]. While the hub
/// is disconnected, [awaitProviderReply] falls back to polling the REST
/// endpoint — never leaving the screen with no path to new messages — starting
/// at [_minPollInterval] and backing off to [_maxPollInterval] the longer the
/// hub stays down, so a slow reply doesn't cost 60 requests over the full
/// [_replyTimeout] window. Each tick also retries the hub join, so a
/// transient drop can heal mid-wait instead of polling for the rest of it.
class ApiChatService implements ChatService {
  const ApiChatService(this._client, this._hub);

  final ApiClient _client;
  final ChatHub _hub;

  static const _minPollInterval = Duration(seconds: 5);
  static const _maxPollInterval = Duration(seconds: 30);
  static const _replyTimeout = Duration(minutes: 5);

  @override
  Future<List<ChatMessage>> fetchMessages(String threadId) async =>
      (await _client.getList(ApiEndpoints.chatThreadMessages(threadId)))
          .map(ChatMessage.fromJson)
          .toList();

  @override
  Future<ChatMessage> sendMessage(String threadId, String text) async =>
      ChatMessage.fromJson(
        await _client.post(
          ApiEndpoints.chatThreadMessages(threadId),
          body: {'text': text},
        ),
      );

  @override
  Future<ChatMessage> awaitProviderReply(
    String threadId, {
    // Ignored: it existed only for the mock's bilingual canned replies. A
    // real thread carries the sender's own words.
    required bool isArabic,
  }) async {
    await _hub.join(threadId);
    try {
      return await _mergedReplies(threadId).first.timeout(_replyTimeout);
    } finally {
      await _hub.leave(threadId);
    }
  }

  /// Provider replies from the hub (subscribed immediately, so nothing
  /// arriving before the first poll tick is lost) plus a backed-off poll of
  /// the REST endpoint that only does work while the hub is disconnected.
  Stream<ChatMessage> _mergedReplies(String threadId) {
    final controller = StreamController<ChatMessage>();
    final seenIds = <String>{};

    void emit(ChatMessage message) {
      if (!message.fromUser && seenIds.add(message.id)) {
        controller.add(message);
      }
    }

    final hubSubscription = _hub.messages(threadId).listen(emit);

    var interval = _minPollInterval;
    Timer? timer;

    void scheduleNext() {
      if (controller.isClosed) return;
      timer = Timer(interval, () async {
        if (!_hub.isConnected) {
          // Give the hub another chance to (re)connect before paying for a
          // REST round trip — a transient drop shouldn't cost the full
          // backoff window in polling.
          await _hub.join(threadId);
        }
        if (_hub.isConnected) {
          interval = _minPollInterval;
        } else {
          final messages = await fetchMessages(threadId);
          messages.forEach(emit);
          final doubled = interval * 2;
          interval = doubled < _maxPollInterval ? doubled : _maxPollInterval;
        }
        scheduleNext();
      });
    }

    scheduleNext();

    controller.onCancel = () {
      hubSubscription.cancel();
      timer?.cancel();
    };

    return controller.stream;
  }
}
