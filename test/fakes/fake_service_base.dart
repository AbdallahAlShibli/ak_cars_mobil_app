import 'package:ak_cars_mobil_app/core/error/app_exception.dart';

/// Shared plumbing for the test doubles.
///
/// These used to live in `lib/` beside the interfaces they implement, so the
/// shipped app carried a complete second data layer. It does not any more: the
/// app binds the `Api*` services and nothing else, and this world exists only
/// to give the widget tests something deterministic to render against.
///
/// Its job is still to make the doubles behave like network clients — every
/// read goes through a `Future` and raises the same `AppException` types the
/// REST implementations do — so a test exercises the same asynchronous code
/// path production does.
mixin MockServiceBase {
  /// Resolves [value] as if it came off the wire.
  Future<T> respond<T>(T value) async => value;

  /// Resolves [value], or raises [NotFoundException] when it is null — the
  /// equivalent of a 404.
  Future<T> respondRequired<T extends Object>(T? value, String what) async {
    final resolved = await respond(value);
    if (resolved == null) throw NotFoundException('$what not found');
    return resolved;
  }
}
