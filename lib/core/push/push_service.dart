import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import '../constants/api_endpoints.dart';
import '../network/api_client.dart';

/// FCM registration and the data-only message → [AppNotification] bridge.
///
/// **Requires a Firebase project wired up natively** (`flutterfire configure`,
/// `google-services.json` / `GoogleService-Info.plist`) before it can deliver
/// anything — that is an infrastructure step outside this repo's Dart code.
/// Every method here is defensive about that: a missing native config throws
/// inside [FirebaseCore], is caught, logged, and swallowed rather than taking
/// down sign-in or app boot. Push is additive; its absence must never be the
/// reason a user cannot sign in.
class PushService {
  PushService(this._client);

  final ApiClient _client;

  bool _initialized = false;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp();
      _initialized = true;
      // FCM can rotate the device token at any time (app restore, token
      // expiry) — re-register whenever that happens, same as at sign-in.
      //
      // Through [registerCurrentDevice] rather than posting inline, so the
      // rotation path gets the same try/catch every other method here has.
      // Inline, the POST was unawaited and unguarded: a failure (offline,
      // 401, 500) became an unhandled async error escaping to the zone
      // handler, in the one class whose contract is that push failures are
      // logged and swallowed.
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => unawaited(registerCurrentDevice()),
      );
      return true;
    } catch (error, stack) {
      developer.log(
        'Firebase.initializeApp() failed — push notifications are '
        'unavailable until the native Firebase config is added.',
        name: 'PushService',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Registers this device's current FCM token with the server. Call on
  /// sign-in and whenever FCM reports a token refresh.
  Future<void> registerCurrentDevice() async {
    if (!await _ensureInitialized()) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _client.post(
        ApiEndpoints.notificationDevices,
        body: {'token': token, 'platform': _platform},
      );
    } catch (error, stack) {
      developer.log(
        'Device push registration failed',
        name: 'PushService',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Unregisters this device's current token — called from `signOut()` so a
  /// shared or wiped phone stops receiving another account's pushes.
  Future<void> unregisterCurrentDevice() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _client.delete(ApiEndpoints.notificationDevice(token));
    } catch (error, stack) {
      developer.log(
        'Device push unregistration failed',
        name: 'PushService',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Subscribes [onMessage] to every data-only FCM frame, decoded as the same
  /// JSON shape `GET /notifications` returns — so a push and a fetched inbox
  /// row are the same object and the app never renders two versions of one
  /// event.
  Stream<Map<String, dynamic>> dataMessages() => FirebaseMessaging.onMessage
      .map((message) => message.data)
      .where((data) => data.isNotEmpty);
}
