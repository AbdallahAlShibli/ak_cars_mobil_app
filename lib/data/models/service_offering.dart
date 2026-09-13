import 'package:collection/collection.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import '../../core/utils/guid.dart';
import '../../core/utils/search_match.dart';
import 'media_attachment.dart';
import 'service_provider.dart';

/// A concrete service a specific provider sells within a category.
class ServiceOffering {
  const ServiceOffering({
    required this.id,
    required this.categoryId,
    required this.categorySlug,
    required this.name,
    required this.provider,
    required this.description,
    this.price,
    this.durationMin,
    this.includes = const [],
    this.warrantyMonths,
    this.isActive = true,
    this.photo,
  });

  final String id;

  /// GUID of the [ServiceCategory] this sits under.
  final String categoryId;

  /// That category's slug, denormalized onto the offering.
  ///
  /// Carried here for the same reason [provider] is expanded inline: the
  /// screens that need it have an offering and nothing else. The booking
  /// screen decides whether it is drawing an emergency callout, and the
  /// maintenance mapper decides which schedule line a completed booking
  /// resets — neither has the category list to hand, and neither should have
  /// to fetch one to answer a question about the record it is already
  /// holding.
  final String categorySlug;

  final L name;

  /// Expanded relation: the API returns the provider inline on this endpoint
  /// so a listing screen never has to fan out N requests.
  final ServiceProvider provider;

  final L description;

  /// Null means "quote after inspection".
  final double? price;
  final int? durationMin;

  /// What the price covers, one line per item. Shared per category — the
  /// checklist is what the customer is buying, not a per-workshop sales
  /// pitch.
  final List<L> includes;

  /// Workmanship warranty on the job. Null where a warranty makes no sense
  /// (a callout, an open-ended contract).
  final int? warrantyMonths;

  /// Publish/unpublish flag for a workshop's own catalogue management. The
  /// public catalogue read only ever returns `true` rows; `/my-workshop`
  /// reads return both so the owner can see what they have unpublished.
  final bool isActive;

  /// The workshop owner's chosen photo for this service. Optional — a screen
  /// showing an offering with no photo falls back to a default placeholder
  /// rather than an empty frame.
  final MediaAttachment? photo;

  /// The catalogue id a "request a part + installation" booking files itself
  /// under. Not a real category in the marketplace catalogue — nothing lists
  /// or searches it — but a stable key so the maintenance mapper and the
  /// analytics can tell these bookings apart from catalogue ones.
  static const partInstallCategorySlug = 'part-install';

  /// The stand-in offering a [BookingType.customQuote] booking carries.
  ///
  /// A custom request has no catalogue entry behind it — that is the point of
  /// it — but every screen in the app reads the workshop, the title and the
  /// price off `request.offering`. Rather than making that field nullable and
  /// teaching a dozen widgets to branch, the request carries a quote-only
  /// offering that describes exactly what it is: this workshop, this part, no
  /// published price. `price: null` is not a placeholder here — it is the
  /// truth until the quote arrives.
  factory ServiceOffering.partInstall({
    required ServiceProvider provider,
    required String partDescription,
  }) => ServiceOffering(
    // Derived rather than random so the same workshop's part-install
    // offering is the same record every time it is built — this factory
    // runs on each read of a custom-quote booking, and a fresh GUID per
    // call would make the offering compare unequal to itself.
    id: derivedGuid('part-install', provider.id),
    categoryId: derivedGuid('category', partInstallCategorySlug),
    categorySlug: partInstallCategorySlug,
    // The customer's own words, shown in both languages because the app
    // does not translate what a user typed.
    name: L(partDescription, partDescription),
    provider: provider,
    description: const L(
      'طلب قطعة + تركيبها — السعر بعد عرض الورشة',
      'Part supplied and fitted — priced by the workshop',
    ),
  );

  bool get quoteOnly => price == null;

  /// True for the synthetic offering above rather than a catalogue entry.
  bool get isPartInstall => categorySlug == partInstallCategorySlug;

  /// Free-text search over the service, its workshop and where that workshop
  /// is. [localizedPlace] carries the translated area/governorate in, so the
  /// model does not have to reach for the location catalogue.
  bool matchesQuery(String query, {String? localizedPlace}) =>
      SearchMatch.all(query, [
        name.ar,
        name.en,
        description.ar,
        description.en,
        provider.name.ar,
        provider.name.en,
        provider.area,
        provider.region,
        localizedPlace,
      ]);

  factory ServiceOffering.fromJson(JsonMap json) => ServiceOffering(
    id: json.requireString('id'),
    categoryId: json.stringOr('categoryId', ''),
    categorySlug: json.stringOr('categorySlug', ''),
    name: L.fromJson(json['name']),
    provider: ServiceProvider.fromJson(json.requireObject('provider')),
    description: L.fromJson(json['description']),
    price: json.doubleOrNull('price'),
    durationMin: json.intOrNull('durationMin'),
    includes: [
      for (final item in (json['includes'] as List<dynamic>? ?? const []))
        L.fromJson(item),
    ],
    warrantyMonths: json.intOrNull('warrantyMonths'),
    isActive: json.boolOr('isActive', true),
    photo: json['photo'] == null
        ? null
        : MediaAttachment.fromJson(json.requireObject('photo')),
  );

  JsonMap toJson() => {
    'id': id,
    'categoryId': categoryId,
    'categorySlug': categorySlug,
    'name': name.toJson(),
    'provider': provider.toJson(),
    'description': description.toJson(),
    'price': price,
    'durationMin': durationMin,
    'includes': [for (final item in includes) item.toJson()],
    'warrantyMonths': warrantyMonths,
    'isActive': isActive,
    'photo': photo?.toJson(),
  };

  ServiceOffering copyWith({
    String? id,
    String? categoryId,
    String? categorySlug,
    L? name,
    ServiceProvider? provider,
    L? description,
    double? price,
    int? durationMin,
    List<L>? includes,
    int? warrantyMonths,
    bool? isActive,
    MediaAttachment? photo,
    bool clearPhoto = false,
  }) => ServiceOffering(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    categorySlug: categorySlug ?? this.categorySlug,
    name: name ?? this.name,
    provider: provider ?? this.provider,
    description: description ?? this.description,
    price: price ?? this.price,
    durationMin: durationMin ?? this.durationMin,
    includes: includes ?? this.includes,
    warrantyMonths: warrantyMonths ?? this.warrantyMonths,
    isActive: isActive ?? this.isActive,
    photo: clearPhoto ? null : (photo ?? this.photo),
  );

  @override
  bool operator ==(Object other) =>
      other is ServiceOffering &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.categorySlug == categorySlug &&
      other.name == name &&
      other.provider == provider &&
      other.description == description &&
      other.price == price &&
      other.durationMin == durationMin &&
      other.warrantyMonths == warrantyMonths &&
      other.isActive == isActive &&
      other.photo == photo &&
      const ListEquality<L>().equals(other.includes, includes);

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    categorySlug,
    name,
    provider,
    description,
    price,
    durationMin,
    warrantyMonths,
    isActive,
    photo,
    Object.hashAll(includes),
  );
}
