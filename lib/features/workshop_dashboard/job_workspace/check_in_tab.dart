import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../di/providers.dart';
import '../../../state/job_workspace_state.dart';
import '../../services/job_media_widgets.dart';
import 'job_workspace_common.dart';

/// The car's condition as the workshop takes it: mileage, fuel, bodywork,
/// what was left inside, and photos. One record per booking, saved over.
class CheckInTab extends ConsumerStatefulWidget {
  const CheckInTab({super.key, required this.request, required this.onChanged});

  final ServiceRequest request;
  final JobRequestChanged onChanged;

  @override
  ConsumerState<CheckInTab> createState() => _CheckInTabState();
}

class _CheckInTabState extends ConsumerState<CheckInTab>
    with AutomaticKeepAliveClientMixin {
  static const _maxPhotos = 6;

  late final TextEditingController _odometer;
  late final TextEditingController _exterior;
  late final TextEditingController _belongings;
  FuelLevel? _fuel;
  List<MediaAttachment> _photos = const [];
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final saved = widget.request.checkIn;
    _odometer = TextEditingController(text: saved?.odometerKm?.toString() ?? '');
    _exterior = TextEditingController(text: saved?.exteriorNotes ?? '');
    _belongings = TextEditingController(text: saved?.belongings ?? '');
    _fuel = saved?.fuelLevel;
    _photos = saved?.photos ?? const [];
  }

  @override
  void dispose() {
    _odometer.dispose();
    _exterior.dispose();
    _belongings.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = S.of(context);
    final typed = _odometer.text.trim();
    final odometer = typed.isEmpty ? null : int.tryParse(typed);
    if (typed.isNotEmpty && odometer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t('أدخل قراءة العداد كرقم صحيح.', 'Enter the mileage as a whole number.'),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await runJobAction(context, () async {
      final saved = await ref
          .read(jobWorkspaceServiceProvider)
          .saveCheckIn(
            widget.request.id,
            odometerKm: odometer,
            fuelLevel: _fuel,
            exteriorNotes: _exterior.text.trim(),
            belongings: _belongings.text.trim(),
            photos: _photos,
          );
      widget.onChanged(widget.request.copyWith(checkIn: saved));
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('حُفظ الاستلام', 'Check-in saved'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final ak = AkColors.of(context);
    final saved = widget.request.checkIn;
    final editable = JobStages.checkIn.contains(widget.request.escrow);

    return ListView(
      padding: jobTabPadding,
      children: [
        if (!editable) ...[
          StageNotice(
            saved == null
                ? s.t(
                    'يُسجَّل الاستلام بعد تأكيد حجز المبلغ وحتى أثناء العمل.',
                    'Check-in is recorded once the funds are held, up to while the work is in progress.',
                  )
                : s.t(
                    'الاستلام مقفل في هذه المرحلة — هذا ما سُجِّل.',
                    'Check-in is locked at this stage — this is what was recorded.',
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          s.t(
            'سجّل حالة السيارة عند استلامها — تحميك وتحمي العميل عند أي خلاف.',
            "Record the car's condition as you take it — it protects you and the customer if anything is disputed.",
          ),
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _odometer,
          enabled: editable,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: s.t('قراءة العداد (كم)', 'Odometer (km)'),
            prefixIcon: const Icon(LucideIcons.gauge, size: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          s.t('مستوى الوقود', 'Fuel level'),
          style: TextStyle(fontSize: 12, color: ak.inkSub),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final level in FuelLevel.values)
              ChoiceChip(
                label: Text(level.label.of(s)),
                selected: _fuel == level,
                onSelected: editable
                    ? (on) => setState(() => _fuel = on ? level : null)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _exterior,
          enabled: editable,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: s.t('حالة الهيكل', 'Exterior condition'),
            hintText: s.t('خدوش، صدمات، زجاج مكسور…', 'Scratches, dents, cracked glass…'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _belongings,
          enabled: editable,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: s.t('مقتنيات تُركت في السيارة', 'Belongings left in the car'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          s.t('الصور (حتى $_maxPhotos)', 'Photos (up to $_maxPhotos)'),
          style: TextStyle(fontSize: 12, color: ak.inkSub),
        ),
        const SizedBox(height: AppSpacing.sm),
        JobPhotoPicker(
          photos: _photos,
          max: _maxPhotos,
          enabled: editable,
          onChanged: (photos) => setState(() => _photos = photos),
        ),
        if (saved != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            s.t(
              'آخر حفظ: ${formatJobDate(saved.recordedAt)}',
              'Last saved: ${formatJobDate(saved.recordedAt)}',
            ),
            style: context.text.bodySecondary,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: editable && !_saving ? _save : null,
          icon: BusyIcon(icon: LucideIcons.save, busy: _saving),
          label: Text(s.t('حفظ الاستلام', 'Save check-in')),
        ),
      ],
    );
  }
}
