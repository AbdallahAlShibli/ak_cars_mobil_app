import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/home_ranking_config.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/service_marketplace_repository.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../garage/maintenance_screen.dart';

final _fmt = intl.NumberFormat('#,###', 'en');

/// Money, which needs its fractional rials: `_fmt` rounds to whole numbers,
/// which is right for an odometer and wrong for a price — a service discounted
/// to 4.5 must not be advertised as 5.
final _money = intl.NumberFormat('#,##0.##', 'en');
final _rating = intl.NumberFormat('0.0', 'en');

/// Everything the home page renders below its greeting.
///
/// Each section is its own `ConsumerWidget` reading one provider, so a change
/// in the garage repaints the car list and nothing else — the page itself holds
/// no data logic at all.

// ---------------------------------------------------------------- offers rail

/// Section 2 — this week's real discounts (`homeOffersProvider`).
///
/// Everything in this rail has passed the six checks in
/// `ServiceMarketplaceRepository.liveOffers`: an approved workshop, a listed
/// service, a reference price that matches what the platform publishes, a
/// discount that actually reduces it, the founder's switch, and a date range
/// that includes today. Each card therefore shows all four things the spec
/// requires — the percentage, the old price struck through, the new price, and
/// the deadline — because it has all four for real.
///
/// With nothing discounted the rail renders nothing and the page omits the
/// section entirely. A heading over an empty rail would be the "قسم فارغ
/// بعنوان مضلّل" the spec forbids.
class HomeOffersRail extends ConsumerStatefulWidget {
  const HomeOffersRail({super.key});

  @override
  ConsumerState<HomeOffersRail> createState() => _HomeOffersRailState();
}

class _HomeOffersRailState extends ConsumerState<HomeOffersRail> {
  final _controller = PageController(viewportFraction: 0.88);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final page = _controller.page;
      if (page != null && mounted) setState(() => _page = page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(homeOffersProvider);
    if (offers.isEmpty) return const SizedBox.shrink();

    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SandSectionHeader(s.offersTitle),
        const SizedBox(height: 2),
        Text(
          s.t('خصومات فعلية من ورش معتمدة — بتاريخ انتهاء',
              'Real discounts from approved workshops — with an end date'),
          style: TextStyle(fontSize: 10.5, color: AkColors.of(context).inkSub),
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: 158,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: offers.length,
            itemBuilder: (context, i) {
              // The neighbouring cards sit slightly back, which is what makes
              // a swipe feel like a deck rather than a scroll.
              final distance = (_page - i).abs().clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 11),
                child: Transform.scale(
                  scale: 1 - distance * 0.05,
                  child: Opacity(
                    opacity: 1 - distance * 0.25,
                    child: _DiscountCard(live: offers[i]),
                  ),
                ),
              );
            },
          ),
        ),
        if (offers.length > 1) ...[
          const SizedBox(height: 9),
          _Dots(count: offers.length, page: _page),
        ],
      ],
    );
  }
}

/// One discount: what it is, whose it is, what it costs now instead of before,
/// and when it stops.
class _DiscountCard extends StatelessWidget {
  const _DiscountCard({required this.live});

  final LiveOffer live;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final offer = live.offer;
    final offering = live.offering;
    final days = offer.daysLeft(DateTime.now());

