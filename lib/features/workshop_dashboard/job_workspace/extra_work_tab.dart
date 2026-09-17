import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../di/providers.dart';
import '../../../state/job_workspace_state.dart';
import '../../services/job_media_widgets.dart';
import '../../services/job_report_widgets.dart';
import 'job_workspace_common.dart';

/// Opens the extra-work form and creates the request. Returns what was
/// created, or null when the workshop backed out or the call failed.
Future<ExtraWorkRequest?> showExtraWorkSheet(
  BuildContext context, {
  required ServiceRequest request,
  InspectionItem? fromItem,
}) => showModalBottomSheet<ExtraWorkRequest>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ExtraWorkSheet(request: request, fromItem: fromItem),
);

/// Work found mid-job that the customer did not book. It is sent to the
/// customer, who approves or declines in the app; approved work is added to
/// the booking total and the founder confirms the extra funds are held.
class ExtraWorkTab extends ConsumerWidget {
  const ExtraWorkTab({super.key, required this.request, required this.onChanged});

  final ServiceRequest request;
  final JobRequestChanged onChanged;

  Future<void> _create(BuildContext context) async {
    final created = await showExtraWorkSheet(context, request: request);
    if (created == null) return;
    onChanged(request.copyWith(extraWork: [created, ...request.extraWork]));
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    ExtraWorkRequest extra,
  ) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('سحب الطلب؟', 'Withdraw this request?')),
        content: Text(
          s.t(
            'لن يتمكن العميل من الموافقة عليه بعد السحب.',
            'The customer will no longer be able to approve it.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('تراجع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('سحب', 'Withdraw')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runJobAction(context, () async {
      final withdrawn = await ref
          .read(jobWorkspaceServiceProvider)
          .withdrawExtraWork(request.id, extra.id);
      onChanged(
        request.copyWith(
          extraWork: [
            for (final e in request.extraWork) e.id == withdrawn.id ? withdrawn : e,
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final editable = JobStages.work.contains(request.escrow);

    return ListView(
      padding: jobTabPadding,
      children: [
        if (editable)
          FilledButton.icon(
            onPressed: () => _create(context),
            icon: const Icon(LucideIcons.plus, size: 17),
            label: Text(s.t('اطلب عملاً إضافياً', 'Request extra work')),
          )
        else
          StageNotice(
            s.t(
              'يُطلب العمل الإضافي بعد قبول الطلب وأثناء العمل.',
              'Extra work can be requested once the job is accepted and while it is in progress.',
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (request.extraWork.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.wrench,
            message: s.t(
              'لم يُطلب أي عمل إضافي على هذا الحجز.',
              'No extra work has been requested on this job.',
            ),
          )
        else
          for (final (i, extra) in request.extraWork.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            ExtraWorkSummaryCard(
              extra: extra,
              footer: extra.isPending && editable
                  ? Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => _withdraw(context, ref, extra),
                        child: Text(s.t('سحب الطلب', 'Withdraw')),
                      ),
                    )
                  : null,
            ),
          ],
      ],
    );
  }
}

class _ExtraWorkSheet extends ConsumerStatefulWidget {
  const _ExtraWorkSheet({required this.request, this.fromItem});

  final ServiceRequest request;
  final InspectionItem? fromItem;

  @override
  ConsumerState<_ExtraWorkSheet> createState() => _ExtraWorkSheetState();
}

class _ExtraWorkSheetState extends ConsumerState<_ExtraWorkSheet> {
  static const _maxPhotos = 6;

  late final TextEditingController _description;
  final _parts = TextEditingController();
  final _labour = TextEditingController();
  late List<MediaAttachment> _photos;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.fromItem;
    _description = TextEditingController(
      text: item == null
          ? ''
          : [item.name, if (item.note.isNotEmpty) item.note].join(' — '),
    );
    _photos = item?.photos ?? const [];
    for (final c in [_parts, _labour]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _parts.dispose();
    _labour.dispose();
    super.dispose();
  }

  double _value(TextEditingController c) =>
      c.text.trim().isEmpty ? 0 : (parseJobNumber(c.text) ?? -1);

  Future<void> _submit() async {
    final s = S.of(context);
    final parts = _value(_parts);
    final labour = _value(_labour);
    final description = _description.text.trim();
    final problem = description.isEmpty
        ? s.t('صف العمل المطلوب.', 'Describe the work.')
        : parts < 0 || labour < 0
        ? s.t('الأسعار يجب أن تكون أرقاماً.', 'Prices must be numbers.')
        : parts + labour <= 0
        ? s.t('أدخل سعر القطع أو العمالة.', 'Enter a parts or labour price.')
        : null;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    setState(() => _saving = true);
    ExtraWorkRequest? created;
    await runJobAction(context, () async {
      created = await ref
          .read(jobWorkspaceServiceProvider)
          .createExtraWork(
            widget.request.id,
            description: description,
            partsPrice: parts,
            laborPrice: labour,
            inspectionItemId: widget.fromItem?.id,
            photos: _photos,
          );
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (created != null) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final parts = _value(_parts);
    final labour = _value(_labour);
    final total = (parts < 0 ? 0.0 : parts) + (labour < 0 ? 0.0 : labour);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.t('طلب عمل إضافي', 'Request extra work'), style: context.text.cardTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                s.t(
                  'يوافق العميل عليه في التطبيق قبل أن تبدأ، ويُضاف المبلغ إلى الحجز ويُحفظ كضمان.',
                  'The customer approves it in the app before you start; the amount is added to the booking and held in escrow.',
                ),
                style: context.text.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: s.t('ما العمل المطلوب؟', 'What needs doing?'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _parts,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: s.t('القطع (ر.ع)', 'Parts (OMR)')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _labour,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: s.t('العمالة (ر.ع)', 'Labour (OMR)')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                s.t('صور (حتى $_maxPhotos)', 'Photos (up to $_maxPhotos)'),
                style: TextStyle(fontSize: 12, color: ak.inkSub),
              ),
              const SizedBox(height: AppSpacing.sm),
              JobPhotoPicker(
                photos: _photos,
                max: _maxPhotos,
                onChanged: (photos) => setState(() => _photos = photos),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: Text(s.t('الإجمالي', 'Total'), style: context.text.bodyPrimary)),
                  RialAmount(total, style: context.text.price),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: BusyIcon(icon: LucideIcons.send, busy: _saving),
                label: Text(s.t('أرسل للعميل', 'Send to customer')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
