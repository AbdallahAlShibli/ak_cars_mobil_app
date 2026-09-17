import 'dart:async';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../data/models/app_notification.dart';
import '../constants/app_constants.dart';
import 'notification_display.dart';
import 'push_service.dart';

/// The background push service's connection to `/hubs/notifications`, run in
/// the service's own isolate while the app is closed.
///
/// It authenticates with this install's push key (`?device_key=`), never the
/// session; see `PushKeyStore` for why. It does not give up on its own: a
/// failed connect is retried with a capped back-off, and a dropped connection
/// reconnects indefinitely. Every (re)connect asks the hub what was `Missed`
/// since the connection was last known alive, so a row raised during a network
/// gap, or while the phone dozed, still reaches the notification center. A
/// short list of already-shown ids keeps that catch-up from repeating a banner.
///
/// Only the API refusing the key ends it — signed out on another path, or the
/// app not opened for the whole session lifetime. `onKeyRejected` then stops
/// the service until the app registers the key again.
class BackgroundPushChannel {
  BackgroundPushChannel({
    required this._hubUrl,
    required this._display,
    required this._preferences,
    required this._onKeyRejected,
  });

  static const deviceKeyParameter = 'device_key';
  static const missedMethod = 'Missed';

  static const shownIdsLimit = 100;
  static const aliveInterval = Duration(minutes: 1);

  /// How far before the last-alive moment catch-up starts, covering a row
  /// raised just before the drop and a phone clock a little off the server's.
  static const catchUpOverlap = Duration(minutes: 2);

  /// The furthest back catch-up ever reaches; matches the hub's own bound.
  static const catchUpWindow = Duration(days: 3);

