import '../../core/json/json_utils.dart';

/// A time-boxed discount an approved workshop runs on one listed service
/// (home-page spec §3).
///
/// This is *not* the same thing as a [Promotion]. A promotion is an
/// announcement — "your money is held until you collect the car" — and carries
/// no price at all. An offer is a claim about money: this workshop will do this
/// listed job for less than its published price, until this date. Because it is
/// a claim about money, every part of it is checked before it is ever rendered:
/// see [invalidReason], which the repository runs against the live catalogue.
///
/// Three properties are deliberate:
///
/// - **The reference price is not the seller's to type.** [referencePrice] must
///   equal the `ServiceOffering.price` this workshop already publishes on the
///   platform. A workshop cannot inflate a "was" price to manufacture a
///   discount — the repository rejects the offer if the two disagree.
/// - **The founder switches it on.** [activeByFounder] is the platform's
///   approval. Offers are created and enabled from the founder panel in this
///   phase, not self-served by workshops.
/// - **It expires.** [endsAt] is mandatory, enforced on read, and printed on
///   the card. A discount with no deadline is not an offer, it is a price.
///
/// There is no field here that money could buy: no boost, no rank, no
/// sponsored slot (spec §2). An offer earns its place on the home page by
/// being a real saving on real work, or it is not shown.
class Offer {
  const Offer({
    required this.id,
    required this.workshopId,
    required this.serviceOfferingId,
    required this.referencePrice,
    required this.discountedPrice,
    required this.startsAt,
    required this.endsAt,
    this.activeByFounder = false,
    this.regions = const {},
  });

  final String id;

  /// The workshop running it. Must be an approved workshop
  /// (`ServiceProvider.isApproved`) *and* must be the workshop that sells
  /// [serviceOfferingId] — an offer on someone else's service is nonsense.
  final String workshopId;

  /// The exact listed service the discount applies to.
  final String serviceOfferingId;

  /// The workshop's published price for that service, copied from the
  /// catalogue. Validated against it on every read.
  final double referencePrice;

  /// What the customer pays while the offer runs. Must be strictly less than
  /// [referencePrice].
  final double discountedPrice;

  final DateTime startsAt;

  /// Mandatory deadline. A card is not rendered past it.
  final DateTime endsAt;

  /// The founder's switch. False means created but not approved — invisible.
  final bool activeByFounder;

  /// Governorates the offer runs in. Empty means wherever the workshop is,
  /// which is the normal case: an offer is a workshop's own price, and a
  /// workshop is in one place.
  final Set<String> regions;

  /// How much is knocked off, as a percentage of the published price.
  double get discountPercent =>
      referencePrice <= 0 ? 0 : ((referencePrice - discountedPrice) / referencePrice) * 100;

  /// The saving in rials.
  double get savings => referencePrice - discountedPrice;

  /// True when the discount is a real reduction rather than a relabelling.
  bool get isRealDiscount =>
      referencePrice > 0 && discountedPrice > 0 && discountedPrice < referencePrice;

