import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../models/app_notification.dart';
import '../notification_service.dart';

/// The inbox over REST (§12) — server-owned in production.
///
/// The server raises every notification as a side effect of the event that
/// caused it; the app only fetches and marks-read.
class ApiNotificationService implements NotificationService {
  const ApiNotificationService(this._client);

  final ApiClient _client;

  @override
  Future<List<AppNotification>> fetchNotifications() async =>
      (await _client.getList(ApiEndpoints.notifications))
          .map(AppNotification.fromJson)
          .toList();

  // The route answers with the whole inbox, not 204 — markAllRead() is typed
  // Future<List<AppNotification>> and the screen rebuilds from what it
  // returns.
  @override
  Future<List<AppNotification>> markAllRead() async =>
      (await _client.postList(ApiEndpoints.markNotificationsRead))
          .map(AppNotification.fromJson)
          .toList();

  @override
  Future<List<AppNotification>> markRead(String id) async =>
      (await _client.postList(ApiEndpoints.markNotificationRead(id)))
          .map(AppNotification.fromJson)
          .toList();

  // DELETE is the verb the caller means — it leaves their inbox. What the
  // server does with the row is its business, and it keeps it.
  @override
  Future<List<AppNotification>> dismiss(String id) async =>
      (await _client.deleteList(ApiEndpoints.notification(id)))
          .map(AppNotification.fromJson)
          .toList();

  @override
  Future<List<AppNotification>> dismissAll() async =>
      (await _client.deleteList(ApiEndpoints.notifications))
          .map(AppNotification.fromJson)
          .toList();

  @override
  Future<AppNotification> push({
    required L title,
    required L body,
    IconData icon = LucideIcons.bell,
    String? route,
  }) =>
      throw UnsupportedError(
        'Notifications are raised by the server, as a side effect of the '
        'event that caused them. NotificationRepositoryImpl.notify*() must '
        'not call push().',
      );
}
