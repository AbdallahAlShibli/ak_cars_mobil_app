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
}
