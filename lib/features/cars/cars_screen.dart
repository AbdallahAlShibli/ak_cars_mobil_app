import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/car_catalog.dart';
import '../../data/gallery_data.dart';
import 'listing_card.dart';

/// Cars marketplace — gradient hero with live search, fancy manufacturer
/// tiles, filtered feed, and a directional floating "Post ad" button
/// (bottom-start: left in English, right in Arabic).
class CarsScreen extends ConsumerStatefulWidget {
  const CarsScreen({super.key});

  @override
  ConsumerState<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends ConsumerState<CarsScreen> {
  VehicleType _type = VehicleType.all;
  bool _allMakes = false;
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allFeed = ref.watch(galleryFeedProvider);
    final q = _query.trim().toLowerCase();
    final feed = allFeed.where((l) {
      final typeOk = switch (_type) {
        VehicleType.trucks || VehicleType.bikes => false,
        _ => true,
      };
      if (!typeOk) return false;
      if (q.isEmpty) return true;
      return l.displayTitle.toLowerCase().contains(q) ||
          l.region.toLowerCase().contains(q);
    }).toList();

    final countsByMake = <String, int>{};
    for (final l in allFeed) {
      countsByMake[l.make] = (countsByMake[l.make] ?? 0) + 1;
    }
    final makes = [...CarCatalog.makes]..sort((a, b) =>
        (countsByMake[b.name] ?? 0).compareTo(countsByMake[a.name] ?? 0));

    return Scaffold(
      floatingActionButton: _PostAdFab(onTap: () {
        if (!ensureRegistered(context, ref)) return;
        context.push('/post-ad');
      }),
      // Bottom-start: left in English (LTR), right in Arabic (RTL).
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          // ------------------------------------------------ hero header
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -34,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -20,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          const Color(0xFF6A5CFF).withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          'Find your next car',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${allFeed.length} live listings across Oman',
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.white70),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _search,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Search make, model or city…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: q.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18),
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final t in VehicleType.values) ...[
                              _HeroTypeChip(
                                label: t.label,
                                icon: t.icon,
                                selected: _type == t,
                                onTap: () =>
                                    setState(() => _type = t),
                              ),
                              const SizedBox(width: 7),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ------------------------------------------------ manufacturers
          if (q.isEmpty) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                'Manufacturer',
                action: _allMakes ? 'Show less' : 'View all',
                onAction: () => setState(() => _allMakes = !_allMakes),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _allMakes
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: makes.length,
                        itemBuilder: (context, i) => _MakeTile(
                          make: makes[i],
                          count: countsByMake[makes[i].name] ?? 0,
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: makes.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, i) => _MakeTile(
                          make: makes[i],
                          count: countsByMake[makes[i].name] ?? 0,
                        ),
                      ),
                    ),
            ),
          ],
          // ------------------------------------------------ feed
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(
              q.isEmpty ? 'All cars' : '${feed.length} results',
              action: 'Filters',
              onAction: () => context.push('/cars/results'),
            ),
          ),
          const SizedBox(height: 10),
          if (feed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const IconTile(Icons.no_crash_rounded,
                        size: 64,
                        radius: 22,
                        background: AppColors.field,
                        foreground: AppColors.ink3),
                    const SizedBox(height: 10),
                    Text(
                      q.isEmpty
                          ? 'No listings in this category yet'
                          : 'No cars match "$_query"',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.ink2),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final (i, l) in feed.indexed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Entrance(
                  delayMs: 40 * i,
                  child: ListingCard(listing: l),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

/// Frosted type chip that sits on the hero gradient.
class _HeroTypeChip extends StatelessWidget {
  const _HeroTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: selected ? AppColors.brandDark : Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.brandDark : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fancy manufacturer tile — gradient-ringed real logo + listing count.
class _MakeTile extends StatelessWidget {
  const _MakeTile({required this.make, required this.count});

  final CarMake make;
  final int count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/cars/make/${Uri.encodeComponent(make.name)}');
      },
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: MakeLogo(make: make, size: 42),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              make.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              count > 0 ? '$count cars' : 'Browse',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: count > 0 ? AppColors.brand : AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient floating "Post ad" button — placed at bottom-start so it
/// sits left in English and right in Arabic automatically.
class _PostAdFab extends StatelessWidget {
  const _PostAdFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: Colors.white, size: 19),
            SizedBox(width: 8),
            Text(
              'Post ad',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