    return SandPressable(
      // Straight to the service, which shows the same two prices from the same
      // record — there is no second copy of this number to drift.
      onTap: () => context.push('/service/${offering.id}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ak.promoBgA, ak.promoBgB],
          ),
          border: Border.all(color: ak.promoBorder),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offering.name.of(s).replaceAll('\n', ' '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: ak.promoTitle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // The percentage is computed from the two prices below it, so
                // the ribbon and the numbers cannot disagree.
                SandStatusPill(
                  s.t('خصم ${offer.discountPercent.round()}٪',
                      '${offer.discountPercent.round()}% off'),
                  background: ak.danger,
                  foreground: ak.onPrimary,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                offering.provider.name.of(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: ak.promoSub),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: _money.format(offer.discountedPrice),
                      style: AppTheme.numeric(size: 17, color: ak.promoTitle),
                    ),
                    TextSpan(text: ' ${s.omr}'),
                  ]),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ak.promoTitle,
                  ),
                ),
                const SizedBox(width: 7),
                // The published price, struck through. Read from the catalogue
                // via the validated offer, never typed by the workshop.
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${_money.format(offer.referencePrice)} ${s.omr}',
                    style: TextStyle(
                      fontSize: 11,
                      color: ak.promoSub,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(LucideIcons.clock, size: 11, color: ak.promoSub),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    days <= 0
                        ? s.t('ينتهي اليوم', 'ends today')
                        : s.t('ينتهي بعد ${s.days(days)}',
                            'ends in ${s.days(days)}'),
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: ak.promoSub),
                  ),
                ),
                Text(
                  s.t('احجز بالعرض', 'Book this offer'),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ak.promoTitle),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.arrowRight, size: 13, color: ak.promoTitle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------- announcements rail

/// Platform announcements (`homeAnnouncementsProvider`) — how escrow works,
/// which workshops collect a car.
///
/// Kept well below the three sections the spec orders, and kept separate from
/// the offers rail, because these carry no price and no deadline. Calling them
/// offers is what would let the offers section look full on a week when
/// nothing was actually discounted.
class HomeAnnouncementsRail extends ConsumerStatefulWidget {
  const HomeAnnouncementsRail({super.key});

  @override
  ConsumerState<HomeAnnouncementsRail> createState() =>
      _HomeAnnouncementsRailState();
}

