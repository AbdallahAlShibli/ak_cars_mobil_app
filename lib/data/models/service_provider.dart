import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        Fulfillment.workshop => LucideIcons.store,
        Fulfillment.pickup => LucideIcons.truckElectric,
        Fulfillment.roadside => LucideIcons.triangleAlert,
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

/// Something a workshop is equipped and certified to do, beyond ordinary
/// mechanical work.
///
/// Kept separate from [ServiceProvider.verified] (which is about the business
/// being checked) because these gate *what* can be booked: high-voltage work
/// on an EV needs trained staff and insulated tooling, and a home charger
/// inspection needs an electrical contractor.
enum ProviderCapability { evService, evChargerInstall }

extension ProviderCapabilityX on ProviderCapability {
  /// Stable wire value.
  String get key => name;

  L get label => switch (this) {
        ProviderCapability.evService =>
          const L('معتمد لخدمة السيارات الكهربائية', 'EV-certified'),
        ProviderCapability.evChargerInstall =>
          const L('تركيب وفحص شواحن منزلية', 'Home charger installation'),
      };

  IconData get icon => switch (this) {
        ProviderCapability.evService => LucideIcons.zap,
        ProviderCapability.evChargerInstall => LucideIcons.plugZap,
      };

  static ProviderCapability? fromKey(String? key) {
    for (final value in ProviderCapability.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return null;
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
    this.isApproved = false,
    this.capabilities = const {},
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

  /// Platform approval — the gate on anything that *promotes* this workshop
  /// (home-page spec §3: "معتمدة من المنصة — شرط لأي عرض أو إبراز").
  ///
  /// Distinct from [verified], which is a badge about the business having been
  /// checked. This one is an editorial decision by the platform, and it gates
  /// two things and only two: whether the workshop may run an [Offer], and
  /// whether it may be ranked on the home page's workshop boards. It does
  /// **not** hide the workshop from the services list — an unapproved workshop
  /// still sells, it just does not get promoted.
  ///
  /// Defaults to false, including on the wire: a workshop the API says nothing
  /// about has not been approved, and must not be promoted on that silence.
  final bool isApproved;

  /// Specialist work this workshop is equipped for. Empty is the normal case —
  /// an ordinary garage — and is why every existing provider needed no change
  /// when this was added.
  final Set<ProviderCapability> capabilities;

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

  bool can(ProviderCapability? capability) =>
      capability == null || capabilities.contains(capability);

  /// Trained and equipped for high-voltage work on an electric car.
  bool get evCertified => capabilities.contains(ProviderCapability.evService);

  factory ServiceProvider.fromJson(JsonMap json) => ServiceProvider(
        id: json.requireString('id'),
        name: L.fromJson(json['name']),
        area: json.stringOr('area', ''),
        region: json.stringOr('region', ''),
        distanceKm: json.doubleOr('distanceKm', 0),
        verified: json.boolOr('verified', false),
        isApproved: json.boolOr('isApproved', false),
        fulfillments: json
            .stringList('fulfillments')
            .map(FulfillmentX.fromKey)
            .toSet(),
        capabilities: {
          for (final key in json.stringList('capabilities'))
            ?ProviderCapabilityX.fromKey(key),
        },
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
        'isApproved': isApproved,
        'fulfillments': [for (final f in fulfillments) f.key],
        'capabilities': [for (final c in capabilities) c.key],
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
    bool? isApproved,
    Set<Fulfillment>? fulfillments,
    Set<ProviderCapability>? capabilities,
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
        isApproved: isApproved ?? this.isApproved,
        fulfillments: fulfillments ?? this.fulfillments,
        capabilities: capabilities ?? this.capabilities,
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
      other.isApproved == isApproved &&
      other.pickupFee == pickupFee &&
      other.phone == phone &&
      other.whatsapp == whatsapp &&
      other.vatNumber == vatNumber &&
      other.crNumber == crNumber &&
      other.hours == hours &&
      other.fulfillments.length == fulfillments.length &&
      other.fulfillments.containsAll(fulfillments) &&
      other.capabilities.length == capabilities.length &&
      other.capabilities.containsAll(capabilities);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        area,
        region,
        distanceKm,
        verified,
        isApproved,
        pickupFee,
        phone,
        whatsapp,
        vatNumber,
        crNumber,
        hours,
        Object.hashAllUnordered(fulfillments),
        Object.hashAllUnordered(capabilities),
      );
}
