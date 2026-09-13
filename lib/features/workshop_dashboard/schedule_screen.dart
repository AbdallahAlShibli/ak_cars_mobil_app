import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../state/provider_dashboard_state.dart';
import '../operations/escrow_action_bar.dart';

/// Slots, booked slots and assigned jobs for one day, plus the working-hours
/// config (slot template, capacity, closed days) those slots are generated
/// from — see `provider_dashboard_state.dart`'s `WorkshopScheduleNotifier`
/// (day view) and `WorkshopScheduleConfigNotifier` (config).
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final day = DateTime(_date.year, _date.month, _date.day);
    final schedule = ref.watch(workshopScheduleProvider(day));

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(
        title: Text(s.t('الجدول', 'Schedule')),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings2),
            tooltip: s.t('إعدادات ساعات العمل', 'Working-hours settings'),
            onPressed: () => _showConfigSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            _DayPicker(
              day: day,
              onChanged: (picked) => setState(() => _date = picked),
            ),
            const SizedBox(height: AppSpacing.md),
            schedule.when(
              loading: () => const ListSkeleton(),
              error: (error, _) => EmptyState(
                icon: LucideIcons.circleAlert,
                message: s.t(
                  'تعذّر تحميل الجدول.',
                  'Couldn\'t load the schedule.',
                ),
              ),
              data: (data) {
                if (data.slots.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.calendarOff,
                    title: s.t('يوم مغلق', 'Closed today'),
                    message: s.t(
                      'لا مواعيد متاحة في هذا اليوم.',
                      'No slots available on this day.',
                    ),
                    compact: true,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final slot in data.slots)
                          Chip(
                            label: Text(slot),
                            backgroundColor: data.isAvailable(slot)
                                ? ak.surfaceDim
                                : ak.dangerSoft,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SectionHeader(
                      s.t('المهام المعيّنة اليوم', 'Assigned today'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (data.assignedJobs.isEmpty)
                      EmptyState(
                        icon: LucideIcons.clipboardList,
                        message: s.t('لا مهام معيّنة.', 'Nothing assigned.'),
                        compact: true,
                      )
                    else
                      for (final job in data.assignedJobs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            child: OperatorRequestHeader(request: job),
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ScheduleConfigSheet(),
    );
  }
}

class _ScheduleConfigSheet extends ConsumerStatefulWidget {
  const _ScheduleConfigSheet();

  @override
  ConsumerState<_ScheduleConfigSheet> createState() =>
      _ScheduleConfigSheetState();
}

class _ScheduleConfigSheetState extends ConsumerState<_ScheduleConfigSheet> {
  final _slotTemplate = TextEditingController();
  final _capacity = TextEditingController(text: '1');
  final _closedDays = <String>{};
  bool _initialized = false;
  bool _saving = false;

  /// Wire values are English `DateTime.weekday` names — `UpdateScheduleCommand`
  /// parses them straight back into a `DayOfWeek`, so the *key* must stay
  /// English no matter which language the chip is rendered in.
  static const _weekdays = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  static String _weekdayLabel(String key, S s) => switch (key) {
    'Saturday' => s.t('السبت', 'Saturday'),
    'Sunday' => s.t('الأحد', 'Sunday'),
    'Monday' => s.t('الاثنين', 'Monday'),
    'Tuesday' => s.t('الثلاثاء', 'Tuesday'),
    'Wednesday' => s.t('الأربعاء', 'Wednesday'),
    'Thursday' => s.t('الخميس', 'Thursday'),
    'Friday' => s.t('الجمعة', 'Friday'),
    _ => key,
  };

  @override
  void dispose() {
    _slotTemplate.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final config = ref.watch(workshopScheduleConfigProvider);

    return config.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(s.t('تعذّر التحميل.', 'Couldn\'t load.')),
      ),
      data: (data) {
        if (!_initialized) {
          _slotTemplate.text = data.slotTemplate.join(', ');
          _capacity.text = data.capacityPerSlot.toString();
          _closedDays.addAll(data.closedDays);
          _initialized = true;
        }
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            left: AppSpacing.screenMargin,
            right: AppSpacing.screenMargin,
            top: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('ساعات العمل', 'Working hours'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _slotTemplate,
                decoration: InputDecoration(
                  labelText: s.t(
                    'المواعيد (مفصولة بفاصلة)',
                    'Slots (comma-separated)',
                  ),
                  hintText: '09:00, 11:00, 13:00',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s.t('السعة لكل موعد', 'Capacity per slot'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                s.t('أيام الإغلاق', 'Closed days'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final day in _weekdays)
                    FilterChip(
                      label: Text(_weekdayLabel(day, s)),
                      selected: _closedDays.contains(day),
                      onSelected: (v) => setState(
                        () =>
                            v ? _closedDays.add(day) : _closedDays.remove(day),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await ref
                              .read(workshopScheduleConfigProvider.notifier)
                              .save(
                                hours: data.hours,
                                slotTemplate: _slotTemplate.text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList(),
                                capacityPerSlot:
                                    int.tryParse(_capacity.text.trim()) ?? 1,
                                closedDays: _closedDays.toList(),
                              );
                          if (context.mounted) Navigator.of(context).pop();
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.t('حفظ', 'Save')),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Day stepper for the schedule view: previous/next arrows that point the way
/// the language reads, a tappable date that opens a real calendar, and a
/// "today" shortcut that only appears when you have wandered off it.
///
/// Replaced a pair of fixed `chevronRight`/`chevronLeft` buttons whose arrows
/// pointed backwards in English, and a plain text date with no way to reach a
/// day more than a few taps away.
class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.day, required this.onChanged});

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  static String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    Future<void> pick() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: day,
        // A schedule is worth looking a year back (what did we do) and a year
        // forward (what is already booked); anything wider is a scroll, not a
        // feature.
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 1, 12, 31),
      );
      if (picked != null) {
        onChanged(DateTime(picked.year, picked.month, picked.day));
      }
    }

    return Row(
      children: [
        IconButton(
          tooltip: s.t('اليوم السابق', 'Previous day'),
          icon: Icon(rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft),
          onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: pick,
            child: Column(
              children: [
                Text(
                  _format(day),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isToday
                      ? s.t('اليوم', 'Today')
                      : s.t('اضغط لاختيار يوم', 'Tap to pick a day'),
                  style: TextStyle(fontSize: 10.5, color: ak.inkSub),
                ),
              ],
            ),
          ),
        ),
        if (!isToday)
          TextButton(
            onPressed: () => onChanged(DateTime(now.year, now.month, now.day)),
            child: Text(s.t('اليوم', 'Today')),
          ),
        IconButton(
          tooltip: s.t('اليوم التالي', 'Next day'),
          icon: Icon(rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight),
          onPressed: () => onChanged(day.add(const Duration(days: 1))),
        ),
      ],
    );
  }
}
