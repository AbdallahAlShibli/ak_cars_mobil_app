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
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight),
                  onPressed: () => setState(
                    () => _date = _date.subtract(const Duration(days: 1)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: () => setState(
                    () => _date = _date.add(const Duration(days: 1)),
                  ),
                ),
              ],
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

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
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
                      label: Text(day),
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
