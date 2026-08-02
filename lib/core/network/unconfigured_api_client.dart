import '../error/app_exception.dart';
import '../json/json_utils.dart';
import 'api_client.dart';

/// The [ApiClient] this build ships with — one that cannot reach anything.
///
/// **This is deliberate, and it is not a stub that pretends.** There is no HTTP
/// package in `pubspec.yaml` yet, and adding one is a decision about
/// dependencies rather than about architecture. What §12 asks for is that the
/// REST path *exists end to end*: every service has an API implementation,
/// every binding is conditional, and switching over produces a clear failure
/// rather than a silent fallback to demo data.
///
/// So every method throws [NetworkException] — the same type the real adapter
/// will throw when the device is offline, which is what makes the two paths
/// interchangeable from the state layer's point of view (§12 rule 5). The
/// message names the base URL, because the failure mode this guards against is
/// somebody running with `AK_DATA_SOURCE=api` against an environment whose
/// `apiBaseUrl` still points at localhost and concluding the API is down.
///
/// Phase 2 replaces this with a Dio/http adapter and changes nothing else:
/// [apiClientProvider] is the only place that names it.
class UnconfiguredApiClient implements ApiClient {
  const UnconfiguredApiClient({required this.baseUrl});

  /// Echoed into the failure so the message says *what* could not be reached.
  final String baseUrl;

  Never _unreachable(String method, String path) => throw NetworkException(
        'No HTTP adapter is wired into this build, so $method $baseUrl$path '
        'could not be sent. Register a real ApiClient in '
        'lib/di/providers.dart (apiClientProvider), or run without '
        '--dart-define=AK_DATA_SOURCE=api to use the mock data source.',
      );

  @override
  Future<JsonMap> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _unreachable('GET', path);

  @override
  Future<JsonMap> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _unreachable('POST', path);

  @override
  Future<JsonMap> put(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _unreachable('PUT', path);

  @override
  Future<JsonMap> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _unreachable('PATCH', path);

  @override
  Future<JsonMap> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _unreachable('DELETE', path);

  @override
  Future<List<JsonMap>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _unreachable('GET', path);
}
