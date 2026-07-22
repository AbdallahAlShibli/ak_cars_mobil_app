import '../../core/json/json_utils.dart';

/// A vehicle brand and the models it sells, as shown in the car pickers.
class CarMake {
  const CarMake(this.name, this.models, {this.monogram});

  final String name;
  final List<String> models;

  /// Short mark shown in the logo tile (defaults to first 2 letters).
  final String? monogram;

  String get mark =>
      monogram ?? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();

  static const _slugExceptions = {
    'Mercedes-Benz': 'mercedes-benz',
    'Range Rover': 'land-rover',
    'Land Rover': 'land-rover',
    'Mini': 'mini',
    'MG': 'mg',
    'GMC': 'gmc',
  };

  String get slug =>
      _slugExceptions[name] ?? name.toLowerCase().replaceAll(' ', '-');

  /// Real brand logo (staging CDN — falls back to a monogram offline).
  String get logoUrl =>
      'https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/thumb/$slug.png';

  factory CarMake.fromJson(JsonMap json) => CarMake(
        json.requireString('name'),
        json.stringList('models'),
        monogram: json.stringOrNull('monogram'),
      );

  JsonMap toJson() => {
        'name': name,
        'models': models,
        'monogram': monogram,
      };

  CarMake copyWith({String? name, List<String>? models, String? monogram}) =>
      CarMake(
        name ?? this.name,
        models ?? this.models,
        monogram: monogram ?? this.monogram,
      );

  @override
  bool operator ==(Object other) =>
      other is CarMake &&
      other.name == name &&
      other.monogram == monogram &&
      Object.hashAll(other.models) == Object.hashAll(models);

  @override
  int get hashCode => Object.hash(name, monogram, Object.hashAll(models));
}

/// Studio photo of a specific make/model (staging CDN). The image changes
/// with the selected car; UI must always provide a fallback.
String carImageUrl(String make, String model, {int angle = 23}) {
  final makeSlug = make.toLowerCase().replaceAll(' ', '');
  final modelSlug = model.toLowerCase().split(' ').first;
  return 'https://cdn.imagin.studio/getimage?customer=hrjavascript-mastery'
      '&make=$makeSlug&modelFamily=$modelSlug&zoomType=fullscreen&angle=$angle';
}
