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
    this.phone,
    this.whatsapp,
    this.vatNumber,
    this.crNumber,
    this.hours,
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

  /// Shop landline/mobile in international form (`+968…`).
  final String? phone;

  /// WhatsApp number, digits only — often a different line from [phone].
  final String? whatsapp;

  /// Oman VAT Identification Number: `OM` followed by 10 digits, issued by
  /// the Oman Tax Authority. Only VAT-registered businesses have one (the
  /// registration threshold is turnover-based), so a null here means "not
  /// VAT registered" and must not be rendered as a blank field.
  final String? vatNumber;

  /// Commercial Registration number from the Ministry of Commerce.
  final String? crNumber;

  /// Opening hours, free text ("Sat–Thu 8:00–20:00").
  final L? hours;

  /// True once the workshop can issue a VAT invoice for a parts order.
  bool get vatRegistered => vatNumber != null && vatNumber!.isNotEmpty;

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
        phone: json.stringOrNull('phone'),
        whatsapp: json.stringOrNull('whatsapp'),
        vatNumber: json.stringOrNull('vatNumber'),
        crNumber: json.stringOrNull('crNumber'),
        hours: json['hours'] == null ? null : L.fromJson(json['hours']),
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
        'phone': phone,
        'whatsapp': whatsapp,
        'vatNumber': vatNumber,
        'crNumber': crNumber,
        'hours': hours?.toJson(),
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
    String? phone,
    String? whatsapp,
    String? vatNumber,
    String? crNumber,
    L? hours,
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
        phone: phone ?? this.phone,
        whatsapp: whatsapp ?? this.whatsapp,
        vatNumber: vatNumber ?? this.vatNumber,
        crNumber: crNumber ?? this.crNumber,
        hours: hours ?? this.hours,
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
      other.phone == phone &&
      other.whatsapp == whatsapp &&
      other.vatNumber == vatNumber &&
      other.crNumber == crNumber &&
      other.hours == hours &&
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
        phone,
        whatsapp,
        vatNumber,
        crNumber,
        hours,
        Object.hashAllUnordered(fulfillments),
      );
}
