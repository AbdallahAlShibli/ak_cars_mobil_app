@TestOn('browser')
library;

import 'package:ak_cars_mobil_app/data/services/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real [TokenStore] against the real `flutter_secure_storage_web`, in a
/// real browser — the one link the pure-Dart tests cannot cover.
///
/// `flutter_secure_storage_web` AES-GCM-encrypts every value under a single
/// key it creates lazily in `localStorage`. Writing the three token fields
/// concurrently made each write mint its own key and overwrite the last, so
/// most values became undecryptable and every authenticated request went out
/// with no `Authorization` header. Nothing in the pure-Dart suite can catch
/// that: it needs WebCrypto.
///
/// Run with:
///   flutter test test/web --platform chrome
void main() {
  test('a saved session reads back', () async {
    final tokens = TokenStore();
    addTearDown(tokens.tryClear);
    await tokens.clear();

    await tokens.save(
      access: 'access-token-value',
      refresh: 'refresh-token-value',
      expiresIn: 3600,
    );

    expect(await tokens.readAccessToken(), 'access-token-value');
    expect(await tokens.readRefreshToken(), 'refresh-token-value');
    expect(await tokens.readExpiresAt(), isNotNull);
    expect(await tokens.hasSession(), isTrue);
  });

  test('saving twice over the same store still reads back', () async {
    final tokens = TokenStore();
    addTearDown(tokens.tryClear);

    await tokens.save(access: 'first', refresh: 'r1', expiresIn: 60);
    await tokens.save(access: 'second', refresh: 'r2', expiresIn: 60);

    expect(await tokens.readAccessToken(), 'second');
    expect(await tokens.readRefreshToken(), 'r2');
  });

  test('a cleared store reads as no session, without throwing', () async {
    final tokens = TokenStore();
    await tokens.save(access: 'a', refresh: 'r', expiresIn: 60);
    await tokens.clear();

    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.hasSession(), isFalse);
    expect(await tokens.mayHaveSession(), isFalse,
        reason: 'a readable empty store must answer "no session", not "maybe" '
            '— "maybe" is what sent a guest a burst of 401s every cold start');
  });
}
