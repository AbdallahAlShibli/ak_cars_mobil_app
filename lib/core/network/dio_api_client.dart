import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

import '../../config/app_config.dart';
import '../../core/constants/api_endpoints.dart';
import '../../data/services/token_store.dart';
import '../error/app_exception.dart';
import '../json/json_utils.dart';
import '../utils/jwt_claims.dart';
import 'api_client.dart';
import 'app_signer.dart';
import 'network_activity.dart';
import 'response_cache.dart';
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
  DioApiClient({
    required AppConfig config,
    required this._tokens,
    this._cache = const NoResponseCache(),
    this._activity,
    this._signer,
  })  : _baseUrl = config.apiBaseUrl,
        _readTimeout = config.readTimeout,
        _readRetries = config.readRetries,
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
    //
    // [kReleaseMode] is the second lock, and it is not redundant. The first
    // one is a build flag that fails *open*: `AK_ENV` defaults to
    // `development`, and an unrecognised value used to resolve there too, so
    // a release build shipped with the dart-define omitted or misspelled
    // (`AK_ENV=prod`) would have accepted any certificate any attacker
    // presented — bearer token, refresh token and customer records readable
    // on any hostile network, with nothing in the app to show for it.
    // `AppEnvironment.fromKey` now falls back to production instead, but a
    // constant the compiler can prove is the only guard that does not depend
    // on someone getting a build command right.
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
    if (!kIsWeb) {
      final trustDevCertificate =
          !kReleaseMode && config.environment.isDevelopment;
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        // Kept open past Dart's 15 s default, so the next screen reuses the
        // connection instead of paying for a new TLS handshake through the
        // tunnel — see [AppConfig.connectionIdleTimeout].
        final client = HttpClient()..idleTimeout = config.connectionIdleTimeout;
        if (trustDevCertificate) {
          client.badCertificateCallback = (cert, host, port) => true;
        }
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
          // Last, over the final URI: every retry passes through here again
          // and gets a fresh nonce and timestamp.
          final signer = _signer;
          if (signer != null) {
            options.headers.addAll(signer.headersFor(options.method, options.uri));
          }
          handler.next(options);
        },
      ),
    );
  }

  final String _baseUrl;
  final TokenStore _tokens;
  final Dio _dio;
  final Duration _readTimeout;
  final int _readRetries;
  final ResponseCache _cache;

  /// What the app-wide loading bar reads; null where nothing shows one.
  final NetworkActivity? _activity;

  /// Signs each request as coming from this app; null in builds without a
  /// client secret (and in tests that do not exercise it).
  final AppSigner? _signer;

  /// The pause before asking a stalled read again, multiplied by the attempt
  /// number — long enough not to hammer a link that has just stalled.
  static const _readRetryBackoff = Duration(milliseconds: 400);

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

  /// Every request, counted in [NetworkActivity] from its first attempt until
  /// its last retry settles.
  Future<Response<dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    _activity?.begin();
    try {
      return await _attempt(
        method,
        path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
      );
    } finally {
      _activity?.end();
    }
  }

  Future<Response<dynamic>> _attempt(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool isRetry = false,
    int readAttempt = 0,
    bool clockCorrected = false,
  }) async {
    final isRead = method == 'GET';
    try {
      return await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          receiveTimeout: isRead ? _readTimeout : null,
        ),
      );
    } on DioException catch (e) {
      // A read that stalled or never connected is asked again: through the
      // tunnel the next attempt usually answers at once. Never a write — one
      // that timed out may still have reached the server.
      if (isRead && readAttempt < _readRetries && _isTransient(e)) {
        await Future<void>.delayed(_readRetryBackoff * (readAttempt + 1));
        return _attempt(
          method,
          path,
          queryParameters: queryParameters,
          headers: headers,
          isRetry: isRetry,
          readAttempt: readAttempt + 1,
        );
      }
      // The API refused the signature because this device's clock is off.
      // It said what time it is; line up with it and try once more.
      final serverTime = clockCorrected ? null : _serverTimeIfClockSkew(e);
      if (serverTime != null) {
        _signer!.adoptServerTime(serverTime);
        return _attempt(
          method,
          path,
          body: body,
          queryParameters: queryParameters,
          headers: headers,
          isRetry: isRetry,
          readAttempt: readAttempt,
          clockCorrected: true,
        );
      }
      if (e.response?.statusCode == 401 &&
          !isRetry &&
          !_isAuthRoute(path) &&
          await _refreshAndSave()) {
        return _attempt(
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

  /// The API's clock, when [e] is its "device clock is off" refusal.
  int? _serverTimeIfClockSkew(DioException e) {
    final response = e.response;
    if (_signer == null || response?.statusCode != 403) return null;
    final data = response!.data;
    if (data is! Map || data['code'] != AppSigner.clockSkewCode) return null;
    return int.tryParse(response.headers.value(AppSigner.serverTimeHeader) ?? '');
  }

  /// A failure with no response behind it that another attempt could fix.
  static bool _isTransient(DioException e) =>
      e.response == null &&
      (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError);

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

  JsonMap _asObject(Response<dynamic> response) =>
      _objectFrom(response.data, response.requestOptions.path);

  JsonMap _objectFrom(Object? data, String path) {
    if (data is Map) return JsonMap.from(data);
    // `204 No Content`, or any empty 2xx body: nothing to decode is the
    // answer, not a malformed one. `POST /auth/logout` and the `/check` auth
    // routes answer this way, and their callers ignore the map.
    if (data == null || (data is String && data.isEmpty)) return const <String, dynamic>{};
    throw SerializationException(
      'Expected a JSON object from $path, got '
      '${data.runtimeType}',
    );
  }

  List<JsonMap> _asList(Response<dynamic> response) =>
      _listFrom(response.data, response.requestOptions.path);

  List<JsonMap> _listFrom(Object? data, String path) {
    if (data is List) {
      return data.whereType<Map>().map(JsonMap.from).toList(growable: false);
    }
    throw SerializationException(
      'Expected a JSON array from $path, got '
      '${data.runtimeType}',
    );
  }

  /// A `GET`, through the [ResponseCache] when the caller runs inside a
  /// [ResponseCacheScope] — see that class. Everywhere else, a plain request.
  Future<Object?> _read(
    String path,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  ) async {
    Future<Object?> fetch() async => (await _send(
          'GET',
          path,
          queryParameters: queryParameters,
          headers: headers,
        ))
            .data;

    final scope = ResponseCacheScope.current;
    if (scope == null || _mustBeLive(path)) return fetch();
    final key = await _cacheKey(path, queryParameters);
    if (scope.readsStoredAnswers) {
      final cached = await _cache.read(key);
      if (cached != null) {
        scope.markServedFromCache();
        return cached;
      }
    }
    final data = await fetch();
    if (data is Map || data is List) unawaited(_cache.write(key, data));
    return data;
  }

  /// Reads that are never answered from disk, even at start-up: a provider's
  /// bookable slots are live occupancy, and a stored grid could offer a slot
  /// somebody has booked since.
  ///
  /// The profile used to be here too. Since start-up stopped waiting on the
  /// network it is served from disk like the lists, so a signed-in cold start
  /// does not open on a guest's screens for the second the round trip takes;
  /// `AppBootstrap.completeWarmUp` asks the server again right after the first
  /// frame and signs an expired session out
  /// (`AuthNotifier.restore(revalidate: true)`).
  static bool _mustBeLive(String path) => path.endsWith('/slots');

  /// Scoped to the account the stored token was issued for, and to the host,
  /// so one account's garage is never served to another account signed in on
  /// the same phone, nor a staging answer to a production build.
  Future<String> _cacheKey(
    String path,
    Map<String, dynamic>? queryParameters,
  ) async {
    final account = jwtSubject(await _tokens.tryReadAccessToken()) ?? 'guest';
    final query = [
      for (final entry in (queryParameters ?? const {}).entries)
        if (entry.value != null) '${entry.key}=${entry.value}',
    ]..sort();
    return '$account|$_baseUrl$path?${query.join('&')}';
  }

  @override
  Future<JsonMap> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _objectFrom(await _read(path, queryParameters, headers), path);

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
      _listFrom(await _read(path, queryParameters, headers), path);

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

  @override
  Future<List<JsonMap>> putList(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asList(await _send(
        'PUT',
        path,
        body: body,
        queryParameters: queryParameters,
        headers: headers,
      ));

  @override
  Future<List<JsonMap>> deleteList(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async =>
      _asList(await _send(
        'DELETE',
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
          code: code,
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
