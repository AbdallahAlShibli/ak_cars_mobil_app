import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../theme/app_colors.dart';

/// Real brand logo in a white circle. Falls back to a monogram tile
/// when the logo can't load (offline / unknown brand).
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
      child: Image.network(
        make.logoUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => _Monogram(mark: make.mark),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _Monogram(mark: make.mark),
      ),
    );
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

/// Studio photo of the selected car — updates whenever make/model change.
/// Falls back to a tinted car icon when the photo can't load.
class CarImage extends StatelessWidget {
  const CarImage({
    super.key,
    required this.make,
    required this.model,
    this.height = 130,
    this.fallbackIcon = Icons.directions_car_filled_rounded,
  });

  final String make;
  final String model;
  final double height;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Image.network(
          carImageUrl(make, model),
          key: ValueKey('$make-$model'),
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => _fallback(),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Center(
                  child: Icon(fallbackIcon,
                      size: height * 0.45, color: const Color(0xFFD8D1C4)),
                ),
        ),
      ),
    );
  }

  Widget _fallback() => Center(
        child: Icon(fallbackIcon,
            size: height * 0.55, color: AppColors.ink3),
      );
}
