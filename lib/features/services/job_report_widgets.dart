import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'job_media_widgets.dart';

/// What the workshop recorded while the car was with it, as the customer
/// sees it on the booking: extra work to decide on first, then the check-in,
/// the inspection report, answered extra work and the invoice.
///
/// Renders nothing for a booking with none of these — which is every booking
/// served by an API from before the job workspace.
class JobReportSection extends StatelessWidget {
  const JobReportSection({super.key, required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pending = request.pendingExtraWork;
    final answered = [
      for (final e in request.extraWork)
        if (!e.isPending) e,
    ];
    final checkIn = request.checkIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final extra in pending) ...[
          ExtraWorkApprovalCard(request: request, extra: extra),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
        if (checkIn != null) ...[
          SectionHeader(s.t('استلام السيارة', 'Vehicle check-in')),
          const SizedBox(height: AppSpacing.headingGap),
          CheckInReportCard(checkIn: checkIn),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
        if (request.inspection.isNotEmpty) ...[
          SectionHeader(s.t('تقرير الفحص', 'Inspection report')),
          const SizedBox(height: AppSpacing.headingGap),
          InspectionReportCard(items: request.inspection),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
        if (answered.isNotEmpty) ...[
          SectionHeader(s.t('أعمال إضافية', 'Extra work')),
          const SizedBox(height: AppSpacing.headingGap),
          for (final (i, extra) in answered.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            ExtraWorkSummaryCard(extra: extra),
          ],
          const SizedBox(height: AppSpacing.sectionGap),
        ],
        if (request.invoiceNumber != null) ...[
          OutlinedButton.icon(
            onPressed: () => context.push('/invoice/${request.id}'),
            icon: const Icon(LucideIcons.receipt, size: 17),
            label: Text(s.t('عرض الفاتورة', 'View invoice')),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ],
    );
  }
}

/// One extra-work request: status, what it is, what it costs, the evidence.
class ExtraWorkSummaryCard extends StatelessWidget {
  const ExtraWorkSummaryCard({super.key, required this.extra, this.footer});

  final ExtraWorkRequest extra;
  final Widget? footer;

  /// Amber while someone still has to act on it — the customer (pending) or
  /// the founder (approved, awaiting funds).
  static UrgencyLevel levelFor(ExtraWorkStatus status) => switch (status) {
    ExtraWorkStatus.pending || ExtraWorkStatus.approved => UrgencyLevel.upcoming,
    _ => UrgencyLevel.normal,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final level = levelFor(extra.status);
    final style = context.text.bodySecondary;
    final note = extra.customerNote ?? '';

    return UrgencyCard(
      level: level,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UrgencyLabel(extra.status.label.of(s), level: level),
          const SizedBox(height: AppSpacing.sm),
          Text(extra.description, style: context.text.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          RialAmount(extra.amount, style: context.text.price),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: s.t('قطع ', 'Parts ')),
                rialAmountSpan(amount: extra.partsPrice, style: style),
                TextSpan(text: s.t(' + عمالة ', ' + labour ')),
                rialAmountSpan(amount: extra.laborPrice, style: style),
              ],
            ),
          ),
          if (extra.photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            JobPhotoThumbs(photos: extra.photos),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.t('ملاحظة العميل: $note', 'Customer note: $note'),
              style: style,
            ),
          ],
          ?footer,
        ],
      ),
    );
  }
}

/// Pending extra work with the customer's two answers.
class ExtraWorkApprovalCard extends ConsumerStatefulWidget {
  const ExtraWorkApprovalCard({
    super.key,
    required this.request,
    required this.extra,
  });

  final ServiceRequest request;
  final ExtraWorkRequest extra;

  @override
  ConsumerState<ExtraWorkApprovalCard> createState() =>
      _ExtraWorkApprovalCardState();
}

class _ExtraWorkApprovalCardState extends ConsumerState<ExtraWorkApprovalCard> {
  bool _busy = false;

