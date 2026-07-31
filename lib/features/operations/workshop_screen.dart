import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../services/proof_upload_sheet.dart';
import 'escrow_action_bar.dart';

/// The workshop's panel (spec §2 and §6): accept or reject a job, start work,
/// submit the completion proof.
///
/// Deliberately plain. Spec §6 is explicit that these panels exist to operate
/// the pilot, not to impress anyone — every pixel spent styling this is a
/// pixel not spent on the customer's booking flow.
class WorkshopScreen extends ConsumerWidget {
  const WorkshopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final requests = ref.watch(requestsProvider);
    final queue = [
      for (final r in requests)
        if (!r.escrow.isTerminal) r,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('لوحة الورشة', 'Workshop panel'))),
      body: SafeArea(
        child: queue.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    s.t('لا توجد طلبات مفتوحة.', 'No open jobs.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.ink3),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: queue.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _JobCard(request: queue[i]),
              ),
      ),
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final proof = request.proof;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OperatorRequestHeader(request: request),
          if (proof != null) ...[
            const SizedBox(height: 10),
            Text(
              proof.notes.isEmpty
                  ? s.t(
                      'رُفع الإثبات بلا ملاحظات.',
                      'Proof submitted with no notes.',
                    )
                  : proof.notes,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.ink3,
                height: 1.6,
              ),
            ),
          ],
          if (request.partRequest != null) ...[
            const SizedBox(height: 10),
            _PartRequestBrief(request: request),
          ],
          const SizedBox(height: 12),
          EscrowActionBar(
            request: request,
            actor: EscrowActor.workshop,
            onSubmitProof: () => _submitProof(context, ref, request),
            onSubmitQuote: () => _submitQuote(context, ref, request),
          ),
          if (_reviewable(ref, request)) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/review/${request.id}?direction=${ReviewDirection.workshopToCustomer.key}',
              ),
              icon: const Icon(Icons.star_outline_rounded, size: 17),
              label: Text(s.t('قيّم العميل', 'Rate the customer')),
            ),
          ],
        ],
      ),
    );
  }

  /// The workshop's half of the bidirectional review (spec §8) — unlocked by
  /// the same release, and only where it has not already been written.
  bool _reviewable(WidgetRef ref, ServiceRequest request) =>
      AppFlags.verifiedReviews &&
      ref.watch(pendingWorkshopReviewsProvider).any((r) => r.id == request.id);

  /// Prices a part request: two figures, entered separately, because that is
  /// what the customer is shown and what they are agreeing to.
  Future<void> _submitQuote(
    BuildContext context,
    WidgetRef ref,
    ServiceRequest request,
  ) async {
    final s = S.of(context);
    final quote = await showModalBottomSheet<Quote>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _QuoteSheet(s: s, request: request),
    );
    if (quote == null || !context.mounted) return;

    await ref.read(requestsProvider.notifier).submitQuote(request.id, quote);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'أُرسل العرض — القرار الآن عند العميل',
            'Quote sent — the decision is with the customer',
          ),
        ),
      ),
    );
  }

  Future<void> _submitProof(
    BuildContext context,
    WidgetRef ref,
    ServiceRequest request,
  ) async {
    final s = S.of(context);
    final result = await showModalBottomSheet<ProofDraft>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ProofUploadSheet(s: s, request: request),
    );
    if (result == null || !context.mounted) return;

    await ref
        .read(requestsProvider.notifier)
        .fire(
          request.id,
          EscrowEvent.submitProof,
          actor: EscrowActor.workshop,
          proof: ProofOfWork(
            id: 'proof-${request.id}',
            requestId: request.id,
            notes: result.notes.trim(),
            submittedAt: DateTime.now(),
            media: result.media,
            includesPartBoxPhoto: result.includesPartBoxPhoto,
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'أُرسل الإثبات — الطلب الآن بانتظار العميل',
            'Proof sent — the job is now with the customer',
          ),
        ),
      ),
    );
  }
}

