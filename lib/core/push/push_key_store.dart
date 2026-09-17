import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/services/token_store.dart';

/// This install's push key: the random value the API knows the device by on
/// `/hubs/notifications` once the app is closed (`?device_key=`).
///
/// Why not the session's own tokens: refresh tokens rotate, and the API burns
/// the whole token family when one is used twice. The background push service
/// runs in its own isolate beside the app, so if both refreshed, the second
/// refresh would sign the user out. The key is registered with
/// `POST /notifications/devices` while the app holds a session, authenticates
/// that one hub and nothing else, and is deleted on sign-out.
///
/// Kept in the platform keystore with the session tokens' own options, where
/// the background service's isolate can read it too.
class PushKeyStore {
  PushKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: TokenStore.androidOptions,
            iOptions: TokenStore.iosOptions,
          );

  static const _storageKey = 'ak_cars_push_device_key';
  static const _keyBytes = 32;

  final FlutterSecureStorage _storage;

  /// The stored key, or null when there is none or the store cannot be read.
  Future<String?> tryRead() async {
    try {
      final key = await _storage.read(key: _storageKey);
      return key == null || key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  /// The stored key, generating and storing one first when there is none;
  /// `created` tells the caller the API has never seen it. Throws when the
  /// store cannot be read or written.
  Future<({String key, bool created})> readOrCreate() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) {
      return (key: existing, created: false);
    }
    final key = generate();
    await _storage.write(key: _storageKey, value: key);
    return (key: key, created: true);
  }

  /// Deletes the key; a store that refuses leaves one the API no longer
  /// accepts, which the next sign-in replaces.
  Future<void> tryClear() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {}
  }

  /// 32 bytes from the platform's secure generator as unpadded base64url —
  /// 43 characters that are safe in a query string and a URL path as they are.
  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(_keyBytes, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
