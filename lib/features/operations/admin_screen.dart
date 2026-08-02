import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/escrow_timeline.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/attachment_view.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'escrow_action_bar.dart';
import 'operator_shell.dart';
import 'queue_urgency.dart';

/// The founder's panel (spec §3 note 2 and §6, restructured by phase 2.5 §5).
///
/// It used to be one scrolling column of queues with the offers list bolted to
/// the bottom. That shape stopped working the moment there was more than one
/// kind of decision to make on it: onboarding, disputes, money and offers are
/// four different jobs done at four different times, and stacking them meant
/// scrolling past three of them to reach the fourth.
///
/// Five tabs now — the spec's four, plus the audit log §6 asks to be
/// filterable inside this panel:
///
/// * **Today** — everything waiting on the founder right now, SLA-coloured.
/// * **Workshops** — the onboarding pipeline and the approve/reject decision.
/// * **Money** — the escrow ledger and what each workshop is owed.
/// * **Offers** — unchanged, moved here whole.
/// * **Log** — who changed what, when, and why.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);

    return OperatorShell(
      title: s.t('لوحة المؤسس', 'Founder panel'),
      banner: OffAppTransferNotice(
        s.t(
          'الأرقام هنا تعكس ما سجّله التطبيق فقط. تحويل المبالغ فعلياً يتم خارجه في هذه المرحلة.',
          'These figures reflect only what the app recorded. Actual transfers happen outside it at this stage.',
        ),
      ),
      tabs: [
        OperatorTab(
          label: s.t('اليوم', 'Today'),
          builder: (context) => const _TodayTab(),
        ),
        OperatorTab(
          label: s.t('الورش', 'Workshops'),
          builder: (context) => const _ProvidersTab(),
        ),
        OperatorTab(
          label: s.t('المال', 'Money'),
          builder: (context) => const _MoneyTab(),
        ),
        OperatorTab(
          label: s.t('العروض', 'Offers'),
          builder: (context) => const _OffersTab(),
        ),
        OperatorTab(
          label: s.t('السجل', 'Log'),
          builder: (context) => const _AuditTab(),
        ),
      ],
    );
  }
}

// ============================================================ tab 1 — today

