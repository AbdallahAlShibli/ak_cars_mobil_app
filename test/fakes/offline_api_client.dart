import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/json/json_utils.dart';
import 'package:ak_cars_mobil_app/core/network/api_client.dart';
import 'package:ak_cars_mobil_app/core/push/push_service.dart';

/// An [ApiClient] that refuses every call, immediately.
///
/// The app binds `DioApiClient` unconditionally now, so without this a widget
/// test would open real sockets to `https://localhost:7291`. That is not a
/// theoretical objection: it is what made the suite hang. Dio arms a
/// connect/receive timeout timer per request, `pumpAndSettle` waits for the
/// timer queue to drain, and the test sat there until its own ten-minute
/// deadline fired.
///
/// It throws rather than returning empty so a service the harness forgot to
/// double fails loudly at the call site, naming itself — the same reasoning
/// the app's own "no silent fallback" rule is built on.
class OfflineApiClient implements ApiClient {
  const OfflineApiClient();

  Never _refuse(String method, String path) => throw NetworkException(
        'OfflineApiClient refused $method $path. A test reached the network: '
        'override the service it belongs to in fakeServiceOverrides().',
      );

  @override
  Future<JsonMap> get(String path,
          {Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('GET', path);

  @override
  Future<JsonMap> post(String path,
          {Object? body,
          Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('POST', path);

  @override
  Future<JsonMap> put(String path,
          {Object? body,
          Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('PUT', path);

  @override
  Future<JsonMap> patch(String path,
          {Object? body,
          Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('PATCH', path);

  @override
  Future<JsonMap> delete(String path,
          {Object? body,
          Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('DELETE', path);

  @override
  Future<List<JsonMap>> getList(String path,
          {Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('GET', path);

  @override
  Future<List<JsonMap>> postList(String path,
          {Object? body,
          Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('POST', path);

  @override
  Future<List<JsonMap>> putList(String path,
          {Object? body,
          Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('PUT', path);

  @override
  Future<List<JsonMap>> deleteList(String path,
          {Object? body,
          Map<String, dynamic>? queryParameters,
          Map<String, String>? headers}) async =>
      _refuse('DELETE', path);
}

/// A [PushService] that never opens a connection.
///
/// `NotificationsNotifier.build` subscribes to `dataMessages()` and
/// `connections()` on every launch and `AkCarsApp` calls `start()`, so every
/// widget test builds one. The real service would dial
/// `/hubs/notifications` and initialise the local-notifications plugin, which
/// has no platform side under `flutter_tester`.
class SilentPushService implements PushService {
  const SilentPushService();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<Map<String, dynamic>> dataMessages() => const Stream.empty();

  @override
  Stream<void> connections() => const Stream.empty();

  @override
  Stream<String?> openedRoutes() => const Stream.empty();
}
