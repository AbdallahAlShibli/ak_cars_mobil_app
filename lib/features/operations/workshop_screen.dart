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
import 'operator_shell.dart';
import 'queue_urgency.dart';

/// The workshop's panel (spec §2 and §6, extended by phase 2.5 §3 and §4).
///
/// Three tabs, because a workshop asks three different questions and they were
/// previously answered by one screen that only answered the first:
///
/// * **Jobs** — the queue. "Needs you" first, because that is the only reason
///   anyone opens this screen in a hurry.
/// * **Earnings** — what is held, what was released, and what the platform
///   took. Previously nowhere in the app, which meant a workshop's only way to
///   learn the commission was to compare a booking total against a bank
///   statement.
/// * **Performance** — acceptance, response time, completion, disputes and the
///   real reviews behind the rating. Every figure derived, none stored.
class WorkshopScreen extends ConsumerWidget {
  const WorkshopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final workshop = ref.watch(activeWorkshopProvider);
    final standIn = ref.watch(isStandingInForDemoProvider);

    return OperatorShell(
      title: s.t('لوحة الورشة', 'Workshop panel'),
      // Named rather than implied: on the pilot's role switcher this panel is
      // showing a workshop the account does not own, and a figures screen that
      // does not say whose figures they are will be read as yours.
      banner: standIn && workshop != null
          ? OffAppTransferNotice(
              s.t(
                'عرض تجريبي — تشاهد لوحة ${workshop.name.of(s)}. الأرقام تخص هذه الورشة، لا حسابك.',
                'Demo view — you are looking at ${workshop.name.of(s)}. These figures are that workshop\'s, not your account\'s.',
              ),
            )
          : null,
      tabs: [
        OperatorTab(
          label: s.t('الطلبات', 'Jobs'),
          builder: (context) => const _JobsTab(),
        ),
        OperatorTab(
          label: s.t('الأرباح', 'Earnings'),
          builder: (context) => const _EarningsTab(),
        ),
        OperatorTab(
          label: s.t('الأداء', 'Performance'),
          builder: (context) => const _PerformanceTab(),
        ),
      ],
    );
  }
}

/// The queue, unchanged in substance from the pre-2.5 screen: a pinned strip of
/// counts, then "waiting on you" and "waiting on others" as separate queues.
///
/// What did change is the scope. It used to list every booking the app knew
/// about; it now lists this workshop's, because the seeded marketplace has
/// forty of them belonging to a dozen workshops and a panel that mixes them is
/// not a workshop's panel.
class _JobsTab extends ConsumerWidget {
  const _JobsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final requests = ref.watch(workshopJobsProvider);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ------------------------------------------- metrics layer
        // Pinned, so the shape of the day stays visible while the operator
        // scrolls through the jobs that make it up.
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
              AppSpacing.md, AppSpacing.screenMargin, AppSpacing.lg),
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
    );
  }
}

