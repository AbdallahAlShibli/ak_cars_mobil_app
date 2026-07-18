import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/car_catalog.dart';
import '../../data/gallery_data.dart';

/// Listing detail — photo carousel with counter, share/favorite,
/// "Ask about price" chip, full spec table, description, report,
/// seller card, related ads, sticky Call | WhatsApp bar.
class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _photos = PageController();
  int _photo = 0;
  bool _expanded = false;

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  void _demo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _reportAd(BuildContext context) async {
    const reasons = [
      'Misleading information',
      'Wrong price',
      'Already sold',
      'Prohibited content',
      'Suspected fraud',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Report this ad',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final r in reasons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined,
                      size: 19, color: AppColors.bad),
                  title: Text(r, style: const TextStyle(fontSize: 13.5)),
                  onTap: () => Navigator.pop(context, r),
                ),
            ],
          ),
        ),
      ),
    );
    if (reason != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Reported: "$reason" — our team will review it')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = GalleryData.listings
        .firstWhereOrNull((l) => l.id == widget.listingId);
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Listing not found')),
      );
    }

    final favorites = ref.watch(favoritesProvider);
    final fav = favorites.contains(listing.id);
    final related = GalleryData.related(listing);

    final specs = <(String, String, Color?)>[
      ('Car name', listing.displayTitle, null),
      ('Mileage', '${listing.mileage} km', null),
      ('Deal type', listing.dealType, null),
      ('Body type', listing.bodyType, null),
      ('Cylinders', '${listing.cylinders}', null),
      ('Transmission', listing.transmission, null),
      ('Keys', '${listing.keys}', null),
      ('Spec grade', listing.specGrade, null),
      ('Drivetrain', listing.drivetrain, null),
      ('Fuel type', listing.fuel, null),
      ('Exterior color', listing.exteriorColor, listing.exteriorSwatch),
      ('Interior color', listing.interiorColor, listing.interiorSwatch),
      ('Published', '14/7/2026', null),
      ('Region', listing.region, null),
    ];

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.bg,
                leading: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                ),
                actions: [
                  _RoundButton(
                    icon: Icons.share_rounded,
                    onTap: () => _demo('Listing link copied to share'),
                  ),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: fav
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    color: fav ? AppColors.bad : AppColors.ink,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final next = Set<String>.from(favorites);
                      if (!next.add(listing.id)) next.remove(listing.id);
                      ref.read(favoritesProvider.notifier).state = next;
                    },
                  ),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'listing-${listing.id}',
                        child: PageView.builder(
                          controller: _photos,
                          itemCount: listing.photoCount,
                          onPageChanged: (i) =>
                              setState(() => _photo = i),
                          itemBuilder: (context, i) => ColoredBox(
                            color: const Color(0xFFE7ECF3),
                            child: Image.network(
                              carImageUrl(listing.make, listing.model,
                                  angle: 20 + (i % 8) * 5),
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, _) => Center(
                                child: Icon(listing.icon,
                                    size: 72,
                                    color: const Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 14,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              key: ValueKey(_photo),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.ink.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_photo + 1} / ${listing.photoCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                sliver: SliverList.list(
                  children: [
                    Entrance(
                      child: Text(
                        listing.displayTitle,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Entrance(
                      delayMs: 50,
                      child: Row(
                        children: [
                          if (listing.price != null)
                            Text(
                              'OMR ${listing.price!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDark,
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () => Contact.whatsapp(
                                context,
                                '96892000000',
                                message:
                                    'Hi, what is the price of your ${listing.displayTitle} on AK Cars?',
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 9),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AppColors.brand, width: 1.5),
                                  borderRadius:
                                      BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Ask about price',
                                  style: TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          StatusBadge(listing.dealType),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Entrance(
                      delayMs: 90,
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Details',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            for (final (i, s) in specs.indexed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 11),
                                decoration: BoxDecoration(
                                  border: i == specs.length - 1
                                      ? null
                                      : const Border(
                                          bottom: BorderSide(
                                              color: Color(0xFFF1F5F9)),
                                        ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(s.$1,
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.ink2)),
                                    ),
                                    if (s.$3 != null) ...[
                                      Container(
                                        width: 16,
                                        height: 16,
                                        margin: const EdgeInsets.only(
                                            right: 6),
                                        decoration: BoxDecoration(
                                          color: s.$3,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppColors.border),
                                        ),
                                      ),
                                    ],
                                    Text(s.$2,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Entrance(
                      delayMs: 120,
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Description',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            AnimatedCrossFade(
                              duration:
                                  const Duration(milliseconds: 200),
                              crossFadeState: _expanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              firstChild: Text(
                                listing.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.ink2,
                                    height: 1.6),
                              ),
                              secondChild: Text(
                                listing.description,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.ink2,
                                    height: 1.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _expanded = !_expanded),
                                child: Text(
                                  _expanded ? 'Show less' : 'Show more',
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Entrance(
                      delayMs: 140,
                      child: AppCard(
                        onTap: () => _reportAd(context),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flag_outlined,
                                size: 17, color: AppColors.bad),
                            SizedBox(width: 8),
                            Text(
                              'Report this ad',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.bad,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Entrance(
                      delayMs: 160,
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: AppColors.brandSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  listing.sellerName[0],
                                  style: const TextStyle(
                                    color: AppColors.brandDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(listing.sellerName,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Joined ${listing.sellerJoined}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.ink3),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${listing.sellerAds} ads  ·  ${listing.sellerFollowers} followers',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink2),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFFCBD5E1)),
                          ],
                        ),
                      ),
                    ),
                    if (related.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Entrance(
                        delayMs: 180,
                        child: SectionHeader('Related ads'),
                      ),
                      const SizedBox(height: 10),
                      Entrance(
                        delayMs: 200,
                        child: SizedBox(
                          height: 132,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: related.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final r = related[i];
                              return GestureDetector(
                                onTap: () => context.pushReplacement(
                                    '/cars/listing/${r.id}'),
                                child: Container(
                                  width: 150,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        r.tint,
                                        r.tint.withValues(alpha: 0.6),
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Icon(r.icon,
                                            size: 36,
                                            color: Colors.white60),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.ink
                                                .withValues(alpha: 0.6),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    999),
                                          ),
                                          child: Text(
                                            r.price != null
                                                ? 'OMR ${r.price!.toStringAsFixed(0)}'
                                                : 'Ask for price',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.bg,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        side: const BorderSide(
                            color: AppColors.brand, width: 1.5),
                      ),
                      onPressed: () =>
                          Contact.call(context, '+96892000000'),
                      icon: const Icon(Icons.phone_rounded, size: 17),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25A55A),
                      ),
                      onPressed: () => Contact.whatsapp(
                        context,
                        '96892000000',
                        message:
                            'Hi, I am interested in your ad on AK Cars.',
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 17),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }
}
