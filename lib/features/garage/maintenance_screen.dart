import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/utils/guid.dart';
import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'my_cars_screen.dart';

final _fmt = intl.NumberFormat('#,###', 'en');

/// The maintenance dashboard for **one** car (handoff #3c).
///
/// Every registered car owns its own maintenance book, and this page shows the
/// book of the car the owner is looking at — the default car, or whichever one
/// they picked from the switcher. Nothing here is shared between cars, and
/// nothing is claimed about a car whose owner has not told the app anything
/// yet: an item with no record says "no record yet" and offers the two ways to
/// change that, rather than drawing a countdown from numbers nobody entered.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final cars = ref.watch(garageProvider);
    final car = ref.watch(maintenanceCarProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: SandRefresh(
          onRefresh: () =>
              ref.read(sessionRefreshProvider).refreshVisibleData(),
          child: car == null
              ? _NoCarState(
                  header: _header(context, s, showMyCars: cars.isNotEmpty),
                )
              : _CarBook(car: car, cars: cars),
        ),
      ),
    );
  }

  static Widget _header(
    BuildContext context,
    S s, {
    required bool showMyCars,
    // [SandTabHeader], not [SandHeader]: this is one of the five tab roots, and
    // they now introduce themselves the same way — no back button (there is
    // nothing behind a tab root to go back to), a subtitle saying what the tab
    // is for, and one action on the end.
  }) => SandTabHeader(
    s.navMyCar,
    subtitle: s.t(
      'دفتر الصيانة — لكل سيارة سجلها ومواعيدها',
      'The maintenance book — each car keeps its own records',
    ),
    // The garage lives one tap from here now that the home tab is gone:
    // this is the only place a user manages their cars from.
    trailing: showMyCars
        ? InkPill(
            label: s.t('سياراتي', 'My cars'),
            outlined: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 1,
            ),
            onTap: () => context.push('/garage'),
          )
        : null,
  );

  static String monthLabel(S s, DateTime d) {
    const ar = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    const en = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return s.isAr
        ? '${ar[d.month - 1]} ${d.year}'
        : '${en[d.month - 1]} ${d.year}';
  }

  static String dayLabel(S s, DateTime d) => '${d.day} ${monthLabel(s, d)}';
}

/// Empty garage: there is no book to show, so the page asks for a car rather
/// than illustrating itself with one the user does not own.
class _NoCarState extends StatelessWidget {
  const _NoCarState({required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.md,
        AppSpacing.screenMargin,
        AppSpacing.xl,
      ),
      children: [
        header,
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.06),
        EmptyState(
          icon: LucideIcons.notebookPen,
          title: s.t(
            'ابدأ دفتر صيانة سيارتك',
            'Start your car\'s maintenance book',
          ),
          message: s.t(
            'أضف سيارتك الأولى لنبدأ نتابع صيانتها معك — كل سيارة بسجلها ومواعيدها.',
            'Add your first car and we will keep track of its servicing with you — each car keeps its own records and reminders.',
          ),
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            ),
            onPressed: () => context.push('/add-car'),
            icon: const Icon(LucideIcons.plus, size: 17),
            label: Text(s.t('أضف سيارة', 'Add car')),
          ),
        ),
      ],
    );
  }
}

/// The dashboard for [car]: its identity, its mileage, its schedule, its
/// history.
class _CarBook extends ConsumerWidget {
  const _CarBook({required this.car, required this.cars});

