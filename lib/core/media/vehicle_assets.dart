/// Lookup for **bundled** vehicle imagery (`assets/cars/`, `assets/logos/`).
///
/// The app renders cars offline by default: `CarImage` draws a vector
/// silhouette (see `core/widgets/car_artwork.dart`) so a car always has a
/// picture with no network, no CDN account and no third-party licensing.
/// A real photo takes over the moment one is bundled here.
///
/// **To add a real photo (temporary, until the publish decision is made):**
/// 1. Drop the file in `assets/cars/` — e.g. `toyota_land_cruiser.webp`.
/// 2. Add one line to [bundledCarPhotos] keyed by [vehicleKey].
/// 3. `flutter pub get` is not needed — the folder is already declared in
///    `pubspec.yaml`.
///
/// The map is explicit on purpose: it means the app never attempts to load an
/// asset that is not there, so there are no missing-asset exceptions in the
/// logs and the lookup is testable without a `rootBundle`.
library;

String _slug(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Canonical key for a make/model pair: `toyota|land-cruiser`.
String vehicleKey(String make, String model) =>
    '${_slug(make)}|${_slug(model)}';

/// Key for the whole model family, ignoring trim words:
/// `Land Cruiser GXR` → `toyota|land`.
String vehicleFamilyKey(String make, String model) {
  final family = model.trim().split(RegExp(r'\s+')).first;
  return '${_slug(make)}|${_slug(family)}';
}

/// Bundled studio photos, keyed by [vehicleKey] (exact) or
/// [vehicleFamilyKey] (whole family). Empty today — the vector silhouette
/// covers every car until real photography is licensed.
const Map<String, String> bundledCarPhotos = <String, String>{};

/// Bundled brand logos, keyed by the make slug (`mercedes-benz`).
/// Empty today — [MakeLogo] falls back to a monogram tile.
const Map<String, String> bundledBrandLogos = <String, String>{};

/// Asset path of a bundled photo for this car, or `null` when none is
/// bundled and the caller should draw the silhouette instead.
String? carPhotoAsset(String make, String model) =>
    bundledCarPhotos[vehicleKey(make, model)] ??
    bundledCarPhotos[vehicleFamilyKey(make, model)];

/// Asset path of a bundled logo for this brand, or `null`.
String? brandLogoAsset(String make) => bundledBrandLogos[_slug(make)];
