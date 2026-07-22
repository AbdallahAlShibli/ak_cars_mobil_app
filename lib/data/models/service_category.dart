import 'package:flutter/widgets.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';

/// A bookable service family (major service, tyres, roadside …).
class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.note,
    this.emergency = false,
    this.badge,
    this.primary = false,
  });

  final String id;
  final L name;
  final IconData icon;

  /// Shown on the card when the category has no price to quote from (e.g.
  /// "quote after inspection"). Real prices are derived from the offerings —
  /// see `ServiceMarketplaceRepository.fromPriceFor`.
  final L? note;
  final bool emergency;

  /// Promo ribbon shown on the card (e.g. "FREE OIL").
  final L? badge;

  /// Primary = big "Car service" package card; otherwise an
  /// "Other services" tile.
  final bool primary;

  factory ServiceCategory.fromJson(JsonMap json) => ServiceCategory(
        id: json.requireString('id'),
        name: L.fromJson(json['name']),
        icon: IconCodec.decode(json.stringOrNull('icon')),
        note: json['note'] == null ? null : L.fromJson(json['note']),
        emergency: json.boolOr('emergency', false),
        badge: json['badge'] == null ? null : L.fromJson(json['badge']),
        primary: json.boolOr('primary', false),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name.toJson(),
        'icon': IconCodec.encode(icon),
        'note': note?.toJson(),
        'emergency': emergency,
        'badge': badge?.toJson(),
        'primary': primary,
      };

  ServiceCategory copyWith({
    String? id,
    L? name,
    IconData? icon,
    L? note,
    bool? emergency,
    L? badge,
    bool? primary,
  }) =>
      ServiceCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        note: note ?? this.note,
        emergency: emergency ?? this.emergency,
        badge: badge ?? this.badge,
        primary: primary ?? this.primary,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceCategory &&
      other.id == id &&
      other.name == name &&
      other.icon == icon &&
      other.note == note &&
      other.emergency == emergency &&
      other.badge == badge &&
      other.primary == primary;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        icon,
        note,
        emergency,
        badge,
        primary,
      );
}
