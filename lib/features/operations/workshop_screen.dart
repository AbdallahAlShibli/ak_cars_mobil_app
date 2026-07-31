import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/escrow_timeline.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../services/proof_upload_sheet.dart';
import 'escrow_action_bar.dart';
import 'queue_urgency.dart';

/// The workshop's panel (spec §2 and §6): accept or reject a job, start work,
/// submit the completion proof.
///
/// Not decorated, but no longer undifferentiated. It was one flat list in
/// which a job waiting on this workshop looked exactly like a job waiting on
/// the customer, and the numbers that describe the day were nowhere. Now it is
/// two layers (§5): a fixed strip of counts at the top, which is reading
/// material, and below it the queues, which are the work — "needs you" first,
/// because that is the only queue anyone opens this screen to clear.
class WorkshopScreen extends ConsumerWidget {
  const WorkshopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final requests = ref.watch(requestsProvider);
    final open = [
      for (final r in requests)
        if (!r.escrow.isTerminal) r,
    ];
    // The split that matters to a workshop: what the table lets *it* move
    // versus what it is only waiting on. Derived from the transition table, so
    // adding a transition puts the job in the right queue on its own.
    final mine = [
      for (final r in open)
        if (r.escrow.transitionsFor(EscrowActor.workshop).isNotEmpty) r,
    ];
    final waiting = [
      for (final r in open)
        if (r.escrow.transitionsFor(EscrowActor.workshop).isEmpty) r,
    ];
    final breaching = [
      for (final r in mine)
        if (QueueSla.levelFor(r,
                window: QueueSla.workshop, waitingOnMe: true) ==
            UrgencyLevel.overdue)
          r,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('لوحة الورشة', 'Workshop panel'))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ------------------------------------------- metrics layer
            // Pinned, so the shape of the day stays visible while the operator
            // scrolls through the jobs that make it up.
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, 0,
                  AppSpacing.screenMargin, AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      value: '${mine.length}',
                      label: s.t('بانتظار إجرائك', 'Waiting on you'),
                      tone: mine.isEmpty ? null : ak.amberText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricTile(
                      value: '${waiting.length}',
                      label: s.t('بانتظار غيرك', 'Waiting on others'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetricTile(
                      value: '${breaching.length}',
                      label: s.t('تجاوزت المهلة', 'Past the window'),
                      tone: breaching.isEmpty ? null : ak.danger,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ak.divider),
            // -------------------------------------------- queue layer
            Expanded(
              child: open.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: EmptyState(
                          icon: LucideIcons.coffee,
                          title: s.t('لا طلبات مفتوحة', 'Nothing open'),
                          message: s.t(
                            'لا طلبات مفتوحة حالياً — راحة بال مستحقة. سيظهر أي طلب جديد هنا فور وصوله.',
                            'No open jobs right now — a quiet moment, well earned. Anything new lands here the second it arrives.',
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenMargin,
                          AppSpacing.lg,
                          AppSpacing.screenMargin,
                          AppSpacing.xl),
                      children: [
                        _Queue(
                          title: s.t('بانتظار إجرائك', 'Waiting on you'),
                          requests: mine,
                          waitingOnMe: true,
                          empty: s.t(
                            'لا شيء بانتظارك الآن — كل الطلبات المفتوحة عند غيرك.',
                            'Nothing is on you right now — every open job is with someone else.',
                          ),
                        ),
                        if (waiting.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sectionGap),
                          _Queue(
                            title: s.t('بانتظار غيرك', 'Waiting on others'),
                            requests: waiting,
                            waitingOnMe: false,
                            empty: '',
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One titled queue: a heading, a rule, and its cards — or its empty message.
///
/// The heading and the divider are what stop the second queue from reading as
/// a continuation of the first, which is the whole point of §5's "clear
/// separator".
class _Queue extends StatelessWidget {
  const _Queue({
    required this.title,
    required this.requests,
    required this.waitingOnMe,
    required this.empty,
  });

  final String title;
  final List<ServiceRequest> requests;
  final bool waitingOnMe;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('$title · ${requests.length}'),
        const SizedBox(height: AppSpacing.headingGap),
        if (requests.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.circleCheck,
            message: empty.isEmpty ? s.t('لا شيء هنا.', 'Nothing here.') : empty,
          )
        else
          for (final (i, r) in requests.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
            _JobCard(request: r, waitingOnMe: waitingOnMe),
          ],
      ],
    );
  }
}

class _JobCard extends ConsumerWidget {
  const _JobCard({required this.request, required this.waitingOnMe});

  final ServiceRequest request;
  final bool waitingOnMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final proof = request.proof;
    final level = QueueSla.levelFor(request,
        window: QueueSla.workshop, waitingOnMe: waitingOnMe);

    return UrgencyCard(
      level: level,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OperatorRequestHeader(request: request),
          const SizedBox(height: AppSpacing.md),
          // The escrow position at a glance, and how long it has held still.
          Row(
            children: [
              Expanded(
                child: EscrowTimeline(
                    state: request.escrow,
                    size: EscrowTimelineSize.compact),
              ),
              const SizedBox(width: AppSpacing.md),
              UrgencyLabel(QueueSla.waitedLabel(s, request), level: level),
            ],
          ),
          if (proof != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              proof.notes.isEmpty
                  ? s.t('رُفع الإثبات بلا ملاحظات.',
                      'Proof submitted with no notes.')
                  : proof.notes,
              style: context.text.bodySecondary.copyWith(height: 1.6),
            ),
          ],
          if (request.partRequest != null) ...[
            const SizedBox(height: AppSpacing.md),
            _PartRequestBrief(request: request),
          ],
          const SizedBox(height: AppSpacing.lg),
          EscrowActionBar(
            request: request,
            actor: EscrowActor.workshop,
            onSubmitProof: () => _submitProof(context, ref, request),
            onSubmitQuote: () => _submitQuote(context, ref, request),
          ),
          if (_reviewable(ref, request)) ...[
            const SizedBox(height: AppSpacing.sm),
            // §5: the secondary action is a text button, not a second full
            // button competing with the escrow transition above it.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: ak.inkSub),
                onPressed: () => context.push(
                  '/review/${request.id}?direction=${ReviewDirection.workshopToCustomer.key}',
                ),
                icon: const Icon(LucideIcons.star, size: 15),
                label: Text(s.t('قيّم العميل', 'Rate the customer')),
              ),
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
            style: context.text.bodySecondary
                .copyWith(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(part.description,
              style: context.text.bodyPrimary.copyWith(height: 1.6)),
          if ((part.preferredBrand ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.t('يفضّل: ${part.preferredBrand}',
                  'Prefers: ${part.preferredBrand}'),
              style: context.text.bodySecondary,
            ),
          ],
          if ((part.symptom ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.t('الأعراض: ${part.symptom}', 'Symptom: ${part.symptom}'),
              style: context.text.bodySecondary,
            ),
          ],
          if (quote != null) ...[
            const SizedBox(height: AppSpacing.md),
            // §2: the workshop's own number leads at price weight; how it
            // was arrived at follows underneath.
            Text('${s.omr} ${quote.total.toStringAsFixed(2)}',
                style: context.text.price),
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              s.t(
                'عرضك: قطعة ${quote.partPrice.toStringAsFixed(2)} + تركيب ${quote.laborPrice.toStringAsFixed(2)}',
                'Your quote: part ${quote.partPrice.toStringAsFixed(2)} + fitting ${quote.laborPrice.toStringAsFixed(2)}',
              ),
              style: context.text.bodySecondary,
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
            Text(s.t('عرض سعر', 'Quote'), style: context.text.screenTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.t(
                'سعر القطعة وأجرة التركيب منفصلان — هكذا يراهما العميل، وهذا ما يوافق عليه.',
                'The part and the fitting are priced separately — that is how the customer sees them, and what they agree to.',
              ),
              style: context.text.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
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
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(s.t('الإجمالي', 'Total'),
                      style: context.text.bodySecondary),
                ),
                Text('${s.omr} ${total.toStringAsFixed(2)}',
                    style: context.text.price),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
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
