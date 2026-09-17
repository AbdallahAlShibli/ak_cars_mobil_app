import 'dart:async';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../config/app_config.dart';
import '../../data/models/app_notification.dart';
import '../../data/services/token_store.dart';
import '../constants/api_endpoints.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../utils/jwt_claims.dart';
import 'background_push.dart';
import 'notification_display.dart';
import 'push_key_store.dart';

/// AK Cars' own push channel — no third-party push provider.
///
/// While a signed-in app runs it holds one SignalR connection to the API's
/// `/hubs/notifications`. Every inbox row the server raises for this account
/// arrives on it as a `Notification` frame carrying the same JSON
/// `GET /notifications` returns:
///
///  * it is published on [dataMessages], which the inbox adopts; and
///  * while the Notifications setting is on, it is shown in the notification
///    center (via [NotificationDisplay]), worded in the app's current
///    language. A tap arrives on [openedRoutes].
///
/// **Once the app is closed** that connection goes with it: Android kills or
/// freezes backgrounded apps, and only FCM/APNs can wake one. On Android,
/// [BackgroundPush] closes the gap with a foreground service holding its own
/// connection, authenticated by this install's push key ([PushKeyStore])
/// rather than the session. Every [start] registers the key for the signed-in
/// account and starts that service; [stop] ends both. iOS has no equivalent
/// without APNs, so there a closed app shows nothing until it is opened — and
/// every (re)connect, announced on [connections], is followed by a fetch of
/// the inbox, so no row is lost.
///
/// Every method is defensive: a hub that is unreachable, or a platform with
/// no notification support, is logged and swallowed. The inbox is the record;
/// this channel only shortens the wait, so it must never be the reason sign-in
/// or app boot fails.
class PushService {
  PushService({
    required AppConfig config,
    required this._tokens,
    required this._client,
    this._preferences,
    PushKeyStore? keys,
    NotificationDisplay? display,
    this._background = const BackgroundPush(),
  }) : _url = hubUrl(config.apiBaseUrl),
       _keys = keys ?? PushKeyStore(),
       _display = display ?? NotificationDisplay();

  /// The hub method the API's `NotificationHub` sends rows on.
  static const frameMethod = 'Notification';

  /// How often a push key that is still valid is registered again. The API
  /// lets a key lapse after the refresh-token lifetime (30 days) without one.
  static const registrationRefresh = Duration(days: 1);

  final String _url;
  final TokenStore _tokens;
  final ApiClient _client;
  final SharedPreferences? _preferences;
  final PushKeyStore _keys;
  final NotificationDisplay _display;
  final BackgroundPush _background;

  final _rows = StreamController<Map<String, dynamic>>.broadcast();
  final _connected = StreamController<void>.broadcast();
  final _taps = StreamController<String?>.broadcast();

  HubConnection? _connection;
  Future<void>? _starting;
  Future<void>? _syncingBackground;
  bool _pluginReady = false;
  bool _permissionAsked = false;

  /// Where the notification hub lives for a given REST base URL — mapped at
  /// the API's root, outside the `/api/v1` group, like the chat hub.
  static String hubUrl(String apiBaseUrl) =>
      Uri.parse(apiBaseUrl).resolve('/hubs/notifications').toString();

  /// Opens the channel for the signed-in account and brings the background
  /// service in line with the account and the Notifications setting. A no-op
  /// for a guest; safe to call on every sign-in, cold start, return to the
  /// foreground and change of that setting.
  Future<void> start() =>
      _starting ??= _start().whenComplete(() => _starting = null);

  Future<void> _start() async {
    if (!await _tokens.mayHaveSession()) return;
    await _ensureLocalNotifications();
    unawaited(_syncBackground());

    final existing = _connection;
    if (existing != null &&
        existing.state != HubConnectionState.Disconnected) {
      return;
    }
    final connection = existing ?? _buildConnection();
    _connection = connection;
    try {
      await connection.start();
      _connected.add(null);
    } catch (error, stack) {
      _log(
        'Notification channel failed to connect — the inbox still loads '
        'when opened, and the next start() tries again',
        error,
        stack,
      );
    }
  }

