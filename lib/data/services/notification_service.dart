import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_config.dart';
import '../../core/i18n/strings.dart';
import '../models/app_notification.dart';
import 'mock_service_base.dart';

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

class MockNotificationService
    with MockServiceBase
    implements NotificationService {
  MockNotificationService({required this.config});

  @override
  final AppConfig config;

  /// Newest first — a fresh install has an empty inbox.
  final List<AppNotification> _notifications = [];

  @override
  Future<List<AppNotification>> fetchNotifications() =>
      respond(List<AppNotification>.unmodifiable(_notifications));

  @override
  Future<AppNotification> push({
    required L title,
    required L body,
    IconData icon = LucideIcons.bell,
    String? route,
  }) {
    final notification = AppNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      icon: icon,
      time: DateTime.now(),
      route: route,
    );
    _notifications.insert(0, notification);
    return respond(notification);
  }

  @override
  Future<List<AppNotification>> markAllRead() {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
    return respond(List<AppNotification>.unmodifiable(_notifications));
  }
}
