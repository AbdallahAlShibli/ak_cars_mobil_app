import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/oman_plate_input.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';

final _fmt = intl.NumberFormat('#,###', 'en');

/// The garage — the user's saved cars.
///
/// The first car in the list is the default one: it is what the services,
/// shop and maintenance screens assume you mean, so it gets a full card with
/// its photo, plate, mileage and what is due next. Every car can be edited,
/// promoted, or removed from here; nothing about a saved car is write-once.
class MyCarsScreen extends ConsumerWidget {
  const MyCarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final cars = ref.watch(garageProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-car'),
        backgroundColor: ak.primary,
        icon: Icon(LucideIcons.plus, color: ak.onPrimary),
        label: Text(
          cars.isEmpty
              ? s.t('أضف سيارة', 'Add car')
              : s.t('أضف سيارة أخرى', 'Add another'),
          style: TextStyle(color: ak.onPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SandHeader(
                s.t('سياراتي', 'My cars'),
                trailing: cars.isEmpty ? null : StatusBadge('${cars.length}'),
              ),
            ),
            Expanded(
              child: cars.isEmpty
                  ? const _EmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
                      children: [
                        Entrance(child: _PrimaryCarCard(car: cars.first)),
                        if (cars.length > 1) ...[
                          const SizedBox(height: 20),
                          SandSectionHeader(
                              s.t('سيارات أخرى', 'Other cars')),
                          const SizedBox(height: 10),
                          for (var i = 1; i < cars.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Entrance(
                                delayMs: 40 * i,
                                child: _SecondaryCarCard(
                                    car: cars[i], index: i),
                              ),
                            ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          s.t(
                            'السيارة الافتراضية هي المستخدمة في حجز الخدمات وفلترة قطع الغيار.',
                            'Your default car is the one used for booking services and filtering parts.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10.5, color: ak.inkFaint, height: 1.6),
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

/// -------------------------------------------------------------- hero card

/// The default car: photo, identity, plate, mileage, what is due next, and
/// the three things people actually come here to do.
class _PrimaryCarCard extends ConsumerWidget {
  const _PrimaryCarCard({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final specs = ref.watch(specCatalogProvider);
    final locations = ref.watch(locationCatalogProvider);

    return SandCard(
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------- photo band
          Stack(
            children: [
              Container(
                height: 148,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ak.surfaceDim,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
                child: CarImage(
                    make: car.make,
                    model: car.model,
                    color: car.color,
                    height: 106),
              ),
              PositionedDirectional(
                top: 12,
                start: 14,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ak.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.star,
                              size: 12, color: ak.onPrimary),
                          const SizedBox(width: 4),
                          Text(
                            s.t('الافتراضية', 'DEFAULT'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: ak.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // An electric car should be recognisable as one from its
                    // own garage card, not only from a field inside the editor.
                    if (car.powertrain case final powertrain?) ...[
                      const SizedBox(width: 7),
                      _PowertrainBadge(powertrain: powertrain),
                    ],
                  ],
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: _CarMenuButton(car: car, index: 0),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------- identity
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (car.nickname != null) car.label else '',
                              if (car.trim != null) car.trim!,
                            ].where((p) => p.isNotEmpty).join(' · '),
                            style:
                                TextStyle(fontSize: 11.5, color: ak.inkSub),
                          ),
                        ],
                      ),
                    ),
                    if (car.plate != null) ...[
                      const SizedBox(width: 10),
                      _PlateChip(plate: car.plate!),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // ---------------------------------------------------- specs
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _SpecChip(
                        icon: LucideIcons.calendar,
                        label: '${car.year}'),
                    if (car.powertrain case final powertrain?)
                      _SpecChip(
                        icon: powertrain.icon,
                        label: powertrain.label.of(s),
                      ),
                    if (car.color != null)
                      _SpecChip(
                        label: specs.localized(car.color!, s.isAr),
                        swatch: specs.swatchOf(car.color!),
                      ),
                    if (car.wilayat != null)
                      _SpecChip(
                        icon: LucideIcons.mapPin,
                        label: locations.localized(car.wilayat!, s.isAr),
                      )
                    else if (car.governorate != null)
                      _SpecChip(
                        icon: LucideIcons.map,
                        label: locations.localized(car.governorate!, s.isAr),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _MileageRow(car: car),
                const SizedBox(height: 10),
                _DueStrip(car: car),
                if (!car.hasFullDetails) ...[
                  const SizedBox(height: 10),
                  _CompleteDetailsNudge(car: car),
                ],
                const SizedBox(height: 14),
                // -------------------------------------------------- actions
                Row(
                  children: [
                    Expanded(
                      child: _Action(
                        icon: LucideIcons.wrench,
                        label: s.t('احجز خدمة', 'Book service'),
                        primary: true,
                        onTap: () => context.go('/services'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Action(
                        icon: LucideIcons.notebookPen,
                        label: s.t('الصيانة', 'Maintenance'),
                        onTap: () {
                          ref
                              .read(selectedMaintenanceCarIdProvider.notifier)
                              .state = car.id;
                          context.go('/my-car');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Action(
                        icon: LucideIcons.pencil,
                        label: s.t('تعديل', 'Edit'),
                        onTap: () => context.push('/garage/edit/${car.id}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------- other cars

class _SecondaryCarCard extends ConsumerWidget {
  const _SecondaryCarCard({required this.car, required this.index});

  final Car car;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Dismissible(
      key: ValueKey('garage-${car.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 22),
        decoration: BoxDecoration(
          color: ak.dangerSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(LucideIcons.trash2, color: ak.danger),
      ),
      onDismissed: (_) => removeCarWithUndo(context, ref, car, index),
      child: SandCard(
        radius: 20,
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/garage/edit/${car.id}'),
        child: Column(
          children: [
            Row(
          children: [
            Container(
              width: 74,
              height: 50,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: ak.surfaceDim,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CarImage(
                  make: car.make,
                  model: car.model,
                  color: car.color,
                  height: 50),
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
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (car.plate != null) ...[
                        Text(
                          car.plate!,
                          style: AppTheme.numeric(
                              size: 11,
                              weight: FontWeight.w700,
                              color: ak.inkSub),
                        ),
                        Text(' · ',
                            style: TextStyle(
                                fontSize: 11, color: ak.inkFaint)),
                      ],
                      if (car.powertrain case final powertrain?) ...[
                        Icon(powertrain.icon, size: 11, color: ak.inkFaint),
                        const SizedBox(width: 3),
                        Text(
                          powertrain.badge.of(s),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ak.inkSub),
                        ),
                        Text(' · ',
                            style:
                                TextStyle(fontSize: 11, color: ak.inkFaint)),
                      ],
                      Flexible(
                        child: Text(
                          car.odometerKm != null
                              ? '${_fmt.format(car.odometerKm)} ${s.km}'
                              : s.t('لا ممشى محفوظ', 'No mileage saved'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 11, color: ak.inkFaint),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _CarMenuButton(car: car, index: index),
          ],
        ),
            // This car's own book, not the default car's.
            const SizedBox(height: 10),
            _DueStrip(car: car),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------- fragments

/// "Electric" / "Hybrid" pill on the car photo.
///
/// Electric gets the accent treatment; everything else stays quiet — the badge
/// exists to make an EV feel recognised, not to decorate every card.
class _PowertrainBadge extends StatelessWidget {
  const _PowertrainBadge({required this.powertrain});

  final Powertrain powertrain;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final electric = powertrain.isFullyElectric;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: electric ? ak.successSoft : ak.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: electric ? ak.success : ak.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(powertrain.icon,
              size: 12, color: electric ? ak.success : ak.inkSub),
          const SizedBox(width: 4),
          Text(
            powertrain.label.of(s),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: electric ? ak.success : ak.inkSub,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini Omani plate, so a car is recognisable at a glance the same way it is
/// in the car park.
class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final (number, letters) = OmanPlateInput.parse(plate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OmanPlateInput.plateYellow,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: OmanPlateInput.plateInk, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: OmanPlateInput.plateInk,
            ),
          ),
          Container(
            width: 1.6,
            height: 14,
            color: OmanPlateInput.plateInk,
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),
          Text(
            letters,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: OmanPlateInput.plateInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.label, this.icon, this.swatch});

  final String label;
  final IconData? icon;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (swatch != null)
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(color: ak.border),
              ),
            )
          else if (icon != null)
            Icon(icon, size: 12, color: ak.inkSub),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: ak.inkSub),
          ),
        ],
      ),
    );
  }
}

/// Mileage with an inline update action — the one car detail that changes
/// every week, so it does not deserve a trip through the edit form.
class _MileageRow extends ConsumerWidget {
  const _MileageRow({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: ak.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.gauge, size: 17, color: ak.inkSub),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('الممشى — تدخله بنفسك', 'Mileage — entered by you'),
                  style: TextStyle(fontSize: 9.5, color: ak.inkFaint),
                ),
                const SizedBox(height: 1),
                car.odometerKm != null
                    ? Text.rich(TextSpan(children: [
                        TextSpan(
                          text: _fmt.format(car.odometerKm),
                          style: AppTheme.numeric(size: 17, color: ak.ink),
                        ),
                        TextSpan(
                          text: ' ${s.km}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: ak.inkSub),
                        ),
                      ]))
                    : Text(
                        s.t('لم يُسجّل بعد', 'Not recorded yet'),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: ak.inkSub),
                      ),
              ],
            ),
          ),
          InkPill(
            label: car.odometerKm == null
                ? s.t('أضف', 'Add')
                : s.t('حدّث', 'Update'),
            fontSize: 11,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            onTap: () => showMileageSheet(context, ref, car),
          ),
        ],
      ),
    );
  }
}

/// What *this car's* maintenance book says is due next. It reads the same
/// computed items as the maintenance screen — no second opinion, nothing
/// shown for an item with no service record, and nothing borrowed from
/// another car in the garage.
class _DueStrip extends ConsumerWidget {
  const _DueStrip({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final due = ref.watch(maintenanceDueForCarProvider(car.id));
    final next = due.mostUrgent;

    void openBook() {
      ref.read(selectedMaintenanceCarIdProvider.notifier).state = car.id;
      context.go('/my-car');
    }

    if (next == null || next.status == DueStatus.noRecord) {
      return GestureDetector(
        onTap: openBook,
        child: Row(
          children: [
            Icon(LucideIcons.notebookPen, size: 14, color: ak.inkFaint),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                s.t('لا سجل صيانة لهذه السيارة بعد — أضف آخر خدمة لتبدأ التذكيرات.',
                    'No service record for this car yet — add its last service to start reminders.'),
                style: TextStyle(fontSize: 10.5, color: ak.inkFaint),
              ),
            ),
          ],
        ),
      );
    }

    final (pill, bg, fg, bar) = switch (next.status) {
      DueStatus.due => (
          s.t('حان الآن', 'Due now'),
          ak.dangerSoft,
          ak.dangerText,
          ak.danger
        ),
      DueStatus.near => (
          s.t('قريب', 'Due soon'),
          ak.amberBgSoft,
          ak.amberText,
          ak.amber
        ),
      _ => (
          s.t('بوضع جيد', 'In good shape'),
          ak.successSoft,
          ak.success,
          ak.success
        ),
    };

    return GestureDetector(
      onTap: openBook,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  next.shortTitle.of(s),
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              SandStatusPill(pill, background: bg, foreground: fg),
            ],
          ),
          if (next.progress != null) ...[
            const SizedBox(height: 7),
            SandProgressBar(value: next.progress!, color: bar),
          ],
        ],
      ),
    );
  }

}

/// Amber nudge shown while the car is missing the details that services and
/// the shop actually need.
class _CompleteDetailsNudge extends StatelessWidget {
  const _CompleteDetailsNudge({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final missing = <String>[
      if (car.plate == null) s.t('اللوحة', 'plate'),
      if (car.odometerKm == null) s.t('الممشى', 'mileage'),
      if (car.governorate == null) s.t('الموقع', 'location'),
    ];
    return GestureDetector(
      onTap: () => context.push('/garage/edit/${car.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ak.amberBgSoft,
          border: Border.all(color: ak.amberBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 15, color: ak.amberText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.t('أكمل ${missing.join('، ')} لحجز الخدمات بسرعة.',
                    'Add your ${missing.join(', ')} to book services faster.'),
                style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: ak.amberText),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 17, color: ak.amberText),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        decoration: BoxDecoration(
          color: primary ? ak.primary : ak.surfaceDim,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: primary ? ak.onPrimary : ak.ink),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: primary ? ak.onPrimary : ak.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overflow menu: everything you can do to a saved car in one place.
class _CarMenuButton extends ConsumerWidget {
  const _CarMenuButton({required this.car, required this.index});

  final Car car;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final isPrimary = index == 0;

    return PopupMenuButton<String>(
      tooltip: s.t('خيارات', 'Options'),
      icon: Icon(LucideIcons.ellipsisVertical, size: 20, color: ak.inkSub),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) async {
        HapticFeedback.selectionClick();
        switch (value) {
          case 'edit':
            context.push('/garage/edit/${car.id}');
          case 'primary':
            ref.read(garageProvider.notifier).setPrimary(car.id);
          case 'maintenance':
            ref.read(selectedMaintenanceCarIdProvider.notifier).state = car.id;
            context.go('/my-car');
          case 'mileage':
            await showMileageSheet(context, ref, car);
          case 'remove':
            await confirmRemoveCar(context, ref, car, index);
        }
      },
      itemBuilder: (context) => [
        if (!isPrimary)
          PopupMenuItem(
            value: 'primary',
            child: _MenuItem(
                icon: LucideIcons.star,
                label: s.t('اجعلها الافتراضية', 'Make default')),
          ),
        PopupMenuItem(
          value: 'edit',
          child: _MenuItem(
              icon: LucideIcons.pencil,
              label: s.t('تعديل التفاصيل', 'Edit details')),
        ),
        PopupMenuItem(
          value: 'mileage',
          child: _MenuItem(
              icon: LucideIcons.gauge,
              label: s.t('تحديث الممشى', 'Update mileage')),
        ),
        // Every car has its own book, so every car's menu opens it — the
        // maintenance page is not a view of the default car alone.
        PopupMenuItem(
          value: 'maintenance',
          child: _MenuItem(
              icon: LucideIcons.notebookPen,
              label: s.t('دفتر الصيانة', 'Maintenance book')),
        ),
        PopupMenuItem(
          value: 'remove',
          child: _MenuItem(
            icon: LucideIcons.trash2,
            label: s.t('حذف السيارة', 'Remove car'),
            color: ak.danger,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: color ?? ak.inkSub),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? ak.ink),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(LucideIcons.car,
                size: 64,
                radius: 22,
                background: ak.surfaceDim,
                foreground: ak.inkFaint),
            const SizedBox(height: 12),
            Text(
              s.t('لا سيارات في مرآبك', 'No cars in your garage'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              s.t('أضف سيارتك لتحصل على خدمات وتذكيرات مناسبة.',
                  'Add your car to get matched services and reminders.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: ak.inkSub, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------- actions

/// Numeric sheet for one car's odometer.
///
/// The write goes through the maintenance notifier, which updates that car's
/// maintenance book *and* the saved car — one reading, one car, one place it
/// is stored. The garage card and the maintenance page cannot show two
/// different mileages for the same vehicle, and updating the second car in the
/// garage no longer moves the first car's countdown.
Future<void> showMileageSheet(
  BuildContext context,
  WidgetRef ref,
  Car car,
) {
  final ak = AkColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ak.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _MileageSheet(
      car: car,
      onSave: (km) =>
          ref.read(garageProvider.notifier).setOdometer(car.id, km),
    ),
  );
}

/// Owns its own controller: disposing one from the caller would outlive the
/// sheet's exit animation and rebuild a disposed field.
class _MileageSheet extends StatefulWidget {
  const _MileageSheet({required this.car, required this.onSave});

  final Car car;
  final ValueChanged<int> onSave;

  @override
  State<_MileageSheet> createState() => _MileageSheetState();
}

class _MileageSheetState extends State<_MileageSheet> {
  late final _controller =
      TextEditingController(text: widget.car.odometerKm?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final km = int.tryParse(_controller.text.trim());
    if (km == null || km <= 0) return;
    widget.onSave(km);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('ممشى ${widget.car.displayName}',
                '${widget.car.displayName} mileage'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            s.t('أدخل قراءة العداد الحالية بالكيلومترات.',
                'Enter the current odometer reading in kilometres.'),
            style: TextStyle(fontSize: 12, color: ak.inkSub),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _save(),
            style: AppTheme.numeric(size: 18, color: ak.ink),
            decoration: InputDecoration(
              hintText: s.t('مثال: 128450', 'e.g. 128450'),
              suffixText: s.km,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _save,
            child: Text(s.t('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }
}

Future<void> confirmRemoveCar(
  BuildContext context,
  WidgetRef ref,
  Car car,
  int index,
) async {
  final s = S.of(context);
  final ak = AkColors.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(s.t('حذف السيارة؟', 'Remove car?')),
      content: Text(s.t('سيتم حذف ${car.displayName} من مرآبك.',
          '${car.displayName} will be removed from your garage.')),
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
          child: Text(s.t('حذف', 'Remove')),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false) || !context.mounted) return;
  removeCarWithUndo(context, ref, car, index);
}

/// Removes [car] and offers an undo — a mis-swipe should not cost the user
/// the re-typing of a car they registered months ago.
void removeCarWithUndo(
  BuildContext context,
  WidgetRef ref,
  Car car,
  int index,
) {
  final s = S.of(context);
  // Held before the removal: on a swipe the card that owns `ref` is gone by
  // the time Undo is tapped, and reading through it then throws. The
  // notifier itself outlives the widget.
  final garage = ref.read(garageProvider.notifier);
  HapticFeedback.mediumImpact();
  garage.remove(car.id);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(s.t('تم حذف ${car.displayName}',
            '${car.displayName} removed')),
        action: SnackBarAction(
          label: s.t('تراجع', 'Undo'),
          onPressed: () => garage.restore(car, index),
        ),
      ),
    );
}
