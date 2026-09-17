import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../constants/app_constants.dart';
import 'background_push_channel.dart';
import 'notification_display.dart';
import 'push_key_store.dart';

/// Keeps AK Cars' notifications reaching the notification center after the
/// app is closed — on Android, and without a third-party push provider.
///
/// A closed or long-backgrounded app has no process left to hold a
/// connection, and only FCM/APNs can wake one. What Android does allow is a
/// *foreground service*: a process the system keeps running with the app's UI
/// gone, provided it shows an ongoing notification. This starts one
/// (`flutter_background_service`, type `remoteMessaging`) whose isolate runs
/// [BackgroundPushChannel], and it comes back after a reboot or an app update.
///
/// The ongoing notification sits on its own low-importance channel: it makes
/// no sound, and the user can hide that channel in system settings without
/// stopping delivery.
///
/// What still stops it: force-stopping the app from system settings, and the
/// battery managers of some manufacturers, which kill foreground services
/// too. iOS has no equivalent — only APNs can wake a suspended iOS app — so
/// there this does nothing.
class BackgroundPush {
  const BackgroundPush();

  /// Sent from the app to the service's isolate to end it.
  static const stopCommand = 'stop';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts the service unless it is already running.
  Future<void> enable({
    required String languageCode,
    required NotificationDisplay display,
  }) async {
    if (!isSupported) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) return;
      final text = connectionText(languageCode);
      await display.createConnectionChannel(
        name: text.channelName,
        description: text.channelDescription,
      );
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: backgroundPushMain,
          isForegroundMode: true,
          autoStart: false,
          autoStartOnBoot: true,
          notificationChannelId: NotificationDisplay.connectionChannelId,
          initialNotificationTitle: text.title,
          initialNotificationContent: text.content,
          foregroundServiceNotificationId:
              NotificationDisplay.connectionNotificationId,
          foregroundServiceTypes: const [AndroidForegroundType.remoteMessaging],
        ),
        iosConfiguration: IosConfiguration(autoStart: false),
      );
      await service.startService();
    } catch (error, stack) {
      developer.log(
        'The background notification service could not start — '
        'notifications still arrive while the app is open',
        name: 'BackgroundPush',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Stops a running service and starts it again, so its connection
  /// authenticates afresh — after the push key moved to another account.
  Future<void> restart({
    required String languageCode,
    required NotificationDisplay display,
  }) async {
    if (!isSupported) return;
    await disable();
    try {
      final service = FlutterBackgroundService();
      var waited = Duration.zero;
      while (waited < _stopTimeout && await service.isRunning()) {
        await Future<void>.delayed(_stopPoll);
        waited += _stopPoll;
      }
    } catch (error, stack) {
      developer.log(
        'Could not confirm the background notification service stopped',
        name: 'BackgroundPush',
        error: error,
        stackTrace: stack,
      );
    }
    await enable(languageCode: languageCode, display: display);
  }

  static const _stopPoll = Duration(milliseconds: 200);
  static const _stopTimeout = Duration(seconds: 5);

  /// Ends the service if it is running.
  Future<void> disable() async {
    if (!isSupported) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) service.invoke(stopCommand);
    } catch (error, stack) {
      developer.log(
        'The background notification service could not be stopped',
        name: 'BackgroundPush',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// The ongoing notification's wording, and its channel's, in the app's
  /// language at the time the service starts.
  static ({
    String title,
    String content,
    String channelName,
    String channelDescription,
  })
  connectionText(String languageCode) => languageCode == 'en'
      ? (
          title: 'AK Cars',
          content: 'Receiving your updates',
          channelName: 'Background connection',
          channelDescription:
              'Keeps AK Cars notifications arriving while the app is closed. '
              'Hiding this channel does not stop them.',
        )
      : (
          title: 'AK Cars',
          content: 'يستقبل تحديثاتك',
          channelName: 'الاتصال في الخلفية',
          channelDescription:
              'يُبقي إشعارات AK Cars تصلك والتطبيق مغلق. '
              'إخفاء هذه القناة لا يوقفها.',
        );
}

/// The service's entry point, run in its own isolate by
/// `flutter_background_service` — after [BackgroundPush.enable], after a
/// reboot, and after an app update.
@pragma('vm:entry-point')
Future<void> backgroundPushMain(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final key = await PushKeyStore().tryRead();
  // Signed out, or notifications switched off, since the service last ran —
  // typically a reboot after either.
  if (key == null ||
      !(preferences.getBool(AppConstants.prefsNotifications) ?? true)) {
    await service.stopSelf();
    return;
  }

  final display = NotificationDisplay();
  await display.initialize();
  final channel = BackgroundPushChannel(
    hubUrl: BackgroundPushChannel.hubUrlFor(AppConfig.current().apiBaseUrl, key),
    display: display,
    preferences: preferences,
    onKeyRejected: () => unawaited(service.stopSelf()),
  );
  service.on(BackgroundPush.stopCommand).listen((_) async {
    await channel.close();
    await service.stopSelf();
  });
  await channel.run();
}
