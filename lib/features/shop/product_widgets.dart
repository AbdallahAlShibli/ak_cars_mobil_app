import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

/// Star + numeric rating, used by every product surface (grid card, best
/// seller rail, product page) so the same number never renders two ways.
class ProductRating extends StatelessWidget {
  const ProductRating({super.key, required this.rating, this.size = 11});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.star, size: size + 2, color: ak.amber),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: ak.inkSub,
          ),
        ),
      ],
    );
  }
}

/// Price, with the pre-discount price struck through when the part is on
/// offer.
class ProductPriceLine extends StatelessWidget {
  const ProductPriceLine({
    super.key,
    required this.product,
    required this.size,
  });

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            'OMR ${product.price.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: ak.ink,
            ),
          ),
        ),
        if (product.onOffer) ...[
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              product.oldPrice!.toStringAsFixed(2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size - 3,
                color: ak.inkFaint,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Amber discount pill ("-15%"). Amber, never red — red is reserved for SOS.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent, this.suffix = ''});

  final int percent;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ak.amber,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '-$percent%$suffix',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1D1B17),
        ),
      ),
    );
  }
}