/// Everything that is waiting on the founder, in the order it should be
/// cleared: disputes first (a customer and a workshop are both stuck), then
/// unconfirmed money, then applications, then the automatic release that is
/// about to fire.
class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final requests = ref.watch(operatorQueueProvider);
    final window = ref.watch(appConfigProvider).approvalWindow;
    final pending = ref.watch(pendingApplicationsProvider);

    final needsFunds = [
      for (final r in requests)
        if (r.escrow == EscrowState.createdPendingPayment) r,
    ];
    final disputes = [
      for (final r in requests)
        if (r.escrow == EscrowState.disputed) r,
    ];
    final running = [
      for (final r in requests)
        if (!r.escrow.isTerminal &&
            r.escrow != EscrowState.createdPendingPayment &&
            r.escrow != EscrowState.disputed)
          r,
    ];
    // Approval windows that have already lapsed. The release is automatic, but
    // the founder should be able to see which ones are about to move without
    // anyone touching them — a silent automatic release is indistinguishable
    // from the app taking the workshop's side.
    final lapsing = [
      for (final r in requests)
        if (r.autoReleaseDue(window)) r,
    ];
    // Every booking whose money is actually being held — which includes the
    // disputed ones. They are listed in their own section rather than under
    // "in flight", but the funds have not moved: the dispute notification
    // tells the customer "the funds stay held", so the founder's total has to
    // agree with it.
    final held = requests.fold<double>(
        0, (sum, r) => r.escrow.holdsFunds ? sum + r.total : sum);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final completedThisMonth = [
      for (final r in requests)
        if (r.escrow == EscrowState.releasedToWorkshop &&
            !r.inCurrentStateSince.isBefore(monthStart))
          r,
    ];
    final completedValue =
        completedThisMonth.fold<double>(0, (sum, r) => sum + r.total);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.lg,
          AppSpacing.screenMargin, AppSpacing.xl),
      children: [
        // ------------------------------------------- metrics layer
        // Deliberately inert: these are the numbers the founder checks, not
        // things to press.
        Row(
          children: [
            Expanded(
              child: MetricTile(
                value: '${s.omr} ${held.toStringAsFixed(2)}',
                label: s.t('محجوز في الضمان', 'Held in escrow'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                value: '${running.length}',
                label: s.t('طلبات جارية', 'In flight'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                value: '${disputes.length}',
                label: s.t('نزاعات مفتوحة', 'Open disputes'),
                tone: disputes.isEmpty ? null : ak.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricTile(
                value: '${completedThisMonth.length}',
                label: s.t(
                  'اكتمل هذا الشهر · ${s.omr} ${completedValue.toStringAsFixed(0)}',
                  'Completed this month · ${s.omr} ${completedValue.toStringAsFixed(0)}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // -------------------------------------------- queue layer
        // Disputes lead: both sides of the transaction are blocked, and this
        // is the queue measured against `QueueSla.founder`'s four hours.
        _Section(
          title: s.t('نزاعات', 'Disputes'),
          emptyIcon: LucideIcons.handshake,
          empty: s.t('لا نزاعات مفتوحة — الطرفان راضيان حتى الآن.',
              'No open disputes — both sides are happy so far.'),
          requests: disputes,
          showDisputeNote: true,
          waitingOnFounder: true,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _Section(
          title:
              s.t('بانتظار تأكيد استلام المبلغ', 'Awaiting funds confirmation'),
          emptyIcon: LucideIcons.banknote,
          empty: s.t(
              'لا تحويلات بانتظارك — كل حجز مدفوع مؤكَّد.',
              'No transfers waiting on you — every paid booking is confirmed.'),
          requests: needsFunds,
          waitingOnFounder: true,
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // Applications land here as a *pointer*, not a second queue: the
        // pipeline in the Workshops tab is the one place they are actioned
        // (§11 step 2), and duplicating the buttons would mean two places to
        // keep the mandatory-reason rule in.
        SectionHeader(
            '${s.t('طلبات تسجيل ورش', 'Workshop applications')} · ${pending.length}'),
        const SizedBox(height: AppSpacing.headingGap),
        if (pending.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.store,
            message: s.t('لا طلبات تسجيل بانتظار مراجعتك.',
                'No applications waiting on your review.'),
          )
        else
          for (final (i, provider) in pending.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _ApplicationSummary(provider: provider),
          ],
        const SizedBox(height: AppSpacing.sectionGap),

        _Section(
          title: s.t('انتهت مهلة موافقة العميل', "Customer's window has lapsed"),
          emptyIcon: LucideIcons.timer,
          empty: s.t('لا مهلة منتهية — لا تحرير تلقائي وشيك.',
              'No lapsed windows — no automatic release is imminent.'),
          requests: lapsing,
          readOnly: true,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _Section(
          title: s.t('طلبات جارية', 'In flight'),
          emptyIcon: LucideIcons.wrench,
          empty: s.t('لا طلبات جارية الآن.', 'Nothing in flight right now.'),
          requests: running,
          readOnly: true,
        ),
      ],
    );
  }
}

/// A one-line pointer to an application, on the Today tab.
class _ApplicationSummary extends StatelessWidget {
  const _ApplicationSummary({required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final level = _applicationUrgency(provider);

    return UrgencyCard(
      level: level,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider.name.of(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.cardTitle),
                const SizedBox(height: AppSpacing.xs / 2),
                Text('${provider.stage.label(s)} · ${provider.area}',
                    style: context.text.bodySecondary),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          UrgencyLabel(_waitedLabel(s, provider), level: level),
        ],
      ),
    );
  }
}

/// How long an application has been waiting, on the same three-level scale the
/// booking queues use.
///
/// A day rather than [QueueSla.founder]'s four hours: reading a commercial
/// registration is not the same job as unblocking a stuck transaction, and
/// colouring every application red by lunchtime would train the founder to
/// ignore the colour — which is the failure mode `status_indicator.dart` exists
/// to avoid.
UrgencyLevel _applicationUrgency(ServiceProvider provider, {DateTime? now}) {
  final since = provider.stageSince;
  if (since == null) return UrgencyLevel.normal;
  final waited = (now ?? DateTime.now()).difference(since);
  const window = Duration(hours: 24);
  if (waited >= window) return UrgencyLevel.overdue;
  if (waited >= window * (2 / 3)) return UrgencyLevel.upcoming;
  return UrgencyLevel.normal;
}

String _waitedLabel(S s, ServiceProvider provider, {DateTime? now}) {
  final since = provider.stageSince;
  if (since == null) return s.t('غير معروف', 'Unknown');
  final waited = (now ?? DateTime.now()).difference(since);
  if (waited.inHours < 1) {
    return s.t('منذ ${waited.inMinutes} دقيقة', '${waited.inMinutes}m waiting');
  }
  if (waited.inHours < 24) {
    return s.t('منذ ${waited.inHours} ساعة', '${waited.inHours}h waiting');
  }
  return s.t('منذ ${s.days(waited.inDays)}', '${s.days(waited.inDays)} waiting');
}

// ======================================================== tab 2 — workshops

/// The onboarding pipeline and the decision that moves a workshop along it
/// (§5 tab 2, §11 steps 2–3).
///
/// Two things had to be true here and neither was before: the founder can see
/// *everything the applicant submitted*, including the commercial registration
/// document, and a rejection cannot be recorded without a written reason. The
/// second is enforced three deep — the dialog will not submit without one, the
/// repository refuses without one, and the mock service throws — because it is
/// the only thing standing between "rejected" and a workshop owner with no idea
/// what to fix.
class _ProvidersTab extends ConsumerWidget {
  const _ProvidersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final pipeline = ref.watch(onboardingPipelineProvider);
    final roster = ref.watch(rosterProvider);
    final pending = ref.watch(pendingApplicationsProvider);
    final live = [
      for (final p in roster)
        if (p.stage == ProviderOnboardingStage.approved) p,
    ];
    final stopped = [
      for (final p in roster)
        if (p.stage == ProviderOnboardingStage.suspended) p,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.lg,
          AppSpacing.screenMargin, AppSpacing.xl),
      children: [
        SectionHeader(s.t('أنبوب الاعتماد', 'Onboarding pipeline')),
        const SizedBox(height: AppSpacing.headingGap),
        // Every stage, including the empty ones: a pipeline that hides its
        // empty columns changes shape as you work through it, which is exactly
        // when you want it to hold still.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final stage in ProviderOnboardingStage.values)
              _StageChip(stage: stage, count: pipeline[stage] ?? 0),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(
            '${s.t('بانتظار قرارك', 'Waiting on your decision')} · ${pending.length}'),
        const SizedBox(height: AppSpacing.headingGap),
        if (pending.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.inbox,
            message: s.t(
                'لا طلبات معلّقة — كل ورشة قُدِّمت حتى الآن صدر فيها قرار.',
                'Nothing pending — every application so far has been decided.'),
          )
        else
          for (final (i, provider) in pending.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
            _ApplicationCard(provider: provider),
          ],
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader('${s.t('ورش معتمدة', 'Approved')} · ${live.length}'),
        const SizedBox(height: AppSpacing.headingGap),
        for (final (i, provider) in live.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.itemGap),
          _RosterRow(provider: provider),
        ],
        if (stopped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          SectionHeader(
              '${s.t('موقوفة أو مرفوضة', 'Suspended or rejected')} · ${stopped.length}'),
          const SizedBox(height: AppSpacing.headingGap),
          for (final (i, provider) in stopped.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _RosterRow(provider: provider),
          ],
        ],
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage, required this.count});

  final ProviderOnboardingStage stage;
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final empty = count == 0;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: empty ? ak.surfaceDim : ak.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ak.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stage.icon, size: 14, color: empty ? ak.inkFaint : ak.inkSub),
          const SizedBox(width: AppSpacing.xs + 2),
          Text('$count',
              style: context.text.labelStrong
                  .copyWith(color: empty ? ak.inkFaint : ak.ink)),
          const SizedBox(width: AppSpacing.xs),
          Text(stage.label(s),
              style: context.text.bodySecondary
                  .copyWith(color: empty ? ak.inkFaint : ak.inkSub)),
        ],
      ),
    );
  }
}

