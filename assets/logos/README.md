# assets/logos — bundled brand logos (temporary)

`MakeLogo` shows the real brand logo from the CDN, falling back to a monogram
tile while it loads and if it fails. To bundle a logo instead of fetching it:

1. Add `<make-slug>.png` here, e.g. `mercedes-benz.png` (square, transparent
   background, ~256px).
2. Register it in `lib/core/media/vehicle_assets.dart`:

   ```dart
   const Map<String, String> bundledBrandLogos = <String, String>{
     'mercedes-benz': 'assets/logos/mercedes-benz.png',
   };
   ```

Brand logos are trademarks — confirm usage rights before shipping them in a
published build. See `assets/cars/README.md` for the same note on photos.