  bool isWithin(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  /// Whole days until [endsAt], clamped at 0 so a card caught mid-expiry reads
  /// "last day" rather than a negative count.
  int daysLeft(DateTime now) =>
      (endsAt.difference(now).inHours / 24).ceil().clamp(0, 3650);

  bool runsIn(String? region, {required String workshopRegion}) {
    if (region == null) return true;
    if (regions.isEmpty) return workshopRegion == region;
    return regions.contains(region);
  }

  factory Offer.fromJson(JsonMap json) => Offer(
        id: json.requireString('id'),
        workshopId: json.requireString('workshopId'),
        serviceOfferingId: json.requireString('serviceOfferingId'),
        referencePrice: json.doubleOr('referencePrice', 0),
        discountedPrice: json.doubleOr('discountedPrice', 0),
        startsAt: json.dateTimeOr('startsAt', DateTime.now()),
        endsAt: json.dateTimeOr('endsAt', DateTime.now()),
        activeByFounder: json.boolOr('activeByFounder', false),
        regions: json.stringList('regions').toSet(),
      );

  JsonMap toJson() => {
        'id': id,
        'workshopId': workshopId,
        'serviceOfferingId': serviceOfferingId,
        'referencePrice': referencePrice,
        'discountedPrice': discountedPrice,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'activeByFounder': activeByFounder,
        'regions': regions.toList(),
      };

  Offer copyWith({
    String? id,
    String? workshopId,
    String? serviceOfferingId,
    double? referencePrice,
    double? discountedPrice,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? activeByFounder,
    Set<String>? regions,
  }) =>
      Offer(
        id: id ?? this.id,
        workshopId: workshopId ?? this.workshopId,
        serviceOfferingId: serviceOfferingId ?? this.serviceOfferingId,
        referencePrice: referencePrice ?? this.referencePrice,
        discountedPrice: discountedPrice ?? this.discountedPrice,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        activeByFounder: activeByFounder ?? this.activeByFounder,
        regions: regions ?? this.regions,
      );

  @override
  bool operator ==(Object other) =>
      other is Offer &&
      other.id == id &&
      other.workshopId == workshopId &&
      other.serviceOfferingId == serviceOfferingId &&
      other.referencePrice == referencePrice &&
      other.discountedPrice == discountedPrice &&
      other.startsAt == startsAt &&
      other.endsAt == endsAt &&
      other.activeByFounder == activeByFounder &&
      other.regions.length == regions.length &&
      other.regions.containsAll(regions);

  @override
  int get hashCode => Object.hash(
        id,
        workshopId,
        serviceOfferingId,
        referencePrice,
        discountedPrice,
        startsAt,
        endsAt,
        activeByFounder,
        Object.hashAllUnordered(regions),
      );
}

/// Why an offer may not be shown — the spec's six validation rules (§3),
/// named so the founder panel can say which one failed instead of silently
/// dropping the row.
enum OfferRejection {
  /// The workshop is not on the platform any more.
  unknownWorkshop,

  /// The workshop exists but is not platform-approved.
  workshopNotApproved,

  /// The service is not listed in the catalogue.
  unlistedService,

  /// The service is listed, but not by this workshop.
  serviceNotThisWorkshops,

  /// The service is quote-only, so there is no published price to discount.
  serviceHasNoPublishedPrice,

  /// The stated "was" price is not the price the platform publishes.
  referencePriceMismatch,

  /// The "discount" does not reduce anything.
  notADiscount,

  /// The founder has not switched it on.
  notApprovedByFounder,

  /// Outside its own start/end dates.
  outsideItsDates,
}

extension OfferRejectionX on OfferRejection {
  /// Bilingual explanation, for the founder panel.
  (String ar, String en) get reason => switch (this) {
        OfferRejection.unknownWorkshop =>
          ('الورشة غير موجودة في المنصة', 'Workshop is not on the platform'),
        OfferRejection.workshopNotApproved =>
          ('الورشة غير معتمدة', 'Workshop is not approved'),
        OfferRejection.unlistedService =>
          ('الخدمة غير مدرجة في المنصة', 'Service is not listed'),
        OfferRejection.serviceNotThisWorkshops => (
            'الخدمة تخص ورشة أخرى',
            'That service belongs to a different workshop',
          ),
        OfferRejection.serviceHasNoPublishedPrice => (
            'الخدمة بعرض سعر — لا سعر معلن ليُخصم منه',
            'Quote-only service — no published price to discount',
          ),
        OfferRejection.referencePriceMismatch => (
            'السعر المرجعي لا يطابق السعر المعلن',
            'Reference price does not match the published price',
          ),
        OfferRejection.notADiscount => (
            'السعر بعد الخصم ليس أقل من المرجعي',
            'Discounted price is not below the reference price',
          ),
        OfferRejection.notApprovedByFounder =>
          ('غير مفعّل من المؤسس', 'Not enabled by the founder'),
        OfferRejection.outsideItsDates =>
          ('خارج مدة العرض', 'Outside the offer window'),
      };
}
