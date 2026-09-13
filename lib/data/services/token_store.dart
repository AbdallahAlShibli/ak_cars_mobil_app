import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session's access/refresh tokens live between app launches.
///
/// Backed by `flutter_secure_storage` — the platform keychain/keystore, not
/// `SharedPreferences`. Prefs is a plaintext XML file on Android and a
/// readable plist on iOS; a refresh token there is a session anyone with the
/// device (or a backup of it) can resume.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(aOptions: _android, iOptions: _ios);

  /// Jetpack Security's `EncryptedSharedPreferences`, which is *not* the
  /// plugin's Android default — the default is its own older keystore-wrapped
  /// scheme written over a plain prefs file.
  static const _android = AndroidOptions(encryptedSharedPreferences: true);

  /// `first_unlock_this_device`, not the plugin's default `unlocked`.
  ///
  /// The `_this_device` half is the one that matters here: it keeps the
  /// refresh token out of iCloud and iTunes backups, so a restore onto a
  /// second phone cannot resume this session — which is the exact threat the
  /// doc comment above names, "or a backup of it".
  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'ak_cars_access_token';
  static const _refreshTokenKey = 'ak_cars_refresh_token';
  static const _expiresAtKey = 'ak_cars_token_expires_at';

  /// Writes the three values **one at a time**, never concurrently.
  ///
  /// This looks like a pointless serialisation and is not. On web,
  /// `flutter_secure_storage` AES-GCM-encrypts each value under a single key it
  /// keeps in `localStorage`, and it creates that key lazily: `read if present,
  /// else generate and store`. That sequence is not atomic. Three writes
  /// started together against a store that has no key yet all see "no key",
  /// all generate a *different* one, and each overwrites the last — so two of
  /// the three values end up encrypted under a key that is no longer there,
  /// and every later read of them rejects with `OperationError`.
  ///
  /// The symptom was not "storage is broken". It was **every authenticated
  /// request answering 401 immediately after a successful registration**:
  /// `POST /auth/register` returned tokens, this stored them, and the request
  /// interceptor's `tryReadAccessToken()` then swallowed the decrypt failure
  /// and sent no `Authorization` header at all. Nothing in the app could tell
  /// that apart from being signed out.
  ///
  /// Sequential writes make the first call create the key and the other two
  /// import it. Device platforms never had the bug — the keystore has no
  /// shared key to race over — which is why it only ever showed on web.
  Future<void> save({
    required String access,
    required String refresh,
    required int expiresIn,
  }) async {
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
    await _storage.write(
      key: _expiresAtKey,
      value: expiresAt.toIso8601String(),
    );
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  /// [readAccessToken] / [readRefreshToken] that answer `null` rather than
  /// throwing when the store itself will not cooperate.
  ///
  /// Reading is not merely a lookup: on web the value is AES-decrypted through
  /// WebCrypto, which raises `OperationError` if the key in storage no longer
  /// matches the ciphertext (a rotated key, a half-cleared origin, storage
  /// written by another build). On device the read can fail on a keystore
  /// behind the lock screen or a keychain refusing on a restored backup, and
  /// under `flutter test` there is no platform channel at all.
  ///
  /// "No readable token" and "no token" lead to the same place — an
  /// unauthenticated request, which the server answers `401`, which the app
  /// already handles. What must *not* happen is the read throwing through a
  /// caller that cannot say anything useful about it: [DioApiClient]'s request
  /// interceptor turned such a throw into `NetworkException: could not reach
  /// the configured host`, blaming the network for a storage fault.
  Future<String?> tryReadAccessToken() => _orNull(readAccessToken);

  Future<String?> tryReadRefreshToken() => _orNull(readRefreshToken);

  /// [clear] that cannot throw. Used where clearing is a best-effort cleanup on
  /// a path that is already failing — a throw there would replace the real
  /// error with this one.
  Future<void> tryClear() async {
    try {
      await clear();
    } catch (_) {
      // Nothing useful to do: the caller is already handling a failure, and a
      // token that could not be deleted will be overwritten at the next
      // sign-in.
    }
  }

  static Future<String?> _orNull(Future<String?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> readExpiresAt() async {
    final raw = await _storage.read(key: _expiresAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<bool> hasSession() async => await readAccessToken() != null;

  /// Whether an auth-gated request is worth making at all.
  ///
  /// Answers `true` when the store cannot be read — no platform channel under
  /// `flutter test`, a keystore locked behind the lock screen, a keychain that
  /// refuses on a restored backup. Callers use this to *skip* requests that
  /// could only answer `401`, so the failure mode has to be "ask the server
  /// anyway", never "assume signed out": guessing `false` on an unreadable
  /// store would silently sign a real session out of its own warm-up, while
  /// guessing `true` costs at worst the one request that was being made
  /// before any of this existed.
  Future<bool> mayHaveSession() async {
    try {
      return await hasSession();
    } catch (_) {
      return true;
    }
  }

  /// Sequential for the same reason [save] is — see its comment. Deleting does
  /// not touch the web store's encryption key today, but keeping both write
  /// paths single-file means no future change to this class can reintroduce
  /// the race by accident.
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}
