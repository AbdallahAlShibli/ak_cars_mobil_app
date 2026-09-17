import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Posts AK Cars' system notifications — from the app's own isolate and from
/// the background push service's.
///
/// While the app is open both may receive the same inbox row. The notification
/// id is therefore derived from the row's id ([idFor]) and posted with
/// `onlyAlertOnce`, so the second post silently replaces the first instead of
/// adding a duplicate that rings twice.
///
/// Every method logs and swallows plugin failures: a banner that cannot be
/// shown never costs the inbox row behind it.
class NotificationDisplay {
  static const updatesChannelId = 'akcars_updates';
  static const connectionChannelId = 'akcars_connection';

  /// The background service's own ongoing notification.
  static const connectionNotificationId = 7001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Sets the plugin up; answers whether notifications can be shown at all.
  /// [onTap] receives a tapped notification's payload, which is its route.
  Future<bool> initialize({void Function(String? payload)? onTap}) async {
    if (_ready) return true;
    if (kIsWeb) return false;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: onTap == null
            ? null
            : (response) => onTap(response.payload),
      );
      _ready = true;
    } catch (error, stack) {
      _log('Local notifications are unavailable — rows still reach the inbox',
          error, stack);
    }
    return _ready;
  }

  /// Android 13+ and iOS show nothing until the user allows it. A refusal
  /// only hides the banner, never the inbox.
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (error, stack) {
      _log('Could not ask for notification permission', error, stack);
    }
  }

  /// Whether tapping one of these notifications launched the app, and that
  /// notification's payload.
  Future<({bool launched, String? payload})> launchDetails() async {
    if (!_ready) return (launched: false, payload: null);
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      return (
        launched: details?.didNotificationLaunchApp ?? false,
        payload: details?.notificationResponse?.payload,
      );
    } catch (error, stack) {
      _log('Could not read how the app was launched', error, stack);
      return (launched: false, payload: null);
    }
  }

  /// The quiet channel the background service's ongoing notification sits
  /// on — no sound, no vibration, no badge — which the user can switch off in
  /// system settings without stopping delivery.
  Future<void> createConnectionChannel({
    required String name,
    required String description,
  }) async {
    if (kIsWeb) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              connectionChannelId,
              name,
              description: description,
              importance: Importance.low,
              playSound: false,
              enableVibration: false,
              showBadge: false,
            ),
          );
    } catch (error, stack) {
      _log('Could not create the background connection channel', error, stack);
    }
  }

  /// Shows one inbox row in the notification center.
  Future<void> show({
    required String notificationId,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: idFor(notificationId),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            updatesChannelId,
            'AK Cars updates',
            channelDescription: 'Bookings, payments, orders and messages',
            importance: Importance.high,
            priority: Priority.high,
            onlyAlertOnce: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
        payload: route,
      );
    } catch (error, stack) {
      _log('Could not show a system notification', error, stack);
    }
  }

  /// A notification id for an inbox row that every isolate computes the same:
  /// 32-bit FNV-1a over the row's id, kept positive and clear of
  /// [connectionNotificationId]. Not `String.hashCode`, which two isolates are
  /// not promised to agree on.
  static int idFor(String notificationId) {
    var hash = 0x811c9dc5;
    for (final unit in notificationId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final id = hash & 0x7fffffff;
    return id == connectionNotificationId ? id + 1 : id;
  }

  static void _log(String message, Object error, StackTrace stack) =>
      developer.log(
        message,
        name: 'NotificationDisplay',
        error: error,
        stackTrace: stack,
      );
}
