import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../config/app_config.dart';

/// Signs every API request so the API can tell this app from anything else
/// calling it (the API's `AppSignatureMiddleware`).
///
/// The signature is HMAC-SHA256, under this build's client secret, of
/// `"{METHOD}\n{path?query}\n{unix seconds}\n{nonce}"` — the same string the
/// API rebuilds from the request it receives. A fresh nonce per request means
/// a captured request cannot be sent again, and the path in the signature
/// means it cannot be pointed at another route.
///
/// The secret comes from the build (`--dart-define-from-file`), never from the
/// source tree, and release builds are obfuscated — which raises the cost of
/// pulling it out of the APK without making it impossible.
class AppSigner {
  AppSigner({
    required this.clientId,
    required String secret,
    DateTime Function()? clock,
    Random? random,
  }) : _key = utf8.encode(secret),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  /// The signer for this build, or null when it was built without a client
  /// secret — its requests then go unsigned, which an API that enforces the
  /// check refuses.
  static AppSigner? fromBuild() =>
      AppConfig.appClientId.isEmpty || AppConfig.appSecret.isEmpty
      ? null
      : AppSigner(clientId: AppConfig.appClientId, secret: AppConfig.appSecret);

  static const clientHeader = 'X-AK-Client';
  static const timestampHeader = 'X-AK-Timestamp';
  static const nonceHeader = 'X-AK-Nonce';
  static const signatureHeader = 'X-AK-Signature';
  static const serverTimeHeader = 'X-AK-Server-Time';

  /// The API's answer when this device's clock is too far from its own.
  static const clockSkewCode = 'app_clock_skew';

  final String clientId;
  final List<int> _key;
  final DateTime Function() _clock;
  final Random _random;

  /// Seconds added to the device clock, learned from the API after a
  /// [clockSkewCode] refusal. Zero until then.
  int _offsetSeconds = 0;

  int get _deviceSeconds =>
      _clock().toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

  /// The four headers that sign [method] to [uri].
  Map<String, String> headersFor(String method, Uri uri) {
    final timestamp = '${_deviceSeconds + _offsetSeconds}';
    final nonce = _nonce();
    return {
      clientHeader: clientId,
      timestampHeader: timestamp,
      nonceHeader: nonce,
      signatureHeader: sign(method, targetOf(uri), timestamp, nonce),
    };
  }

  /// Lines this device's clock up with [serverSeconds] for every later request.
  void adoptServerTime(int serverSeconds) {
    _offsetSeconds = serverSeconds - _deviceSeconds;
  }

  String sign(String method, String target, String timestamp, String nonce) {
    final message = '${method.toUpperCase()}\n$target\n$timestamp\n$nonce';
    return Hmac(sha256, _key).convert(utf8.encode(message)).toString();
  }

  /// The path and query as they go on the wire — what the API signs against.
  static String targetOf(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    return uri.hasQuery ? '$path?${uri.query}' : path;
  }

  String _nonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
