import '../../core/json/json_utils.dart';
import 'media_attachment.dart';
import 'service_provider.dart';

/// What a workshop owner filled in when they registered (spec §8, §10).
///
/// **Carries only what [ServiceProvider] does not already have a home for**,
/// and uses [ServiceProvider]'s own field names for everything it shares with
/// it (`crNumber`, `vatNumber`, `area`, `fulfillments`). That is not a style
/// preference: approval (§11 step 3) turns this into a [ServiceProvider] by
/// copying fields straight across, and a renamed field is a mapping step that
/// can be got wrong.
///
/// Deliberately has **no bank or transfer details**. Money moves by hand in the
/// pilot and the founder arranges it out of band after approval; asking for an
/// IBAN at registration would raise the drop-off on a form nobody has been
/// approved on yet, for a field nothing in the app reads.
class WorkshopApplication {
  const WorkshopApplication({
    required this.businessNameAr,
    required this.crNumber,
    required this.crDocument,
    required this.area,
    required this.submittedAt,
    this.businessNameEn,
    this.vatNumber,
    this.fulfillments = const {},
  });

  /// Commercial-registration name, Arabic. Required — it is the legal name the
  /// document has to match.
  final String businessNameAr;

  /// The same name in English. Optional: plenty of Omani CRs carry only the
  /// Arabic name, and a required field here would be a field people invent an
  /// answer for.
  final String? businessNameEn;

  /// Commercial Registration number from the Ministry of Commerce. Same field
  /// name and meaning as [ServiceProvider.crNumber].
  final String crNumber;

  /// Oman VATIN. Optional and explicitly labelled so — registration in Oman is
  /// turnover-based, so a small garage genuinely does not have one, and a
  /// required field would be answered with a made-up number.
  final String? vatNumber;

  /// The uploaded CR certificate — image or PDF, held as base64 bytes on the
  /// application itself. Required: the founder is asked to verify a business,
  /// and there is nothing to verify without it.
  ///
  /// Carrying the bytes rather than a URL is what makes "required" mean
  /// something here. A URL can be stored while the file behind it never
  /// finished uploading, and the reviewer would be looking at a broken frame
  /// on the screen where they approve a business; bytes on the record either
  /// arrived or the application did not.
  final MediaAttachment crDocument;

  /// Canonical English area key, from `LocationCatalog`.
  final String area;

  /// How the workshop takes delivery of cars. Multi-select here, unlike the
  /// single choice a customer makes per booking — a workshop that does both
  /// counter work and collection is the normal case.
  final Set<Fulfillment> fulfillments;

  final DateTime submittedAt;

  /// The display name to use, preferring the language the reader is in but
  /// never inventing a translation: an application with no English name shows
  /// the Arabic one to an English reader, which is what the CR actually says.
  String displayName({required bool isAr}) {
    if (isAr) return businessNameAr;
    final en = businessNameEn?.trim();
    return (en == null || en.isEmpty) ? businessNameAr : en;
  }

  factory WorkshopApplication.fromJson(JsonMap json) => WorkshopApplication(
        businessNameAr: json.stringOr('businessNameAr', ''),
        businessNameEn: json.stringOrNull('businessNameEn'),
        crNumber: json.stringOr('crNumber', ''),
        vatNumber: json.stringOrNull('vatNumber'),
        crDocument: MediaAttachment.fromJson(json.requireObject('crDocument')),
        area: json.stringOr('area', ''),
        fulfillments:
            json.stringList('fulfillments').map(FulfillmentX.fromKey).toSet(),
        submittedAt: json.dateTimeOr('submittedAt', DateTime.now()),
      );

  JsonMap toJson() => {
        'businessNameAr': businessNameAr,
        'businessNameEn': businessNameEn,
        'crNumber': crNumber,
        'vatNumber': vatNumber,
        'crDocument': crDocument.toJson(),
        'area': area,
        'fulfillments': [for (final f in fulfillments) f.key],
        'submittedAt': submittedAt.toIso8601String(),
      };

  WorkshopApplication copyWith({
    String? businessNameAr,
    String? businessNameEn,
    String? crNumber,
    String? vatNumber,
    MediaAttachment? crDocument,
    String? area,
    Set<Fulfillment>? fulfillments,
    DateTime? submittedAt,
  }) =>
      WorkshopApplication(
        businessNameAr: businessNameAr ?? this.businessNameAr,
        businessNameEn: businessNameEn ?? this.businessNameEn,
        crNumber: crNumber ?? this.crNumber,
        vatNumber: vatNumber ?? this.vatNumber,
        crDocument: crDocument ?? this.crDocument,
        area: area ?? this.area,
        fulfillments: fulfillments ?? this.fulfillments,
        submittedAt: submittedAt ?? this.submittedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkshopApplication &&
      other.businessNameAr == businessNameAr &&
      other.businessNameEn == businessNameEn &&
      other.crNumber == crNumber &&
      other.vatNumber == vatNumber &&
      other.crDocument == crDocument &&
      other.area == area &&
      other.submittedAt == submittedAt &&
      other.fulfillments.length == fulfillments.length &&
      other.fulfillments.containsAll(fulfillments);

  @override
  int get hashCode => Object.hash(
        businessNameAr,
        businessNameEn,
        crNumber,
        vatNumber,
        crDocument,
        area,
        submittedAt,
        Object.hashAllUnordered(fulfillments),
      );
}
