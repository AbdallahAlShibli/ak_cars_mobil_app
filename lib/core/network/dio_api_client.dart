import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../config/app_config.dart';
import '../../core/constants/api_endpoints.dart';
import '../../data/services/token_store.dart';
import '../error/app_exception.dart';
import '../json/json_utils.dart';
import 'api_client.dart';
import 'browser_cors_warning.dart'
    if (dart.library.js_interop) 'browser_cors_warning_web.dart';

/// The real HTTP adapter. The only file in the app that knows Dio exists.
///
/// Responsibilities, and nothing beyond them:
///  1. prefix [AppConfig.apiBaseUrl];
///  2. attach `Authorization: Bearer …` from [TokenStore];
///  3. apply connect/receive timeouts from [AppConfig];
///  4. on a `401`, refresh once and retry the original request, then give up;
///  5. translate every failure into an [AppException], per
///     `docs/api_contract.md`'s error table;
///  6. return [JsonMap] / `List<JsonMap>` and never leak a [DioException].
class DioApiClient implements ApiClient {
  DioApiClient({required AppConfig config, required this._tokens})
      : _baseUrl = config.apiBaseUrl,
        _dio = Dio(
          BaseOptions(
            baseUrl: config.apiBaseUrl,
            connectTimeout: config.connectTimeout,
            receiveTimeout: config.receiveTimeout,
          ),
        ) {
    // The local dev API always redirects http → https (ASP.NET's
    // `UseHttpsRedirection` runs unconditionally, not just outside
    // Development), so dev talks to it over https too — on the ASP.NET
    // Kestrel dev certificate, which is self-signed and not in the device's
    // trust store. Trusting it here is scoped to [AppEnvironment.development]
    // only; staging and production still validate the certificate chain
    // normally, exactly like every other https client.
    // The browser owns TLS trust on web — there is no client-side hook to
    // bypass a self-signed cert, and `_dio.httpClientAdapter` isn't an
    // `IOHttpClientAdapter` there (it's the browser adapter), so the cast
    // itself would throw. Visiting the dev API's origin once in the browser
    // and accepting its certificate warning is the web equivalent of this
    // trust step.
    // Web only, and only noise: every request this client makes carries a
    // JSON body or a bearer token, so Dio warns about a CORS preflight on all
    // of them — with a stack trace each. See [silenceBrowserCorsWarnings].
    silenceBrowserCorsWarnings(_dio);
    if (!kIsWeb && config.environment.isDevelopment) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // `tryRead…`, because a throw here does not stay here: Dio turns an
          // exception out of `onRequest` into a `DioException` with no
          // response, which `_translate` can only read as
          // `DioExceptionType.unknown` and report as "Could not reach
          // <host>" — the network blamed for an unreadable keystore. An
          // unreadable token is treated as no token, which sends the request
          // unauthenticated and lets the server's `401` be the answer.
          final token = await _tokens.tryReadAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final String _baseUrl;
  final TokenStore _tokens;
  final Dio _dio;

  /// Exposed for tests confirming the composition root wires this adapter to
  /// the configured environment's URL.
  String get baseUrl => _baseUrl;

  /// Guards against a stampede of concurrent refreshes when several requests
  /// hit `401` at once — only the first actually calls `/auth/refresh`, the
  /// rest await its result.
  Future<bool>? _refreshing;

  bool _isAuthRoute(String path) =>
      path == ApiEndpoints.login ||
      path == ApiEndpoints.loginVerify ||
      path == ApiEndpoints.register ||
      path == ApiEndpoints.refreshToken;

  Future<Response<dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool isRetry = false,
  }) async {
    try {
      return await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(method: method, headers: headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 &&
          !isRetry &&
          !_isAuthRoute(path) &&
          await _refreshAndSave()) {
        return _send(
          method,
          path,
          body: body,
          queryParameters: queryParameters,
          headers: headers,
          isRetry: true,
        );
      }
      throw _translate(e);
    }
  }

  Future<bool> _refreshAndSave() {
    return _refreshing ??= _doRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _doRefresh() async {
    // Outside the `try`, so it has to be the non-throwing read: an exception
    // here would escape `_refreshAndSave` and surface from inside `_send`'s
    // `on DioException` block, replacing the original `401` with a raw
    // platform error — and leaking a package-specific type to callers, which
    // this class promises never to do.
    final refreshToken = await _tokens.tryReadRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      final json = (response.data as Map).cast<String, dynamic>();
      await _tokens.save(
        access: json.requireString('accessToken'),
        refresh: json.requireString('refreshToken'),
        expiresIn: json.intOr('expiresIn', 3600),
      );
      return true;
    } on DioException {
      await _tokens.tryClear();
      return false;
    } catch (_) {
      // A refresh response the client could not read, or a store that would
      // not take the new pair. The session was not renewed either way, and
      // saying so is all a `bool` can do. Deliberately *not* clearing here:
      // unlike a rejected refresh, none of this proves the stored token is
      // bad, and discarding a good session over a transient storage fault
      // would sign the user out for no reason.
      return false;
    }
  }

  JsonMap _asObject(Response<dynamic> response) {
    final data = response.data;
    if (data is Map) return JsonMap.from(data);
    throw SerializationException(
      'Expected a JSON object from ${response.requestOptions.path}, got '
      '${data.runtimeType}',
    );
  }

  List<JsonMap> _asList(Response<dynamic> response) {
    final data = response.data;
    if (data is List) {
      return data.whereType<Map>().map(JsonMap.from).toList(growable: false);
    }
    throw SerializationException(
      'Expected a JSON array from ${response.requestOptions.path}, got '
      '${data.runtimeType}',
    );
  }

  @override
  Future<JsonMap> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asObject(await _send(
        'GET',
        path,
        queryParameters: queryParameters,
        headers: headers,
      ));

  @override
  Future<JsonMap> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asObject(await _send(
        'POST',
        path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
      ));

  @override
  Future<JsonMap> put(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asObject(await _send(
        'PUT',
        path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
      ));

  @override
  Future<JsonMap> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asObject(await _send(
        'PATCH',
        path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
      ));

  @override
  Future<JsonMap> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asObject(await _send(
        'DELETE',
        path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
      ));

  @override
  Future<List<JsonMap>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asList(await _send(
        'GET',
        path,
        queryParameters: queryParameters,
        headers: headers,
      ));

  @override
  Future<List<JsonMap>> postList(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asList(await _send(
        'POST',
        path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
      ));

  // RFC 9457 `ProblemDetails`. `code` is an extension member and it is the
  // only part we branch on — `title` and `detail` are for humans and logs.
  AppException _translate(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return RequestTimeoutException('$_baseUrl timed out', cause: e);
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return NetworkException('Could not reach $_baseUrl', cause: e);
      default:
        break;
    }

    final status = e.response?.statusCode ?? 0;
    final problem = e.response?.data is Map
        ? (e.response!.data as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final code = problem['code']?.toString();
    final detail = problem['detail']?.toString() ??
        problem['title']?.toString() ??
        'Request failed';

    return switch (status) {
      // The envelope's `code` rides along: a `401` from `/auth/login/verify`
      // carries `otp_invalid_or_expired`, and the login screen has something
      // specific to say about that one. Every other caller ignores it and
      // treats a `401` as "no session", exactly as before.
      401 => UnauthorizedException(detail, code: code, cause: e),
      403 => ForbiddenException(detail, cause: e),
      404 => NotFoundException(detail, cause: e),
      // The rate limiter answers in plain text, not the problem+json every
      // other failure uses, so `detail` here is the useless fallback — the
      // status is the whole message and the type carries it.
      429 => RateLimitedException(
          'Rate limited by $_baseUrl',
          cause: e,
        ),
      // A `409` carrying a code is a business rule like any other — the server
      // refused because of a stable, documented condition
      // (`account_already_exists`, `review_already_exists`), not because the
      // request was malformed. Leaving it in the `ApiException` catch-all made
      // "that phone is already registered" indistinguishable from a 500 at the
      // call site, so the only thing a screen could do with it was fail.
      400 || 409 || 422 when code != null =>
        BusinessRuleException(detail, code: code, cause: e),
      400 || 422 => ValidationException(
          detail,
          fieldErrors: _fieldErrors(problem['errors']),
          cause: e,
        ),
      _ => ApiException(detail, statusCode: status, errorCode: code, cause: e),
    };
  }

  Map<String, List<String>> _fieldErrors(Object? errors) {
    if (errors is! Map) return const {};
    return {
      for (final entry in errors.entries)
        entry.key.toString(): (entry.value is List)
            ? (entry.value as List).map((e) => e.toString()).toList()
            : [entry.value.toString()],
    };
  }
}
