import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_config.dart';
import '../../data/models/models.dart';
import '../media/vehicle_assets.dart';
import '../theme/app_colors.dart';
import 'car_artwork.dart';

/// Brand logo tile — the real logo, same as the web app.
///
/// Falls back to a monogram tile while the logo loads and if it fails, so a
/// brand row never renders as a line of empty circles offline. A logo bundled
/// in `assets/logos/` and registered in [bundledBrandLogos] wins over the CDN.
class MakeLogo extends StatelessWidget {
  const MakeLogo({super.key, required this.make, this.size = 38});

  final CarMake make;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: _mark(),
    );
  }

  Widget _mark() {
    final asset = brandLogoAsset(make.name);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => _Monogram(mark: make.mark),
      );
    }
    if (AppConfig.useRemoteVehicleImages) {
      return Image.network(
        make.logoUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => _Monogram(mark: make.mark),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _Monogram(mark: make.mark),
      );
    }
    return _Monogram(mark: make.mark);
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.mark});

  final String mark;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Text(
        mark,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// Picture of a car — updates whenever make/model change.
///
/// Resolution order:
///  1. a real photo bundled in `assets/cars/` (see [carPhotoAsset]);
///  2. the remote studio CDN — the default, so mobile matches the web app;
///  3. the drawn silhouette ([CarArtwork]) while loading and on failure.
///
/// Step 3 is why this widget never renders an empty box on a phone with no
/// connection, which is what the whole app used to do on Android and iOS.
/// `--dart-define=AK_REMOTE_CAR_IMAGES=false` skips step 2 entirely.
class CarImage extends StatelessWidget {
  const CarImage({
    super.key,
    required this.make,
    required this.model,
    this.height = 130,
    this.color,
    this.variant = 0,
    this.expand = false,
    this.fallbackIcon = LucideIcons.carFront,
  });

  final String make;
  final String model;

  /// Fixed height for the picture. Ignored when [expand] is true.
  final double height;

  /// Exterior colour name (`'White'`, `'Silver'`, …) when the car has one.
  final String? color;

  /// Index of this render among several of the same car (photo carousels),
  /// so repeated "photos" are not identical.
  final int variant;

  /// Fill the parent's constraints instead of using [height] — for hero
  /// headers and carousels.
  final bool expand;

  /// Kept for call-site compatibility. The silhouette is now the fallback
  /// for every failure path, so this icon is no longer rendered — it only
  /// still describes the car's category at the call site.
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final picture = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey('$make-$model-$variant'),
        child: _picture(),
      ),
    );
    return expand ? picture : SizedBox(height: height, child: picture);
  }

  Widget _picture() {
    final asset = carPhotoAsset(make, model);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: expand ? BoxFit.cover : BoxFit.contain,
        errorBuilder: (context, _, _) => _artwork(),
      );
    }
    if (AppConfig.useRemoteVehicleImages) {
      return Image.network(
        // Variant 0 keeps the CDN's default angle — the exact pose the web app
        // shows. Later carousel pages rotate around the car.
        variant == 0
            ? carImageUrl(make, model)
            : carImageUrl(make, model, angle: 20 + (variant % 8) * 5),
        fit: expand ? BoxFit.cover : BoxFit.contain,
        errorBuilder: (context, _, _) => _artwork(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _artwork(),
      );
    }
    return _artwork();
  }

  Widget _artwork() => Padding(
        padding: EdgeInsets.all(expand ? 18 : 4),
        child: CarArtwork(
          make: make,
          model: model,
          color: color,
          variant: variant,
        ),
      );
}
