import 'package:collection/collection.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import '../../core/utils/search_match.dart';
import 'service_provider.dart';

/// A concrete service a specific provider sells within a category.
class ServiceOffering {
  const ServiceOffering({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.provider,
    required this.description,
    this.price,
    this.durationMin,
    this.includes = const [],
    this.warrantyMonths,
  });

  final String id;
  final String categoryId;
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

  /// The catalogue id a "request a part + installation" booking files itself
  /// under. Not a real category in the marketplace catalogue — nothing lists
  /// or searches it — but a stable key so the maintenance mapper and the
  /// analytics can tell these bookings apart from catalogue ones.
  static const partInstallCategoryId = 'part-install';

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
  }) =>
      ServiceOffering(
        id: 'part-install-${provider.id}',
        categoryId: partInstallCategoryId,
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
  bool get isPartInstall => categoryId == partInstallCategoryId;

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
        name: L.fromJson(json['name']),
        provider: ServiceProvider.fromJson(json.requireObject('provider')),
        description: L.fromJson(json['description']),
        price: json.doubleOrNull('price'),
        durationMin: json.intOrNull('durationMin'),
        includes: [
          for (final item in (json['includes'] as List<dynamic>? ?? const []))
            L.fromJson(item)
        ],
        warrantyMonths: json.intOrNull('warrantyMonths'),
      );

  JsonMap toJson() => {
        'id': id,
        'categoryId': categoryId,
        'name': name.toJson(),
        'provider': provider.toJson(),
        'description': description.toJson(),
        'price': price,
        'durationMin': durationMin,
        'includes': [for (final item in includes) item.toJson()],
        'warrantyMonths': warrantyMonths,
      };

  ServiceOffering copyWith({
    String? id,
    String? categoryId,
    L? name,
    ServiceProvider? provider,
    L? description,
    double? price,
    int? durationMin,
    List<L>? includes,
    int? warrantyMonths,
  }) =>
      ServiceOffering(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        provider: provider ?? this.provider,
        description: description ?? this.description,
        price: price ?? this.price,
        durationMin: durationMin ?? this.durationMin,
        includes: includes ?? this.includes,
        warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceOffering &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.name == name &&
      other.provider == provider &&
      other.description == description &&
      other.price == price &&
      other.durationMin == durationMin &&
      other.warrantyMonths == warrantyMonths &&
      const ListEquality<L>().equals(other.includes, includes);

  @override
  int get hashCode => Object.hash(
        id,
        categoryId,
        name,
        provider,
        description,
        price,
        durationMin,
        warrantyMonths,
        Object.hashAll(includes),
      );
}