  static const _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
  ];
  static const maxRetryDelay = Duration(minutes: 5);

  final String _hubUrl;
  final NotificationDisplay _display;
  final SharedPreferences _preferences;
  final void Function() _onKeyRejected;

  HubConnection? _connection;
  Timer? _aliveTimer;
  Completer<void>? _wake;
  var _closed = false;
  Future<void> _showing = Future.value();

  /// The notification hub for [apiBaseUrl], carrying [pushKey].
  static String hubUrlFor(String apiBaseUrl, String pushKey) =>
      Uri.parse(PushService.hubUrl(apiBaseUrl))
          .replace(queryParameters: {deviceKeyParameter: pushKey})
          .toString();

  /// The wait after [failures] consecutive failed attempts.
  static Duration retryDelay(int failures) =>
      failures >= 0 && failures < _retryDelays.length
      ? _retryDelays[failures]
      : maxRetryDelay;

  /// Whether [error] is the API refusing the push key, rather than a network
  /// or server fault worth retrying. A refused negotiate surfaces either as an
  /// [HttpError] or as a general error naming the status.
  static bool isKeyRejection(Object? error) =>
      (error is HttpError && error.statusCode == 401) ||
      (error != null && '$error'.contains('negotiate 401'));

  /// Where catch-up starts: [catchUpOverlap] before the connection was last
  /// known alive, never further back than [catchUpWindow], and never later
  /// than [catchUpOverlap] ago — so a clock that jumped cannot skip rows.
  static DateTime catchUpSince(DateTime? aliveAt, DateTime now) {
    final latest = now.subtract(catchUpOverlap);
    if (aliveAt == null) return latest;
    final since = aliveAt.subtract(catchUpOverlap);
    if (since.isAfter(latest)) return latest;
    final earliest = now.subtract(catchUpWindow);
    return since.isBefore(earliest) ? earliest : since;
  }

  /// [shown] with [id] as its newest entry, keeping the newest
  /// [shownIdsLimit].
  static List<String> rememberShown(List<String> shown, String id) {
    final next = [...shown.where((existing) => existing != id), id];
    return next.length <= shownIdsLimit
        ? next
        : next.sublist(next.length - shownIdsLimit);
  }

  /// Connects and stays connected until [close] or a refused key.
  Future<void> run() async {
    var failures = 0;
    while (!_closed) {
      final outcome = await _connectOnce();
      if (_closed || outcome == _Outcome.rejected) return;
      failures = outcome == _Outcome.ended ? 0 : failures + 1;
      await _sleep(retryDelay(failures));
    }
  }

  Future<void> close() async {
    _closed = true;
    _aliveTimer?.cancel();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    final connection = _connection;
    _connection = null;
    if (connection == null) return;
    try {
      await connection.stop();
    } catch (error, stack) {
      _log('Background connection failed to stop cleanly', error, stack);
    }
  }

  Future<_Outcome> _connectOnce() async {
    final connection = HubConnectionBuilder()
        .withUrl(_hubUrl)
        .withAutomaticReconnect(reconnectPolicy: const _KeepTrying())
        .build();
    final ended = Completer<Exception?>();
    connection.on(PushService.frameMethod, (arguments) {
      final row = PushService.decodeFrame(arguments);
      if (row != null) _enqueueShow(row);
    });
    connection.onreconnecting(({error}) => unawaited(_markAlive()));
    connection.onreconnected(
      ({connectionId}) => unawaited(_catchUp(connection)),
    );
    connection.onclose(({error}) {
      if (!ended.isCompleted) ended.complete(error);
    });

    _connection = connection;
    try {
      await connection.start();
    } catch (error, stack) {
      _connection = null;
      if (isKeyRejection(error)) {
        _log('The API refused this install\'s push key; stopping', error, stack);
        _onKeyRejected();
        return _Outcome.rejected;
      }
      _log('Background connection failed to connect; retrying', error, stack);
      return _Outcome.failed;
    }

    _aliveTimer = Timer.periodic(aliveInterval, (_) => unawaited(_markAlive()));
    await _catchUp(connection);
    final error = await ended.future;
    _aliveTimer?.cancel();
    _connection = null;
    await _markAlive();
    if (error != null && isKeyRejection(error)) {
      _log('The API refused this install\'s push key; stopping', error,
          StackTrace.current);
      _onKeyRejected();
      return _Outcome.rejected;
    }
    return _Outcome.ended;
  }

  /// A wait that [close] cuts short.
  Future<void> _sleep(Duration duration) {
    final wake = _wake = Completer<void>();
    final timer = Timer(duration, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future.whenComplete(timer.cancel);
  }

  Future<void> _catchUp(HubConnection connection) async {
    try {
      final since = catchUpSince(_aliveAt, DateTime.now().toUtc());
      final rows = await connection.invoke(
        missedMethod,
        args: [since.toIso8601String()],
      );
      await _markAlive();
      if (rows is! List) return;
      for (final item in rows) {
        final row = PushService.decodeFrame([item]);
        if (row != null) _enqueueShow(row);
      }
    } catch (error, stack) {
      _log('Could not fetch notifications missed while disconnected', error,
          stack);
    }
  }

  /// One row at a time, so a frame and a catch-up carrying the same row
  /// cannot both pass the already-shown check.
  void _enqueueShow(Map<String, dynamic> row) {
    _showing = _showing.then((_) => _showOnce(row)).catchError(
      (Object error, StackTrace stack) =>
          _log('Could not show a background notification', error, stack),
    );
  }

  Future<void> _showOnce(Map<String, dynamic> row) async {
    // Language and the Notifications switch are written by the app's own
    // isolate; without a reload this one keeps the values it started with.
    await _preferences.reload();
    if (!(_preferences.getBool(AppConstants.prefsNotifications) ?? true)) {
      return;
    }
    final notification = AppNotification.fromJson(row);
    if (notification.read) return;
    final shown =
        _preferences.getStringList(AppConstants.prefsPushShownIds) ?? const [];
    if (shown.contains(notification.id)) return;

    final language =
        _preferences.getString(AppConstants.prefsLanguage) ?? 'ar';
    final (title, body) = PushService.textFor(notification, language);
    await _display.show(
      notificationId: notification.id,
      title: title,
      body: body,
      route: notification.route,
    );
    await _preferences.setStringList(
      AppConstants.prefsPushShownIds,
      rememberShown(shown, notification.id),
    );
  }

  DateTime? get _aliveAt => DateTime.tryParse(
    _preferences.getString(AppConstants.prefsPushAliveAt) ?? '',
  );

  Future<void> _markAlive() async {
    try {
      await _preferences.setString(
        AppConstants.prefsPushAliveAt,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (error, stack) {
      _log('Could not record the connection as alive', error, stack);
    }
  }

  // Never logs the hub URL: it carries the push key.
  static void _log(String message, Object error, StackTrace stack) =>
      developer.log(
        message,
        name: 'BackgroundPush',
        error: error,
        stackTrace: stack,
      );
}

enum _Outcome { ended, failed, rejected }

/// SignalR's default policy gives up after four attempts; a service whose
/// whole job is to stay connected must not. A refused key is the exception.
class _KeepTrying implements IRetryPolicy {
  const _KeepTrying();

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) =>
      BackgroundPushChannel.isKeyRejection(retryContext.retryReason)
      ? null
      : BackgroundPushChannel.retryDelay(
          retryContext.previousRetryCount,
        ).inMilliseconds;
}