/// What this workshop has earned, is holding, and has been charged (§3).
///
/// Three figures and a table, in that order, because that is the order the
/// questions are asked in: *is anything coming?*, *what landed?*, *what did it
/// cost me?*
///
/// The commission is a headline, not a column total you have to derive. A
/// workshop that discovers the platform's cut by subtracting two numbers
/// trusts the platform less than one that was shown the figure plainly, and
/// the difference costs nothing to give.
class _EarningsTab extends ConsumerWidget {
  const _EarningsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final earnings = ref.watch(workshopEarningsProvider);
    final days = earnings.window.inDays;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.lg,
          AppSpacing.screenMargin, AppSpacing.xl),
      children: [
        OperatorFigure(
          value: '${s.omr} ${earnings.heldInEscrow.toStringAsFixed(2)}',
          label: s.t('محجوز في الضمان', 'Held in escrow'),
          hint: s.t('على طلباتك المفتوحة — ليست لك بعد.',
              'On your open jobs — not yours yet.'),
          tone: earnings.heldInEscrow > 0 ? ak.amberText : null,
        ),
        const SizedBox(height: AppSpacing.itemGap),
        OperatorFigure(
          value: '${s.omr} ${earnings.releasedNet.toStringAsFixed(2)}',
          label: s.t('حُرِّر خلال ${s.days(days)}', 'Released in $days days'),
          hint: s.t(
            'بعد خصم عمولة ${earnings.releasedCommission.toStringAsFixed(2)} من ${earnings.releasedGross.toStringAsFixed(2)}',
            'After ${earnings.releasedCommission.toStringAsFixed(2)} commission on ${earnings.releasedGross.toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(height: AppSpacing.itemGap),
        OperatorFigure(
          value: '${s.omr} ${earnings.totalCommission.toStringAsFixed(2)}',
          label: s.t('إجمالي العمولة المخصومة', 'Total commission charged'),
          hint: s.t('منذ بداية تعاملك مع المنصة.',
              'Since you joined the platform.'),
        ),
        const SizedBox(height: AppSpacing.md),
        OffAppTransferNotice(
          s.t(
            'التحويل الفعلي يتم خارج التطبيق في هذه المرحلة. ما تراه هنا سجل لما رصده التطبيق، لا رصيد يحتفظ به.',
            'Actual transfers happen outside the app at this stage. What you see here is a record of what the app observed, not a balance it holds.',
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(
          '${s.t('آخر المعاملات', 'Recent transactions')} · ${earnings.lines.length}',
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (earnings.lines.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.receipt,
            message: s.t(
              'لا معاملات بعد — أول طلب يُحرَّر سيظهر هنا بتفصيل العمولة والصافي.',
              'No transactions yet — the first released job lands here with its commission and net broken out.',
            ),
          )
        else
          for (final (i, line) in earnings.lines.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _EarningsRow(line: line),
          ],
      ],
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({required this.line});

  final EarningsLine line;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.request.offering.name.of(s).replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.cardTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // "Held" and "released" are the only two states this table
              // distinguishes, because they are the only two that change
              // whether the money is the workshop's.
              line.pending
                  ? StatusBadge.warn(s.t('محجوز', 'Held'))
                  : StatusBadge.good(s.t('محرَّر', 'Released')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            '${_date(line.at)} · ${line.request.car.label}',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          // The net is what reached (or will reach) the workshop, so it leads;
          // the gross and the commission that produced it follow.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${s.omr} ${line.net.toStringAsFixed(2)}',
                  style: context.text.price),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  s.t(
                    '${line.gross.toStringAsFixed(2)} − عمولة ${line.commission.toStringAsFixed(2)}',
                    '${line.gross.toStringAsFixed(2)} − ${line.commission.toStringAsFixed(2)} fee',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary.copyWith(color: ak.inkSub),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// How this workshop is actually doing (§4).
///
/// Every figure comes from `WorkshopMetrics`, computed in the repository from
/// the bookings' own escrow history and the real reviews. Nothing on this
/// screen is stored anywhere, which is deliberate: the previous generation of
/// provider "stats" in this project was invented from a boolean, and a
/// performance tab that can drift from the jobs behind it is worse than none.
///
/// A rate with no denominator renders as "—", never as 0%. A workshop that has
/// never been sent a job has not refused any, and printing "0% acceptance"
/// would be an accusation the data does not support.
class _PerformanceTab extends ConsumerWidget {
  const _PerformanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final m = ref.watch(workshopMetricsProvider);

    if (m.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: EmptyState(
            icon: LucideIcons.chartNoAxesColumn,
            title: s.t('لا أرقام بعد', 'Nothing to measure yet'),
            message: s.t(
              'تظهر أرقام الأداء بعد أول طلب يصلك. لن نعرض نِسَباً قبل أن يكون خلفها عمل فعلي.',
              'Performance figures appear after your first job. We will not show a rate before there is real work behind it.',
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.lg,
          AppSpacing.screenMargin, AppSpacing.xl),
      children: [
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: _percent(m.acceptanceRate),
                label: s.t('نسبة القبول', 'Acceptance rate'),
                hint: s.t('${m.accepted} من ${m.received} طلباً',
                    '${m.accepted} of ${m.received} jobs'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: _duration(s, m.avgResponseTime),
                label: s.t('متوسط زمن الرد', 'Avg response time'),
                hint: s.t('من وصول الطلب إلى قبوله',
                    'From arrival to acceptance'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.itemGap),
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: _percent(m.completionRate),
                label: s.t('نسبة الإنجاز', 'Completion rate'),
                hint: s.t('${m.completed} من ${m.accepted} مقبولاً',
                    '${m.completed} of ${m.accepted} accepted'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: _percent(m.disputeRate),
                label: s.t('نسبة النزاعات', 'Dispute rate'),
                hint: s.t('${m.disputed} نزاعاً', '${m.disputed} disputed'),
                tone: (m.disputeRate ?? 0) > 0.1 ? ak.danger : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(s.t('تقييم العملاء', 'Customer rating')),
        const SizedBox(height: AppSpacing.headingGap),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Null, not zero: "nobody has rated us" and "we score
                      // nothing" are different statements and the screen has
                      // to be able to make the first one.
                      m.avgRating == null
                          ? '—'
                          : m.avgRating!.toStringAsFixed(1),
                      style: context.text.price,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      m.reviewCount == 0
                          ? s.t('لا تقييمات بعد', 'No reviews yet')
                          : s.reviews(m.reviewCount),
                      style: context.text.bodySecondary,
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.star, size: 20, color: ak.amberText),
            ],
          ),
        ),
        if (m.recentReviews.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          SectionHeader(s.t('آخر ما كُتب عنك', 'What customers wrote')),
          const SizedBox(height: AppSpacing.headingGap),
          for (final (i, review) in m.recentReviews.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _ReviewRow(review: review),
          ],
        ],
      ],
    );
  }

  /// A rate, or an em dash when there is no denominator behind it.
  static String _percent(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()}%';

  static String _duration(S s, Duration? d) {
    if (d == null) return '—';
    if (d.inHours < 1) return s.t('${d.inMinutes} دقيقة', '${d.inMinutes} min');
    if (d.inHours < 24) return s.t('${d.inHours} ساعة', '${d.inHours}h');
    return s.days(d.inDays);
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return AppCard(
      color: ak.surfaceDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  LucideIcons.star,
                  size: 13,
                  color: i < review.rating ? ak.amberText : ak.inkFaint,
                ),
              const Spacer(),
              // §8: a review written after a dispute is labelled, not hidden.
              // A resolved dispute is part of the record.
              if (review.afterDispute)
                StatusBadge(s.t('بعد نزاع محلول', 'After a resolved dispute')),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              // The customer's own words, verbatim.
              review.comment!,
              style: context.text.bodyPrimary.copyWith(height: 1.6),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            review.serviceType.of(s),
            style: context.text.bodySecondary.copyWith(fontSize: 11),
          ),
        ],
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

    await ref
        .read(operatorQueueProvider.notifier)
        .submitQuote(request.id, quote);
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
        .read(operatorQueueProvider.notifier)
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
