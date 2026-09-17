import 'package:ak_cars_mobil_app/core/network/chat_hub.dart';
import 'package:ak_cars_mobil_app/core/push/push_service.dart';
import 'package:ak_cars_mobil_app/data/models/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

/// The wire contract with the API's own push service (`NotificationHub`,
/// `SignalRNotificationPusher`) and its hub mappings — both of which silently
/// did nothing when the client disagreed with the server.
void main() {
  Map<String, dynamic> row() => {
    'id': '3f785ad7-1f0d-41fa-9ba0-cc7831e4ef5d',
    'title': {'ar': 'طلب حجز جديد', 'en': 'New booking request'},
    'body': {
      'ar': 'وصل طلب حجز جديد إلى قائمتك.',
      'en': 'A new booking request has arrived in your queue.',
    },
    'icon': 'notification',
    'time': '2026-09-14T13:26:21.955',
    'read': false,
    'route': '/workshop',
  };

  group('PushService.decodeFrame', () {
    test('decodes the inbox row a Notification frame carries', () {
      final json = PushService.decodeFrame([row()]);

      expect(json, isNotNull);
      final notification = AppNotification.fromJson(json!);
      expect(notification.id, '3f785ad7-1f0d-41fa-9ba0-cc7831e4ef5d');
      expect(notification.title.en, 'New booking request');
      expect(notification.title.ar, 'طلب حجز جديد');
      expect(notification.read, isFalse);
      expect(notification.route, '/workshop');
      expect(notification.time, DateTime(2026, 9, 14, 13, 26, 21, 955));
    });

    test('anything that is not one inbox row is ignored, not half-decoded', () {
      expect(PushService.decodeFrame(null), isNull);
      expect(PushService.decodeFrame([]), isNull);
      expect(PushService.decodeFrame(['text']), isNull);
      expect(PushService.decodeFrame([<String, dynamic>{'title': 'no id'}]), isNull);
    });
  });

  group('what a system notification shows and opens', () {
    test('its text follows the reader’s language', () {
      final notification = AppNotification.fromJson(row());

      expect(PushService.textFor(notification, 'en'), (
        'New booking request',
        'A new booking request has arrived in your queue.',
      ));
      expect(PushService.textFor(notification, 'ar'), (
        'طلب حجز جديد',
        'وصل طلب حجز جديد إلى قائمتك.',
      ));
    });

    test('a tap opens the row’s route, or nothing when it has none', () {
      expect(PushService.routeOf(row()), '/workshop');
      expect(PushService.routeOf({...row(), 'route': null}), isNull);
      expect(PushService.routeOf({...row(), 'route': ''}), isNull);
    });
  });

  group('hub URLs are resolved at the API origin, not under /api/v1', () {
    test('notifications', () {
      expect(
        PushService.hubUrl('https://akcarsapi.0coders.com/api/v1'),
        'https://akcarsapi.0coders.com/hubs/notifications',
      );
    });

    test('chat', () {
      expect(
        ChatHub.hubUrl('https://akcarsapi.0coders.com/api/v1'),
        'https://akcarsapi.0coders.com/hubs/chat',
      );
      expect(
        ChatHub.hubUrl('https://localhost:7291/api/v1'),
        'https://localhost:7291/hubs/chat',
      );
    });
  });
}
