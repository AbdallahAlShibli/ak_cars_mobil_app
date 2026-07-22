import 'package:flutter/widgets.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';

/// An in-app notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.time,
    this.read = false,
    this.route,
  });

  final String id;

  /// Bilingual — notifications are stored, so they must render in whatever
  /// language is active when the user reads them, not when they were pushed.
  final L title;
  final L body;
  final IconData icon;
  final DateTime time;
  final bool read;

  /// Deep link opened when the notification is tapped.
  final String? route;

  factory AppNotification.fromJson(JsonMap json) => AppNotification(
        id: json.requireString('id'),
        title: L.fromJson(json['title']),
        body: L.fromJson(json['body']),
        icon: IconCodec.decode(json.stringOrNull('icon')),
        time: json.dateTimeOr('time', DateTime.now()),
        read: json.boolOr('read', false),
        route: json.stringOrNull('route'),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title.toJson(),
        'body': body.toJson(),
        'icon': IconCodec.encode(icon),
        'time': time.toIso8601String(),
        'read': read,
        'route': route,
      };

  AppNotification copyWith({
    String? id,
    L? title,
    L? body,
    IconData? icon,
    DateTime? time,
    bool? read,
    String? route,
  }) =>
      AppNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        icon: icon ?? this.icon,
        time: time ?? this.time,
        read: read ?? this.read,
        route: route ?? this.route,
      );

  @override
  bool operator ==(Object other) =>
      other is AppNotification &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.icon == icon &&
      other.time == time &&
      other.read == read &&
      other.route == route;

  @override
  int get hashCode => Object.hash(id, title, body, icon, time, read, route);
}
