import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_notification.dart';
import '../di/providers.dart';

/// The notification inbox, mirrored from the repository.
///
/// The repository owns both the store and the message copy; this notifier's
/// only job is to expose it to the widget tree and keep the unread badge
/// live.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => const [];

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
