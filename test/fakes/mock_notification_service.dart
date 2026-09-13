import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
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

  /// Mirrors a server-side identity sequence.
  int _nextId = 0;

  /// Ids the owner has taken off their list. Kept beside the rows rather than
  /// removing them, because that is what the server does: `dismissedAt` is
  /// stamped and the record survives.
  final Set<String> _dismissed = {};

  @override
  Future<List<AppNotification>> fetchNotifications() => respond(_inbox);

  @override
  Future<AppNotification> push({
    required L title,
    required L body,
    IconData icon = LucideIcons.bell,
    String? route,
  }) {
    final notification = AppNotification(
      // A counter, not the clock: `DateTime.now()` has millisecond resolution
      // on Windows, so pushing several notifications inside one tick handed
      // them all the same id — after which dismissing one hid every one of
      // them. Ids have to be unique for the store to behave like a table.
      id: 'n${++_nextId}',
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
      if (_dismissed.contains(_notifications[i].id)) continue;
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
    return respond(_inbox);
  }

  @override
  Future<List<AppNotification>> markRead(String id) {
    final at = _notifications.indexWhere((n) => n.id == id);
    if (at < 0) throw NotFoundException('Notification $id not found');
    _notifications[at] = _notifications[at].copyWith(read: true);
    return respond(_inbox);
  }

  // Dismissal is modelled the way the server models it — the row stays and
  // stops being returned. A fake that removed it outright would let a test
  // pass on "deleted", which is the one thing this must not do.
  @override
  Future<List<AppNotification>> dismiss(String id) {
    final at = _notifications.indexWhere((n) => n.id == id);
    if (at < 0) throw NotFoundException('Notification $id not found');
    _dismissed.add(id);
    return respond(_inbox);
  }

  @override
  Future<List<AppNotification>> dismissAll() {
    _dismissed.addAll(_notifications.map((n) => n.id));
    return respond(_inbox);
  }

  /// Everything the store holds, dismissed rows included — the assertion hook
  /// for "hidden, not deleted".
  List<AppNotification> get allIncludingDismissed =>
      List<AppNotification>.unmodifiable(_notifications);

  List<AppNotification> get _visible => [
        for (final n in _notifications)
          if (!_dismissed.contains(n.id)) n,
      ];

  List<AppNotification> get _inbox =>
      List<AppNotification>.unmodifiable(_visible);
}
