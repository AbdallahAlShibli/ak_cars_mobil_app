# assets/cars — bundled car photos (temporary)

Cars come from the studio CDN by default, the same as the web app; the vector
silhouette in `lib/core/widgets/car_artwork.dart` is the fallback while an
image loads and when it fails. Nothing here is required for the app to work —
this folder exists so real photography can be dropped in per model, taking
precedence over the CDN, without touching any screen code.

## Adding a photo

1. Name the file `<make>_<model>.webp` (lowercase, underscores), e.g.
   `toyota_land_cruiser.webp`. WebP keeps the bundle small; PNG/JPG work too.
   Aim for a transparent or light background and roughly 3:2, ~1200px wide.
2. Register it in `lib/core/media/vehicle_assets.dart`:

   ```dart
   const Map<String, String> bundledCarPhotos = <String, String>{
     'toyota|land-cruiser': 'assets/cars/toyota_land_cruiser.webp',
   };
   ```

   The key is `<make-slug>|<model-slug>`. A key using only the first word of
   the model (`'toyota|land'`) matches the whole family, so one photo can
   cover `Land Cruiser`, `Land Cruiser GXR`, and so on.

3. That's it — `CarImage` prefers a bundled photo over everything else, on
   every screen (home, garage, listings, add-car preview, listing detail).

## Licensing note

Studio renders from `cdn.imagin.studio` and brand logos from the
`car-logos-dataset` repo are third-party assets under their own terms. They
are **not** committed here. Clear the rights before bundling them for a
public release.

## Testing the offline path

To see what a phone with no connection shows, skip the CDN entirely:

```
flutter run --dart-define=AK_REMOTE_CAR_IMAGES=false
```

Bundled photos still win over both.
