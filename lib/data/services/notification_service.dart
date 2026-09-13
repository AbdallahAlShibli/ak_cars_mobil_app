import 'package:flutter/widgets.dart';

import '../../core/i18n/strings.dart';
import '../models/app_notification.dart';

/// The in-app notification inbox.
///
/// In production these arrive from the server (push + a fetch on open); in
/// the staging build the app raises them itself as the simulated provider and
/// store move a request or order along. Either way the inbox is owned here,
/// not by a widget.
///
/// Phase 2: implement `RestNotificationService` against `/notifications`.
abstract interface class NotificationService {
  Future<List<AppNotification>> fetchNotifications();

  /// Records a notification and returns it.
  Future<AppNotification> push({
    required L title,
    required L body,
    IconData icon,
    String? route,
  });

  Future<List<AppNotification>> markAllRead();

  /// Marks one notification read. Answers with the whole remaining inbox, the
  /// same shape [markAllRead] uses — the screen rebuilds from the response
  /// rather than patching its own copy and hoping the two agree.
  Future<List<AppNotification>> markRead(String id);

  /// Takes one notification off the owner's list.
  ///
  /// **A dismissal, not a delete.** The server stamps `dismissedAt` and keeps
  /// the row: whether a customer was told their money moved is a question
  /// support has to answer months later, and an inbox is the first thing
  /// anybody clears out.
  Future<List<AppNotification>> dismiss(String id);

  /// Takes every visible notification off the owner's list, on the same terms
  /// as [dismiss].
  Future<List<AppNotification>> dismissAll();
}