/// One pending application, with everything the applicant submitted and the
/// two decisions the founder can make about it.
class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final level = _applicationUrgency(provider);

    return UrgencyCard(
      level: level,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(provider.name.of(s), style: context.text.cardTitle),
              ),
              const SizedBox(width: AppSpacing.sm),
              UrgencyLabel(_waitedLabel(s, provider), level: level),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Everything the applicant typed, so the decision is made on the
          // submission rather than on the workshop's name.
          _Field(label: s.t('المرحلة', 'Stage'), value: provider.stage.label(s)),
          _Field(
            label: s.t('رقم السجل التجاري', 'CR number'),
            value: provider.crNumber ?? s.t('غير مذكور', 'Not given'),
          ),
          _Field(
            label: s.t('الرقم الضريبي', 'VAT number'),
            // Absent is a fact, not a blank: Oman's VAT registration is
            // turnover-based, so plenty of real garages have none.
            value: provider.vatNumber ??
                s.t('غير مسجّلة ضريبياً', 'Not VAT registered'),
          ),
          _Field(
            label: s.t('المنطقة', 'Area'),
            value: '${provider.area} · ${provider.region}',
          ),
          _Field(
            label: s.t('طريقة الاستلام', 'Fulfilment'),
            value: provider.fulfillments.isEmpty
                ? s.t('غير محدّد', 'Not specified')
                : provider.fulfillments.map((f) => f.label(s)).join(' · '),
          ),
          if (provider.rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.t('سبب الرفض السابق: ${provider.rejectionReason}',
                  'Previously rejected: ${provider.rejectionReason}'),
              style: context.text.bodySecondary
                  .copyWith(height: 1.5, color: ak.inkSub),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (provider.crDocument != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: ak.inkSub),
                onPressed: () => _showDocument(context, s, provider),
                icon: const Icon(LucideIcons.fileText, size: 15),
                label: Text(s.t('فتح وثيقة السجل التجاري', 'Open CR document')),
              ),
            )
          else
            Text(
              s.t('لم تُرفق وثيقة سجل تجاري — لا يمكن الاعتماد بلا وثيقة.',
                  'No CR document attached — approval needs one.'),
              style: context.text.bodySecondary.copyWith(color: ak.dangerText),
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              InkPill(
                label: s.t('اعتماد', 'Approve'),
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg + 2, vertical: AppSpacing.sm + 2),
                onTap: provider.crDocument == null
                    ? () => _needsDocument(context, s)
                    : () => _decide(context, ref,
                        stage: ProviderOnboardingStage.approved),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkPill(
                label: s.t('رفض', 'Reject'),
                outlined: true,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg + 2, vertical: AppSpacing.sm + 2),
                onTap: () => _decide(context, ref,
                    stage: ProviderOnboardingStage.suspended),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _needsDocument(BuildContext context, S s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.t(
          'لا يمكن اعتماد ورشة بلا وثيقة سجل تجاري.',
          'A workshop cannot be approved without a CR document.',
        )),
      ));

  /// The certificate itself, rendered from the bytes stored on the record.
  ///
  /// This used to print the document's URL as selectable text, because an
  /// upload was a path to a file on somebody else's device and there was
  /// nothing here to draw. Now the bytes are on the provider, so the founder
  /// reads the actual certificate on the screen where they approve the
  /// business — which is the only way "the founder checks the document"
  /// (§11 step 2) is a real step rather than a click.
  ///
  /// A PDF still cannot be drawn without a decoder the app does not ship;
  /// [AttachmentDocumentCard] names the file and its size in that case rather
  /// than showing an empty frame that could pass for a checked document.
  void _showDocument(BuildContext context, S s, ServiceProvider provider) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.t('وثيقة السجل التجاري', 'CR document')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${provider.name.of(s)} · ${provider.crNumber ?? ''}',
                    style: dialogContext.text.bodyPrimary),
                const SizedBox(height: AppSpacing.sm),
                if (provider.crDocument case final doc?)
                  AttachmentDocumentCard(attachment: doc)
                else
                  Text(
                    s.t('لا توجد وثيقة مرفقة.', 'No document attached.'),
                    style: dialogContext.text.bodySecondary,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(s.t('إغلاق', 'Close')),
            ),
          ],
        ),
      );

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required ProviderOnboardingStage stage,
  }) async {
    final s = S.of(context);
    final rejecting = stage == ProviderOnboardingStage.suspended;

    final reason = rejecting
        ? await showDialog<String>(
            context: context,
            builder: (dialogContext) => _RejectionDialog(s: s),
          )
        : null;
    // Cancelled, or submitted empty. Either way nothing is recorded — §14: no
    // rejection without a written reason.
    if (rejecting && (reason == null || reason.trim().isEmpty)) return;
    if (!context.mounted) return;

    await ref
        .read(adminActionsProvider)
        .setStage(provider.id, stage, reason: reason);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(rejecting
          ? s.t('سُجِّل الرفض — سيرى صاحب الورشة السبب ويستطيع إعادة الإرسال.',
              'Rejection recorded — the owner sees the reason and can re-submit.')
          : s.t('اعتُمدت الورشة — تظهر الآن للعملاء وتستقبل الحجوزات.',
              'Approved — the workshop is now visible to customers and takes bookings.')),
    ));
  }
}

