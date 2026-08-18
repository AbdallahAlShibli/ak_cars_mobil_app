import 'dart:async';
import 'dart:developer' as developer;

import 'package:signalr_netcore/signalr_client.dart';

import '../../config/app_config.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/token_store.dart';
import '../json/json_utils.dart';

/// The real-time delivery optimisation over `/hubs/chat` (spec §chat).
///
/// The REST routes in [ApiChatService] are the whole truth; this hub only
/// shortens the wait for a reply. A client that misses a frame catches up on
/// the next `GET /chat/threads/{id}/messages` — nothing here is load-bearing
/// on its own, which is why every method swallows its own connection errors
/// rather than surfacing them to the screen.
class ChatHub {
  ChatHub({required AppConfig config, required this._tokens}) {
    _connection = HubConnectionBuilder()
        .withUrl(
          '${config.apiBaseUrl}/hubs/chat',
          options: HttpConnectionOptions(
            // `tryRead…`: an unreadable store yields the same empty string a
            // signed-out user gets, so the handshake fails as an ordinary
            // unauthorized connection — which this class already swallows —
            // rather than throwing out of the token factory.
            accessTokenFactory: () async =>
                await _tokens.tryReadAccessToken() ?? '',
          ),
        )
        .build();
    _connection.on('ReceiveMessage', _onReceiveMessage);
  }

  final TokenStore _tokens;
  late final HubConnection _connection;

  final Map<String, StreamController<ChatMessage>> _threadControllers = {};

  bool get isConnected =>
      _connection.state == HubConnectionState.Connected;

  Future<void> _ensureStarted() async {
    if (_connection.state == HubConnectionState.Disconnected) {
      try {
        await _connection.start();
      } catch (error, stack) {
        developer.log(
          'SignalR chat hub failed to connect — falling back to polling',
          name: 'ChatHub',
          error: error,
          stackTrace: stack,
        );
      }
    }
  }

  void _onReceiveMessage(List<Object?>? arguments) {
    if (arguments == null || arguments.length < 2) return;
    final threadId = arguments[0]?.toString();
    final payload = arguments[1];
    if (threadId == null || payload is! Map) return;
    final message = ChatMessage.fromJson(JsonMap.from(payload));
    _threadControllers[threadId]?.add(message);
  }

  Future<void> join(String threadId) async {
    await _ensureStarted();
    if (!isConnected) return;
    try {
      await _connection.invoke('JoinThread', args: [threadId]);
    } catch (error, stack) {
      developer.log(
        'JoinThread failed',
        name: 'ChatHub',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> leave(String threadId) async {
    if (!isConnected) return;
    try {
      await _connection.invoke('LeaveThread', args: [threadId]);
    } catch (_) {
      // Best-effort — the server also times out idle memberships on its own.
    }
  }

  /// Messages received on [threadId] since this call. Callers own the
  /// subscription's lifetime and should cancel it when the thread screen
  /// closes.
  Stream<ChatMessage> messages(String threadId) => _threadControllers
      .putIfAbsent(threadId, () => StreamController<ChatMessage>.broadcast())
      .stream;
}
