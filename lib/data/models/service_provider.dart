import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// How a provider can take delivery of the car.
enum Fulfillment { workshop, pickup, roadside }

extension FulfillmentX on Fulfillment {
  String label(S s) => switch (this) {
        Fulfillment.workshop => s.t('زيارة الورشة', 'Visit workshop'),
        Fulfillment.pickup => s.t('استلام وإعادة', 'Pickup & return'),
        Fulfillment.roadside =>
          s.t('مساعدة على الطريق (طارئ)', 'Roadside (emergency)'),
      };

  IconData get icon => switch (this) {
        Fulfillment.workshop => Icons.storefront_outlined,
        Fulfillment.pickup => Icons.local_shipping_outlined,
        Fulfillment.roadside => Icons.warning_amber_rounded,
      };

  /// Stable wire value — persisted on a service request.
  String get key => name;

  static Fulfillment fromKey(String? key) {
    for (final value in Fulfillment.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return Fulfillment.workshop;
  }
}

/// A workshop or roadside operator on the marketplace.
class ServiceProvider {
  const ServiceProvider({
    required this.id,
    required this.name,
    required this.area,
    required this.region,
    required this.distanceKm,
    required this.verified,
    required this.fulfillments,
    this.pickupFee = 3,
  });

  final String id;
  final L name;

  /// Canonical English area/region keys (see [LocationCatalog.localized]).
  final String area;
  final String region;
  final double distanceKm;
  final bool verified;
  final Set<Fulfillment> fulfillments;
  final double pickupFee;

  factory ServiceProvider.fromJson(JsonMap json) => ServiceProvider(
        id: json.requireString('id'),
        name: L.fromJson(json['name']),
        area: json.stringOr('area', ''),
        region: json.stringOr('region', ''),
        distanceKm: json.doubleOr('distanceKm', 0),
        verified: json.boolOr('verified', false),
        fulfillments: json
            .stringList('fulfillments')
            .map(FulfillmentX.fromKey)
            .toSet(),
        pickupFee: json.doubleOr('pickupFee', 3),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name.toJson(),
        'area': area,
        'region': region,
        'distanceKm': distanceKm,
        'verified': verified,
        'fulfillments': [for (final f in fulfillments) f.key],
        'pickupFee': pickupFee,
      };

  ServiceProvider copyWith({
    String? id,
    L? name,
    String? area,
    String? region,
    double? distanceKm,
    bool? verified,
    Set<Fulfillment>? fulfillments,
    double? pickupFee,
  }) =>
      ServiceProvider(
        id: id ?? this.id,
        name: name ?? this.name,
        area: area ?? this.area,
        region: region ?? this.region,
        distanceKm: distanceKm ?? this.distanceKm,
        verified: verified ?? this.verified,
        fulfillments: fulfillments ?? this.fulfillments,
        pickupFee: pickupFee ?? this.pickupFee,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceProvider &&
      other.id == id &&
      other.name == name &&
      other.area == area &&
      other.region == region &&
      other.distanceKm == distanceKm &&
      other.verified == verified &&
      other.pickupFee == pickupFee &&
      other.fulfillments.length == fulfillments.length &&
      other.fulfillments.containsAll(fulfillments);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        area,
        region,
        distanceKm,
        verified,
        pickupFee,
        Object.hashAllUnordered(fulfillments),
      );
}