class _HomeAnnouncementsRailState
    extends ConsumerState<HomeAnnouncementsRail> {
  final _controller = PageController(viewportFraction: 0.88);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final page = _controller.page;
      if (page != null && mounted) setState(() => _page = page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(homeAnnouncementsProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SandSectionHeader(s.announcementsTitle),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final distance = (_page - i).abs().clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 11),
                child: Transform.scale(
                  scale: 1 - distance * 0.05,
                  child: Opacity(
                    opacity: 1 - distance * 0.25,
                    child: _AnnouncementCard(offer: items[i]),
                  ),
                ),
              );
            },
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 9),
          _Dots(count: items.length, page: _page),
        ],
      ],
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.offer});

  final Promotion offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final offering = offer.offeringId == null
        ? null
        : marketplace.pricedOffering(offer.offeringId!);
    final price = offering?.price;
    final days = offer.daysLeft(DateTime.now());

    return SandPressable(
      onTap: () {
        if (offering != null) {
          context.push('/service/${offering.id}');
          return;
        }
        final query = offer.query;
        context.go(query == null
            ? '/services'
            : '/services?q=${Uri.encodeQueryComponent(query)}');
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ak.promoBgA, ak.promoBgB],
          ),
          border: Border.all(color: ak.promoBorder),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: ak.surface.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(offer.icon, size: 17, color: ak.promoTitle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    offer.title.of(s),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: ak.promoTitle,
                    ),
                  ),
                ),
                if (offer.badge != null) ...[
                  const SizedBox(width: 8),
                  SandStatusPill(
                    offer.badge!.of(s),
                    background: ak.surface.withValues(alpha: 0.7),
                    foreground: ak.promoSub,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                offer.body.of(s),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 10.5, height: 1.5, color: ak.promoSub),
              ),
            ),
            Row(
              children: [
                if (price != null)
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: s.t('من ', 'from ')),
                      TextSpan(
                        text: _money.format(price),
                        style: AppTheme.numeric(
                            size: 13, color: ak.promoTitle),
                      ),
                      TextSpan(text: ' ${s.omr}'),
                    ]),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ak.promoTitle,
                    ),
                  )
                else if (offering != null)
                  Text(
                    s.t('عرض سعر بعد الفحص', 'quote after inspection'),
                    style: TextStyle(fontSize: 10, color: ak.promoSub),
                  ),
                const Spacer(),
                // A deadline is only shown when the campaign really has one.
                if (days != null) ...[
                  Icon(LucideIcons.clock, size: 11, color: ak.promoSub),
                  const SizedBox(width: 4),
                  Text(
                    days <= 0
                        ? s.t('آخر يوم', 'last day')
                        : s.t('باقي ${s.days(days)}', '${s.days(days)} left'),
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: ak.promoSub),
                  ),
                  const SizedBox(width: 9),
                ],
                Icon(LucideIcons.arrowRight, size: 14, color: ak.promoTitle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: (page.round() == i) ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: (page.round() == i) ? ak.primary : ak.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- registered cars

/// One registered car: its picture, the details the owner filled in, and the
/// one countdown closest to running out.
///
/// Nothing on this card is inferred. A field the owner has not entered renders
/// as an invitation to enter it, not as a plausible-looking value, and the
/// countdown comes from that car's own book — the same numbers the My Car page
/// shows, via the same provider.
class HomeCarCard extends ConsumerWidget {
  const HomeCarCard({super.key, required this.car, this.primary = false});

  final Car car;

  /// The default car — the one every other screen acts on.
  final bool primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final due = ref.watch(maintenanceDueForCarProvider(car.id));
    final book = ref.watch(maintenanceBookProvider(car.id));
    final urgent = due.byUrgency.firstOrNull;
    final projected = book.projectedOdometerKm();
    final odometer = projected ?? car.odometerKm;
    // Only a *projected* reading carries the "estimated" suffix — a number the
    // owner entered today is not an estimate.
    final estimated = projected != null && book.isProjected();
    final governorate = car.governorate == null
        ? null
        : ref.watch(locationCatalogProvider).localized(car.governorate!, s.isAr);

    return SandPressable(
      onTap: () {
        // The card and the page it opens must be about the same car.
        ref.read(selectedMaintenanceCarIdProvider.notifier).state = car.id;
        context.go('/my-car');
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: ak.surface,
          border: Border.all(color: ak.border),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------- the car itself
            Stack(
              children: [
                Container(
                  height: 132,
                  width: double.infinity,
                  color: ak.surfaceDim,
                  child: CarImage(
                    make: car.make,
                    model: car.model,
                    color: car.color,
                    height: 132,
                  ),
                ),
                if (primary)
                  PositionedDirectional(
                    top: 10,
                    start: 12,
                    child: SandStatusPill(
                      s.t('السيارة الافتراضية', 'Default car'),
                      background: ak.primary,
                      foreground: ak.onPrimary,
                    ),
                  ),
                if (car.powertrain != null)
                  PositionedDirectional(
                    top: 10,
                    end: 12,
                    child: SandStatusPill(
                      car.powertrain!.badge.of(s),
                      background: car.plugsIn ? ak.successSoft : ak.surfaceDim,
                      foreground: car.plugsIn ? ak.success : ak.inkSub,
                    ),
                  ),
              ],
            ),
            // ------------------------------------------------------- details
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          car.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('${s.details} ›',
                          style: TextStyle(fontSize: 10.5, color: ak.inkSub)),
                    ],
                  ),
                  // The make/model line is worth repeating only when the owner
                  // named the car something else.
                  if (car.displayName != car.label) ...[
                    const SizedBox(height: 2),
                    Text(
                      car.label,
                      style: TextStyle(fontSize: 10.5, color: ak.inkSub),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      if (odometer != null)
                        _MetaChip(
                          icon: LucideIcons.gauge,
                          label: estimated
                              ? '${_fmt.format(odometer)} ${s.km} · ${s.t('تقديري', 'est.')}'
                              : '${_fmt.format(odometer)} ${s.km}',
                        )
                      else
                        _MetaChip(
                          icon: LucideIcons.gauge,
                          label: s.t('أضف الممشى', 'Add mileage'),
                          muted: true,
                        ),
                      if (car.plate != null)
                        _MetaChip(
                            icon: LucideIcons.creditCard, label: car.plate!)
                      else
                        _MetaChip(
                          icon: LucideIcons.creditCard,
                          label: s.t('أضف اللوحة', 'Add plate'),
                          muted: true,
                        ),
                      if (governorate != null)
                        _MetaChip(
                            icon: LucideIcons.mapPin, label: governorate),
                      if (car.trim != null)
                        _MetaChip(icon: LucideIcons.settings2, label: car.trim!),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DueStrip(car: car, item: urgent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The car's most urgent schedule line, the honest first-run state, and — in
/// every case — the one button the spec asks for.
///
/// Home-page spec §1: "كل بند تذكير = زر حجز مباشر". A countdown the user
/// cannot act on from where they are reading it is a notification, not a front
/// page. So this strip always ends in an action: *book it* when there is a
/// countdown, *tell us when you last did it* when there is not.
class _DueStrip extends ConsumerWidget {
  const _DueStrip({required this.car, required this.item});

  final Car car;
  final DueItem? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final d = item;

    if (d == null || d.status == DueStatus.noRecord || d.progress == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.circleAlert, size: 14, color: ak.inkFaint),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  d == null
                      ? s.t('لا سجل صيانة بعد — أضف آخر خدمة ليبدأ العد.',
                          'No service history yet — add your last service to start the countdown.')
                      // Naming the item is the difference between a chore and
                      // a question the owner can answer in one tap.
                      : s.t('متى غيّرت ${d.shortTitle.ar} آخر مرة؟',
                          'When did you last do ${d.shortTitle.en.toLowerCase()}?'),
                  style: TextStyle(fontSize: 10, color: ak.inkSub, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Wrap, not Row: the item name is inside the button label, and a
          // long one ("فحص وترصيص الإطارات") plus "احجز الآن" does not fit on
          // one line of a narrow phone.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InkPill(
                label: d == null
                    ? s.t('أضف آخر خدمة', 'Add last service')
                    : s.t('أضف آخر ${d.shortTitle.ar}',
                        'Add last ${d.shortTitle.en.toLowerCase()}'),
                fontSize: 10.5,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                onTap: () {
                  if (d == null) {
                    ref.read(selectedMaintenanceCarIdProvider.notifier).state =
                        car.id;
                    context.go('/my-car');
                    return;
                  }
                  showRecordSheet(context, ref, car: car, item: d.item);
                },
              ),
              if (d != null)
                InkPill(
                  label: s.bookNow,
                  outlined: true,
                  fontSize: 10.5,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  onTap: () => bookMaintenanceItem(context, ref, car: car, item: d),
                ),
            ],
          ),
        ],
      );
    }

    // Overdue is its own state, in the app's alert colour: the spec asks for
    // "متأخّر — احجز الآن" rather than another shade of "coming up".
    final overdue = d.status == DueStatus.due;
    final near = d.status == DueStatus.near;
    final color = overdue
        ? ak.danger
        : near
            ? ak.amber
            : ak.success;
    final textColor = overdue
        ? ak.dangerText
        : near
            ? ak.amberText
            : ak.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                d.shortTitle.of(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: ak.inkSub),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _remaining(s, d),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SandProgressBar(value: d.progress!, color: color, animate: true),
        const SizedBox(height: 11),
        SizedBox(
          width: double.infinity,
          child: SandPressable(
            onTap: () => bookMaintenanceItem(context, ref, car: car, item: d),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: overdue ? ak.danger : ak.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                overdue ? s.overdueBookNow : s.bookNow,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ak.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _remaining(S s, DueItem d) {
    final km = d.remainingKm;
    if (km != null) {
      final value = '${_fmt.format(km)} ${s.km}';
      final text = s.t('باقي $value', '$value left');
      return d.estimated ? '$text · ${s.t('تقديري', 'est.')}' : text;
    }
    final months = d.remainingMonths ?? 0;
    if (months <= 0) return s.t('حان الآن', 'due now');
    return s.t('بعد ${s.months(months)}', 'in ${s.months(months)}');
  }
}

/// The empty-garage card. Registering a car is what turns the whole page from a
/// catalogue into something about the user's own vehicle, so this is the one
/// call to action the page makes for itself.
class HomeAddCarCard extends StatelessWidget {
  const HomeAddCarCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return SandPressable(
      onTap: () => context.push('/add-car'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: ak.surface,
          border: Border.all(color: ak.border),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: ak.surfaceDim, shape: BoxShape.circle),
              child: Icon(LucideIcons.carFront, size: 21, color: ak.inkSub),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('سجّل سيارتك', 'Register your car'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.t('دقيقة واحدة، وتصير الصفحة عن سيارتك: مواعيد الصيانة والخدمات المناسبة لها.',
                        'One minute, and this page becomes about your car — its service countdowns and the work that suits it.'),
                    style:
                        TextStyle(fontSize: 10.5, color: ak.inkSub, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(LucideIcons.arrowRight, size: 16, color: ak.ink),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------- recommendations

/// "Suggested for your car" — `homeRecommendationsProvider`.
///
/// The order varies per app launch (see `sessionSeedProvider`) but only within
/// a reason band, so a genuinely overdue item is never demoted by the shuffle.
/// Each card states its own reason, because a suggestion the app cannot justify
/// is advertising.
class HomeRecommendationsRail extends ConsumerWidget {
  const HomeRecommendationsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeRecommendationsProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    final s = S.of(context);
    final cars = ref.watch(garageProvider).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SandSectionHeader(
          s.recommendedTitle,
          action: s.viewAll,
          onAction: () => context.go('/services'),
        ),
        const SizedBox(height: 2),
        Text(
          s.t('من ممشى سيارتك وسجل خدماتها',
              'From your mileage and service history'),
          style: TextStyle(fontSize: 10.5, color: AkColors.of(context).inkSub),
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 11),
            itemBuilder: (context, i) => Entrance(
              delayMs: 40 * i,
              child: _RecommendationCard(
                item: items[i],
                // Only worth naming the car when there is more than one.
                showCar: cars > 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item, required this.showCar});

  final Recommendation item;
  final bool showCar;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final urgent = item.reason == RecommendationReason.dueNow ||
        item.reason == RecommendationReason.dueSoon;

    return SandPressable(
      onTap: () {
        final offeringId = item.offeringId;
        if (offeringId != null) {
          context.push('/service/$offeringId');
          return;
        }
        final query = item.category.name.of(s).replaceAll('\n', ' ');
        context.go('/services?q=${Uri.encodeQueryComponent(query)}');
      },
      child: Container(
        width: 176,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        decoration: BoxDecoration(
          color: ak.surface,
          border: Border.all(color: urgent ? ak.amberBorder : ak.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: urgent ? ak.amberBgSoft : ak.surfaceDim,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(item.category.icon,
                      size: 16, color: urgent ? ak.amber : ak.ink),
                ),
                const Spacer(),
                Text(
                  s.workshops(item.workshops),
                  style: TextStyle(fontSize: 9, color: ak.inkFaint),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              item.category.name.of(s).replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                _reason(s),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: ak.inkSub, height: 1.45),
              ),
            ),
            Row(
              children: [
                Expanded(child: _price(context, s, ak)),
                Icon(LucideIcons.arrowRight, size: 13, color: ak.ink),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _price(BuildContext context, S s, AkColors ak) {
    final price = item.fromPrice;
    if (price == null) {
      return Text(
        s.t('سعر بعد الفحص', 'quote after check'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 9.5, color: ak.inkSub),
      );
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: s.t('من ', 'from ')),
        TextSpan(
          text: _money.format(price),
          style: AppTheme.numeric(size: 12, color: ak.ink),
        ),
        TextSpan(text: ' ${s.omr}'),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: 9.5, fontWeight: FontWeight.w700, color: ak.inkSub),
    );
  }

  /// The card's justification, in the user's own numbers wherever possible.
  String _reason(S s) {
    final car = showCar ? '${item.car.displayName} · ' : '';
    final due = item.due;
    switch (item.reason) {
      case RecommendationReason.dueNow:
        return '$car${s.t('حان موعدها', 'due now')}';
      case RecommendationReason.dueSoon:
        final km = due?.remainingKm;
        if (km != null) {
          return '$car${s.t('باقي ${_fmt.format(km)} ${s.km}', '${_fmt.format(km)} ${s.km} left')}';
        }
        final months = due?.remainingMonths;
        if (months != null) {
          return '$car${s.t('بعد ${s.months(months)}', 'in ${s.months(months)}')}';
        }
        return '$car${s.t('تقترب', 'coming up')}';
      case RecommendationReason.noRecord:
        return '$car${s.t('لا سجل لها بعد', 'no record for it yet')}';
      case RecommendationReason.electric:
        return '$car${s.t('لسيارتك الكهربائية', 'for your electric car')}';
      case RecommendationReason.popular:
        final bookings = item.bookings;
        final window = item.windowDays ?? 30;
        if (bookings == null) return s.t('شائعة في عُمان', 'popular in Oman');
        return s.t('${s.bookings(bookings)} في آخر ${s.days(window)}',
            '${s.bookings(bookings)} in the last ${s.days(window)}');
    }
  }
}

// ------------------------------------------------------------- most booked

/// The marketplace's most-booked categories, with the count and the window that
/// ranked them — an aggregate from the API, never derived on the phone.
class HomeMostBookedSection extends ConsumerWidget {
  const HomeMostBookedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = ref.watch(mostBookedServicesProvider);
    if (ranked.isEmpty) return const SizedBox.shrink();

    final s = S.of(context);
    final window = ranked.first.demand.windowDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SandSectionHeader(
          s.mostBookedTitle,
          action: s.viewAll,
          onAction: () => context.go('/services'),
        ),
        const SizedBox(height: 2),
        Text(
          s.t('في كل عُمان — آخر ${s.days(window)}',
              'Across Oman — last ${s.days(window)}'),
          style: TextStyle(fontSize: 10.5, color: AkColors.of(context).inkSub),
        ),
        const SizedBox(height: 11),
        for (final (i, entry) in ranked.indexed) ...[
          if (i > 0) const SizedBox(height: 9),
          Entrance(
            delayMs: 40 * i,
            child: _MostBookedRow(rank: i + 1, entry: entry),
          ),
        ],
      ],
    );
  }
}

class _MostBookedRow extends ConsumerWidget {
  const _MostBookedRow({required this.rank, required this.entry});

  final int rank;
  final RankedCategory entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final region = ref.watch(regionProvider);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final scope = region.isEmpty ? null : region;
    final cheapest =
        marketplace.cheapestOfferingFor(entry.category.id, region: scope);
    final workshops =
        marketplace.providerCountFor(entry.category.id, region: scope);
    final name = entry.category.name.of(s).replaceAll('\n', ' ');

    return SandPressable(
      onTap: () => cheapest == null
          ? context.go('/services?q=${Uri.encodeQueryComponent(name)}')
          : context.push('/service/${cheapest.id}'),
      child: SandCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: 11),
            Icon(entry.category.icon, size: 18, color: ak.ink),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Two real numbers: what the country booked, and how many
                    // workshops the user can actually reach for it.
                    '${s.bookings(entry.demand.bookings)} · ${s.workshops(workshops)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, color: ak.inkSub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (cheapest?.price != null)
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: _money.format(cheapest!.price),
                    style: AppTheme.numeric(size: 12.5, color: ak.ink),
                  ),
                  TextSpan(
                    text: ' ${s.omr}',
                    style: TextStyle(fontSize: 9, color: ak.inkSub),
                  ),
                ]),
              )
            else
              Icon(LucideIcons.chevronRight, size: 15, color: ak.inkFaint),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- trusted workshops

/// Section 3 — the reassurance the spec's "حاجة → فرصة → طمأنة" sequence ends
/// on: which workshops other people actually trust.
///
/// Two boards behind one heading, exactly as the spec lays out: **الأعلى
/// تقييماً**, ranked on customer ratings, and **الأكثر طلباً**, ranked on
/// bookings that were completed and released in the last
/// [HomeRankingConfig.popularWindowDays] days. Both are computed on every read
/// from live data — there is no stored order — and neither has any input a
/// workshop could pay for.
///
/// The empty states are the reason this is one widget rather than two
/// sections:
///  * no workshop has enough reviews yet → the ratings tab is replaced by
///    "ورش معتمدة قريبة منك", under that heading and no other;
///  * nothing has been completed yet → the "الأكثر طلباً" tab is not offered
///    at all, rather than shown empty.
class HomeTrustedWorkshopsSection extends ConsumerStatefulWidget {
  const HomeTrustedWorkshopsSection({super.key});

  @override
  ConsumerState<HomeTrustedWorkshopsSection> createState() =>
      _HomeTrustedWorkshopsSectionState();
}

class _HomeTrustedWorkshopsSectionState
    extends ConsumerState<HomeTrustedWorkshopsSection> {
  bool _showDemand = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final rated = ref.watch(topRatedWorkshopsProvider);
    final requested = ref.watch(mostRequestedWorkshopsProvider);
    final approved = ref.watch(approvedWorkshopsProvider);
    final region = ref.watch(regionProvider);
    final regionLabel =
        ref.watch(locationCatalogProvider).localized(region, s.isAr);

    // Nothing to stand behind at all — not even an approved workshop. The
    // section is omitted by the page rather than rendered as a headline with
    // no body.
    if (rated.items.isEmpty && requested.items.isEmpty && approved.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasRatings = rated.items.isNotEmpty;
    final hasDemand = requested.items.isNotEmpty;
    final showDemand = hasDemand && (_showDemand || !hasRatings);

    final String subtitle;
    if (showDemand) {
      subtitle = requested.nationwide
          ? s.t('في كل عُمان — حجوزات مكتملة في آخر ${s.days(HomeRankingConfig.popularWindowDays)}',
              'Across Oman — bookings completed in the last ${s.days(HomeRankingConfig.popularWindowDays)}')
          : s.t('في $regionLabel — حجوزات مكتملة في آخر ${s.days(HomeRankingConfig.popularWindowDays)}',
              'In $regionLabel — bookings completed in the last ${s.days(HomeRankingConfig.popularWindowDays)}');
    } else if (hasRatings) {
      subtitle = rated.nationwide
          ? s.t('في كل عُمان — بتقييمات العملاء',
              'Across Oman — from customer ratings')
          : s.t('في $regionLabel — بتقييمات العملاء',
              'In $regionLabel — from customer ratings');
    } else {
      // The honest version of an empty leaderboard: say what these workshops
      // are (approved, close) and do not imply a ranking nobody has earned.
      subtitle = s.t(
          'لا تقييمات كافية بعد — هذه ورش معتمدة من المنصة، الأقرب أولاً',
          'Not enough ratings yet — these are platform-approved workshops, nearest first');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SandSectionHeader(
          hasRatings ? s.trustedWorkshopsTitle : s.approvedNearbyTitle,
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 10.5, color: ak.inkSub)),
        // The switch appears only when there really are two boards to switch
        // between.
        if (hasRatings && hasDemand) ...[
          const SizedBox(height: 11),
          _BoardTabs(
            labels: (s.topRatedTab, s.mostRequestedTab),
            secondSelected: showDemand,
            onSelect: (demand) => setState(() => _showDemand = demand),
          ),
        ],
        const SizedBox(height: 11),
        if (showDemand)
          for (final (i, entry) in requested.items.indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            Entrance(
              delayMs: 40 * i,
              child: _WorkshopRow(
                rank: i + 1,
                provider: entry.provider,
                trailing: _DemandTrailing(demand: entry.demand),
              ),
            ),
          ]
        else if (hasRatings)
          for (final (i, entry) in rated.items.indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            Entrance(
              delayMs: 40 * i,
              child: _WorkshopRow(
                rank: i + 1,
                provider: entry.provider,
                trailing: _RatingTrailing(rating: entry.rating),
              ),
            ),
          ]
        else
          for (final (i, provider) in approved.indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            Entrance(
              delayMs: 40 * i,
              // No rank badge: these are not ranked, they are simply approved
              // and nearby, and a numbered list would imply an order.
              child: _WorkshopRow(
                provider: provider,
                trailing: _DistanceTrailing(provider: provider),
              ),
            ),
          ],
      ],
    );
  }
}

