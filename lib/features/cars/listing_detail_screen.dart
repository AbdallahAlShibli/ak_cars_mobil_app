import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

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
    final s = S.of(context);
    final reasons = [
      s.t('معلومات مضللة', 'Misleading information'),
      s.t('سعر خاطئ', 'Wrong price'),
      s.t('تم بيعها بالفعل', 'Already sold'),
      s.t('محتوى محظور', 'Prohibited content'),
      s.t('اشتباه احتيال', 'Suspected fraud'),
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
              Text(s.t('الإبلاغ عن هذا الإعلان', 'Report this ad'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
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
            content: Text(s.t('تم الإبلاغ: "$reason" — سيراجعه فريقنا',
                'Reported: "$reason" — our team will review it'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final specCatalog = ref.watch(specCatalogProvider);
    final locations = ref.watch(locationCatalogProvider);
    // The user's own ads are part of the feed, so search it rather than the
    // platform listings alone.
    final listing = ref
        .watch(galleryFeedProvider)
        .firstWhereOrNull((l) => l.id == widget.listingId);
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
            child: Text(s.t('الإعلان غير موجود', 'Listing not found'))),
      );
    }

    final favorites = ref.watch(favoritesProvider);
    final fav = favorites.contains(listing.id);
    final related = ref.watch(relatedListingsProvider(listing));

    String spec(String value) => specCatalog.localized(value, s.isAr);

    final specs = <(String, String, Color?)>[
      (s.t('اسم السيارة', 'Car name'), listing.displayTitle, null),
      (s.t('الحالة', 'Condition'), spec(listing.condition), null),
      (s.t('الممشى', 'Mileage'), '${listing.mileage} ${s.km}', null),
      (s.t('نوع الصفقة', 'Deal type'), spec(listing.dealType), null),
      (s.t('نوع الهيكل', 'Body type'), spec(listing.bodyType), null),
      (
        s.t('المحرك', 'Engine'),
        listing.engineLitres == 0
            ? s.t('كهربائي', 'Electric')
            : s.t('${listing.engineLitres.toStringAsFixed(1)} لتر',
                '${listing.engineLitres.toStringAsFixed(1)} L'),
        null,
      ),
      (
        s.t('الإسطوانات', 'Cylinders'),
        listing.cylinders == 0 ? '—' : '${listing.cylinders}',
        null
      ),
      (s.t('ناقل الحركة', 'Transmission'), spec(listing.transmission), null),
      (s.t('الأبواب', 'Doors'), '${listing.doors}', null),
      (s.t('المقاعد', 'Seats'), '${listing.seats}', null),
      (s.t('المفاتيح', 'Keys'), '${listing.keys}', null),
      (s.t('المواصفات الإقليمية', 'Regional spec'),
          spec(listing.regionalSpec), null),
      (
        s.t('الضمان', 'Warranty'),
        listing.hasWarranty
            ? s.t('تحت الضمان', 'Under warranty')
            : s.t('لا يوجد', 'None'),
        null
      ),
      (s.t('نوع البائع', 'Seller type'), spec(listing.sellerType), null),
      (s.t('نظام الدفع', 'Drivetrain'), spec(listing.drivetrain), null),
      (s.t('نوع الوقود', 'Fuel type'), spec(listing.fuel), null),
      // Electric facts, in the order a used-EV buyer asks for them. Each row
      // appears only when the seller actually stated it — a blank "Range: —"
      // reads as a car with no range.
      if (listing.plugsIn) ...[
        if (listing.rangeKm case final range?)
          (
            s.t('المدى (حسب البائع)', 'Range (as stated)'),
            s.t('$range كم', '$range km'),
            null
          ),
        if (listing.batteryWarrantyUntilYear case final year?)
          (
            s.t('ضمان البطارية', 'Battery warranty'),
            s.t('حتى $year', 'Until $year'),
            null
          ),
        if (listing.chargerIncluded case final included?)
          (
            s.t('شاحن مع السيارة', 'Charger included'),
            included
                ? s.t('نعم', 'Yes')
                : s.t('لا', 'No'),
            null
          ),
      ],
      (s.t('اللون الخارجي', 'Exterior color'),
          spec(listing.exteriorColor), listing.exteriorSwatch),
      (s.t('اللون الداخلي', 'Interior color'),
          spec(listing.interiorColor), listing.interiorSwatch),
      (s.t('تاريخ النشر', 'Published'), '14/7/2026', null),
      (
        s.t('المنطقة', 'Region'),
        locations.localizedRegion(listing.region, s.isAr),
        null
      ),
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
                  child: SandBackButton(
                    translucent: true,
                    onTap: () => context.pop(),
                  ),
                ),
                actions: [
                  _RoundButton(
                    icon: Icons.share_rounded,
                    onTap: () => _demo(s.t('تم نسخ رابط الإعلان للمشاركة',
                        'Listing link copied to share')),
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
                            child: CarImage(
                              make: listing.make,
                              model: listing.model,
                              color: listing.exteriorColor,
                              variant: i,
                              expand: true,
                              fallbackIcon: listing.icon,
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
                              '${s.omr} ${listing.price!.toStringAsFixed(0)}',
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
                                message: s.t(
                                    'مرحباً، كم سعر سيارتك ${listing.displayTitle} على AK Cars؟',
                                    'Hi, what is the price of your ${listing.displayTitle} on AK Cars?'),
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
                                child: Text(
                                  s.t('اسأل عن السعر', 'Ask about price'),
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          StatusBadge(spec(listing.dealType)),
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
                            Text(s.details,
                                style: const TextStyle(
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
                                    Flexible(
                                      child: Text(s.$2,
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700)),
                                    ),
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
                            Text(s.t('الوصف', 'Description'),
                                style: const TextStyle(
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
                                  _expanded
                                      ? s.t('عرض أقل', 'Show less')
                                      : s.t('عرض المزيد', 'Show more'),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flag_outlined,
                                size: 17, color: AppColors.bad),
                            const SizedBox(width: 8),
                            Text(
                              s.t('الإبلاغ عن هذا الإعلان',
                                  'Report this ad'),
                              style: const TextStyle(
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
                                    s.t('انضم في ${listing.sellerJoined}',
                                        'Joined ${listing.sellerJoined}'),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.ink3),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.t('${listing.sellerAds} إعلانات  ·  ${listing.sellerFollowers} متابعين',
                                        '${listing.sellerAds} ads  ·  ${listing.sellerFollowers} followers'),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink2),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFFD8D1C4)),
                          ],
                        ),
                      ),
                    ),
                    if (related.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Entrance(
                        delayMs: 180,
                        child: SectionHeader(
                            s.t('إعلانات مشابهة', 'Related ads')),
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
                                                ? '${s.omr} ${r.price!.toStringAsFixed(0)}'
                                                : s.t('اسأل عن السعر',
                                                    'Ask for price'),
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
                      label: Text(s.t('اتصال', 'Call')),
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
                        message: s.t(
                            'مرحباً، أنا مهتم بإعلانك على AK Cars.',
                            'Hi, I am interested in your ad on AK Cars.'),
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
