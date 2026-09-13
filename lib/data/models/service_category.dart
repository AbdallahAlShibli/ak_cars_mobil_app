import 'package:flutter/widgets.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';
import 'powertrain.dart';
import 'service_provider.dart';

/// The editable half of a [ServiceCategory], as the founder's editor submits
/// it — everything except [ServiceCategory.id] (assigned by the server) and
/// [ServiceCategory.badge] (which has its own one-field write, because it is
/// the field that changes most often and the only one carrying no behaviour).
///
/// A separate type rather than a bag of named arguments on the service, because
/// create and update take exactly the same fields and a second parameter list
/// is how the two drift apart.
class ServiceCategoryDraft {
  const ServiceCategoryDraft({
    required this.slug,
    required this.name,
    required this.icon,
    this.note,
    this.emergency = false,
    this.primary = false,
    this.powertrains = const {},
    this.requires,
  });

  /// See [ServiceCategory.slug] — this is behaviour, not wording.
  final String slug;
  final L name;
  final IconData icon;
  final L? note;
  final bool emergency;
  final bool primary;
  final Set<Powertrain> powertrains;
  final ProviderCapability? requires;

  /// The wire body both the create and the update endpoint accept.
  JsonMap toJson() => {
        'slug': slug,
        'nameAr': name.ar,
        'nameEn': name.en,
        'icon': IconCodec.encode(icon),
        'noteAr': note?.ar,
        'noteEn': note?.en,
        'emergency': emergency,
        'primary': primary,
        'powertrains': [for (final p in powertrains) p.key],
        'requires': requires?.key,
      };

  /// Seeds the editor from the row being edited.
  factory ServiceCategoryDraft.of(ServiceCategory c) => ServiceCategoryDraft(
        slug: c.slug,
        name: c.name,
        icon: c.icon,
        note: c.note,
        emergency: c.emergency,
        primary: c.primary,
        powertrains: c.powertrains,
        requires: c.requires,
      );
}

/// A bookable service family (major service, tyres, roadside …).
class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.icon,
    this.note,
    this.emergency = false,
    this.badge,
    this.primary = false,
    this.powertrains = const {},
    this.requires,
  });

  /// GUID — the record's primary key, and the only thing that identifies
  /// *this row*. Nothing branches on it.
  final String id;

  /// The stable, human-readable key for what kind of service this is:
  /// `express`, `tyres`, `ev-check`, `sos`.
  ///
  /// **Behaviour hangs off the slug, never off [id].** Two things in the app
  /// need to know that a category *is* the tyre service and not merely some
  /// category: the maintenance mapper, which resets the right schedule line
  /// after a booking (`MaintenanceTypeX.forCategory`), and the booking screen,
  /// which treats `sos` as an emergency callout.
  ///
  /// Those used to switch on `id` back when ids were hand-written words. Once
  /// every record's id became a GUID that stopped being possible — and it was
  /// always the wrong field to read. An id says *which row*; a slug says *what
  /// kind*. Splitting them means a category can be re-seeded, re-imported, or
  /// created fresh in another environment with a different primary key and the
  /// oil-change countdown still resets.
  final String slug;

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
        slug: json.stringOr('slug', ''),
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
        'slug': slug,
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
    String? slug,
    L? name,
    IconData? icon,
    L? note,
    bool? emergency,
    L? badge,
    bool? primary,
    Set<Powertrain>? powertrains,
    ProviderCapability? requires,
    // `badge: null` cannot mean "clear" in a copyWith — it is indistinguishable
    // from "leave alone". Taking a ribbon down is a real operation the founder
    // panel performs, so it gets its own flag.
    bool clearBadge = false,
  }) =>
      ServiceCategory(
        id: id ?? this.id,
        slug: slug ?? this.slug,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        note: note ?? this.note,
        emergency: emergency ?? this.emergency,
        badge: clearBadge ? null : (badge ?? this.badge),
        primary: primary ?? this.primary,
        powertrains: powertrains ?? this.powertrains,
        requires: requires ?? this.requires,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceCategory &&
      other.id == id &&
      other.slug == slug &&
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
        slug,
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
