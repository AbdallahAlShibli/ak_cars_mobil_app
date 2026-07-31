import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'provider_details_card.dart';
import 'review_widgets.dart';

/// Selected add-ons for the in-flight booking (shared with BookingScreen).
final selectedAddOnsProvider = StateProvider<Set<String>>((ref) => {});

/// Service detail page.
///
/// The questions a customer asks before handing over a car are: what exactly
/// am I paying for, how long does it take, who is the workshop, and what
/// happens if the job turns out bigger than the quote. The page answers them
/// in that order — what's included, then how the job runs, then the
/// workshop's own record (hours, phone, VAT/CR registration), then the extras
/// and the total.
///
/// Everything on this page comes from the offering, the provider record, or a
/// review someone earned the right to write. The rating shown is derived from
/// those reviews and is absent — in words — for a workshop nobody has rated;
/// it is never a default score. There is still no "Open now" badge: that one
/// does not exist in the data, and the old header invented an "Open" pill for
/// every workshop regardless of its hours.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.offeringId});

  final String offeringId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    // The offering *as it would be charged* — a live offer's discount is
    // already in `offering.price`, so the total, the book bar, the booking
    // screen and the escrow amount all inherit it without knowing offers
    // exist. `offer` is carried alongside only so the page can show what the
    // price was struck down from.
    final offering = marketplace.pricedOffering(offeringId);
    final offer = marketplace.offerFor(offeringId);
    if (offering == null) {
      return Scaffold(
        appBar: AppBar(),
        body:
            Center(child: Text(s.t('الخدمة غير متاحة', 'Service unavailable'))),
      );
    }

    final provider = offering.provider;
    final car = ref.watch(primaryCarProvider);
    final selected = ref.watch(selectedAddOnsProvider);
    final addOns = marketplace.addOnsFor(provider.id);
    final services = addOns.where((a) => !a.isPart).toList();
    final parts = addOns.where((a) => a.isPart).toList();
    final category = marketplace.categories
        .firstWhereOrNull((c) => c.id == offering.categoryId);

    final addOnTotal = addOns
        .where((a) => selected.contains(a.id))
        .fold<double>(0, (sum, a) => sum + a.price);
    final total = (offering.price ?? 0) + addOnTotal;

    // Same service, other workshops — the comparison the marketplace exists
    // to make possible. Priced, like everything else on this screen, so a
    // rival's discount is visible in the comparison rather than hidden by it.
    final elsewhere = [
      for (final o in marketplace.offeringsFor(offering.categoryId,
          region: provider.region))
        if (o.provider.id != provider.id) marketplace.pricedOffering(o.id)!,
    ];

    // Everything else this workshop sells.
    final alsoHere = [
      for (final o in marketplace.pricedOfferings)
        if (o.provider.id == provider.id && o.categoryId != offering.categoryId)
          o,
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: ak.bg,
            surfaceTintColor: Colors.transparent,
            title: Text(offering.name.of(s),
                style: const TextStyle(fontSize: 15.5)),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: ak.surfaceDim,
                alignment: Alignment.center,
                child: Icon(
                  category?.icon ?? LucideIcons.wrench,
                  size: 84,
                  color: ak.inkFaint,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------- identity
                  Text(
                    offering.name.of(s),
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.name.of(s),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ak.inkSub),
                        ),
                      ),
                      if (provider.verified) ...[
                        const SizedBox(width: 5),
                        Icon(LucideIcons.badgeCheck,
                            size: 14, color: ak.success),
                      ],
                      const SizedBox(width: 8),
                      // Flexible so a long workshop name and a long review
                      // count share the line instead of overflowing it.
                      Flexible(
                        child: RatingSummaryLine(
                            providerId: provider.id, compact: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    offering.description.of(s),
                    style: TextStyle(
                        fontSize: 12.5, color: ak.inkSub, height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  _priceCard(offering, offer, s, ak),
                  const SizedBox(height: 12),
                  _facts(offering, s, ak),
                  const SizedBox(height: 12),
                  _carRow(context, car, s, ak),
                  if (offering.includes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionHeader(s.t('ما الذي يشمله السعر', "What's included")),
                    const SizedBox(height: 8),
                    _includes(offering, s, ak),
                  ],
                  const SizedBox(height: 18),
                  SectionHeader(s.t('كيف تسير الخدمة', 'How it works')),
                  const SizedBox(height: 8),
                  _howItWorks(offering, s, ak),
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionHeader(
                        s.t('أيضاً من هذه الورشة', 'Also from this workshop')),
                    const SizedBox(height: 8),
                    _AddOnRow(addOns: services, selected: selected, ref: ref),
                  ],
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionHeader(
                        s.t('قطع متوفرة لسيارتك', 'Parts they stock for your car')),
                    const SizedBox(height: 8),
                    _AddOnRow(addOns: parts, selected: selected, ref: ref),
                  ],
                  // Reviews sit directly above the workshop's own details, so
                  // the decision of *which* workshop is made with both in
                  // view. Every review here comes from a completed, released
                  // booking — there is no other way one gets written.
                  if (AppFlags.verifiedReviews) ...[
                    const SizedBox(height: 18),
                    SectionHeader(
                        s.t('تقييمات موثّقة', 'Verified reviews')),
                    const SizedBox(height: 8),
                    ProviderReviewList(providerId: provider.id),
                  ],
                  const SizedBox(height: 18),
                  SectionHeader(s.t('بيانات الورشة', 'Workshop details')),
                  const SizedBox(height: 8),
                  ProviderDetailsCard(
                    provider: provider,
                    showFulfillments: true,
                    whatsappMessage: s.t(
                        'مرحباً، أستفسر عن خدمة "${offering.name.ar}" عبر تطبيق AK Cars.',
                        'Hi, I am asking about your "${offering.name.en}" service on AK Cars.'),
                  ),
                  if (elsewhere.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionHeader(s.t('نفس الخدمة في ورش أخرى',
                        'Same service, other workshops')),
                    const SizedBox(height: 10),
                    _offeringRail(elsewhere, s, ak, showProvider: true),
                  ],
                  if (alsoHere.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SectionHeader(s.t('خدمات أخرى لدى هذه الورشة',
                        'Other services at this workshop')),
                    const SizedBox(height: 10),
                    _offeringRail(alsoHere, s, ak, showProvider: false),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _bookBar(context, ref, offering, total, addOnTotal, s, ak),
    );
  }

  // -------------------------------------------------------------- price
  Widget _priceCard(
      ServiceOffering offering, Offer? offer, S s, AkColors ak) {
    if (offering.quoteOnly) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: ak.amberBgSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ak.amberBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.receiptText, size: 19, color: ak.amberText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('السعر بعد الفحص', 'Price quoted after inspection'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ak.amberText),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.t(
                        'تفحص الورشة السيارة أولاً وترسل عرض سعر مفصّلاً — '
                            'لا يبدأ أي عمل قبل موافقتك.',
                        'The workshop inspects the car first and sends an '
                            'itemized quote — no work starts until you approve it.'),
                    style: TextStyle(
                        fontSize: 11.5, color: ak.inkSub, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Oman quotes service prices VAT-inclusive, so the tax is backed out of
    // the price rather than added to it.
    final vat = offering.price! - offering.price! / (1 + AppConstants.vatRate);
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'OMR ${offering.price!.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              // Flexible, not fixed: the price is the one thing that must
              // never be clipped, so the label yields to it under a large
              // text scale.
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    s.t('سعر ثابت', 'Fixed price'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ak.success),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.t(
                'شامل ضريبة القيمة المضافة ٥٪ (${vat.toStringAsFixed(2)} ${s.omr})',
                'Includes 5% VAT (OMR ${vat.toStringAsFixed(2)})'),
            style: TextStyle(fontSize: 11.5, color: ak.inkSub),
          ),
          // The offer, stated in full on the page that takes the booking: what
          // it was, what it is, and when it stops. Same three numbers the home
          // card showed, from the same validated record — this page cannot
          // contradict the rail that sent the user here.
          if (offer != null) ...[
            const SizedBox(height: 11),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ak.dangerSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ak.dangerBorder),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.tag,
                      size: 16, color: ak.dangerText),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: s.t(
                                  'خصم ${offer.discountPercent.round()}٪ — بدلاً من ',
                                  '${offer.discountPercent.round()}% off — was '),
                            ),
                            TextSpan(
                              text:
                                  'OMR ${offer.referencePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough),
                            ),
                          ]),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ak.dangerText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.t(
                              'ينتهي العرض في ${_date(offer.endsAt)} — بعده يعود السعر المعلن.',
                              'Offer ends ${_date(offer.endsAt)} — the published price applies after that.'),
                          style:
                              TextStyle(fontSize: 11, color: ak.inkSub, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// `YYYY-MM-DD`, which is unambiguous in both languages and needs no
  /// month-name table.
  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // -------------------------------------------------------------- facts
  Widget _facts(ServiceOffering offering, S s, AkColors ak) {
    final items = <(IconData, String, String)>[
      (
        LucideIcons.clock,
        s.t('المدة', 'Duration'),
        offering.durationMin != null
            ? s.t('${offering.durationMin} دقيقة', '${offering.durationMin} min')
            : s.t('حسب العمل', 'Open-ended'),
      ),
      (
        LucideIcons.shield,
        s.t('ضمان العمل', 'Workmanship'),
        offering.warrantyMonths != null
            ? s.t('${offering.warrantyMonths} شهراً',
                '${offering.warrantyMonths} months')
            : s.t('لا ينطبق', 'Not applicable'),
      ),
      (
        LucideIcons.shieldCheck,
        s.t('الدفع', 'Payment'),
        s.t('بعد الإنجاز', 'After completion'),
      ),
    ];
    return Row(
      children: [
        for (final (index, item) in items.indexed) ...[
          if (index > 0) const SizedBox(width: 9),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              child: Column(
                children: [
                  Icon(item.$1, size: 19, color: ak.ink),
                  const SizedBox(height: 7),
                  Text(item.$2,
                      style: TextStyle(fontSize: 10.5, color: ak.inkSub)),
                  const SizedBox(height: 2),
                  Text(
                    item.$3,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------- your car
  Widget _carRow(BuildContext context, Car? car, S s, AkColors ak) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      onTap: car == null ? () => context.push('/add-car') : null,
      child: Row(
        children: [
          Icon(LucideIcons.car, size: 17, color: ak.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: s.t('السيارة: ', 'Car: '),
                style: TextStyle(fontSize: 12, color: ak.inkSub),
                children: [
                  TextSpan(
                    text: car?.displayName ??
                        s.t('لم تُحدَّد بعد', 'Not selected yet'),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: ak.ink),
                  ),
                ],
              ),
            ),
          ),
          StatusBadge(car == null
              ? s.t('أضف سيارة', 'Add a car')
              : s.t('تُؤكَّد عند الحجز', 'Confirmed at booking')),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- includes
  Widget _includes(ServiceOffering offering, S s, AkColors ak) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Column(
        children: [
          for (final (index, item) in offering.includes.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.circleCheckBig, size: 16, color: ak.success),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.of(s),
                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------- how it works
  Widget _howItWorks(ServiceOffering offering, S s, AkColors ak) {
    final steps = <(String, String)>[
      (
        s.t('احجز وقتاً ومكاناً', 'Book a time and place'),
        s.t('اختر الموعد وطريقة التسليم — زيارة الورشة أو استلام السيارة.',
            'Pick the slot and how the car gets there — visit the workshop or have it collected.'),
      ),
      if (offering.quoteOnly)
        (
          s.t('فحص ثم عرض سعر', 'Inspection, then a quote'),
          s.t('تفحص الورشة السيارة وترسل عرضاً مفصّلاً للموافقة عليه.',
              'The workshop inspects the car and sends an itemized quote for you to approve.'),
        )
      else
        (
          s.t('العمل بالسعر الثابت', 'Work at the fixed price'),
          s.t('أي عمل إضافي خارج الباقة يحتاج موافقتك أولاً.',
              'Anything beyond this package needs your approval first.'),
        ),
      (
        s.t('تابع الحالة في التطبيق', 'Track it in the app'),
        s.t('تصلك تحديثات الحالة حتى جاهزية السيارة للتسليم.',
            'Status updates arrive until the car is ready for delivery.'),
      ),
      (
        s.t('ادفع بعد الإنجاز', 'Pay after completion'),
        s.t('المبلغ محتجز ولا يُحوَّل للورشة قبل تأكيدك للاستلام.',
            'The amount is held and only released to the workshop once you confirm.'),
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Column(
        children: [
          for (final (index, step) in steps.indexed) ...[
            if (index > 0) const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ak.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ak.onPrimary),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.$1,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(step.$2,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: ak.inkSub,
                              height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------ offering rail
  Widget _offeringRail(
    List<ServiceOffering> offerings,
    S s,
    AkColors ak, {
    required bool showProvider,
  }) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: offerings.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final o = offerings[i];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.replace('/service/${o.id}');
            },
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ak.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ak.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    showProvider ? o.provider.name.of(s) : o.name.of(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    showProvider
                        ? '${o.provider.distanceKm} ${s.km}'
                        : (o.durationMin != null
                            ? s.t('${o.durationMin} دقيقة', '${o.durationMin} min')
                            : s.t('حسب العمل', 'Open-ended')),
                    style: TextStyle(fontSize: 11, color: ak.inkSub),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    o.price != null
                        ? 'OMR ${o.price!.toStringAsFixed(2)}'
                        : s.t('عرض سعر', 'Quote'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------- book bar
  Widget _bookBar(
    BuildContext context,
    WidgetRef ref,
    ServiceOffering offering,
    double total,
    double addOnTotal,
    S s,
    AkColors ak,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: ak.surface,
        border: Border(top: BorderSide(color: ak.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!offering.quoteOnly && addOnTotal > 0) ...[
              Row(
                children: [
                  Text(
                    s.t('الخدمة ${offering.price!.toStringAsFixed(2)} + إضافات ${addOnTotal.toStringAsFixed(2)}',
                        'Service ${offering.price!.toStringAsFixed(2)} + extras ${addOnTotal.toStringAsFixed(2)}'),
                    style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                  ),
                  const Spacer(),
                  Text(
                    'OMR ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            FilledButton(
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                // Rule 4: registration gate before any service request.
                if (!ensureRegistered(context, ref)) return;
                context.push('/book/${offering.id}');
              },
              child: Text(
                offering.quoteOnly
                    ? s.t('اطلب فحصاً وعرض سعر', 'Request inspection & quote')
                    : s.t('اختر الوقت والمكان — ${total.toStringAsFixed(2)} ${s.omr}',
                        'Choose time & place — OMR ${total.toStringAsFixed(2)}'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOnRow extends StatelessWidget {
  const _AddOnRow({
    required this.addOns,
    required this.selected,
    required this.ref,
  });

  final List<AddOn> addOns;
  final Set<String> selected;
  final WidgetRef ref;

  /// Widest a card may get before a second column is worth having, and the
  /// narrowest it may be squeezed to before the price and the "+ Add" badge
  /// stop fitting on one line.
  static const _gap = 9.0;
  static const _minCardWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    // A provider can stock any number of extras, so the row wraps rather than
    // laying every card side by side — three `Expanded` cards on a phone
    // overflowed, and the count is the API's to decide, not ours.
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits =
            ((constraints.maxWidth + _gap) / (_minCardWidth + _gap)).floor();
        final columns = fits.clamp(1, 2).clamp(1, addOns.length);
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final a in addOns)
              SizedBox(width: width, child: _card(context, a)),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, AddOn a) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final isSelected = selected.contains(a.id);
    return AppCard(
      padding: const EdgeInsets.all(11),
      onTap: () {
        final next = Set<String>.from(selected);
        if (!next.add(a.id)) next.remove(a.id);
        ref.read(selectedAddOnsProvider.notifier).state = next;
      },
      border: Border.all(
        color: isSelected ? ak.primary : ak.border,
        width: isSelected ? 2 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.name.of(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('+ ${s.omr} ${a.price.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: ak.inkFaint)),
              ),
              const SizedBox(width: 4),
              isSelected
                  ? StatusBadge.good(s.t('✓ أضيفت', '✓ Added'))
                  : StatusBadge(s.t('+ إضافة', '+ Add')),
            ],
          ),
        ],
      ),
    );
  }
}
