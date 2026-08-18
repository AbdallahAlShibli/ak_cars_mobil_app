import 'package:ak_cars_mobil_app/data/services/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A token store that will not answer.
///
/// Reading is not a plain lookup. On web the value is AES-decrypted through
/// WebCrypto, which raises `OperationError` when the key in storage no longer
/// matches the ciphertext; on device the read can fail on a locked keystore or
/// a keychain refusing on a restored backup; under `flutter test` there is no
/// platform channel at all.
///
/// Every caller on a request path has to treat that as "no token", because the
/// alternative is worse than being signed out: an unguarded read threw out of
/// `DioApiClient`'s request interceptor, where Dio turned it into a
/// `DioException` with no response — reported to the user as "could not reach
/// the server", the network blamed for a storage fault.
void main() {
  group('an unreadable store', () {
    test('reads as no token rather than throwing', () async {
      final tokens = _UnreadableStore();

      expect(await tokens.tryReadAccessToken(), isNull);
      expect(await tokens.tryReadRefreshToken(), isNull);
    });

    test('still throws from the plain reads, which is what they are for',
        () async {
      final tokens = _UnreadableStore();

      // The unguarded forms stay unguarded: callers that genuinely want to
      // know go on being told. Only the request path opts out.
      await expectLater(tokens.readAccessToken(), throwsA(isA<StateError>()));
      await expectLater(tokens.readRefreshToken(), throwsA(isA<StateError>()));
    });

    test('clears without throwing on a path that is already failing',
        () async {
      final tokens = _UnreadableStore();
      await expectLater(tokens.tryClear(), completes);
    });

    test('mayHaveSession still guesses "yes", not "signed out"', () async {
      // Unchanged, and deliberately the opposite guess to `tryRead…`: this one
      // only decides whether a request is worth making, and guessing "no" on
      // an unreadable store would sign a real session out of its own warm-up.
      expect(await _UnreadableStore().mayHaveSession(), isTrue);
    });
  });
}

/// Every operation fails, the way a rotated WebCrypto key or a locked keystore
/// makes them fail. `TokenStore`'s own `FlutterSecureStorage` is never
/// constructed against a platform channel here — these overrides replace the
/// only methods that would reach one.
class _UnreadableStore extends TokenStore {
  Never _fail() => throw StateError('keystore unavailable');

  @override
  Future<String?> readAccessToken() async => _fail();

  @override
  Future<String?> readRefreshToken() async => _fail();

  @override
  Future<void> clear() async => _fail();
}