  HubConnection _buildConnection() {
    final connection = HubConnectionBuilder()
        .withUrl(
          _url,
          options: HttpConnectionOptions(
            // `tryRead…`: an unreadable store yields the same empty string a
            // signed-out user gets, which the hub refuses as an ordinary
            // unauthorized connection.
            accessTokenFactory: () async =>
                await _tokens.tryReadAccessToken() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();
    connection.on(frameMethod, _onFrame);
    connection.onreconnected(({connectionId}) => _connected.add(null));
    return connection;
  }

  /// Sign-out. Stops the background service and deletes this install's push
  /// key on the server, then closes the channel — all before the tokens are
  /// cleared, since unregistering needs the session. The next account on a
  /// shared phone never receives this one's rows.
  Future<void> stop() async {
    await _retireBackground();
    await _closeConnection();
  }

  /// Wired to `pushServiceProvider`'s `onDispose`. Not [stop]: tearing the
  /// provider down (a hot restart, a test container) is not a sign-out and
  /// must not unregister the device.
  Future<void> dispose() async {
    await _closeConnection();
    await _rows.close();
    await _connected.close();
    await _taps.close();
  }

  /// Inbox rows as they are raised, in the `GET /notifications` shape.
  Stream<Map<String, dynamic>> dataMessages() => _rows.stream;

  /// Fires after every successful connect and reconnect — the moments a fetch
  /// is needed to pick up whatever was raised while the channel was down.
  Stream<void> connections() => _connected.stream;

  /// The route of each system notification the user taps (including the one
  /// that launched the app), or null when it names none.
  Stream<String?> openedRoutes() => _taps.stream;

  Future<void> _closeConnection() async {
    final connection = _connection;
    _connection = null;
    if (connection == null) return;
    try {
      await connection.stop();
    } catch (error, stack) {
      _log('Notification channel failed to stop cleanly', error, stack);
    }
  }

  void _onFrame(List<Object?>? arguments) {
    final row = decodeFrame(arguments);
    if (row == null || _rows.isClosed) return;
    _rows.add(row);
    // Into the notification center whether or not the app is open. On
    // Android the background service may post the same row; both use the
    // row's own notification id, so it lands once.
    if (_notificationsEnabled) unawaited(_show(row));
  }

  Future<void> _syncBackground() => _syncingBackground ??= _doSyncBackground()
      .whenComplete(() => _syncingBackground = null);

  Future<void> _doSyncBackground() async {
    if (!BackgroundPush.isSupported) return;
    if (!_notificationsEnabled) {
      await _background.disable();
      return;
    }
    var accountSwitched = false;
    try {
      final (:key, :created) = await _keys.readOrCreate();
      final account = jwtSubject(await _tokens.tryReadAccessToken());
      final registeredFor = _preferences?.getString(
        AppConstants.prefsPushRegisteredFor,
      );
      if (created || _registrationIsStale(account, registeredFor)) {
        await _client.post(
          ApiEndpoints.notificationDevices,
          body: {'token': key, 'platform': 'android'},
        );
        await _recordRegistration(account);
        accountSwitched =
            registeredFor != null && account != null && registeredFor != account;
      }
    } catch (error, stack) {
      _log(
        'Could not register this install\'s push key — the background '
        'service keeps its last registration, if it has one',
        error,
        stack,
      );
    }
    // The server moved the key to this account, but a service that is
    // already connected is still authenticated as the previous one.
    if (accountSwitched) {
      await _background.restart(languageCode: _language, display: _display);
    } else {
      await _background.enable(languageCode: _language, display: _display);
    }
  }

  bool _registrationIsStale(String? account, String? registeredFor) {
    final registeredAt = DateTime.tryParse(
      _preferences?.getString(AppConstants.prefsPushRegisteredAt) ?? '',
    );
    return registeredAt == null ||
        DateTime.now().toUtc().difference(registeredAt) > registrationRefresh ||
        account == null ||
        registeredFor != account;
  }

  Future<void> _recordRegistration(String? account) async {
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setString(
      AppConstants.prefsPushRegisteredAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    if (account == null) {
      await preferences.remove(AppConstants.prefsPushRegisteredFor);
    } else {
      await preferences.setString(AppConstants.prefsPushRegisteredFor, account);
    }
  }

  Future<void> _retireBackground() async {
    if (!BackgroundPush.isSupported) return;
    await _background.disable();
    final key = await _keys.tryRead();
    if (key != null) {
      try {
        await _client.delete(ApiEndpoints.notificationDevice(key));
      } catch (error, stack) {
        _log(
          'Could not unregister this install\'s push key — it is deleted on '
          'the device, so nothing presents it again, and the API lets it lapse',
          error,
          stack,
        );
      }
      await _keys.tryClear();
    }
    await _preferences?.remove(AppConstants.prefsPushRegisteredAt);
    await _preferences?.remove(AppConstants.prefsPushRegisteredFor);
  }

  Future<void> _ensureLocalNotifications() async {
    if (_pluginReady) return;
    final ready = await _display.initialize(
      onTap: (payload) {
        if (!_taps.isClosed) _taps.add(_routeOrNull(payload));
      },
    );
    if (!ready) return;
    _pluginReady = true;
    await _askPermissionOnce();

    final launch = await _display.launchDetails();
    if (launch.launched && !_taps.isClosed) {
      _taps.add(_routeOrNull(launch.payload));
    }
  }

  /// Asked once per process; a refusal only hides the banner, never the
  /// inbox.
  Future<void> _askPermissionOnce() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    await _display.requestPermission();
  }

  Future<void> _show(Map<String, dynamic> row) async {
    if (!_pluginReady) return;
    final AppNotification notification;
    try {
      notification = AppNotification.fromJson(row);
    } catch (error, stack) {
      _log('Could not read a pushed row', error, stack);
      return;
    }
    final (title, body) = textFor(notification, _language);
    await _display.show(
      notificationId: notification.id,
      title: title,
      body: body,
      route: notification.route,
    );
  }

  /// The app's current language; Arabic is the first-launch default (see
  /// `SettingsNotifier.build`).
  String get _language =>
      _preferences?.getString(AppConstants.prefsLanguage) ?? 'ar';

  /// The Settings screen's Notifications switch; on until turned off.
  bool get _notificationsEnabled =>
      _preferences?.getBool(AppConstants.prefsNotifications) ?? true;

  static void _log(String message, Object error, StackTrace stack) =>
      developer.log(
        message,
        name: 'PushService',
        error: error,
        stackTrace: stack,
      );

  /// The inbox row a `Notification` frame carries, or null for anything that
  /// is not exactly one row with an id.
  static Map<String, dynamic>? decodeFrame(List<Object?>? arguments) {
    if (arguments == null || arguments.length != 1) return null;
    final frame = arguments.first;
    if (frame is! Map) return null;
    final row = Map<String, dynamic>.from(frame);
    final id = row['id'];
    return id is String && id.isNotEmpty ? row : null;
  }

  /// Where tapping [row]'s system notification should go, or null.
  static String? routeOf(Map<String, dynamic> row) => _routeOrNull(row['route']);

  static String? _routeOrNull(Object? route) =>
      route is String && route.isNotEmpty ? route : null;

  /// The title and body a system notification shows, in [languageCode].
  static (String, String) textFor(
    AppNotification notification,
    String languageCode,
  ) => languageCode == 'en'
      ? (notification.title.en, notification.body.en)
      : (notification.title.ar, notification.body.ar);
}
