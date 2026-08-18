import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../data/models/app_notification.dart';
import '../di/providers.dart';

/// The notification inbox, mirrored from the repository.
///
/// The repository owns both the store and the message copy; this notifier's
/// only job is to expose it to the widget tree and keep the unread badge
/// live.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  /// See [ReviewsNotifier]'s field of the same name — identical hazard, since
  /// [_loadFromServer] is also started from [build] and left unawaited.
  bool _disposed = false;

  @override
  List<AppNotification> build() {
    ref.onDispose(() => _disposed = true);
    // The inbox is server-owned: load the fetched rows and keep listening for
    // pushes.
    unawaited(load());
    _subscribeToPush();
    return const [];
  }

  /// A `401` here means "nobody is signed in", the same ordinary cold-start
  /// case [AppBootstrap.warmUp] skips for the other auth-gated repositories —
  /// this one is not warmed there because the inbox loads lazily from [build],
  /// so it needs the same session guard here instead. Without it a guest's
  /// cold start still spent a round trip on an inbox that can only come back
  /// `401`, which is the one auth-gated request bootstrap's guard cannot cover.
  ///
  /// Public because [build] is not the only caller any more: [SessionRefresh]
  /// calls it again at sign-in. The alternative — invalidating this provider —
  /// would rebuild the notifier and open a *second* push subscription without
  /// closing the first, so the same message would be adopted twice.
  Future<void> load() async {
    if (_disposed) return;
    if (!await ref.read(tokenStoreProvider).mayHaveSession()) return;
    if (_disposed) return;
    try {
      final inbox =
          await ref.read(notificationRepositoryProvider).fetchNotifications();
      if (_disposed) return;
      state = inbox;
    } on UnauthorizedException {
      // Still reachable above the guard on an expired token. Leave the guest
      // inbox empty either way; signing in rebuilds this notifier.
    }
  }

  /// Drops this account's inbox on sign-out.
  ///
  /// A direct `state =` write, for the same reason [load]'s own doc comment
  /// gives for not invalidating this provider: invalidating would rebuild the
  /// notifier and open a second push subscription without closing the first.
  /// `SessionRefresh.clearAfterSignOut` also hit a second, independent problem
  /// invalidating a `NotifierProvider` read via `.notifier` outside a widget's
  /// `watch` — see `RequestsNotifier.clear`'s doc comment — so this is the
  /// fix for both at once.
  void clear() => state = const [];

  void _subscribeToPush() {
    // A push and a fetched inbox row decode from the same JSON shape, so
    // this never renders a differently-worded copy of an event already on
    // screen.
    ref.read(pushServiceProvider).dataMessages().listen(
          (data) => adopt(AppNotification.fromJson(data)),
        );
  }

  /// Adds a notification the repository has just raised to the inbox.
  ///
  /// Notifications are always *authored* by the repository — the copy for
  /// every lifecycle event lives there, not in a widget — so this notifier
  /// only ever adopts the result.
  void adopt(AppNotification? notification) {
    if (notification == null) return;
    state = [notification, ...state];
  }

  Future<void> markAllRead() async {
    state = [for (final n in state) n.copyWith(read: true)];
    await ref.read(notificationRepositoryProvider).markAllRead();
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
        NotificationsNotifier.new);

final unreadCountProvider = Provider<int>(
    (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);
