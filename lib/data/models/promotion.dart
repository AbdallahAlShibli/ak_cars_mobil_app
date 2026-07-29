import 'package:flutter/widgets.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/json/json_utils.dart';

/// A promoted offer — a workshop's own campaign, or a platform announcement.
///
/// This is the record behind the home page's offers rail. Three properties of
/// it are deliberate:
///
/// - **It points at something real.** [offeringId] / [providerId] / [query] are
///   validated against the live catalogue by
///   `ServiceMarketplaceRepository.promotions`, so a card that cannot be
///   honoured is never rendered. A card whose tap lands nowhere is worse than
///   no card.
/// - **It does not carry a price.** The price the customer sees comes from the
///   offering it points at, so the rail can never advertise a number the
///   booking screen then contradicts. [badge] is for a claim the workshop
///   itself makes ("خصم ٢٠٪"), not for a computed figure.
/// - **It expires.** [endsAt] is enforced on read; a finished campaign
///   disappears instead of promising a price nobody honours any more.
class Promotion {
  const Promotion({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    this.badge,
    this.providerId,
    this.offeringId,
    this.query,
    this.regions = const {},
    this.endsAt,
  });

  final String id;
  final L title;
  final L body;

  /// Rendered on the card. Encoded as a stable [IconCodec] key on the wire.
  final IconData icon;

  /// Short ribbon — the workshop's own claim, shown verbatim.
  final L? badge;

  /// The workshop running the campaign, when it is a workshop's own. Null on a
  /// platform announcement.
  final String? providerId;

  /// The exact offering the card sells, when it sells one. Preferred over
  /// [query]: the card can then show the real price and open the real service
  /// page.
  final String? offeringId;

  /// Fallback destination — a search the services tab can actually run. Used
  /// where a campaign covers several offerings ("all AC work, 20% off").
  final String? query;

  /// Governorates the campaign runs in. Empty means nationwide, which is the
  /// normal case for a platform announcement.
  ///
  /// A workshop's offer is only shown to users whose selected governorate it
  /// covers — the same rule the services list already follows, and the reason a
  /// Muscat user is not hooked by a Salalah-only discount.
  final Set<String> regions;

  /// When the campaign stops. Null means open-ended.
  final DateTime? endsAt;

  bool runsIn(String? region) =>
      regions.isEmpty || region == null || regions.contains(region);

  bool isLive(DateTime now) {
    final end = endsAt;
    return end == null || end.isAfter(now);
  }

  /// Whole days left, or null when the campaign is open-ended. Clamped at 0 so
  /// a card caught mid-expiry reads "last day" rather than a negative count.
  int? daysLeft(DateTime now) {
    final end = endsAt;
    if (end == null) return null;
    return (end.difference(now).inHours / 24).ceil().clamp(0, 3650);
  }

  factory Promotion.fromJson(JsonMap json) => Promotion(
        id: json.requireString('id'),
        title: L.fromJson(json['title']),
        body: L.fromJson(json['body']),
        icon: IconCodec.decode(json.stringOrNull('icon')),
        badge: json['badge'] == null ? null : L.fromJson(json['badge']),
        providerId: json.stringOrNull('providerId'),
        offeringId: json.stringOrNull('offeringId'),
        query: json.stringOrNull('query'),
        regions: json.stringList('regions').toSet(),
        endsAt: json.dateTimeOrNull('endsAt'),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title.toJson(),
        'body': body.toJson(),
        'icon': IconCodec.encode(icon),
        'badge': badge?.toJson(),
        'providerId': providerId,
        'offeringId': offeringId,
        'query': query,
        'regions': regions.toList(),
        'endsAt': endsAt?.toIso8601String(),
      };

  Promotion copyWith({
    String? id,
    L? title,
    L? body,
    IconData? icon,
    L? badge,
    String? providerId,
    String? offeringId,
    String? query,
    Set<String>? regions,
    DateTime? endsAt,
  }) =>
      Promotion(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        icon: icon ?? this.icon,
        badge: badge ?? this.badge,
        providerId: providerId ?? this.providerId,
        offeringId: offeringId ?? this.offeringId,
        query: query ?? this.query,
        regions: regions ?? this.regions,
        endsAt: endsAt ?? this.endsAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Promotion &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.icon == icon &&
      other.badge == badge &&
      other.providerId == providerId &&
      other.offeringId == offeringId &&
      other.query == query &&
      other.endsAt == endsAt &&
      other.regions.length == regions.length &&
      other.regions.containsAll(regions);

  @override
  int get hashCode => Object.hash(
        id,
        title,
        body,
        icon,
        badge,
        providerId,
        offeringId,
        query,
        endsAt,
        Object.hashAllUnordered(regions),
      );
}
