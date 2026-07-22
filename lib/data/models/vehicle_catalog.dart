import '../../core/json/json_utils.dart';
import 'car_make.dart';

/// Make/model/trim catalog powering every car picker in the app.
///
/// Served by `CatalogRepository`; backed by `GET /cars/catalog` and
/// `GET /cars/trims` in Phase 2.
class VehicleCatalog {
  const VehicleCatalog({
    required this.makes,
    required this.trimsByModel,
    required this.plateLetters,
    this.earliestYear = 1990,
  });

  final List<CarMake> makes;

  /// Sub-model (trim) options per model — mirrors the marketplace's
  /// "Sub-Model" facet.
  final Map<String, List<String>> trimsByModel;

  /// Letters valid on an Omani plate.
  final List<String> plateLetters;

  /// Oldest model year offered in year pickers.
  final int earliestYear;

  static const empty = VehicleCatalog(
    makes: [],
    trimsByModel: {},
    plateLetters: [],
  );

  /// Newest-first model years, ending at [earliestYear]. Computed rather than
  /// stored so the list never goes stale as the calendar advances.
  List<int> get years =>
      [for (var y = DateTime.now().year + 1; y >= earliestYear; y--) y];

  List<String> trimsFor(String model) => trimsByModel[model] ?? const [];

  CarMake? makeNamed(String name) {
    for (final make in makes) {
      if (make.name == name) return make;
    }
    return null;
  }

  List<String> modelsOf(String makeName) => makeNamed(makeName)?.models ?? const [];

  factory VehicleCatalog.fromJson(JsonMap json) => VehicleCatalog(
        makes: json.objectList('makes').map(CarMake.fromJson).toList(),
        trimsByModel: {
          for (final entry
              in (json.objectOrNull('trimsByModel') ?? const {}).entries)
            entry.key: (entry.value as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList(growable: false),
        },
        plateLetters: json.stringList('plateLetters'),
        earliestYear: json.intOr('earliestYear', 1990),
      );

  JsonMap toJson() => {
        'makes': [for (final m in makes) m.toJson()],
        'trimsByModel': trimsByModel,
        'plateLetters': plateLetters,
        'earliestYear': earliestYear,
      };

  VehicleCatalog copyWith({
    List<CarMake>? makes,
    Map<String, List<String>>? trimsByModel,
    List<String>? plateLetters,
    int? earliestYear,
  }) =>
      VehicleCatalog(
        makes: makes ?? this.makes,
        trimsByModel: trimsByModel ?? this.trimsByModel,
        plateLetters: plateLetters ?? this.plateLetters,
        earliestYear: earliestYear ?? this.earliestYear,
      );
}