/// The mandatory-reason dialog (§11 step 3).
///
/// The confirm button stays disabled until something is typed. Not a validation
/// message after the fact — a button that cannot be pressed says what is
/// required before the founder has invested anything in pressing it.
class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog({required this.s});

  final S s;

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final ready = _reason.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(s.t('سبب الرفض', 'Reason for rejection')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t(
              'يُعرض هذا النص لصاحب الورشة كما هو، وهو ما سيعتمد عليه في التصحيح وإعادة الإرسال.',
              'The owner is shown this text verbatim, and it is what they will act on when they re-submit.',
            ),
            style: context.text.bodySecondary.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reason,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s.t('مثال: صورة السجل غير واضحة',
                  'e.g. the CR image is not legible'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: ready
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
          child: Text(s.t('تسجيل الرفض', 'Record rejection')),
        ),
      ],
    );
  }
}

/// A workshop already decided about — approved or stopped — with the one
/// control that reverses it.
class _RosterRow extends ConsumerWidget {
  const _RosterRow({required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final approved = provider.isApproved;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(provider.name.of(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.cardTitle),
              ),
              const SizedBox(width: AppSpacing.sm),
              approved
                  ? StatusBadge.good(s.t('معتمدة', 'Approved'))
                  : StatusBadge.bad(s.t('موقوفة', 'Suspended')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text('${provider.area} · ${provider.region}',
              style: context.text.bodySecondary),
          if (provider.rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('"${provider.rejectionReason}"',
                style: context.text.bodySecondary
                    .copyWith(height: 1.5, color: ak.inkSub)),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkPill(
              label: approved
                  ? s.t('إيقاف', 'Suspend')
                  : s.t('إعادة الاعتماد', 'Re-approve'),
              outlined: approved,
              fontSize: 11,
              onTap: () => _toggle(context, ref, approved: approved),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required bool approved,
  }) async {
    final s = S.of(context);
    // Stopping a live workshop is the same act as rejecting an application —
    // somebody loses access and is owed a sentence explaining why. Same rule,
    // same dialog.
    final reason = approved
        ? await showDialog<String>(
            context: context,
            builder: (dialogContext) => _RejectionDialog(s: s),
          )
        : null;
    if (approved && (reason == null || reason.trim().isEmpty)) return;
    if (!context.mounted) return;

    await ref.read(adminActionsProvider).setStage(
          provider.id,
          approved
              ? ProviderOnboardingStage.suspended
              : ProviderOnboardingStage.approved,
          reason: reason,
        );
  }
}

/// A label/value pair on an application card.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(label, style: context.text.bodySecondary),
            ),
            Expanded(
              child: Text(value,
                  style: context.text.bodyPrimary.copyWith(height: 1.5)),
            ),
          ],
        ),
      );
}

