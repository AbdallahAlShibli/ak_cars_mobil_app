import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/app_notification.dart';
import 'package:ak_cars_mobil_app/data/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'fake_service_base.dart';

class MockNotificationService
    with MockServiceBase
    implements NotificationService {
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
