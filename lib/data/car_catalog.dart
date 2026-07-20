/// Make/model catalog — mirrors the AKCars website car picker.
/// Replace with `GET /api/cars/catalog` in Phase 2.
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
}

/// Studio photo of a specific make/model (staging CDN). The image changes
/// with the selected car; UI must always provide a fallback.
String carImageUrl(String make, String model, {int angle = 23}) {
  final makeSlug = make.toLowerCase().replaceAll(' ', '');
  final modelSlug = model.toLowerCase().split(' ').first;
  return 'https://cdn.imagin.studio/getimage?customer=hrjavascript-mastery'
      '&make=$makeSlug&modelFamily=$modelSlug&zoomType=fullscreen&angle=$angle';
}

abstract final class CarCatalog {
  static const plateLetters = ['A', 'B', 'D', 'H', 'M', 'R', 'S', 'W', 'X', 'Y'];

  static List<int> get years =>
      [for (var y = DateTime.now().year + 1; y >= 1990; y--) y];

  static const makes = [
    CarMake('Toyota', [
      '86', 'Avalon', 'Camry', 'Corolla', 'Crown', 'C-HR', 'FJ Cruiser',
      'Fortuner', 'Hiace', 'Hilux', 'Land Cruiser', 'Land Cruiser 70',
      'Prado', 'RAV4', 'Rush', 'Sequoia', 'Supra', 'Tacoma', 'Tundra',
      'Urban Cruiser', 'Yaris',
    ], monogram: 'TO'),
    CarMake('Nissan', [
      'Altima', 'Armada', 'Kicks', 'Maxima', 'Navara', 'Pathfinder',
      'Patrol', 'Sunny', 'X-Trail', 'Xterra', 'Z',
    ], monogram: 'NI'),
    CarMake('Lexus', [
      'ES', 'GX', 'IS', 'LS', 'LX', 'NX', 'RX', 'UX',
    ], monogram: 'LX'),
    CarMake('Mercedes-Benz', [
      'A-Class', 'C-Class', 'E-Class', 'S-Class', 'G-Class', 'GLC', 'GLE',
      'GLS',
    ], monogram: 'MB'),
    CarMake('Honda', [
      'Accord', 'City', 'Civic', 'CR-V', 'HR-V', 'Pilot',
    ], monogram: 'HO'),
    CarMake('Hyundai', [
      'Accent', 'Creta', 'Elantra', 'Palisade', 'Santa Fe', 'Sonata',
      'Tucson',
    ], monogram: 'HY'),
    CarMake('Jeep', [
      'Cherokee', 'Grand Cherokee', 'Wrangler',
    ], monogram: 'JP'),
    CarMake('Dodge', ['Challenger', 'Charger', 'Durango'], monogram: 'DO'),
    CarMake('Ford', [
      'Bronco', 'Edge', 'Expedition', 'Explorer', 'F-150', 'Mustang',
      'Ranger', 'Taurus',
    ], monogram: 'FO'),
    CarMake('Chevrolet', [
      'Camaro', 'Captiva', 'Corvette', 'Groove', 'Malibu', 'Silverado',
      'Tahoe', 'Traverse',
    ], monogram: 'CH'),
    CarMake('GMC', ['Acadia', 'Sierra', 'Terrain', 'Yukon'], monogram: 'GM'),
    CarMake('Mitsubishi', [
      'ASX', 'Attrage', 'L200', 'Montero Sport', 'Outlander', 'Pajero',
    ], monogram: 'MI'),
    CarMake('Kia', [
      'Cerato', 'K5', 'Pegas', 'Seltos', 'Sorento', 'Sportage', 'Telluride',
    ], monogram: 'KIA'),
    CarMake('BMW', [
      '3 Series', '5 Series', '7 Series', 'X3', 'X5', 'X6', 'X7',
    ], monogram: 'BMW'),
    CarMake('Audi', ['A4', 'A6', 'A8', 'Q3', 'Q5', 'Q7', 'Q8'], monogram: 'AU'),
    CarMake('Volkswagen', [
      'Golf', 'Jetta', 'Passat', 'Teramont', 'Tiguan', 'Touareg',
    ], monogram: 'VW'),
    CarMake('Mazda', ['CX-5', 'CX-9', 'Mazda3', 'Mazda6'], monogram: 'MA'),
    CarMake('Subaru', ['Forester', 'Impreza', 'Outback', 'XV'], monogram: 'SU'),
    CarMake('Suzuki', [
      'Baleno', 'Ciaz', 'Dzire', 'Grand Vitara', 'Jimny', 'Swift',
    ], monogram: 'SZ'),
    CarMake('Isuzu', ['D-Max', 'MU-X'], monogram: 'IS'),
    CarMake('Land Rover', [
      'Defender', 'Discovery', 'Discovery Sport',
    ], monogram: 'LR'),
    CarMake('Range Rover', [
      'Evoque', 'Sport', 'Velar', 'Vogue',
    ], monogram: 'RR'),
    CarMake('Infiniti', ['Q50', 'QX50', 'QX60', 'QX80'], monogram: 'IN'),
    CarMake('Porsche', [
      '911', 'Cayenne', 'Macan', 'Panamera', 'Taycan',
    ], monogram: 'PO'),
    CarMake('Volvo', ['S90', 'XC40', 'XC60', 'XC90'], monogram: 'VO'),
    CarMake('Mini', ['Clubman', 'Cooper', 'Countryman'], monogram: 'MN'),
    CarMake('Lincoln', ['Aviator', 'Navigator', 'Nautilus'], monogram: 'LI'),
    CarMake('Cadillac', ['CT5', 'Escalade', 'XT5', 'XT6'], monogram: 'CA'),
    CarMake('Genesis', ['G70', 'G80', 'GV70', 'GV80'], monogram: 'GE'),
    CarMake('Tesla', ['Model 3', 'Model S', 'Model X', 'Model Y'],
        monogram: 'TE'),
    CarMake('MG', ['5', 'GT', 'HS', 'RX5', 'ZS'], monogram: 'MG'),
    CarMake('Changan', ['Alsvin', 'CS35 Plus', 'CS75', 'Eado'],
        monogram: 'CN'),
    CarMake('Geely', ['Coolray', 'Emgrand', 'Monjaro', 'Tugella'],
        monogram: 'GL'),
  ];
}
