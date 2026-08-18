import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Marketplace listing card: photo, title, price / "Ask for price",
/// time-ago, WhatsApp | Call actions, favorite heart. Hero image → detail.
class ListingCard extends ConsumerWidget {
  const ListingCard({super.key, required this.listing});

  final GalleryListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final favorites = ref.watch(favoritesProvider);
    final fav = favorites.contains(listing.id);

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/cars/listing/${listing.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final next = Set<String>.from(favorites);
                        if (!next.add(listing.id)) next.remove(listing.id);
                        ref.read(favoritesProvider.notifier).state = next;
                      },
                      child: AnimatedScale(
                        scale: fav ? 1.15 : 1,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          fav
                              ? LucideIcons.heart
                              : LucideIcons.heart,
                          size: 20,
                          color: fav ? AppColors.bad : AppColors.ink3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        listing.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                listing.price != null
                    ? RialAmount(
                        listing.price!,
                        decimals: 0,
                        bold: true,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDark,
                        ),
                      )
                    : Text(
                        s.t('اسأل عن السعر', 'Ask for price'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDark,
                        ),
                      ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(LucideIcons.clock,
                        size: 12, color: AppColors.ink3),
                    const SizedBox(width: 4),
                    Text(listing.postedLabel(s),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.ink3)),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _ContactAction(
                      icon: LucideIcons.messageCircle,
                      label: 'WhatsApp',
                      color: const Color(0xFF25A55A),
                      onTap: () => Contact.whatsapp(
                        context,
                        '96892000000',
                        message: s.t(
                            'مرحباً، أنا مهتم بسيارتك ${listing.displayTitle} على AK Cars.',
                            'Hi, I am interested in your ${listing.displayTitle} on AK Cars.'),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: AppColors.border,
                    ),
                    _ContactAction(
                      icon: LucideIcons.phone,
                      label: s.t('اتصال', 'Call'),
                      color: AppColors.brand,
                      onTap: () => Contact.call(context, '+96892000000'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Hero(
            tag: 'listing-${listing.id}',
            child: Container(
              width: 118,
              height: 108,
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: CarImage(
                make: listing.make,
                model: listing.model,
                color: listing.exteriorColor,
                height: 108,
                fallbackIcon: listing.icon,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