/// The two-way switch between the boards. Deliberately not a `TabBar`: there
/// is no page to swipe, just one list that changes what it is ranked by.
class _BoardTabs extends StatelessWidget {
  const _BoardTabs({
    required this.labels,
    required this.secondSelected,
    required this.onSelect,
  });

  final (String, String) labels;
  final bool secondSelected;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      children: [
        for (final (isSecond, label) in [(false, labels.$1), (true, labels.$2)])
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: SandPressable(
              onTap: () => onSelect(isSecond),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSecond == secondSelected ? ak.primary : ak.surface,
                  border: Border.all(
                      color: isSecond == secondSelected
                          ? ak.primary
                          : ak.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        isSecond == secondSelected ? ak.onPrimary : ak.inkSub,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One workshop row, shared by all three boards so a workshop looks the same
/// whichever list it is in. Only the trailing number changes, because only the
/// reason it is listed changes.
class _WorkshopRow extends ConsumerWidget {
  const _WorkshopRow({
    required this.provider,
    required this.trailing,
    this.rank,
  });

  final ServiceProvider provider;
  final Widget trailing;

  /// Null on the approved-nearby fallback, which is not a ranking.
  final int? rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final locations = ref.watch(locationCatalogProvider);
    final place = '${locations.localized(provider.area, s.isAr)}'
        ' · ${locations.localized(provider.region, s.isAr)}';

    return SandPressable(
      // Opens the services tab searching this workshop — its own offerings,
      // with its own prices, rather than a profile page that cannot be booked
      // from.
      onTap: () => context.go(
          '/services?q=${Uri.encodeQueryComponent(provider.name.of(s))}'),
      child: SandCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            if (rank != null) ...[
              _RankBadge(rank: rank!),
              const SizedBox(width: 11),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.name.of(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      // Platform approval is a condition of appearing on any of
                      // these boards, so the badge is a fact about every row.
                      const SizedBox(width: 5),
                      Icon(LucideIcons.badgeCheck, size: 13, color: ak.success),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.evCertified
                        ? '$place · ${s.t('معتمدة للكهربائية', 'EV-certified')}'
                        : place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, color: ak.inkSub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _RatingTrailing extends StatelessWidget {
  const _RatingTrailing({required this.rating});

  final WorkshopRating rating;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Icon(LucideIcons.star, size: 12, color: ak.amber),
            const SizedBox(width: 3),
            Text(
              _rating.format(rating.rating),
              style: AppTheme.numeric(size: 12.5, color: ak.ink),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // The count is not decoration: it is what makes the score mean
        // anything, and it is why a 4.9 from four people is not on this list.
        Text(
          s.reviews(rating.reviews),
          style: TextStyle(fontSize: 9, color: ak.inkFaint),
        ),
      ],
    );
  }
}

class _DemandTrailing extends StatelessWidget {
  const _DemandTrailing({required this.demand});

  final WorkshopDemand demand;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _fmt.format(demand.completedBookings),
          style: AppTheme.numeric(size: 12.5, color: ak.ink),
        ),
        const SizedBox(height: 2),
        Text(
          s.t('حجز مكتمل', 'completed'),
          style: TextStyle(fontSize: 9, color: ak.inkFaint),
        ),
      ],
    );
  }
}

class _DistanceTrailing extends StatelessWidget {
  const _DistanceTrailing({required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${provider.distanceKm.toStringAsFixed(1)} ${s.km}',
          style: AppTheme.numeric(size: 12, color: ak.ink),
        ),
        const SizedBox(height: 2),
        Text(
          s.approvedBadge,
          style: TextStyle(fontSize: 9, color: ak.inkFaint),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ shared

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final top = rank == 1;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: top ? ak.primary : ak.surfaceDim,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$rank',
        style: AppTheme.numeric(
          size: 11,
          color: top ? ak.onPrimary : ak.inkSub,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.muted = false});

  final IconData icon;
  final String label;

  /// A field the owner has not filled in — an invitation, styled as one.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(999),
        border: muted ? Border.all(color: ak.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: muted ? ak.inkFaint : ak.inkSub),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: muted ? ak.inkFaint : ak.ink,
            ),
          ),
        ],
      ),
    );
  }
}