// ============================================================ tab 3 — money

/// The escrow ledger and what each workshop is owed (§5 tab 3).
///
/// Nothing here moves money, and the tab says so twice — once in the panel's
/// standing banner and once in the confirmation beside the button. "Mark as
/// paid" records that a bank transfer happened; it is a note, not a
/// transaction, and a button that implied otherwise would be the most
/// misleading control in the app.
class _MoneyTab extends ConsumerWidget {
  const _MoneyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final requests = ref.watch(operatorQueueProvider);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final outstanding = ref.watch(outstandingByProviderProvider);
    final ledger = ref.watch(payoutsProvider);
    final config = ref.watch(appConfigProvider);

    final held = requests.fold<double>(
        0, (sum, r) => r.escrow.holdsFunds ? sum + r.total : sum);
    final cutoff = DateTime.now().subtract(config.earningsWindow);
    final released = requests.fold<double>(
        0,
        (sum, r) => r.escrow == EscrowState.releasedToWorkshop &&
                !r.inCurrentStateSince.isBefore(cutoff)
            ? sum + r.total
            : sum);
    final refunded = requests.fold<double>(
        0, (sum, r) => r.escrow == EscrowState.refunded ? sum + r.total : sum);
    final owed = [
      for (final entry in outstanding.entries)
        if (entry.value > 0.005) entry,
    ]..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.lg,
          AppSpacing.screenMargin, AppSpacing.xl),
      children: [
        SectionHeader(s.t('دفتر الضمان', 'Escrow ledger')),
        const SizedBox(height: AppSpacing.headingGap),
        OperatorFigure(
          value: '${s.omr} ${held.toStringAsFixed(2)}',
          label: s.t('محجوز الآن', 'Held right now'),
          hint: s.t(
              'يشمل الطلبات المتنازع عليها — النزاع يجمّد المبلغ ولا يعيده.',
              'Includes disputed jobs — a dispute freezes the money, it does not return it.'),
        ),
        const SizedBox(height: AppSpacing.itemGap),
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: '${s.omr} ${released.toStringAsFixed(2)}',
                label: s.t('حُرِّر خلال ${s.days(config.earningsWindow.inDays)}',
                    'Released in ${config.earningsWindow.inDays} days'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: '${s.omr} ${refunded.toStringAsFixed(2)}',
                label: s.t('مُعاد للعملاء', 'Refunded'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(
            '${s.t('مستحقات الورش', 'Owed to workshops')} · ${owed.length}'),
        const SizedBox(height: AppSpacing.headingGap),
        if (owed.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.banknote,
            message: s.t('لا مستحقات قائمة — كل ما حُرِّر سُجِّل تحويله.',
                'Nothing outstanding — every release has a transfer recorded against it.'),
          )
        else
          for (final (i, entry) in owed.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _OwedRow(
              provider: marketplace.providerById(entry.key)!,
              amount: entry.value,
            ),
          ],
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(
            '${s.t('تحويلات مسجَّلة', 'Recorded transfers')} · ${ledger.length}'),
        const SizedBox(height: AppSpacing.headingGap),
        if (ledger.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.receipt,
            message:
                s.t('لم تسجَّل أي تحويلات بعد.', 'No transfers recorded yet.'),
          )
        else
          for (final (i, record) in ledger.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _PayoutRow(
              record: record,
              provider: marketplace.providerById(record.providerId),
            ),
          ],
      ],
    );
  }
}