/// What a part request asked for, as the workshop needs to read it: the
/// customer's own words, plus the car the part has to fit.
class _PartRequestBrief extends StatelessWidget {
  const _PartRequestBrief({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final part = request.partRequest!;
    final quote = request.quote;

    return AppCard(
      color: ak.surfaceDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('طلب قطعة + تركيب', 'Part + fitting request'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ak.inkSub,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            part.description,
            style: const TextStyle(fontSize: 12.5, height: 1.6),
          ),
          if ((part.preferredBrand ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s.t(
                'يفضّل: ${part.preferredBrand}',
                'Prefers: ${part.preferredBrand}',
              ),
              style: TextStyle(fontSize: 11.5, color: ak.inkSub),
            ),
          ],
          if ((part.symptom ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s.t('الأعراض: ${part.symptom}', 'Symptom: ${part.symptom}'),
              style: TextStyle(fontSize: 11.5, color: ak.inkSub),
            ),
          ],
          if (quote != null) ...[
            const SizedBox(height: 8),
            Text(
              s.t(
                'عرضك: قطعة ${quote.partPrice.toStringAsFixed(2)} + تركيب ${quote.laborPrice.toStringAsFixed(2)} = ${quote.total.toStringAsFixed(2)} ر.ع',
                'Your quote: part ${quote.partPrice.toStringAsFixed(2)} + fitting ${quote.laborPrice.toStringAsFixed(2)} = OMR ${quote.total.toStringAsFixed(2)}',
              ),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The itemised quote form (spec §6).
///
/// Two amount fields, both required. There is deliberately no single "total"
/// field to type into: a lump sum is the verbal arrangement this transaction
/// replaces, so the model cannot express one and neither can this sheet.
class _QuoteSheet extends StatefulWidget {
  const _QuoteSheet({required this.s, required this.request});

  final S s;
  final ServiceRequest request;

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  final _part = TextEditingController();
  final _partPrice = TextEditingController();
  final _laborPrice = TextEditingController();
  final _brand = TextEditingController();
  final _warranty = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seeded with what the customer wrote so the workshop corrects it rather
    // than retypes it — and any correction is then visibly the workshop's.
    _part.text = widget.request.partRequest?.description ?? '';
  }

  @override
  void dispose() {
    _part.dispose();
    _partPrice.dispose();
    _laborPrice.dispose();
    _brand.dispose();
    _warranty.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _partAmount => double.tryParse(_partPrice.text.trim());
  double? get _laborAmount => double.tryParse(_laborPrice.text.trim());

  bool get _ready =>
      _part.text.trim().isNotEmpty &&
      (_partAmount ?? -1) >= 0 &&
      (_laborAmount ?? -1) >= 0 &&
      (_partAmount! + _laborAmount!) > 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final ak = AkColors.of(context);
    final total = (_partAmount ?? 0) + (_laborAmount ?? 0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('عرض سعر', 'Quote'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              s.t(
                'سعر القطعة وأجرة التركيب منفصلان — هكذا يراهما العميل، وهذا ما يوافق عليه.',
                'The part and the fitting are priced separately — that is how the customer sees them, and what they agree to.',
              ),
              style: TextStyle(fontSize: 12, color: ak.inkSub),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _part,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: s.t('القطعة التي ستركّبها', 'The part you will fit'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _brand,
              decoration: InputDecoration(
                labelText: s.t(
                  'الماركة/الأصل (اختياري)',
                  'Brand / origin (optional)',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _partPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: s.t('سعر القطعة', 'Part price'),
                      suffixText: s.omr,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _laborPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: s.t('أجرة التركيب', 'Fitting'),
                      suffixText: s.omr,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _warranty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: s.t(
                  'كفالة القطعة بالأيام (اختياري)',
                  'Part warranty in days (optional)',
                ),
                helperText: s.t(
                  'كفالتك أنت على القطعة — غير ضمان الدفع.',
                  "Your own warranty on the part — not the payment escrow.",
                ),
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: s.t(
                  'ملاحظة للعميل (اختياري)',
                  'Note to the customer (optional)',
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              s.t(
                'الإجمالي: ${total.toStringAsFixed(2)} ر.ع',
                'Total: OMR ${total.toStringAsFixed(2)}',
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _ready ? _submit : null,
              child: Text(s.t('إرسال العرض', 'Send the quote')),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() => Navigator.of(context).pop(
    Quote(
      // Replaced by the service, which owns the identity sequence.
      id: 'quote-${widget.request.id}',
      requestId: widget.request.id,
      workshopId: widget.request.offering.provider.id,
      partDescription: _part.text.trim(),
      partPrice: _partAmount!,
      laborPrice: _laborAmount!,
      partBrand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      warrantyDays: int.tryParse(_warranty.text.trim()),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: DateTime.now(),
    ),
  );
}
