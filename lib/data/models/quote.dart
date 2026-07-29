import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// What kind of transaction a booking is.
///
/// The two kinds ride the *same* escrow machine (see `escrow.dart`) — a custom
/// quote simply enters it three states earlier, at `requested`, and joins the
/// shared path once the customer accepts a price. There is no second money
/// flow, no second set of operator buttons, and no second set of rules.
enum BookingType {
  /// Booked off the catalogue at a price the workshop published in advance.
  catalogService,

  /// "Request a part + installation": the customer describes what they need,
  /// one workshop prices it, and the customer accepts or walks away.
  customQuote;

  String get key => name;

  bool get isCustomQuote => this == customQuote;

  static BookingType fromKey(String? key) {
    for (final value in BookingType.values) {
      if (value.key == key) return value;
    }
    return BookingType.catalogService;
  }
}

extension BookingTypeX on BookingType {
  L get label => switch (this) {
        BookingType.catalogService => const L('خدمة من الكتالوج', 'Catalogue service'),
        BookingType.customQuote =>
          const L('قطعة + تركيب', 'Part + installation'),
      };
}

/// What the customer asked for, in their own words.
///
/// Never translated and never tidied up: the workshop is the one deciding
/// which part actually fits, and it decides that from what the owner wrote and
/// from the car on the booking — so paraphrasing here would be paraphrasing
/// the input to a technical judgement.
///
/// There is deliberately no fitment/compatibility data behind this. The
/// workshop is the compatibility expert (spec §6); the app does not guess a
/// part number.
class PartRequest {
  const PartRequest({
    required this.description,
    this.preferredBrand,
    this.symptom,
  });

  /// The part or repair the customer is asking for.
  final String description;

  /// A brand or origin they asked for ("أصلي", "Denso"), when they named one.
  /// Null means they did not — not "any brand is fine", which is the
  /// workshop's call to raise in the quote.
  final String? preferredBrand;

  /// What the car is doing wrong, when the customer described a symptom rather
  /// than a part. Optional: someone who knows they need a specific filter has
  /// no symptom to report.
  final String? symptom;

  factory PartRequest.fromJson(JsonMap json) => PartRequest(
        description: json.stringOr('description', ''),
        preferredBrand: json.stringOrNull('preferredBrand'),
        symptom: json.stringOrNull('symptom'),
      );

  JsonMap toJson() => {
        'description': description,
        'preferredBrand': preferredBrand,
        'symptom': symptom,
      };

  PartRequest copyWith({
    String? description,
    String? preferredBrand,
    String? symptom,
  }) =>
      PartRequest(
        description: description ?? this.description,
        preferredBrand: preferredBrand ?? this.preferredBrand,
        symptom: symptom ?? this.symptom,
      );

  @override
  bool operator ==(Object other) =>
      other is PartRequest &&
      other.description == description &&
      other.preferredBrand == preferredBrand &&
      other.symptom == symptom;

  @override
  int get hashCode => Object.hash(description, preferredBrand, symptom);
}

/// A workshop's priced answer to a [PartRequest] (spec §6).
///
/// The part and the labour are **two separate fields**, not one number the
/// workshop typed. That is the whole design: the verbal "I'll do it for 40"
/// is exactly what this transaction exists to replace, so the split is
/// structural rather than a formatting convention — a workshop cannot submit a
/// lump sum through this model.
class Quote {
  const Quote({
    required this.id,
    required this.requestId,
    required this.workshopId,
    required this.partDescription,
    required this.partPrice,
    required this.laborPrice,
    required this.createdAt,
    this.partBrand,
    this.warrantyDays,
    this.note,
  });

  final String id;
  final String requestId;
  final String workshopId;

  /// The part the workshop is actually proposing — its words, which may well
  /// differ from what the customer asked for, because identifying the right
  /// part is the workshop's job.
  final String partDescription;

  final double partPrice;
  final double laborPrice;

  /// Brand or origin the workshop is supplying, when it stated one.
  final String? partBrand;

  /// The **part's own** warranty, in days, as offered by the workshop.
  ///
  /// Emphatically not the payment escrow, which ends at release: this one
  /// starts there. The app records it and shows it; it does not enforce it,
  /// and post-release claims are out of scope for the pilot.
  final int? warrantyDays;

  /// Anything else the workshop wanted the customer to know before accepting.
  final String? note;

  final DateTime createdAt;

  double get total => partPrice + laborPrice;

  factory Quote.fromJson(JsonMap json) => Quote(
        id: json.requireString('id'),
        requestId: json.stringOr('requestId', ''),
        workshopId: json.stringOr('workshopId', ''),
        partDescription: json.stringOr('partDescription', ''),
        partPrice: json.doubleOr('partPrice', 0),
        laborPrice: json.doubleOr('laborPrice', 0),
        partBrand: json.stringOrNull('partBrand'),
        warrantyDays: json.intOrNull('warrantyDays'),
        note: json.stringOrNull('note'),
        createdAt: json.dateTimeOr('createdAt', DateTime.now()),
      );

  JsonMap toJson() => {
        'id': id,
        'requestId': requestId,
        'workshopId': workshopId,
        'partDescription': partDescription,
        'partPrice': partPrice,
        'laborPrice': laborPrice,
        'partBrand': partBrand,
        'warrantyDays': warrantyDays,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  Quote copyWith({
    String? id,
    String? requestId,
    String? workshopId,
    String? partDescription,
    double? partPrice,
    double? laborPrice,
    String? partBrand,
    int? warrantyDays,
    String? note,
    DateTime? createdAt,
  }) =>
      Quote(
        id: id ?? this.id,
        requestId: requestId ?? this.requestId,
        workshopId: workshopId ?? this.workshopId,
        partDescription: partDescription ?? this.partDescription,
        partPrice: partPrice ?? this.partPrice,
        laborPrice: laborPrice ?? this.laborPrice,
        partBrand: partBrand ?? this.partBrand,
        warrantyDays: warrantyDays ?? this.warrantyDays,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Quote &&
      other.id == id &&
      other.requestId == requestId &&
      other.workshopId == workshopId &&
      other.partDescription == partDescription &&
      other.partPrice == partPrice &&
      other.laborPrice == laborPrice &&
      other.partBrand == partBrand &&
      other.warrantyDays == warrantyDays &&
      other.note == note &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        requestId,
        workshopId,
        partDescription,
        partPrice,
        laborPrice,
        partBrand,
        warrantyDays,
        note,
        createdAt,
      );
}

/// What the customer fills in to open a "part + installation" request.
///
/// A request DTO rather than a half-built [PartRequest]: the id, the initial
/// escrow state and the synthesised quote-only offering are the server's to
/// decide, exactly as with [CreateServiceRequestDraft].
class CreatePartRequestDraft {
  const CreatePartRequestDraft({
    required this.providerId,
    required this.carId,
    required this.plate,
    required this.part,
    required this.fulfillment,
  });

  final String providerId;
  final String carId;
  final String plate;
  final PartRequest part;

  /// How the car reaches the workshop. Same three modes as any other booking —
  /// a part fitting is still work done on a car.
  final String fulfillment;

  JsonMap toJson() => {
        'providerId': providerId,
        'carId': carId,
        'plate': plate,
        'part': part.toJson(),
        'fulfillment': fulfillment,
      };
}
