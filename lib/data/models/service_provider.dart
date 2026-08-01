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

/// Where a workshop stands on the road from "applied" to "sells on the
/// marketplace" (spec §5, tab 2).
///
/// A single ordered path, not a set of booleans, for the same reason
/// [EscrowState] is: `isVerified && isSuspended` is not a state anyone can
/// reach here, and the founder panel's pipeline view is just a count per value.
///
/// Only [approved] grants anything. Everything before it is an application in
/// progress; [suspended] is the one terminal-ish value and covers both "we
/// rejected this application" and "we stopped a workshop that was live" —
/// which are the same fact from the marketplace's point of view, and are told
/// apart by [ServiceProvider.rejectionReason] and the audit trail.
enum ProviderOnboardingStage {
  /// The account exists and named itself a workshop; no documents yet.
  applied,

  /// Commercial registration document attached, waiting on a human to read it.
  /// This is where a registration from `register_screen.dart` lands (§11).
  documentsSubmitted,

  /// The founder read the documents and they check out, but the workshop is
  /// not yet switched on for customers.
  verified,

  /// Live: visible to customers, takes bookings, may run offers.
  approved,

  /// Rejected, or stopped after having been live. Always carries a written
  /// reason — see [ServiceProvider.rejectionReason].
  suspended;

  /// Stable wire value.
  String get key => name;

  /// The only value that grants anything.
  bool get grantsAccess => this == ProviderOnboardingStage.approved;

  /// True while the application is waiting on the founder rather than on the
  /// workshop. Drives the founder panel's "needs you" pipeline columns.
  bool get awaitsFounder =>
      this == ProviderOnboardingStage.applied ||
      this == ProviderOnboardingStage.documentsSubmitted ||
      this == ProviderOnboardingStage.verified;

  static ProviderOnboardingStage fromKey(String? key) {
    for (final value in ProviderOnboardingStage.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return ProviderOnboardingStage.applied;
  }
}

extension ProviderOnboardingStageX on ProviderOnboardingStage {
  String label(S s) => switch (this) {
        ProviderOnboardingStage.applied => s.t('قُدِّم الطلب', 'Applied'),
        ProviderOnboardingStage.documentsSubmitted =>
          s.t('الوثائق مرفوعة', 'Documents submitted'),
        ProviderOnboardingStage.verified => s.t('تم التحقّق', 'Verified'),
        ProviderOnboardingStage.approved => s.t('معتمدة', 'Approved'),
        ProviderOnboardingStage.suspended => s.t('موقوفة', 'Suspended'),
      };

  /// What the *workshop owner* is told, which is not what the founder's
  /// pipeline column says: "documents submitted" is an internal position, and
  /// what the applicant needs to know is that somebody is reading them (§11
  /// step 5).
  String ownerStatus(S s) => switch (this) {
        ProviderOnboardingStage.applied ||
        ProviderOnboardingStage.documentsSubmitted ||
        ProviderOnboardingStage.verified =>
          s.t('طلب ورشتك قيد المراجعة', 'Your workshop application is under review'),
        ProviderOnboardingStage.approved =>
          s.t('تم اعتماد ورشتك', 'Your workshop is approved'),
        ProviderOnboardingStage.suspended =>
          s.t('طلبك يحتاج تعديلاً', 'Your application needs a change'),
      };

  IconData get icon => switch (this) {
        ProviderOnboardingStage.applied => LucideIcons.filePlus,
        ProviderOnboardingStage.documentsSubmitted => LucideIcons.fileText,
        ProviderOnboardingStage.verified => LucideIcons.badgeCheck,
        ProviderOnboardingStage.approved => LucideIcons.circleCheck,
        ProviderOnboardingStage.suspended => LucideIcons.circleSlash,
      };
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
    this.stage = ProviderOnboardingStage.applied,
    this.stageSince,
    this.rejectionReason,
    this.crDocumentUrl,
    this.ownerUserId,
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

  /// Where this workshop stands on the onboarding path (spec §5, tab 2).
  ///
  /// This replaced a bare `isApproved` boolean in phase 2.5. The boolean is
  /// still readable — see [isApproved] — but it is now *derived*, so there is
  /// exactly one field that can say whether a workshop is live and no way for
  /// two of them to disagree.
  ///
  /// Defaults to [ProviderOnboardingStage.applied], including on the wire: a
  /// workshop the API says nothing about has not been approved, and must not
  /// be promoted, listed or booked on that silence.
  final ProviderOnboardingStage stage;