class _OwedRow extends ConsumerWidget {
  const _OwedRow({required this.provider, required this.amount});

  final ServiceProvider provider;
  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(provider.name.of(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.cardTitle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('${s.omr} ${amount.toStringAsFixed(2)}',
                  style: context.text.price),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            s.t('صافي المستحق بعد العمولة وبعد ما سُجِّل تحويله.',
                'Net of commission and of everything already recorded as transferred.'),
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkPill(
              label: s.t('علّم كمدفوع', 'Mark as paid'),
              fontSize: 11,
              onTap: () => _markPaid(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('تسجيل تحويل', 'Record a transfer')),
        content: Text(
          s.t(
            'هذا تسجيل فقط: التطبيق لا يحوّل شيئاً. أكّد أنك حوّلت ${s.omr} ${amount.toStringAsFixed(2)} إلى ${provider.name.of(s)} فعلياً.',
            'This only records it — the app transfers nothing. Confirm that you have actually sent ${s.omr} ${amount.toStringAsFixed(2)} to ${provider.name.of(s)}.',
          ),
          style: dialogContext.text.bodyPrimary.copyWith(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('نعم، حوّلته', 'Yes, I sent it')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final now = DateTime.now();
    await ref.read(adminActionsProvider).markPaid(
          providerId: provider.id,
          amount: amount,
          // The period is everything up to now that was not already settled,
          // which is exactly what the outstanding figure was computed over.
          periodFrom: now.subtract(const Duration(days: 3650)),
          periodTo: now,
        );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.record, required this.provider});

  final PayoutRecord record;
  final ServiceProvider? provider;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return AppCard(
      color: AkColors.of(context).surfaceDim,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider?.name.of(s) ?? record.providerId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyPrimary),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(record.note ?? _date(record.markedAt),
                    style: context.text.bodySecondary),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('${s.omr} ${record.amount.toStringAsFixed(2)}',
              style: context.text.labelStrong),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// =========================================================== tab 4 — offers

/// Offer governance, moved here whole and unchanged.
class _OffersTab extends StatelessWidget {
  const _OffersTab();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin,
            AppSpacing.lg, AppSpacing.screenMargin, AppSpacing.xl),
        children: const [_OffersSection()],
      );
}

// ============================================================== tab 5 — log

/// The audit trail (§6), filterable by subject.
///
/// Read-only by construction: there is no control on this screen that writes a
/// line, because every line is written by the action it records. A log you can
/// edit is a log, not an audit trail.
class _AuditTab extends ConsumerStatefulWidget {
  const _AuditTab();

  @override
  ConsumerState<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<_AuditTab> {
  AuditSubjectType? _filter;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final entries = ref.watch(auditLogProvider).ofType(_filter);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.lg,
          AppSpacing.screenMargin, AppSpacing.xl),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SelectChip(
              label: s.t('الكل', 'All'),
              selected: _filter == null,
              onTap: () => setState(() => _filter = null),
            ),
            for (final type in AuditSubjectType.values)
              SelectChip(
                label: type.label(s),
                selected: _filter == type,
                onTap: () => setState(() => _filter = type),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        if (entries.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.scrollText,
            message: s.t('لا سجلات في هذا التصنيف بعد.',
                'Nothing recorded under this filter yet.'),
          )
        else
          for (final (i, entry) in entries.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _AuditRow(entry: entry),
          ],
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

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
              Expanded(
                child: Text(
                  // The machine key, verbatim. This is an audit trail, and a
                  // prettified sentence is a translation of the record rather
                  // than the record.
                  entry.action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelStrong,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(_stamp(entry.at), style: context.text.bodySecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${entry.subjectType.label(s)} ${entry.subjectId} · ${entry.actor.label.of(s)}',
            style: context.text.bodySecondary,
          ),
          if (entry.fromState != null || entry.toState != null) ...[
            const SizedBox(height: AppSpacing.xs / 2),
            Text('${entry.fromState ?? '—'} → ${entry.toState ?? '—'}',
                style: context.text.bodySecondary.copyWith(color: ak.inkSub)),
          ],
          if (entry.note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('"${entry.note}"',
                style: context.text.bodyPrimary
                    .copyWith(height: 1.5, color: ak.inkSub)),
          ],
        ],
      ),
    );
  }

  static String _stamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Offer governance (home-page spec §3): offers are approved and stopped from
/// here, not self-served by workshops.
///
/// The panel shows every offer the platform holds, live or not, with the exact
/// rule that is keeping it off the home page. That is the point of the screen:
/// a workshop asks why its discount is not showing, and the answer is one line
/// long and comes from the same validation the home page runs.
///
/// The founder's switch is the *only* control here. There is deliberately no
/// way to edit a price: the reference price belongs to the published
/// catalogue and the discount belongs to the workshop, and an approval screen
/// that could quietly adjust either would hollow out the validation it exists
/// to enforce. There is also no way to feature or boost one — home-page
/// ranking is on merit only (spec §2), so there is nothing to promote with.
class _OffersSection extends ConsumerWidget {
  const _OffersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final audit = ref.watch(offersAuditProvider);
    final live = audit.where((row) => row.rejection == null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('${s.t('العروض', 'Offers')} · ${audit.length}'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          s.t('$live من ${audit.length} عرضاً تظهر الآن في الرئيسية. '
              'العرض لا يظهر إلا إذا استوفى كل الشروط.',
              '$live of ${audit.length} offers are showing on the home page. '
                  'An offer appears only when it meets every condition.'),
          style: context.text.bodySecondary.copyWith(height: 1.6),
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (audit.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.tag,
            message: s.t(
                'لا عروض مقدَّمة بعد — سيظهر هنا أي عرض ترفعه ورشة، بسبب ظهوره أو حجبه.',
                'No offers submitted yet — anything a workshop puts forward lands here, with the reason it is showing or hidden.'),
          )
        else
          for (final (i, row) in audit.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
            _OfferRow(offer: row.offer, rejection: row.rejection),
          ],
      ],
    );
  }
}

class _OfferRow extends ConsumerWidget {
  const _OfferRow({required this.offer, required this.rejection});

