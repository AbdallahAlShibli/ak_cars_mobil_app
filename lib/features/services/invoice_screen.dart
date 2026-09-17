import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/app_exception.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/job_workspace_state.dart';
import 'job_media_widgets.dart';

/// A booking's invoice, for whoever may read it — the customer, the workshop
/// or the founder; the server decides. It is a frozen snapshot, so the screen
/// only shows what was issued and never recomputes a figure.
class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final invoice = ref.watch(invoiceProvider(requestId));

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('الفاتورة', 'Invoice'))),
      body: SafeArea(
        child: invoice.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              children: [
                Skeleton(height: 140),
                SizedBox(height: AppSpacing.md),
                Skeleton(height: 260),
              ],
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: EmptyState(
                icon: LucideIcons.receipt,
                message: error is NotFoundException
                    ? s.t(
                        'لم تصدر فاتورة لهذا الحجز بعد.',
                        'No invoice has been issued for this booking yet.',
                      )
                    : jobWorkspaceErrorText(s, error),
              ),
            ),
          ),
          data: (data) => _InvoiceBody(invoice: data),
        ),
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final vat = invoice.sellerVatNumber;
    final cr = invoice.sellerCrNumber;
    // The API sends the rate as a fraction (0.05); tolerate a percentage too.
    final vatPercent = invoice.vatRate <= 1
        ? invoice.vatRate * 100
        : invoice.vatRate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.md,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                invoice.isTaxInvoice
                    ? s.t('فاتورة ضريبية', 'Tax invoice')
                    : s.t('إيصال مبسّط', 'Simplified receipt'),
                style: context.text.cardTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(invoice.number, style: context.text.labelStrong),
              Text(
                formatJobDate(invoice.issuedAt),
                style: context.text.bodySecondary,
              ),
              const Divider(height: AppSpacing.lg * 2),
              _Party(
                label: s.t('من', 'From'),
                name: invoice.sellerName.of(s),
                details: [
                  if (vat != null && vat.isNotEmpty)
                    s.t('الرقم الضريبي $vat', 'VAT no. $vat'),
                  if (cr != null && cr.isNotEmpty)
                    s.t('السجل التجاري $cr', 'CR no. $cr'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Party(
                label: s.t('إلى', 'Bill to'),
                name: invoice.buyerName,
                details: [
                  if (invoice.plate.isNotEmpty)
                    s.t('اللوحة ${invoice.plate}', 'Plate ${invoice.plate}'),
                ],
              ),
              const Divider(height: AppSpacing.lg * 2),
              for (final line in invoice.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          line.description.of(s),
                          style: context.text.bodyPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      RialAmount(line.amount),
                    ],
                  ),
                ),
              const Divider(height: AppSpacing.lg * 2),
              if (invoice.isTaxInvoice) ...[
                _TotalRow(
                  label: s.t('المجموع قبل الضريبة', 'Subtotal (excl. VAT)'),
                  amount: invoice.subtotal,
                ),
                _TotalRow(
                  label: s.t(
                    'ضريبة القيمة المضافة ${vatPercent.round()}٪',
                    'VAT ${vatPercent.round()}%',
                  ),
                  amount: invoice.vatAmount,
                ),
              ],
              _TotalRow(
                label: s.t('الإجمالي', 'Total'),
                amount: invoice.total,
                strong: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                invoice.isTaxInvoice
                    ? s.t('الأسعار شاملة ضريبة القيمة المضافة.',
                        'Prices include VAT.')
                    : s.t(
                        'الورشة غير مسجلة في ضريبة القيمة المضافة؛ لا تُحتسب ضريبة.',
                        'The workshop is not VAT-registered; no VAT is charged.',
                      ),
                style: context.text.bodySecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Party extends StatelessWidget {
  const _Party({required this.label, required this.name, required this.details});

  final String label;
  final String name;
  final List<String> details;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.text.bodySecondary),
      const SizedBox(height: 2),
      Text(name, style: context.text.bodyPrimary.copyWith(fontWeight: FontWeight.w700)),
      for (final line in details) Text(line, style: context.text.bodySecondary),
    ],
  );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.strong = false,
  });

  final String label;
  final double amount;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong ? context.text.cardTitle : context.text.bodyPrimary,
          ),
        ),
        RialAmount(
          amount,
          style: strong ? context.text.price : context.text.bodyPrimary,
        ),
      ],
    ),
  );
}
