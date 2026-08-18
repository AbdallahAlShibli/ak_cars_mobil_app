import 'dart:convert';

import 'package:ak_cars_mobil_app/data/services/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// `TokenStore` must never have two writes to the platform store in flight at
/// once.
///
/// This is not a style rule. On web `flutter_secure_storage` encrypts every
/// value under one AES-GCM key that it creates lazily — "read the key if
/// present, otherwise generate one and store it" — and that read-then-write is
/// not atomic. Concurrent writes against a store with no key yet each generate
/// a different key and each overwrite the last, leaving most of the values
/// encrypted under a key that no longer exists.
///
/// What that looked like in the app: registration succeeded, `POST
/// /auth/register` returned tokens, `save()` stored them — and then every
/// authenticated request answered `401`, because the request interceptor's
/// `tryReadAccessToken()` caught the decrypt failure and sent no
/// `Authorization` header. Guest-data adoption, `PUT /user/profile`, the
/// garage, the maintenance books and the challenge board all failed with no
/// error a user could act on.
void main() {
  test('save writes one value at a time, never concurrently', () async {
    final storage = _ConcurrencyWatchingStorage();
    await TokenStore(storage: storage)
        .save(access: 'a', refresh: 'r', expiresIn: 3600);

    expect(storage.writes, hasLength(3));
    expect(storage.maxConcurrentWrites, 1,
        reason: 'two writes in flight together is the race itself');
  });

  test('clear deletes one key at a time', () async {
    final storage = _ConcurrencyWatchingStorage();
    await TokenStore(storage: storage).clear();

    expect(storage.maxConcurrentWrites, 1);
  });

  test('a token saved into a lazily-keyed store reads back', () async {
    // A store that models the web plugin's key handling: one key for the whole
    // store, created on first use, and a value that can only be decrypted by
    // the key that encrypted it.
    final storage = _LazilyKeyedStorage();
    final tokens = TokenStore(storage: storage);

    await tokens.save(access: 'access-123', refresh: 'refresh-456', expiresIn: 60);

    expect(await tokens.readAccessToken(), 'access-123');
    expect(await tokens.readRefreshToken(), 'refresh-456');
    expect(await tokens.hasSession(), isTrue);
  });
}

/// Records how many writes are in flight simultaneously.
class _ConcurrencyWatchingStorage extends FlutterSecureStorage {
  final writes = <String>[];
  int _inFlight = 0;
  int maxConcurrentWrites = 0;

  Future<void> _track(String key) async {
    _inFlight += 1;
    maxConcurrentWrites =
        _inFlight > maxConcurrentWrites ? _inFlight : maxConcurrentWrites;
    // A real platform write suspends; without a suspension point here the
    // concurrent and sequential forms would look identical.
    await Future<void>.delayed(Duration.zero);
    writes.add(key);
    _inFlight -= 1;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _track(key);

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _track(key);
}

/// The web plugin's shape: a single store-wide key, generated on first use,
/// and values that only decrypt under the key they were written with.
class _LazilyKeyedStorage extends FlutterSecureStorage {
  final Map<String, String> _values = {};
  int? _storeKey;
  int _nextKey = 1;

  Future<int> _keyForStore() async {
    // The non-atomic read-then-write the real plugin performs.
    final existing = _storeKey;
    if (existing != null) return existing;
    await Future<void>.delayed(Duration.zero);
    return _storeKey = _nextKey++;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final storeKey = await _keyForStore();
    _values[key] = '$storeKey:${base64Encode(utf8.encode(value ?? ''))}';
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final stored = _values[key];
    if (stored == null) return null;
    final parts = stored.split(':');
    if (int.parse(parts[0]) != _storeKey) {
      // Exactly what WebCrypto raises for a key/ciphertext mismatch.
      throw StateError('OperationError');
    }
    return utf8.decode(base64Decode(parts[1]));
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}