  Future<void> _respond(bool approve) async {
    final s = S.of(context);
    final extra = widget.extra;
    String? note;
    if (approve) {
      final amount = extra.amount.toStringAsFixed(2);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.t('الموافقة على العمل الإضافي؟', 'Approve the extra work?')),
          content: Text(
            s.t(
              'سيُضاف $amount ر.ع إلى حجزك ويُحفظ كضمان مثل المبلغ الأصلي.',
              'OMR $amount is added to your booking and held in escrow like the original amount.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.t('تراجع', 'Back')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.t('موافقة', 'Approve')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      note = await showDialog<String>(
        context: context,
        builder: (_) => JobTextDialog(
          title: s.t('رفض العمل الإضافي؟', 'Decline the extra work?'),
          label: s.t('السبب (اختياري)', 'Reason (optional)'),
          confirmLabel: s.t('رفض', 'Decline'),
        ),
      );
      if (note == null) return;
    }
    if (!mounted) return;

    setState(() => _busy = true);
    await runJobAction(context, () async {
      await ref
          .read(jobWorkspaceServiceProvider)
          .respondToExtraWork(
            widget.request.id,
            extra.id,
            approve: approve,
            note: (note == null || note.isEmpty) ? null : note,
          );
      await ref.read(requestsProvider.notifier).load();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ExtraWorkSummaryCard(
      extra: widget.extra,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text(
            s.t(
              'وجدت الورشة عملاً إضافياً. لن يبدأ قبل موافقتك.',
              'The workshop found more work. It will not start without your approval.',
            ),
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(false),
                  child: Text(s.t('رفض', 'Decline')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _respond(true),
                  child: Text(s.t('موافقة', 'Approve')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CheckInReportCard extends StatelessWidget {
  const CheckInReportCard({super.key, required this.checkIn});

  final VehicleCheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final odometer = checkIn.odometerKm;
    final fuel = checkIn.fuelLevel;
    final facts = <(IconData, String)>[
      if (odometer != null)
        (LucideIcons.gauge, s.t('$odometer كم', '$odometer km')),
      if (fuel != null)
        (
          LucideIcons.fuel,
          s.t('الوقود: ${fuel.label.of(s)}', 'Fuel: ${fuel.label.of(s)}'),
        ),
      (LucideIcons.calendar, formatJobDate(checkIn.recordedAt)),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (icon, label) in facts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: ak.inkSub),
                    const SizedBox(width: 4),
                    Text(label, style: context.text.bodyPrimary),
                  ],
                ),
            ],
          ),
          if (checkIn.exteriorNotes.isNotEmpty)
            ..._labelled(
              context,
              s.t('حالة الهيكل', 'Exterior'),
              checkIn.exteriorNotes,
            ),
          if (checkIn.belongings.isNotEmpty)
            ..._labelled(
              context,
              s.t('المقتنيات في السيارة', 'Belongings in the car'),
              checkIn.belongings,
            ),
          if (checkIn.photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            JobPhotoThumbs(photos: checkIn.photos),
          ],
        ],
      ),
    );
  }

  static List<Widget> _labelled(
    BuildContext context,
    String label,
    String value,
  ) => [
    const SizedBox(height: AppSpacing.md),
    Text(label, style: context.text.bodySecondary),
    const SizedBox(height: 2),
    Text(value, style: context.text.bodyPrimary),
  ];
}

class InspectionReportCard extends StatelessWidget {
  const InspectionReportCard({super.key, required this.items});

  final List<InspectionItem> items;

  static Color toneFor(BuildContext context, InspectionStatus status) =>
      switch (status) {
        InspectionStatus.good => AkColors.of(context).success,
        InspectionStatus.attention =>
          UrgencyStyle.of(context, UrgencyLevel.upcoming).text,
        InspectionStatus.urgent => AkColors.of(context).danger,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final counts = {
      for (final status in InspectionStatus.values)
        status: items.where((i) => i.status == status).length,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final status in InspectionStatus.values)
                if ((counts[status] ?? 0) > 0)
                  _CountPill(
                    color: toneFor(context, status),
                    label: '${status.label.of(s)} · ${counts[status]}',
                  ),
            ],
          ),
          for (final item in items) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: toneFor(context, item.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: context.text.bodyPrimary.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.status.label.of(s),
                        style: context.text.bodySecondary.copyWith(
                          color: toneFor(context, item.status),
                        ),
                      ),
                      if (item.note.isNotEmpty)
                        Text(item.note, style: context.text.bodySecondary),
                      if (item.photos.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        JobPhotoThumbs(photos: item.photos, size: 56),
                      ],
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
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