  final Car car;
  final List<Car> cars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final book = ref.watch(maintenanceBookProvider(car.id));
    final due = ref.watch(maintenanceDueForCarProvider(car.id));
    final history = book.recordsNewestFirst;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.md,
        AppSpacing.screenMargin,
        AppSpacing.xl,
      ),
      children: [
        MaintenanceScreen._header(context, s, showMyCars: true),
        const SizedBox(height: AppSpacing.lg),
        // ------------------------------------------------- car switcher
        if (cars.length > 1) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cars.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) => SelectChip(
                label: cars[i].displayName,
                selected: cars[i].id == car.id,
                onTap: () =>
                    ref.read(selectedMaintenanceCarIdProvider.notifier).state =
                        cars[i].id,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // ------------------------------------------------ car + odometer
        _CarHeaderCard(car: car, book: book),
        const SizedBox(height: AppSpacing.lg),
        // ------------------------------------------------ setup / source
        if (book.isFresh) _SetupBanner(car: car) else _SourceNotice(book: book),
        const SizedBox(height: AppSpacing.sectionGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                s.t('جدول الصيانة', 'Maintenance schedule'),
                style: context.text.cardTitle,
              ),
            ),
            Text(
              s.t('لـ ${car.displayName}', 'for ${car.displayName}'),
              style: context.text.bodySecondary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        for (final d in due) ...[
          _ItemCard(car: car, item: d),
          const SizedBox(height: AppSpacing.itemGap + 2),
        ],
        // ------------------------------------------------ custom items
        SandCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.md + 2,
          ),
          onTap: () => showCustomItemSheet(context, ref, car),
          child: Row(
            children: [
              Icon(LucideIcons.plus, size: 16, color: ak.ink),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('أضف بنداً خاصاً بك', 'Add your own item'),
                      style: context.text.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      s.t(
                        'مساحات المطر، البواجي، زيت الجير، الفحمات — أي شيء تتابعه لهذه السيارة.',
                        'Wipers, spark plugs, gearbox oil, brake pads — anything you track on this car.',
                      ),
                      style: context.text.bodySecondary.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        // ------------------------------------------------------ history
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                s.t('سجل الخدمات', 'Service history'),
                style: context.text.cardTitle,
              ),
            ),
            Text(
              s.t('لهذه السيارة فقط', 'This car only'),
              style: context.text.bodySecondary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (history.isEmpty)
          SandCard(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: EmptyState(
              compact: true,
              icon: LucideIcons.history,
              message: s.t(
                'لا خدمات مسجّلة بعد لهذه السيارة — أضف آخر خدمة لأي بند أعلاه، أو احجز خدمة وستُسجَّل هنا فور اكتمالها.',
                'Nothing logged for this car yet — add the last service for any item above, or book one and it will be recorded here the moment it is completed.',
              ),
            ),
          )
        else
          SandCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, r) in history.indexed)
                  _HistoryRow(
                    car: car,
                    record: r,
                    book: book,
                    last: i == history.length - 1,
                  ),
              ],
            ),
          ),
        if (AppFlags.weekChallengeEnabled) ...[
          const SizedBox(height: 14),
          SandCard(
            onTap: () => context.push('/challenge'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(LucideIcons.flame, size: 18, color: ak.amber),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    s.weeklyChallenge,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronLeft, size: 16, color: ak.inkSub),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Car photo, name, powertrain and the one number the whole page is computed
/// from — this car's mileage, entered by its owner.
class _CarHeaderCard extends ConsumerWidget {
  const _CarHeaderCard({required this.car, required this.book});

  final Car car;
  final MaintenanceBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final projected = book.projectedOdometerKm();
    final isPrimary = ref.watch(primaryCarProvider)?.id == car.id;

    return SandCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: ak.surfaceDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CarImage(
                  make: car.make,
                  model: car.model,
                  color: car.color,
                  height: 52,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // The powertrain is named here because it is why this
                      // schedule holds what it holds.
                      [
                        if (isPrimary)
                          s.t('سيارتك الأساسية', 'Your primary car')
                        else
                          car.label,
                        ?car.powertrain?.label.of(s),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: ak.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.t(
                          'الممشى الحالي — تدخله بنفسك',
                          'Current mileage — entered by you',
                        ),
                        style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: book.currentOdometerKm != null
                                  ? _fmt.format(book.currentOdometerKm)
                                  : '—',
                              style: AppTheme.numeric(size: 22, color: ak.ink),
                            ),
                            TextSpan(
                              text: ' ${s.km}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: ak.inkSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _updatedLabel(s, book.odometerUpdatedAt),
                        style: TextStyle(fontSize: 12.5, color: ak.inkFaint),
                      ),
                      // The projection is shown next to the entered reading,
                      // never instead of it, and always labelled as an
                      // estimate — see MaintenanceBook.avgKmPerDay.
                      if (projected != null &&
                          projected != book.currentOdometerKm)
                        Text(
                          s.t(
                            'تقديري اليوم: ${_fmt.format(projected)} كم (تقدير)',
                            'Estimated today: ${_fmt.format(projected)} km (estimate)',
                          ),
                          style: TextStyle(fontSize: 12.5, color: ak.inkFaint),
                        ),
                    ],
                  ),
                ),
                InkPill(
                  label: book.currentOdometerKm == null
                      ? s.t('أضف الممشى', 'Add mileage')
                      : s.t('حدّث الممشى', 'Update mileage'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  onTap: () => showMileageSheet(context, ref, car),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _updatedLabel(S s, DateTime? at) {
    if (at == null) return s.t('لم يُحدّث بعد', 'Not updated yet');
    final days = DateTime.now().difference(at).inDays;
    final when = days <= 0
        ? s.t('اليوم', 'today')
        : days == 1
        ? s.t('أمس', 'yesterday')
        : s.t('قبل $days أيام', '$days days ago');
    return s.t('آخر تحديث: $when', 'Last update: $when');
  }
}

/// First-run copy for a car with no records at all.
///
/// It replaces the "these numbers come from you" notice while the book is
/// empty, because with nothing in it there are no numbers yet to explain —
/// what the owner needs is the invitation to put their real history in.
class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        border: Border.all(color: ak.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.notebookPen, size: 16, color: ak.ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'ابدأ دفتر صيانة ${car.displayName}',
                    'Start ${car.displayName}\'s maintenance book',
                  ),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s.t(
                    'لا يعرف التطبيق شيئاً عن صيانة هذه السيارة بعد. أدخل آخر خدمة لكل بند — التاريخ وقراءة العداد — ويبدأ العد من هناك.',
                    'The app knows nothing about this car\'s servicing yet. Enter the last service for each item — the date and the odometer reading — and the countdown starts from there.',
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: ak.inkSub,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the numbers on this page come from — and, when a projection is in
/// play, that part of them is an estimate.
class _SourceNotice extends StatelessWidget {
  const _SourceNotice({required this.book});

  final MaintenanceBook book;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ak.amberBgSoft,
        border: Border.all(color: ak.amberBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.info, size: 14, color: ak.amberText),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              book.avgKmPerDay == null
                  ? s.t(
                      'هذه التذكيرات تُحسب من الممشى الذي تدخله وسجل خدمات هذه السيارة في التطبيق — التطبيق لا يقرأ بيانات من السيارة نفسها.',
                      'These reminders are computed from the mileage you enter and this car\'s in-app service history — the app does not read data from the car itself.',
                    )
                  : s.t(
                      'هذه التذكيرات تُحسب من الممشى الذي تدخله وسجل خدمات هذه السيارة، مع تقدير للمسافة منذ آخر إدخال بافتراض معدل استخدام ثابت — التطبيق لا يقرأ بيانات من السيارة نفسها.',
                      'These reminders are computed from the mileage you enter and this car\'s service history, plus an estimate of the distance since your last entry assuming a steady usage rate — the app does not read data from the car itself.',
                    ),
              style: TextStyle(
                fontSize: 12.5,
                color: ak.amberDeep,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One schedule line: its status, its last record, its interval, and the four
/// things the owner can do to it.
class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.car, required this.item});

  final Car car;
  final DueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final book = ref.watch(maintenanceBookProvider(car.id));
    final rule = MaintenanceRule.resolve(item.item, book);

    // §3: an overdue item has to be findable in a 200ms glance down the page,
    // not read for. `UrgencyCard` gives it a red leading edge and a tinted
    // body; "due soon" gets the amber pair; everything healthy stays a plain
    // white card so the two that matter are the only two that stand out.
    final level = switch (item.status) {
      DueStatus.due => UrgencyLevel.overdue,
      DueStatus.near => UrgencyLevel.upcoming,
      _ => UrgencyLevel.normal,
    };
    final pillLabel = switch (item.status) {
      DueStatus.due => s.t('حان الآن', 'Due now'),
      DueStatus.near => s.t('قريب', 'Due soon'),
      DueStatus.good => s.t('بوضع جيد', 'In good shape'),
      DueStatus.noRecord => s.t('لا يوجد سجل', 'No record yet'),
    };
    final barColor = switch (item.status) {
      DueStatus.due => ak.danger,
      DueStatus.near => ak.amber,
      _ => ak.success,
    };

    return UrgencyCard(
      level: level,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.md + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.title.of(s), style: context.text.cardTitle),
              ),
              if (item.isCustom) ...[
                SandStatusPill(
                  s.t('بندك', 'Your item'),
                  background: ak.surfaceDim,
                  foreground: ak.inkSub,
                ),
                const SizedBox(width: AppSpacing.sm - 2),
              ],
              // "In good shape" keeps the green it earned; the two urgent
              // states take their color from the card's own level so the pill
              // and the edge can never disagree.
              if (item.status == DueStatus.good)
                SandStatusPill(
                  pillLabel,
                  background: ak.successSoft,
                  foreground: ak.success,
                )
              else
                UrgencyLabel(pillLabel, level: level),
            ],
          ),
          if (item.progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            SandProgressBar(value: item.progress!, color: barColor),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(_lastLabel(s), style: context.text.bodySecondary),
                ),
                _remainingLabel(context, s, ak),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _setupCopy(s),
              style: context.text.bodySecondary.copyWith(height: 1.7),
            ),
          ],
          const SizedBox(height: AppSpacing.xs + 1),
          Text(
            _intervalLabel(s, rule),
            style: context.text.bodySecondary.copyWith(
              fontSize: 12.5,
              color: ak.inkFaint,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Spec §4: every reminder is a booking button. That closes the
          // loop — the reminder opens a booking, the completed booking writes
          // a service record on *this* car, and the record sharpens the next
          // reminder.
          //
          // The labels carry no price: what an oil change costs depends on the
          // workshop, and the services list a tap away shows the real ones.
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              InkPill(
                label: item.needsSetup
                    ? s.t('أضف آخر خدمة', 'Add last service')
                    : s.t('حدّث السجل', 'Update record'),
                outlined: true,
                fontSize: 12.5,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                onTap: () => showRecordSheet(
                  context,
                  ref,
                  car: car,
                  item: item.item,
                  existing: item.lastRecord?.isManual ?? false
                      ? item.lastRecord
                      : null,
                ),
              ),
              InkPill(
                label: s.t('احجز خدمة', 'Book service'),
                fontSize: 12.5,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                onTap: () => _book(context, ref),
              ),
              if (item.isCustom)
                InkPill(
                  label: s.t('حذف البند', 'Delete item'),
                  outlined: true,
                  fontSize: 12.5,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  onTap: () => _confirmDeleteCustomItem(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _book(BuildContext context, WidgetRef ref) =>
      bookMaintenanceItem(context, ref, car: car, item: item);

  String _setupCopy(S s) {
    // The battery-health line says outright where the number would come from.
    // The app cannot read the car, so an EV owner must never be left wondering
    // whether a missing percentage means "unknown" or "bad".
    if (item.type == MaintenanceType.evBattery && item.needsSetup) {
      return s.t(
        'لا يقرأ التطبيق بيانات سيارتك — تظهر حالة البطارية بعد فحص في ورشة معتمدة.',
        'The app cannot read your car — battery condition appears here after an inspection at an EV-certified workshop.',
      );
    }
    final last = item.lastRecord;
    if (last != null) {
      // There is history, but no interval to measure it against.
      return s.t(
        'آخر خدمة: ${MaintenanceScreen.dayLabel(s, last.date)}. أضف فترة تكرار ليبدأ العد.',
        'Last service: ${MaintenanceScreen.dayLabel(s, last.date)}. Add an interval to start the countdown.',
      );
    }
    return s.t(
      'لا يوجد سجل بعد — أضف آخر مرة تمت فيها الخدمة، أو احجز خدمة وستُسجَّل عند اكتمالها.',
      'No record yet — add the last time this was serviced, or book one and it will be logged when it is completed.',
    );
  }

  String _lastLabel(S s) {
    final r = item.lastRecord;
    if (r == null) return '';
    if (item.remainingKm != null) {
      return s.t(
        'آخر خدمة: ${_fmt.format(r.odometerKm)} كم (${r.workshop})',
        'Last service: ${_fmt.format(r.odometerKm)} km (${r.workshop})',
      );
    }
    return s.t(
      'آخر خدمة: ${MaintenanceScreen.monthLabel(s, r.date)}',
      'Last service: ${MaintenanceScreen.monthLabel(s, r.date)}',
    );
  }

  String _intervalLabel(S s, MaintenanceRule rule) {
    final parts = <String>[
      if (rule.intervalKm != null)
        s.t(
          'كل ${_fmt.format(rule.intervalKm)} كم',
          'every ${_fmt.format(rule.intervalKm)} km',
        ),
      if (rule.intervalMonths != null)
        s.t(
          'كل ${rule.intervalMonths} أشهر',
          'every ${rule.intervalMonths} months',
        ),
    ];
    if (parts.isEmpty) {
      return s.t('لا توجد فترة تكرار محددة', 'No interval set');
    }
    return s.t(
      'الفترة: ${parts.join(' أو ')}',
      'Interval: ${parts.join(' or ')}',
    );
  }

  Widget _remainingLabel(BuildContext context, S s, AkColors ak) {
    if (item.remainingKm != null) {
      final overdue = item.remainingKm! <= 0;
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: overdue ? s.t('متأخر ', 'overdue ') : s.t('باقي ', ''),
            ),
            TextSpan(
              text: _fmt.format(item.remainingKm!.abs()),
              style: AppTheme.numeric(
                size: 14,
                color: overdue ? ak.dangerText : ak.amberText,
              ),
            ),
            TextSpan(text: s.t(' كم', ' km left')),
            // The distance is measured against a projected odometer, so the
            // number is an estimate and has to read as one.
            if (item.estimated)
              TextSpan(text: s.t(' (تقديري)', ' (estimated)')),
          ],
        ),
        style: context.text.bodySecondary,
      );
    }
    final months = item.remainingMonths;
    if (months == null) return const SizedBox.shrink();
    return Text(
      months <= 0
          ? s.t('الموصى به: الآن', 'Recommended: now')
          : s.t(
              'الموصى به: بعد $months أشهر',
              'Recommended: in $months months',
            ),
      style: context.text.bodySecondary,
    );
  }

  Future<void> _confirmDeleteCustomItem(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.t('حذف هذا البند؟', 'Delete this item?')),
        content: Text(
          s.t(
            'سيُحذف "${item.title.ar}" وسجلاته من دفتر ${car.displayName}.',
            '"${item.title.en}" and its records will be removed from ${car.displayName}\'s book.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ak.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    ref.read(maintenanceProvider.notifier).removeCustomItem(car.id, item.key);
  }
}

