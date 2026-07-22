import '../../config/app_config.dart';
import '../../core/error/app_exception.dart';

/// Shared plumbing for the mock services.
///
/// Its whole job is to make the mock services behave like network clients:
/// every read goes through a `Future`, honours the configured latency, and
/// raises the same `AppException` types a REST implementation would. That way
/// the state layer above is already written against real-world failure modes.
mixin MockServiceBase {
  AppConfig get config;

  /// Resolves [value] as if it came off the wire.
  Future<T> respond<T>(T value) async {
    if (config.mockLatency > Duration.zero) {
      await Future<void>.delayed(config.mockLatency);
    }
    return value;
  }

  /// Resolves [value], or raises [NotFoundException] when it is null — the
  /// mock equivalent of a 404.
  Future<T> respondRequired<T extends Object>(T? value, String what) async {
    final resolved = await respond(value);
    if (resolved == null) throw NotFoundException('$what not found');
    return resolved;
  }
}
