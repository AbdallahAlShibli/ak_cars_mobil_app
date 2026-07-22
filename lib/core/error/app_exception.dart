/// Base type for every failure the data layer surfaces.
///
/// Services throw these instead of raw platform errors, so the state layer can
/// switch on a stable set of cases regardless of whether the data came from a
/// mock source or an HTTP client.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  /// Developer-facing description. User-facing copy is chosen by the UI from
  /// the exception *type*, never by parsing this string.
  final String message;

  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// The device could not reach the API at all (offline, DNS, TLS).
class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// The request outlived [AppConfig.connectTimeout] / `receiveTimeout`.
///
/// Deliberately not named `TimeoutException` — that name is taken by
/// `dart:async` and colliding would force import prefixes everywhere.
class RequestTimeoutException extends AppException {
  const RequestTimeoutException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// The server answered with a non-2xx status.
class ApiException extends AppException {
  const ApiException(
    super.message, {
    required this.statusCode,
    this.errorCode,
    this.details,
    super.cause,
    super.stackTrace,
  });

  final int statusCode;

  /// Machine-readable code from the API envelope, when present.
  final String? errorCode;

  /// Field-level validation errors keyed by field name.
  final Map<String, List<String>>? details;

  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 401 — no valid session. The UI should route to registration/sign-in.
class UnauthorizedException extends AppException {
  const UnauthorizedException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// 403 — authenticated but not permitted.
class ForbiddenException extends AppException {
  const ForbiddenException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// 404 — the requested resource does not exist.
class NotFoundException extends AppException {
  const NotFoundException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// 400/422 — the request was rejected for invalid input.
class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });

  final Map<String, List<String>> fieldErrors;
}

/// The payload did not match the shape the models expect.
class SerializationException extends AppException {
  const SerializationException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// A local cache read/write failed (SharedPreferences, disk).
class CacheException extends AppException {
  const CacheException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// A rule the client enforces was violated (e.g. checkout without a
/// completed registration). Not produced by transport.
class BusinessRuleException extends AppException {
  const BusinessRuleException(
    super.message, {
    this.code,
    super.cause,
    super.stackTrace,
  });

  final String? code;
}

/// Anything that escaped classification.
class UnknownException extends AppException {
  const UnknownException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}