/// One line of this car's service history.
class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.car,
    required this.record,
    required this.book,
    required this.last,
  });

  final Car car;
  final ServiceRecord record;
  final MaintenanceBook book;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final itemKey = record.itemKey;
    final item = itemKey == null
        ? null
        : book
              .itemsFor(car.powertrain)
              .where((i) => i.key == itemKey)
              .firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: ak.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 40,
            decoration: BoxDecoration(
              color: ak.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              switch (record.type) {
                MaintenanceType.tyres => LucideIcons.lifeBuoy,
                MaintenanceType.coolant => LucideIcons.thermometer,
                _ => LucideIcons.wrench,
              },
              size: 15,
              color: ak.ink,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title.of(s),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${record.workshop} · '),
                      TextSpan(
                        text: _fmt.format(record.odometerKm),
                        style: AppTheme.numeric(
                          size: 9.5,
                          weight: FontWeight.w500,
                          color: ak.inkSub,
                        ),
                      ),
                      TextSpan(text: ' ${s.km}'),
                    ],
                  ),
                  style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                ),
                if (record.notes case final notes? when notes.isNotEmpty)
                  Text(
                    notes,
                    style: TextStyle(fontSize: 12.5, color: ak.inkFaint),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MaintenanceScreen.monthLabel(s, record.date),
                style: TextStyle(fontSize: 12.5, color: ak.inkSub),
              ),
              if (!record.isManual)
                Text(
                  s.t('من حجز مكتمل', 'From a completed booking'),
                  style: TextStyle(fontSize: 12.5, color: ak.inkFaint),
                ),
            ],
          ),
          // Only what the owner typed can be edited here. A record written by
          // a completed booking is the app's account of what happened and is
          // not theirs to rewrite.
          if (record.isManual && item != null)
            IconButton(
              tooltip: s.t('تعديل', 'Edit'),
              icon: Icon(LucideIcons.pencil, size: 16, color: ak.inkSub),
              onPressed: () => showRecordSheet(
                context,
                ref,
                car: car,
                item: item,
                existing: record,
              ),
            ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------- sheets

/// Manual entry for one item: when it was last done, at what mileage, by whom,
/// and how often it should repeat.
///
/// This is the whole point of the redesign. A first-time user has real history
/// in their head (and in a folder in the glovebox) and had no way to put it
/// in; saving one record here starts that item's countdown from the truth
/// instead of from the day they installed the app.
/// Starts a booking for one maintenance line on one car.
///
/// Sends the owner to the services tab already searching for the item, and
/// leaves behind which car and which line the booking is for, so the completed
/// booking writes its record against the right countdown.
///
/// Shared with the home page: the "احجز الآن" button on a home car card and
/// the "احجز خدمة" button on the My Car page must start the *same* booking,
/// carrying the same intent — two code paths would eventually drift and one of
/// them would silently stop logging its record.
void bookMaintenanceItem(
  BuildContext context,
  WidgetRef ref, {
  required Car car,
  required DueItem item,
}) {
  ref
      .read(maintenanceBookingIntentProvider.notifier)
      .state = MaintenanceBookingIntent(
    carId: car.id,
    itemKey: item.key,
    title: item.title,
  );
  context.go('/services?q=${Uri.encodeQueryComponent(item.shortTitle.en)}');
}

Future<void> showRecordSheet(
  BuildContext context,
  WidgetRef ref, {
  required Car car,
  required MaintenanceItem item,
  ServiceRecord? existing,
}) {
  final ak = AkColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ak.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RecordSheet(car: car, item: item, existing: existing),
  );
}

