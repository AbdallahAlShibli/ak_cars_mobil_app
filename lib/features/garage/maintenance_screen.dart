import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../data/app_state.dart';
import '../../data/maintenance_state.dart';

final _fmt = intl.NumberFormat('#,###', 'en');

/// Maintenance follow-up (handoff #3c) — replaces the fake "health score".
/// Everything is computed from the odometer the user enters + the in-app
/// service history; the app never reads data from the car.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final m = ref.watch(maintenanceProvider);
    final due = ref.watch(maintenanceDueProvider);
    final car = ref.watch(primaryCarProvider);

    final carTitle = car != null
        ? '${car.make} ${car.model} · ${car.year}'
        : s.t('تويوتا كامري SE · 2017', 'Toyota Camry SE · 2017');

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            SandHeader(s.maintenanceTitle),
            const SizedBox(height: 14),
            // ------------------------------------------------ car + odometer
            SandCard(
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
                          make: car?.make ?? 'Toyota',
                          model: car?.model ?? 'Camry',
                          height: 52,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(carTitle,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              s.t('سيارتك الأساسية', 'Your primary car'),
                              style: TextStyle(
                                  fontSize: 10.5, color: ak.inkSub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 13),
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
                                s.t('الممشى الحالي — تدخله بنفسك',
                                    'Current mileage — entered by you'),
                                style: TextStyle(
                                    fontSize: 10, color: ak.inkSub),
                              ),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                    text: m.currentOdometerKm != null
                                        ? _fmt.format(m.currentOdometerKm)
                                        : '—',
                                    style: AppTheme.numeric(
                                        size: 21, color: ak.ink),
                                  ),
                                  TextSpan(
                                    text: ' ${s.km}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: ak.inkSub),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _updatedLabel(s, m.odometerUpdatedAt),
                                style: TextStyle(
                                    fontSize: 9.5, color: ak.inkFaint),
                              ),
                            ],
                          ),
                        ),
                        InkPill(
                          label: s.t('حدّث الممشى', 'Update mileage'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          onTap: () => _showOdometerSheet(context, ref, s),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ------------------------------------------------ source notice
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                    child: Icon(LucideIcons.info,
                        size: 14, color: ak.amberText),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      s.t(
                        'هذه التذكيرات تُحسب من الممشى الذي تدخله وسجل خدماتك في التطبيق — التطبيق لا يقرأ بيانات من السيارة نفسها.',
                        'These reminders are computed from the mileage you enter and your in-app service history — the app does not read data from the car itself.',
                      ),
                      style: TextStyle(
                          fontSize: 10.5, color: ak.amberDeep, height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(s.t('البنود القادمة', 'Upcoming items'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final d in due) ...[
              _DueCard(item: d),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            // ------------------------------------------------ history
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(s.t('سجل الخدمات', 'Service history'),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                ),
                Text(
                  s.t('من حجوزاتك في التطبيق', 'From your in-app bookings'),
                  style: TextStyle(fontSize: 10.5, color: ak.inkSub),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SandCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, r) in m.records.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: i == m.records.length - 1
                            ? null
                            : Border(
                                bottom: BorderSide(color: ak.divider)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: ak.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              switch (r.type) {
                                MaintenanceType.tyres =>
                                  LucideIcons.lifeBuoy,
                                MaintenanceType.coolant =>
                                  LucideIcons.thermometer,
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
                                Text(r.title.of(s),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 1),
                                Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: '${r.workshop} · '),
                                    TextSpan(
                                      text: _fmt.format(r.odometerKm),
                                      style: AppTheme.numeric(
                                          size: 9.5,
                                          weight: FontWeight.w500,
                                          color: ak.inkSub),
                                    ),
                                    TextSpan(text: ' ${s.km}'),
                                  ]),
                                  style: TextStyle(
                                      fontSize: 9.5, color: ak.inkSub),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _monthLabel(s, r.date),
                            style:
                                TextStyle(fontSize: 10, color: ak.inkSub),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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

  static String _monthLabel(S s, DateTime d) {
    const ar = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return s.isAr
        ? '${ar[d.month - 1]} ${d.year}'
        : '${en[d.month - 1]} ${d.year}';
  }

  void _showOdometerSheet(BuildContext context, WidgetRef ref, S s) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ak = AkColors.of(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('حدّث الممشى', 'Update mileage'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                s.t('أدخل قراءة العداد الحالية بالكيلومترات.',
                    'Enter the current odometer reading in kilometres.'),
                style: TextStyle(fontSize: 12, color: ak.inkSub),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: AppTheme.numeric(size: 18, color: ak.ink),
                decoration: InputDecoration(
                  hintText: s.t('مثال: 128450', 'e.g. 128450'),
                  suffixText: s.km,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final km = int.tryParse(controller.text.trim());
                  if (km == null || km <= 0) return;
                  ref
                      .read(maintenanceProvider.notifier)
                      .updateOdometer(km);
                  Navigator.of(sheetContext).pop();
                },
                child: Text(s.t('حفظ', 'Save')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DueCard extends ConsumerWidget {
  const _DueCard({required this.item});

  final DueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    final (pillLabel, pillBg, pillFg) = switch (item.status) {
      DueStatus.due => (s.t('حان الآن', 'Due now'), ak.dangerSoft, ak.dangerText),
      DueStatus.near => (s.t('قريب', 'Due soon'), ak.amberBgSoft, ak.amberText),
      DueStatus.good =>
        (s.t('بوضع جيد', 'In good shape'), ak.successSoft, ak.success),
      DueStatus.noRecord =>
        (s.t('لا يوجد سجل', 'No record'), ak.surfaceDim, ak.inkSub),
    };
    final barColor = switch (item.status) {
      DueStatus.due => ak.danger,
      DueStatus.near => ak.amber,
      _ => ak.success,
    };

    return SandCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.type.title.of(s),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              SandStatusPill(pillLabel,
                  background: pillBg, foreground: pillFg),
            ],
          ),
          if (item.progress != null) ...[
            const SizedBox(height: 9),
            SandProgressBar(value: item.progress!, color: barColor),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _lastLabel(s),
                    style: TextStyle(fontSize: 10, color: ak.inkSub),
                  ),
                ),
                _remainingLabel(s, ak),
              ],
            ),
            // "Near" items get a booking shortcut (oil in the mockup).
            if (item.status == DueStatus.near ||
                item.status == DueStatus.due) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkPill(
                  label: item.type == MaintenanceType.oil
                      ? s.t('احجز تغيير زيت — من 8 ر.ع',
                          'Book an oil change — from OMR 8')
                      : s.t('احجز فحصاً', 'Book a check'),
                  fontSize: 10.5,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  onTap: () => context.go('/services'),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 7),
            Text(
              s.t(
                'أضف آخر مرة تمت فيها الخدمة — أو احجز فحصاً وسيُسجل تلقائياً.',
                'Add the last time this was serviced — or book a check and it will be logged automatically.',
              ),
              style:
                  TextStyle(fontSize: 10.5, color: ak.inkSub, height: 1.7),
            ),
            const SizedBox(height: 9),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: InkPill(
                label: s.t('أضف سجلاً يدوياً', 'Add a manual record'),
                outlined: true,
                fontSize: 10.5,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                onTap: () => _addManualRecord(context, ref, s),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _lastLabel(S s) {
    final r = item.lastRecord;
    if (r == null) return '';
    if (item.type.kmBased) {
      return s.t(
        'آخر تغيير: ${_fmt.format(r.odometerKm)} كم (في ${r.workshop})',
        'Last change: ${_fmt.format(r.odometerKm)} km (at ${r.workshop})',
      );
    }
    return s.t(
      'آخر فحص: ${MaintenanceScreen._monthLabel(s, r.date)}',
      'Last check: ${MaintenanceScreen._monthLabel(s, r.date)}',
    );
  }

  Widget _remainingLabel(S s, AkColors ak) {
    if (item.remainingKm != null) {
      final overdue = item.remainingKm! <= 0;
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: overdue ? s.t('متأخر ', 'overdue ') : s.t('باقي ', '')),
          TextSpan(
            text: _fmt.format(item.remainingKm!.abs()),
            style: AppTheme.numeric(
                size: 10,
                color: overdue ? ak.dangerText : ak.amberText),
          ),
          TextSpan(text: s.t(' كم', ' km left')),
        ]),
        style: TextStyle(fontSize: 10, color: ak.inkSub),
      );
    }
    final months = item.remainingMonths;
    if (months == null) return const SizedBox.shrink();
    return Text(
      months <= 0
          ? s.t('الموصى به: الآن', 'Recommended: now')
          : s.t('الموصى به: بعد $months أشهر', 'Recommended: in $months months'),
      style: TextStyle(fontSize: 10, color: ak.inkSub),
    );
  }

  void _addManualRecord(BuildContext context, WidgetRef ref, S s) {
    final m = ref.read(maintenanceProvider);
    ref.read(maintenanceProvider.notifier).addRecord(
          ServiceRecord(
            id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
            title: L(
              '${item.type.title.ar} (سجل يدوي)',
              '${item.type.title.en} (manual record)',
            ),
            workshop: s.t('سجل يدوي', 'Manual entry'),
            odometerKm: m.currentOdometerKm ?? 0,
            date: DateTime.now(),
            type: item.type,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.t('أُضيف السجل — سيبدأ العدّاد من اليوم.',
            'Record added — the countdown starts today.')),
      ),
    );
  }
}