  final Offer offer;
  final OfferRejection? rejection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final offering = marketplace.offeringById(offer.serviceOfferingId);
    final live = rejection == null;
    // A rejection the founder's switch cannot fix — flipping the switch on an
    // offer whose reference price is wrong changes nothing, and the button
    // says so rather than pretending to work.
    final blockedByOther =
        rejection != null && rejection != OfferRejection.notApprovedByFounder;

    final ak = AkColors.of(context);
    // A blocked offer is a workshop waiting on an answer, so it carries the
    // warning tone; a live one is simply working.
    final level = blockedByOther ? UrgencyLevel.upcoming : UrgencyLevel.normal;

    return UrgencyCard(
      level: level,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offering?.name.of(s).replaceAll('\n', ' ') ??
                      offer.serviceOfferingId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.cardTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              live
                  ? StatusBadge.good(s.t('ظاهر', 'Live'))
                  : StatusBadge(s.t('غير ظاهر', 'Hidden')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(offering?.provider.name.of(s) ?? offer.workshopId,
              style: context.text.bodySecondary),
          const SizedBox(height: AppSpacing.md),
          // §2: the discounted price is what this row is about, so it leads;
          // the price it replaced and the percentage support it.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${s.omr} ${offer.discountedPrice.toStringAsFixed(2)}',
                  style: context.text.price),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '${s.omr} ${offer.referencePrice.toStringAsFixed(2)} · ${offer.discountPercent.round()}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary
                      .copyWith(decoration: TextDecoration.lineThrough),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            s.t('من ${_date(offer.startsAt)} إلى ${_date(offer.endsAt)}',
                '${_date(offer.startsAt)} → ${_date(offer.endsAt)}'),
            style: context.text.bodySecondary,
          ),
          if (rejection != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.isAr ? rejection!.reason.$1 : rejection!.reason.$2,
              style: context.text.bodySecondary
                  .copyWith(height: 1.5, color: ak.inkSub),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              InkPill(
                label: offer.activeByFounder
                    ? s.t('أوقف العرض', 'Stop offer')
                    : s.t('فعّل العرض', 'Enable offer'),
                outlined: offer.activeByFounder,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg + 2, vertical: AppSpacing.sm + 2),
                onTap: () => ref.read(offersAdminProvider).setActive(
                      offer.id,
                      active: !offer.activeByFounder,
                    ),
              ),
              if (blockedByOther) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    s.t('التفعيل وحده لن يُظهره — السبب أعلاه.',
                        'Enabling alone will not show it — see the reason above.'),
                    style: context.text.bodySecondary
                        .copyWith(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// One queue of the founder's panel.
///
/// Every section gets the same three parts in the same order — heading with
/// its count, then either its cards or its empty state — so the eye can tell
/// where one queue ends and the next begins without reading either title.
class _Section extends ConsumerWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.emptyIcon,
    required this.requests,
    this.showDisputeNote = false,
    this.readOnly = false,
    this.waitingOnFounder = false,
  });

