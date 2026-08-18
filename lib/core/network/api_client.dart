import '../json/json_utils.dart';

/// Transport contract the REST services will be written against.
///
/// Deliberately **not implemented** in this staging build: there is no HTTP
/// code in the app yet. Declaring the contract now means Phase 2 adds exactly
/// one concrete class (a Dio/http adapter) and the service layer compiles
/// against it unchanged.
///
/// Implementations are responsible for:
///  * prefixing [AppConfig.apiBaseUrl];
///  * attaching the bearer token;
///  * applying connect/receive timeouts;
///  * translating transport and non-2xx responses into `AppException`s.
///
/// They must never leak a package-specific error type to callers.
abstract interface class ApiClient {
  Future<JsonMap> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  Future<JsonMap> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  Future<JsonMap> put(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  Future<JsonMap> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  Future<JsonMap> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  /// Endpoints that answer with a top-level JSON array rather than an object.
  Future<List<JsonMap>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  /// `POST` routes that answer with a top-level JSON array rather than an
  /// object — e.g. `POST /user/vehicles/{id}/primary` and
  /// `POST /notifications/read`, both of which return the whole updated
  /// collection rather than the single record the verb might suggest.
  Future<List<JsonMap>> postList(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });
}