  /// When [stage] was last set. The founder's pipeline table sorts on how long
  /// an application has been sitting where it is, and that is only honest if it
  /// comes from a recorded timestamp rather than from the row's position.
  final DateTime? stageSince;

  /// Why the application was rejected, or why a live workshop was stopped.
  ///
  /// Never null while [stage] is [ProviderOnboardingStage.suspended] — the
  /// repository refuses a reasonless suspension (§11 step 3), because the
  /// owner is shown this text and "rejected" with no sentence after it is not
  /// something anyone can act on.
  final String? rejectionReason;

  /// The commercial-registration document the applicant uploaded. The founder
  /// opens this before deciding (§11 step 2).
  final String? crDocumentUrl;

  /// The account that owns this workshop, when it came in through
  /// registration. Null for the seeded workshops the platform onboarded by
  /// hand. This is what lets `/workshop` check *this* operator's stage rather
  /// than any approved workshop's.
  final String? ownerUserId;

  /// Platform approval — the gate on anything that promotes, lists or books
  /// this workshop (home-page spec §3, and §5 of the phase-2.5 spec).
  ///
  /// Derived from [stage] rather than stored. Every existing reader (offer
  /// validation, the two home-page leaderboards, `approvedWorkshops`) keeps
  /// working unchanged, and gains the stronger guarantee for free: there is no
  /// longer a way to be `isApproved: true` while sitting in the middle of an
  /// application.
  bool get isApproved => stage.grantsAccess;

  /// True while the workshop cannot yet act — the account exists but the
  /// panel, the bookings and the listing are all closed to it.
  bool get isPendingApproval => stage.awaitsFounder;

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
        // Back-compatible read: a payload from before the staged path only
        // carries the boolean, and `isApproved: true` means exactly
        // "approved". Anything else starts at the beginning of the path
        // rather than being guessed at.
        stage: json['stage'] == null
            ? (json.boolOr('isApproved', false)
                ? ProviderOnboardingStage.approved
                : ProviderOnboardingStage.applied)
            : ProviderOnboardingStage.fromKey(json.stringOrNull('stage')),
        stageSince: json.dateTimeOrNull('stageSince'),
        rejectionReason: json.stringOrNull('rejectionReason'),
        crDocumentUrl: json.stringOrNull('crDocumentUrl'),
        ownerUserId: json.stringOrNull('ownerUserId'),
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
        'stage': stage.key,
        // Written as well as read: it is derived here, but a client on an
        // older build still reads the boolean, and it costs one line to keep
        // that contract rather than silently downgrading every workshop.
        'isApproved': isApproved,
        'stageSince': stageSince?.toIso8601String(),
        'rejectionReason': rejectionReason,
        'crDocumentUrl': crDocumentUrl,
        'ownerUserId': ownerUserId,
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
    ProviderOnboardingStage? stage,
    DateTime? stageSince,
    String? rejectionReason,
    String? crDocumentUrl,
    String? ownerUserId,
    Set<Fulfillment>? fulfillments,
    Set<ProviderCapability>? capabilities,
    double? pickupFee,
    String? phone,
    String? whatsapp,
    String? vatNumber,
    String? crNumber,
    L? hours,
    /// Drops a previous rejection. Needed because the ordinary `?? this.x`
    /// pattern can only set a nullable field, never clear it — and re-approving
    /// a workshop that keeps showing its old rejection reason to its owner is
    /// the bug that pattern would cause (§11 step 5).
    bool clearRejectionReason = false,
  }) =>
      ServiceProvider(
        id: id ?? this.id,
        name: name ?? this.name,
        area: area ?? this.area,
        region: region ?? this.region,
        distanceKm: distanceKm ?? this.distanceKm,
        verified: verified ?? this.verified,
        stage: stage ?? this.stage,
        stageSince: stageSince ?? this.stageSince,
        rejectionReason:
            clearRejectionReason ? null : (rejectionReason ?? this.rejectionReason),
        crDocumentUrl: crDocumentUrl ?? this.crDocumentUrl,
        ownerUserId: ownerUserId ?? this.ownerUserId,
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
      other.stage == stage &&
      other.stageSince == stageSince &&
      other.rejectionReason == rejectionReason &&
      other.crDocumentUrl == crDocumentUrl &&
      other.ownerUserId == ownerUserId &&
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
        stage,
        stageSince,
        rejectionReason,
        crDocumentUrl,
        ownerUserId,
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
