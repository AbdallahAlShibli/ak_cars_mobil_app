import 'package:flutter/widgets.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';
import 'powertrain.dart';
import 'service_provider.dart';

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
    this.powertrains = const {},
    this.requires,
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

  /// Which powertrains this service is for. Empty means "every car" — the
  /// normal case, and the reason an existing category needed no change when
  /// this field was added.
  ///
  /// A non-empty set is a real restriction, not a hint: booking a high-voltage
  /// battery diagnostic for a petrol Camry is not a thing a workshop can do.
  final Set<Powertrain> powertrains;

  /// Capability a workshop must hold to sell this category. Null means any
  /// workshop can. Used to keep the demo catalogue honest — only EV-certified
  /// workshops appear under the EV categories — and to state on screen *why*
  /// the shortlist is shorter than usual.
  final ProviderCapability? requires;

  /// True when this category exists only for cars that plug in.
  bool get evOnly =>
      powertrains.isNotEmpty && powertrains.every((p) => p.plugsIn);

  /// Whether a car with this [powertrain] can book this service. An unknown
  /// powertrain sees everything: the app must not hide a service because the
  /// owner has not filled a field in.
  bool appliesTo(Powertrain? powertrain) =>
      powertrains.isEmpty || powertrain == null ||
      powertrains.contains(powertrain);

  factory ServiceCategory.fromJson(JsonMap json) => ServiceCategory(
        id: json.requireString('id'),
        name: L.fromJson(json['name']),
        icon: IconCodec.decode(json.stringOrNull('icon')),
        note: json['note'] == null ? null : L.fromJson(json['note']),
        emergency: json.boolOr('emergency', false),
        badge: json['badge'] == null ? null : L.fromJson(json['badge']),
        primary: json.boolOr('primary', false),
        powertrains: {
          for (final key in json.stringList('powertrains'))
            ?PowertrainX.fromKey(key),
        },
        requires:
            ProviderCapabilityX.fromKey(json.stringOrNull('requires')),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name.toJson(),
        'icon': IconCodec.encode(icon),
        'note': note?.toJson(),
        'emergency': emergency,
        'badge': badge?.toJson(),
        'primary': primary,
        'powertrains': [for (final p in powertrains) p.key],
        'requires': requires?.key,
      };

  ServiceCategory copyWith({
    String? id,
    L? name,
    IconData? icon,
    L? note,
    bool? emergency,
    L? badge,
    bool? primary,
    Set<Powertrain>? powertrains,
    ProviderCapability? requires,
  }) =>
      ServiceCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        note: note ?? this.note,
        emergency: emergency ?? this.emergency,
        badge: badge ?? this.badge,
        primary: primary ?? this.primary,
        powertrains: powertrains ?? this.powertrains,
        requires: requires ?? this.requires,
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
      other.primary == primary &&
      other.requires == requires &&
      other.powertrains.length == powertrains.length &&
      other.powertrains.containsAll(powertrains);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        icon,
        note,
        emergency,
        badge,
        primary,
        requires,
        Object.hashAllUnordered(powertrains),
      );
}