  final String title;
  final String empty;
  final IconData emptyIcon;
  final List<ServiceRequest> requests;
  final bool showDisputeNote;

  /// Rows the founder watches but does not drive — the workshop and the
  /// customer own those transitions.
  final bool readOnly;

  /// Whether a delay in this queue is the founder's to answer for. Only these
  /// rows can go amber or red — see [QueueSla].
  final bool waitingOnFounder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final window = ref.watch(appConfigProvider).approvalWindow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('$title · ${requests.length}'),
        const SizedBox(height: AppSpacing.headingGap),
        if (requests.isEmpty)
          EmptyState(compact: true, icon: emptyIcon, message: empty)
        else
          for (final (i, r) in requests.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap + 2),
            Builder(builder: (context) {
              final level = QueueSla.levelFor(r,
                  window: QueueSla.founder, waitingOnMe: waitingOnFounder);
              return UrgencyCard(
                level: level,
                onTap: () => context.push('/track/${r.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OperatorRequestHeader(request: r),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: EscrowTimeline(
                              state: r.escrow,
                              size: EscrowTimelineSize.compact),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        UrgencyLabel(QueueSla.waitedLabel(s, r), level: level),
                      ],
                    ),
                    if (showDisputeNote && r.disputeNote.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        // The customer's own words, unedited — a summarised
                        // complaint is a mis-stated complaint.
                        '"${r.disputeNote}"',
                        style: context.text.bodyPrimary
                            .copyWith(height: 1.6, color: ak.inkSub),
                      ),
                    ],
                    if (r.escrow == EscrowState.awaitingApproval)
                      _deadlineLine(context, s, r, window),
                    if (!readOnly) ...[
                      const SizedBox(height: AppSpacing.lg),
                      EscrowActionBar(request: r, actor: EscrowActor.founder),
                    ],
                  ],
                ),
              );
            }),
          ],
      ],
    );
  }

  Widget _deadlineLine(
      BuildContext context, S s, ServiceRequest request, Duration window) {
    final deadline = request.approvalDeadline(window);
    if (deadline == null) return const SizedBox.shrink();
    final hours = deadline.difference(DateTime.now()).inHours;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        hours <= 0
            ? s.t('انتهت مهلة العميل — تحرير تلقائي.',
                "Customer's window has closed — auto-releasing.")
            : s.t('يتبقى للعميل $hours ساعة قبل التحرير التلقائي.',
                'Customer has $hours hours before the automatic release.'),
        style: context.text.bodySecondary,
      ),
    );
  }
}