class _RecordSheet extends ConsumerStatefulWidget {
  const _RecordSheet({required this.car, required this.item, this.existing});

  final Car car;
  final MaintenanceItem item;
  final ServiceRecord? existing;

  @override
  ConsumerState<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends ConsumerState<_RecordSheet> {
  late DateTime _date;
  late final TextEditingController _odometer;
  late final TextEditingController _workshop;
  late final TextEditingController _notes;
  late final TextEditingController _intervalKm;
  late final TextEditingController _intervalMonths;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final book = ref.read(maintenanceBookProvider(widget.car.id));
    final rule = MaintenanceRule.resolve(widget.item, book);

    _date = existing?.date ?? DateTime.now();
    _odometer = TextEditingController(
      text: existing?.odometerKm.toString() ?? '',
    );
    _workshop = TextEditingController(text: existing?.workshop ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _intervalKm = TextEditingController(
      text: rule.intervalKm?.toString() ?? '',
    );
    _intervalMonths = TextEditingController(
      text: rule.intervalMonths?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _odometer.dispose();
    _workshop.dispose();
    _notes.dispose();
    _intervalKm.dispose();
    _intervalMonths.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // A service in the future is not a service that happened.
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final s = S.of(context);
    final maintenance = ref.read(maintenanceProvider.notifier);
    final book = ref.read(maintenanceBookProvider(widget.car.id));
    final carId = widget.car.id;

    final odometer =
        int.tryParse(_odometer.text.trim()) ??
        book.currentOdometerKm ??
        widget.car.odometerKm ??
        0;
    final workshop = _workshop.text.trim();
    final notes = _notes.text.trim();

    maintenance.addRecord(
      carId,
      ServiceRecord(
        id: widget.existing?.id ?? newGuid(),
        title: widget.item.title,
        // The owner's own words when they gave any; otherwise the honest
        // description of where this row came from.
        workshop: workshop.isEmpty ? s.t('سجل يدوي', 'Manual entry') : workshop,
        odometerKm: odometer,
        date: _date,
        itemKey: widget.item.key,
        notes: notes.isEmpty ? null : notes,
      ),
    );
    maintenance.setIntervals(
      carId,
      widget.item.key,
      km: int.tryParse(_intervalKm.text.trim()),
      months: int.tryParse(_intervalMonths.text.trim()),
    );

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'حُفظ السجل — بدأ العد من هذه الخدمة.',
            'Record saved — the countdown starts from this service.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null
                  ? s.t('أضف آخر خدمة', 'Add last service')
                  : s.t('تعديل السجل', 'Edit record'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              '${widget.item.title.of(s)} · ${widget.car.displayName}',
              style: TextStyle(fontSize: 12.5, color: ak.inkSub),
            ),
            const SizedBox(height: 14),
            _SheetLabel(s.t('تاريخ آخر خدمة', 'Last service date')),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: ak.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ak.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 18, color: ak.inkSub),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        MaintenanceScreen.dayLabel(s, _date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.chevronDown, size: 19, color: ak.inkFaint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _SheetLabel(
              s.t('قراءة العداد وقتها (كم)', 'Odometer at that service (km)'),
            ),
            _SheetField(
              controller: _odometer,
              numeric: true,
              hint: s.t('مثال: 123000', 'e.g. 123000'),
            ),
            const SizedBox(height: 10),
            _SheetLabel(
              s.t(
                'الورشة أو مَن نفّذها (اختياري)',
                'Workshop or who did it (optional)',
              ),
            ),
            _SheetField(
              controller: _workshop,
              hint: s.t('مثال: ورشة النور', 'e.g. Al Noor Workshop'),
            ),
            const SizedBox(height: 10),
            _SheetLabel(s.t('ملاحظات (اختياري)', 'Notes (optional)')),
            _SheetField(
              controller: _notes,
              hint: s.t('مثال: زيت 5W-30 تخليقي', 'e.g. 5W-30 synthetic'),
            ),
            const SizedBox(height: 14),
            Text(
              s.t('كل كم تتكرر هذه الخدمة؟', 'How often does this repeat?'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              s.t(
                'املأ أحدهما أو كليهما — يحين الموعد عند أولهما.',
                'Fill in either or both — it falls due at whichever comes first.',
              ),
              style: TextStyle(fontSize: 12.5, color: ak.inkFaint),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SheetLabel(s.t('كل (كم)', 'Every (km)')),
                      _SheetField(
                        controller: _intervalKm,
                        numeric: true,
                        hint: '5000',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SheetLabel(s.t('كل (شهر)', 'Every (months)')),
                      _SheetField(
                        controller: _intervalMonths,
                        numeric: true,
                        hint: '6',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null) ...[
                  TextButton(
                    onPressed: () {
                      ref
                          .read(maintenanceProvider.notifier)
                          .removeRecord(widget.car.id, widget.existing!.id);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      s.t('حذف السجل', 'Delete record'),
                      style: TextStyle(color: ak.danger),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(s.t('حفظ', 'Save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds an extra line to *this* car's schedule.
Future<void> showCustomItemSheet(
  BuildContext context,
  WidgetRef ref,
  Car car, {
  CustomMaintenanceItem? existing,
}) {
  final ak = AkColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ak.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CustomItemSheet(car: car, existing: existing),
  );
}

class _CustomItemSheet extends ConsumerStatefulWidget {
  const _CustomItemSheet({required this.car, this.existing});

  final Car car;
  final CustomMaintenanceItem? existing;

  @override
  ConsumerState<_CustomItemSheet> createState() => _CustomItemSheetState();
}

class _CustomItemSheetState extends ConsumerState<_CustomItemSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _km = TextEditingController(
    text: widget.existing?.intervalKm?.toString() ?? '',
  );
  late final _months = TextEditingController(
    text: widget.existing?.intervalMonths?.toString() ?? '',
  );

  @override
  void dispose() {
    _title.dispose();
    _km.dispose();
    _months.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final km = int.tryParse(_km.text.trim());
    final months = int.tryParse(_months.text.trim());
    ref
        .read(maintenanceProvider.notifier)
        .saveCustomItem(
          widget.car.id,
          CustomMaintenanceItem(
            id: widget.existing?.id ?? newGuid(),
            // Stored exactly as typed and shown the same in both languages —
            // the app does not invent a translation of the owner's words.
            title: title,
            intervalKm: km != null && km > 0 ? km : null,
            intervalMonths: months != null && months > 0 ? months : null,
          ),
        );
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null
                  ? s.t('أضف بنداً خاصاً بك', 'Add your own item')
                  : s.t('تعديل البند', 'Edit item'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              s.t(
                'يُضاف إلى ${widget.car.displayName} وحدها.',
                'Added to ${widget.car.displayName} only.',
              ),
              style: TextStyle(fontSize: 12.5, color: ak.inkSub),
            ),
            const SizedBox(height: 14),
            _SheetLabel(s.t('اسم البند', 'Item name')),
            _SheetField(
              controller: _title,
              autofocus: true,
              hint: s.t('مثال: مساحات المطر', 'e.g. Wiper blades'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SheetLabel(s.t('كل (كم)', 'Every (km)')),
                      _SheetField(
                        controller: _km,
                        numeric: true,
                        hint: '20000',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SheetLabel(s.t('كل (شهر)', 'Every (months)')),
                      _SheetField(
                        controller: _months,
                        numeric: true,
                        hint: '12',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(s.t('حفظ البند', 'Save item')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: ak.inkSub,
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    this.hint,
    this.numeric = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hint;
  final bool numeric;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: numeric
          ? AppTheme.numeric(size: 16, color: ak.ink)
          : const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(hintText: hint),
    );
  }
}
