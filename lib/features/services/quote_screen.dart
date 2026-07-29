import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';

/// The customer's decision on a workshop's quote (spec §6).
///
/// The part and the fitting are shown as **two lines, never one**. That split
/// is the whole reason this transaction exists in the app rather than over the
/// phone: a lump sum is exactly the verbal deal it replaces, and a customer
/// who cannot see what the part costs cannot tell whether they are paying for
/// the part or for the labour.
class QuoteScreen extends ConsumerStatefulWidget {
  const QuoteScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends ConsumerState<QuoteScreen> {
  String? _slot;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final request = ref
        .watch(requestsProvider)
        .firstWhereOrNull((r) => r.id == widget.requestId);

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('عرض السعر', 'Quote'))),
        body: Center(child: Text(s.t('الطلب غير موجود', 'Request not found'))),
      );
    }

    final quote = request.quote;
    final open = request.escrow == EscrowState.quoted;
    final availability = ref
        .watch(serviceMarketplaceRepositoryProvider)
        .availabilityFor(request.offering.provider.id);
    final slots = [
      for (final slot in availability.slots)
        if (availability.isAvailable(slot)) slot,
    ];
    _slot ??= slots.firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('عرض السعر · #${request.id}', 'Quote · #${request.id}')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(child: StatusBadge(request.escrow.label(s))),
          ),
        ],
      ),
      body: SafeArea(
        child: quote == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    s.t('لم تقدّم الورشة سعراً بعد. سنُعلمك فور وصوله.',
                        'The workshop has not priced this yet. We will let you know the moment it does.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: ak.inkSub),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        const IconTile(Icons.storefront_rounded, radius: 999),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(request.offering.provider.name.of(s),
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                '${request.car.label} · ${request.plate}',
                                style: TextStyle(
                                    fontSize: 11.5, color: ak.inkSub),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SectionHeader(s.t('ما طلبته', 'What you asked for')),
                  const SizedBox(height: 9),
                  AppCard(
                    color: ak.surfaceDim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.partRequest?.description ?? '',
                            style: const TextStyle(
                                fontSize: 12.5, height: 1.6)),
                        if ((request.partRequest?.preferredBrand ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            s.t('طلبت: ${request.partRequest!.preferredBrand}',
                                'You asked for: ${request.partRequest!.preferredBrand}'),
                            style:
                                TextStyle(fontSize: 11.5, color: ak.inkSub),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  SectionHeader(s.t('عرض الورشة', "The workshop's quote")),
                  const SizedBox(height: 9),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(quote.partDescription,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        if ((quote.partBrand ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            s.t('الماركة: ${quote.partBrand}',
                                'Brand: ${quote.partBrand}'),
                            style:
                                TextStyle(fontSize: 11.5, color: ak.inkSub),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _PriceRow(
                          label: s.t('سعر القطعة', 'Part'),
                          amount: quote.partPrice,
                        ),
                        const SizedBox(height: 7),
                        _PriceRow(
                          label: s.t('أجرة التركيب', 'Fitting'),
                          amount: quote.laborPrice,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: ak.border),
                        ),
                        _PriceRow(
                          label: s.t('الإجمالي', 'Total'),
                          amount: quote.total,
                          emphasis: true,
                        ),
                      ],
                    ),
                  ),
                  if ((quote.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    AppCard(
                      child: Text(quote.note!,
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.6)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _PartWarrantyNote(days: quote.warrantyDays),

                  if (open) ...[
                    const SizedBox(height: 18),
                    SectionHeader(s.t('متى تناسبك؟', 'When suits you?')),
                    const SizedBox(height: 9),
                    if (slots.isEmpty)
                      AppCard(
                        child: Text(
                          s.t('لا مواعيد معروضة حالياً — تتفق مع الورشة على الموعد في المحادثة.',
                              'No slots published right now — agree a time with the workshop in the chat.'),
                          style:
                              TextStyle(fontSize: 12, color: ak.inkSub),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final slot in slots)
                            SelectChip(
                              label: slot,
                              selected: _slot == slot,
                              onTap: () => setState(() => _slot = slot),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    EscrowBanner(s.t(
                        'بقبولك، يُطلب منك تحويل ${quote.total.toStringAsFixed(2)} ر.ع ويُحجز كضمان — ولا يصل الورشة إلا بعد موافقتك على العمل.',
                        'Accepting asks you to transfer OMR ${quote.total.toStringAsFixed(2)}, held in escrow — the workshop is not paid until you approve the work.')),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _accept(request),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(s.t('أقبل العرض', 'Accept the quote')),
                    ),
                    const SizedBox(height: 9),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ak.dangerText,
                        side: BorderSide(color: ak.dangerSoft, width: 1.5),
                      ),
                      onPressed: _busy ? null : () => _decline(request),
                      child: Text(s.t('أرفض', 'Decline')),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    AppCard(
                      child: Text(
                        request.escrow.label(s),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _accept(ServiceRequest request) async {
    final s = S.of(context);
    setState(() => _busy = true);
    await ref.read(requestsProvider.notifier).fire(
          request.id,
          EscrowEvent.acceptQuote,
          actor: EscrowActor.customer,
          slot: _slot,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(s.t('قبلت العرض — بانتظار تأكيد حجز المبلغ.',
              'Quote accepted — waiting for the funds to be confirmed held.'))),
    );
    context.go('/track/${request.id}');
  }

  Future<void> _decline(ServiceRequest request) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('رفض العرض؟', 'Decline the quote?')),
        content: Text(s.t(
            'يُغلق الطلب. يمكنك إرسال طلب جديد لورشة أخرى في أي وقت.',
            'This closes the request. You can send a new one to another workshop any time.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('تراجع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('أرفض', 'Decline')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await ref.read(requestsProvider.notifier).fire(
          request.id,
          EscrowEvent.declineQuote,
          actor: EscrowActor.customer,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/bookings');
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    this.emphasis = false,
  });

  final String label;
  final double amount;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasis ? 13.5 : 12.5,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
              color: emphasis ? ak.ink : ak.inkSub,
            ),
          ),
        ),
        Text(
          '${s.omr} ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: emphasis ? 17 : 13.5,
            fontWeight: FontWeight.w800,
            color: emphasis ? ak.primary : ak.ink,
          ),
        ),
      ],
    );
  }
}

/// The part's own warranty — and, explicitly, how it differs from the escrow.
///
/// The two are separate guarantees with separate lifetimes: the escrow ends
/// the moment the customer approves the work, while the part warranty starts
/// there. Showing them in the same place without saying so would let a
/// customer believe the app is holding money against a part failing next
/// month. It is not (spec §6).
class _PartWarrantyNote extends StatelessWidget {
  const _PartWarrantyNote({required this.days});

  final int? days;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return AppCard(
      color: ak.surfaceDim,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 17, color: ak.inkSub),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              days == null
                  ? s.t('لم تذكر الورشة كفالة على القطعة. الضمان هنا يغطي الدفعة فقط، حتى موافقتك على العمل.',
                      'The workshop did not state a warranty on the part. The escrow here covers the payment only, up to your approval of the work.')
                  : s.t('كفالة القطعة من الورشة: ${s.days(days!)} — منفصلة عن ضمان الدفع، الذي ينتهي عند موافقتك.',
                      "Workshop's warranty on the part: ${s.days(days!)} — separate from the payment escrow, which ends at your approval."),
              style: TextStyle(fontSize: 11.5, height: 1.6, color: ak.inkSub),
            ),
          ),
        ],
      ),
    );
  }
}
