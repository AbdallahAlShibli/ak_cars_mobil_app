import 'dart:convert';

import 'package:ak_cars_mobil_app/core/push/background_push_channel.dart';
import 'package:ak_cars_mobil_app/core/push/notification_display.dart';
import 'package:ak_cars_mobil_app/core/push/push_key_store.dart';
import 'package:ak_cars_mobil_app/core/utils/jwt_claims.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_netcore/errors.dart';

/// The pieces of background push that decide *whether* a closed app's
/// notification reaches the notification center: the key the API knows the
/// device by, the URL it presents it on, when a dropped connection stops
/// retrying, what catch-up asks for, and how a row posted by two isolates
/// stays one notification. The service and the plugin themselves have no
/// platform side under `flutter_tester`.
void main() {
  group('the push key', () {
    test('is 32 random bytes as unpadded base64url, safe in a query and a path',
        () {
      final key = PushKeyStore.generate();

      expect(key, hasLength(43));
      expect(key, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(Uri.encodeComponent(key), key);
    });

    test('differs between installs', () {
      expect(PushKeyStore.generate(), isNot(PushKeyStore.generate()));
    });
  });

  test('the background hub URL carries the key at the API origin', () {
    expect(
      BackgroundPushChannel.hubUrlFor(
        'https://akcarsapi.0coders.com/api/v1',
        'abc_DEF-123',
      ),
      'https://akcarsapi.0coders.com/hubs/notifications?device_key=abc_DEF-123',
    );
  });

  group('notification ids', () {
    const rowId = '3f785ad7-1f0d-41fa-9ba0-cc7831e4ef5d';

    test('are FNV-1a of the row id, so every isolate posts the same one', () {
      expect(NotificationDisplay.idFor(''), 0x011c9dc5);
      expect(NotificationDisplay.idFor(rowId), NotificationDisplay.idFor(rowId));
      expect(
        NotificationDisplay.idFor(rowId),
        isNot(NotificationDisplay.idFor('3f785ad7-1f0d-41fa-9ba0-cc7831e4ef5e')),
      );
    });

    test('are positive 31-bit ints and never the service’s own notification',
        () {
      for (var i = 0; i < 5000; i++) {
        final id = NotificationDisplay.idFor('row-$i');
        expect(id, inInclusiveRange(0, 0x7fffffff));
        expect(id, isNot(NotificationDisplay.connectionNotificationId));
      }
    });
  });

  group('reconnecting', () {
    test('backs off, then settles at the cap instead of giving up', () {
      expect(BackgroundPushChannel.retryDelay(0), const Duration(seconds: 2));
      expect(BackgroundPushChannel.retryDelay(4), const Duration(minutes: 2));
      expect(
        BackgroundPushChannel.retryDelay(5),
        BackgroundPushChannel.maxRetryDelay,
      );
      expect(
        BackgroundPushChannel.retryDelay(10000),
        BackgroundPushChannel.maxRetryDelay,
      );
    });

    test('only the API refusing the key stops it', () {
      expect(
        BackgroundPushChannel.isKeyRejection(HttpError('Unauthorized', 401)),
        isTrue,
      );
      expect(
        BackgroundPushChannel.isKeyRejection(
          GeneralError('Unexpected status code returned from negotiate 401'),
        ),
        isTrue,
      );
      expect(
        BackgroundPushChannel.isKeyRejection(HttpError('Bad Gateway', 502)),
        isFalse,
      );
      expect(
        BackgroundPushChannel.isKeyRejection(
          Exception('SocketException: Failed host lookup'),
        ),
        isFalse,
      );
      expect(BackgroundPushChannel.isKeyRejection(null), isFalse);
    });
  });

  group('catch-up after a gap', () {
    final now = DateTime.utc(2026, 9, 15, 12);
    const overlap = BackgroundPushChannel.catchUpOverlap;

    test('a first connect looks back only the overlap', () {
      expect(
        BackgroundPushChannel.catchUpSince(null, now),
        now.subtract(overlap),
      );
    });

    test('starts from when the connection was last alive, minus the overlap',
        () {
      final alive = now.subtract(const Duration(hours: 3));

      expect(
        BackgroundPushChannel.catchUpSince(alive, now),
        alive.subtract(overlap),
      );
    });

    test('never reaches further back than the window', () {
      expect(
        BackgroundPushChannel.catchUpSince(
          now.subtract(const Duration(days: 30)),
          now,
        ),
        now.subtract(BackgroundPushChannel.catchUpWindow),
      );
    });

    test('a clock that jumped cannot move it into the future', () {
      expect(
        BackgroundPushChannel.catchUpSince(
          now.add(const Duration(hours: 1)),
          now,
        ),
        now.subtract(overlap),
      );
    });
  });

  group('already-shown ids', () {
    test('keep the newest, bounded', () {
      var shown = <String>[];
      for (var i = 0; i < 150; i++) {
        shown = BackgroundPushChannel.rememberShown(shown, 'n$i');
      }

      expect(shown, hasLength(BackgroundPushChannel.shownIdsLimit));
      expect(shown.first, 'n50');
      expect(shown.last, 'n149');
    });

    test('an id shown again moves to the newest end, not in twice', () {
      expect(
        BackgroundPushChannel.rememberShown(['a', 'b', 'c'], 'a'),
        ['b', 'c', 'a'],
      );
    });
  });

  group('jwtSubject — which account the key was registered for', () {
    String token(Map<String, dynamic> claims) =>
        'e30.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.sig';

    test('reads the account id the API issues as sub', () {
      expect(
        jwtSubject(token({'sub': '0b8f6a1e-5d0c-4f6e-9d57-3c1f0a2b7e44'})),
        '0b8f6a1e-5d0c-4f6e-9d57-3c1f0a2b7e44',
      );
    });

    test('is null for no token, a malformed one, or one without sub', () {
      expect(jwtSubject(null), isNull);
      expect(jwtSubject('not-a-jwt'), isNull);
      expect(jwtSubject(token({'jti': 'x'})), isNull);
    });
  });
}
