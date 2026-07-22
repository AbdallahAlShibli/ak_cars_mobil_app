import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'cars_filter_screen.dart';

final _fmt = intl.NumberFormat('#,###', 'en');

/// Cars marketplace — Sand & Ink (handoff #3d): title + "Post your ad"
/// ink pill, search, category chips, brand row with the amber "+N more"
/// card, and a 2×n ads grid with WhatsApp shortcuts.
class CarsScreen extends ConsumerStatefulWidget {
  const CarsScreen({super.key});

  @override
  ConsumerState<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends ConsumerState<CarsScreen> {
  bool _allMakes = false;
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context).push<CarsFilter>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            CarsFilterScreen(initial: ref.read(carsFilterProvider)),
      ),
    );
    if (result != null) {
      ref.read(carsFilterProvider.notifier).set(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final allFeed = ref.watch(galleryFeedProvider);
    final filter = ref.watch(carsFilterProvider);
    final q = _query.trim().toLowerCase();
    final feed = ref.watch(filteredGalleryProvider).where((l) {
      if (q.isEmpty) return true;
      return l.displayTitle.toLowerCase().contains(q) ||
          l.region.toLowerCase().contains(q);
    }).toList();

    final countsByMake = <String, int>{};
    for (final l in allFeed) {
      countsByMake[l.make] = (countsByMake[l.make] ?? 0) + 1;
    }
    final makes = [...ref.watch(vehicleCatalogProvider).makes]..sort((a, b) =>
        (countsByMake[b.name] ?? 0).compareTo(countsByMake[a.name] ?? 0));
    final topMakes = makes.take(4).toList();

    final categories = [
      ('all', s.t('الكل', 'All')),
      ('Sedan', s.t('سيدان', 'Sedan')),
      ('SUV', s.t('دفع رباعي', 'SUV')),
      ('Pickup', s.t('بيك أب', 'Pickup')),
    ];

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            // ------------------------------------------------ header
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.t('سوق السيارات', 'Cars market'),
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                InkPill(
                  label: s.t('أضف إعلانك', 'Post your ad'),
                  icon: LucideIcons.plus,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  onTap: () {
                    if (!ensureRegistered(context, ref)) return;
                    context.push('/post-ad');
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ------------------------------------------------ search
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: ak.surface,
                border: Border.all(color: ak.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.search, size: 15, color: ak.inkSub),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText:
                            s.t('ابحث: كامري، أرمادا…', 'Search: Camry, Armada…'),
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  if (q.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      child: Icon(LucideIcons.x, size: 15, color: ak.inkSub),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ------------------------------------------------ categories
            Text(
              s.t('الفئات الشائعة', 'Popular categories'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ak.inkSub),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (id, label) in categories) ...[
                    _CategoryChip(
                      label: label,
                      selected: id == 'all'
                          ? filter.bodyTypes.isEmpty
                          : (filter.bodyTypes.length == 1 &&
                              filter.bodyTypes.contains(id)),
                      onTap: () => ref
                          .read(carsFilterProvider.notifier)
                          .setBodyType(id == 'all' ? null : id),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ------------------------------------------------ makes
            Text(
              s.t('كل الماركات', 'All makes'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ak.inkSub),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final m in topMakes) ...[
                  Expanded(child: _MakeCard(make: m)),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _allMakes = !_allMakes),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 2),
                      decoration: BoxDecoration(
                        color: ak.amberSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _allMakes
                                ? '×'
                                : '+${makes.length - topMakes.length}',
                            style: GoogleFonts.chakraPetch(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D1B17),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _allMakes
                                ? s.t('إغلاق', 'Close')
                                : s.t('المزيد', 'More'),
                            style: TextStyle(
                                fontSize: 8.5, color: ak.promoSub),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _allMakes
                  ? Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 9,
                          crossAxisSpacing: 9,
                          childAspectRatio: 1.05,
                        ),
                        itemCount: makes.length - topMakes.length,
                        itemBuilder: (context, i) =>
                            _MakeCard(make: makes[i + topMakes.length]),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 14),
            // ------------------------------------------------ latest ads
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.isEmpty && filter.activeCount == 0
                        ? s.t('أحدث الإعلانات', 'Latest ads')
                        : s.t('${feed.length} نتيجة', '${feed.length} results'),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
                if (filter.activeCount > 0) ...[
                  GestureDetector(
                    onTap: () =>
                        ref.read(carsFilterProvider.notifier).reset(),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: Text(
                        s.t('مسح', 'Clear'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: ak.dangerText,
                        ),
                      ),
                    ),
                  ),
                ],
                GestureDetector(
                  onTap: _openFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: filter.activeCount > 0
                          ? ak.primary
                          : ak.surface,
                      border: filter.activeCount > 0
                          ? null
                          : Border.all(color: ak.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.slidersHorizontal,
                            size: 12,
                            color: filter.activeCount > 0
                                ? ak.onPrimary
                                : ak.inkSub),
                        const SizedBox(width: 5),
                        Text(
                          filter.activeCount > 0
                              ? s.t('فلاتر (${filter.activeCount})',
                                  'Filters (${filter.activeCount})')
                              : s.t('فلاتر', 'Filters'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: filter.activeCount > 0
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: filter.activeCount > 0
                                ? ak.onPrimary
                                : ak.inkSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            if (feed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.car,
                          size: 44, color: ak.inkFaint),
                      const SizedBox(height: 10),
                      Text(
                        q.isNotEmpty
                            ? s.t('لا نتائج لـ "$_query"',
                                'No cars match "$_query"')
                            : filter.activeCount > 0
                                ? s.t('لا إعلانات تطابق هذه الفلاتر',
                                    'No ads match these filters')
                                : s.t('لا إعلانات في هذه الفئة بعد',
                                    'No listings in this category yet'),
                        style:
                            TextStyle(fontSize: 13, color: ak.inkSub),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 11,
                crossAxisSpacing: 11,
                childAspectRatio: 0.92,
                children: [
                  for (final l in feed) _AdCard(listing: l),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? ak.primary : ak.surface,
          border: selected ? null : Border.all(color: ak.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? ak.onPrimary : ak.ink,
          ),
        ),
      ),
    );
  }
}

class _MakeCard extends StatelessWidget {
  const _MakeCard({required this.make});

  final CarMake make;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/cars/make/${Uri.encodeComponent(make.name)}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        decoration: BoxDecoration(
          color: ak.surface,
          border: Border.all(color: ak.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              make.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.chakraPetch(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: ak.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              make.mark,
              style: TextStyle(fontSize: 8.5, color: ak.inkSub),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdCard extends ConsumerWidget {
  const _AdCard({required this.listing});

  final GalleryListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationCatalogProvider);
    final ak = AkColors.of(context);
    final s = S.of(context);
    final featured = listing.dealType != 'Sale only';

    return GestureDetector(
      onTap: () => context.push('/cars/listing/${listing.id}'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: ak.surface,
          border: Border.all(color: ak.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: ak.surfaceDim,
                    child: CarImage(
                        make: listing.make,
                        model: listing.model,
                        height: 92),
                  ),
                  if (featured)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3D9A4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          s.t('مميز', 'Featured'),
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7A6534),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.t('ممشى ${listing.mileage} · ${locations.localizedRegion(listing.region, true)}',
                        '${listing.mileage} km · ${listing.region}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: ak.inkSub),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: listing.price == null
                            ? Text(
                                s.t('عند الطلب', 'Ask for price'),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ak.inkSub),
                              )
                            : Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                    text: _fmt.format(listing.price),
                                    style: AppTheme.numeric(
                                        size: 13, color: ak.ink),
                                  ),
                                  TextSpan(
                                    text: ' ${s.omr}',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: ak.inkSub),
                                  ),
                                ]),
                              ),
                      ),
                      GestureDetector(
                        onTap: () => Contact.whatsapp(
                          context,
                          '96892000000',
                          message: s.t(
                            'مرحباً، مهتم بسيارتك ${listing.displayTitle} المعروضة في AK Cars.',
                            'Hi, I am interested in your ${listing.displayTitle} on AK Cars.',
                          ),
                        ),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: ak.successSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.messageCircle,
                              size: 12, color: ak.success),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
