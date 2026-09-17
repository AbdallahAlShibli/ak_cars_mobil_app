import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../di/providers.dart';
import '../../../state/job_workspace_state.dart';
import '../../services/job_media_widgets.dart';
import 'job_workspace_common.dart';

/// Issuing the booking's invoice. Once issued its number and amounts are
/// frozen, so the button asks first; a second issue returns the same invoice.
class InvoiceTab extends ConsumerStatefulWidget {
  const InvoiceTab({super.key, required this.request, required this.onChanged});

  final ServiceRequest request;
  final JobRequestChanged onChanged;

  @override
  ConsumerState<InvoiceTab> createState() => _InvoiceTabState();
}

class _InvoiceTabState extends ConsumerState<InvoiceTab> {
  bool _busy = false;

  Future<void> _issue() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('إصدار الفاتورة؟', 'Issue the invoice?')),
        content: Text(
          s.t(
            'لا يمكن تعديل رقمها أو مبالغها بعد الإصدار.',
            'Its number and amounts cannot be changed afterwards.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('تراجع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('إصدار', 'Issue')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await runJobAction(context, () async {
      final invoice = await ref
          .read(jobWorkspaceServiceProvider)
          .issueInvoice(widget.request.id);
      widget.onChanged(widget.request.copyWith(invoiceNumber: invoice.number));
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.push('/invoice/${widget.request.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final number = widget.request.invoiceNumber;
    final allowed = JobStages.invoice.contains(widget.request.escrow);

    return ListView(
      padding: jobTabPadding,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(LucideIcons.receipt),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          number ?? s.t('لا فاتورة بعد', 'No invoice yet'),
                          style: context.text.cardTitle,
                        ),
                        const SizedBox(height: AppSpacing.xs / 2),
                        Text(
                          number == null
                              ? s.t(
                                  'تصدر بعد رفع إثبات الإنجاز، ورقمها دائم.',
                                  'Issued once proof of work is in. The number is permanent.',
                                )
                              : s.t(
                                  'صدرت — يستطيع العميل فتحها من حجزه.',
                                  'Issued — the customer can open it from their booking.',
                                ),
                          style: context.text.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (number != null)
                FilledButton.icon(
                  onPressed: () => context.push('/invoice/${widget.request.id}'),
                  icon: const Icon(LucideIcons.fileText, size: 17),
                  label: Text(s.t('عرض الفاتورة', 'View invoice')),
                )
              else if (allowed)
                FilledButton.icon(
                  onPressed: _busy ? null : _issue,
                  icon: BusyIcon(icon: LucideIcons.receipt, busy: _busy),
                  label: Text(s.t('إصدار الفاتورة', 'Issue invoice')),
                )
              else
                StageNotice(
                  s.t(
                    'تتاح عندما يصل الحجز إلى مرحلة موافقة العميل.',
                    'Available once the booking reaches customer approval.',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          s.t(
            'الأسعار شاملة الضريبة. إن كان في ملف ورشتك رقم ضريبي تصدر فاتورة ضريبية بنسبة 5٪، وإلا فإيصال مبسّط.',
            'Prices are VAT-inclusive. With a VAT number on your workshop profile the invoice is a tax invoice showing 5% VAT; otherwise it is a simplified receipt.',
          ),
          style: context.text.bodySecondary,
        ),
      ],
    );
  }
}
