import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../data/models/app_notification.dart';
import '../data/repositories/notification_repository.dart';
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
  /// would rebuild the notifier; [_subscribeToPush] now cancels on dispose so
  /// that no longer doubles every push, but a reload is still the cheaper of
  /// the two and keeps the inbox on screen while it runs.
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
  /// A direct `state =` write, not an invalidate.
  /// `SessionRefresh.clearAfterSignOut` hit a real problem invalidating a
  /// `NotifierProvider` read via `.notifier` outside a widget's `watch` — see
  /// `RequestsNotifier.clear`'s doc comment. (It also used to leak a second
  /// push subscription; [_subscribeToPush] cancels on dispose now, so that
  /// half is fixed at the source rather than avoided here.)
  void clear() => state = const [];

  void _subscribeToPush() {
    // A push and a fetched inbox row decode from the same JSON shape, so
    // this never renders a differently-worded copy of an event already on
    // screen.
    //
    // The subscription is held and cancelled on dispose. Dropping it — which
    // is what this did — outlives the notifier that owns it: a rebuilt
    // notifier leaves the old subscription live, so every push is adopted
    // once per orphaned listener, and the orphan's `adopt` writes `state` on
    // a disposed notifier. Same shape, same reason, as [RequestsNotifier]'s
    // timer cleanup.
    final subscription = ref
        .read(pushServiceProvider)
        .dataMessages()
        .listen((data) => adopt(AppNotification.fromJson(data)));
    ref.onDispose(subscription.cancel);
  }

  /// Adds a notification the repository has just raised to the inbox.
  ///
  /// Notifications are always *authored* by the repository — the copy for
  /// every lifecycle event lives there, not in a widget — so this notifier
  /// only ever adopts the result.
  void adopt(AppNotification? notification) {
    // Reachable after teardown: a push frame already in flight, or one of
    // the repository's `await`ed callers resuming past a sign-out.
    if (_disposed || notification == null) return;
    state = [notification, ...state];
  }

  Future<void> markAllRead() => _apply((repo) => repo.markAllRead());

  /// Marks one notification read — what tapping a card does, and what the
  /// card's own menu offers for one the reader does not want to open.
  Future<void> markRead(String id) => _apply((repo) => repo.markRead(id));

  /// Takes one notification off this user's list.
  ///
  /// **Hidden, not destroyed.** The server keeps the row and stops returning
  /// it; see `NotificationService.dismiss` for why that record outlives the
  /// reader's housekeeping.
  Future<void> dismiss(String id) => _apply((repo) => repo.dismiss(id));

  /// The same for the whole visible inbox.
  Future<void> dismissAll() => _apply((repo) => repo.dismissAll());

  /// Runs one inbox write and adopts whatever the server says is left.
  ///
  /// **Deliberately not optimistic.** It used to apply the change locally
  /// first and roll back on failure, and that was wrong twice over. The list
  /// mutating mid-gesture is what `Dismissible` explicitly forbids — a refused
  /// dismissal put the same key back into a tree that had already recorded it
  /// as dismissed, which asserts — and the rollback did not actually restore
  /// the card, so a failed swipe silently lost a notification until the next
  /// fetch. The screen holds the swipe open across this call instead (see
  /// `confirmDismiss`), which is both correct and better feedback: the card
  /// stays under the finger until the server has actually agreed.
  ///
  /// The response *is* the new state — every one of these routes answers with
  /// the remaining visible inbox precisely so the screen cannot drift from it.
  /// Errors propagate; the screen reports them.
  Future<void> _apply(
    Future<List<AppNotification>> Function(NotificationRepository) call,
  ) async {
    if (_disposed) return;
    final inbox = await call(ref.read(notificationRepositoryProvider));
    if (_disposed) return;
    state = inbox;
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
        NotificationsNotifier.new);

final unreadCountProvider = Provider<int>(
    (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);
