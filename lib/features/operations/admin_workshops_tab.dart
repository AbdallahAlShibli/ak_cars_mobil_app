import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/attachment_view.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/admin_workshop_detail_state.dart';
import '../../state/app_state.dart';
import '../services/proof_upload_sheet.dart';

import 'admin_panel_widgets.dart';
import 'admin_today_tab.dart' show applicationUrgency, applicationWaitedLabel;

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
class AdminWorkshopsTab extends ConsumerWidget {
  const AdminWorkshopsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        AdminSummaryCard(
          icon: LucideIcons.store,
          title: s.t('الورش', 'Workshops'),
          subtitle: s.t(
            'من على المنصة، ومن ينتظر قراراً.',
            'Who is on the platform, and who is waiting on a decision.',
          ),
          stats: [
            AdminStat.count(
              pending.length,
              label: s.t('بانتظار قرارك', 'Awaiting you'),
              color: pending.isEmpty ? null : ak.amberText,
            ),
            AdminStat.count(
              live.length,
              label: s.t('معتمدة', 'Approved'),
              color: ak.success,
            ),
            AdminStat.count(
              stopped.length,
              label: s.t('موقوفة', 'Suspended'),
              color: stopped.isEmpty ? null : ak.inkFaint,
            ),
          ],
          // Every stage, including the empty ones: a pipeline that hides its
          // empty columns changes shape as you work through it, which is
          // exactly when you want it to hold still.
          chips: [
            for (final stage in ProviderOnboardingStage.values)
              AdminMetaChip(
                icon: stage.icon,
                tone: (pipeline[stage] ?? 0) == 0
                    ? AdminChipTone.dim
                    : AdminChipTone.normal,
                label: '${stage.label(s)} · ${pipeline[stage] ?? 0}',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        AdminGroupHeader(
          icon: LucideIcons.inbox,
          title: s.t('بانتظار قرارك', 'Waiting on your decision'),
          count: pending.length,
          tone: pending.isEmpty ? AdminChipTone.normal : AdminChipTone.warn,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (pending.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.inbox,
            message: s.t(
              'لا طلبات معلّقة — كل ورشة قُدِّمت حتى الآن صدر فيها قرار.',
              'Nothing pending — every application so far has been decided.',
            ),
          )
        else
          for (final (i, provider) in pending.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _ApplicationCard(provider: provider),
          ],
        const SizedBox(height: AppSpacing.sectionGap),

        AdminGroupHeader(
          icon: LucideIcons.badgeCheck,
          title: s.t('ورش معتمدة', 'Approved'),
          count: live.length,
          tone: AdminChipTone.good,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (live.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.store,
            message: s.t('لا ورش معتمدة بعد.', 'No approved workshops yet.'),
          )
        else
          for (final (i, provider) in live.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _RosterCard(provider: provider),
          ],
        if (stopped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          AdminGroupHeader(
            icon: LucideIcons.ban,
            title: s.t('موقوفة أو مرفوضة', 'Suspended or rejected'),
            count: stopped.length,
            tone: AdminChipTone.dim,
          ),
          const SizedBox(height: AppSpacing.headingGap),
          for (final (i, provider) in stopped.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _RosterCard(provider: provider),
          ],
        ],
      ],
    );
  }
}

/// One pending application, with everything the applicant submitted and the
/// two decisions the founder can make about it.
class _ApplicationCard extends ConsumerStatefulWidget {
  const _ApplicationCard({required this.provider});

  final ServiceProvider provider;

  @override
  ConsumerState<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends ConsumerState<_ApplicationCard> {
  ServiceProvider get provider => widget.provider;

  // Guards against a second tap firing a second `setStage` call before the
  // first one's response has updated the roster — without this, a founder
  // tapping twice in quick succession (or waiting on a slow connection and
  // tapping again) can submit two decisions whose audit trail both compute
  // their "before" state from the same stale local snapshot.
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final level = applicationUrgency(provider);

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
              UrgencyLabel(applicationWaitedLabel(s, provider), level: level),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Everything the applicant typed, so the decision is made on the
          // submission rather than on the workshop's name — including how to
          // actually reach them, which used to be missing here entirely.
          _Field(
            label: s.t('المرحلة', 'Stage'),
            value: provider.stage.label(s),
          ),
          PhoneField(provider: provider),
          _Field(
            label: s.t('رقم السجل التجاري', 'CR number'),
            value: provider.crNumber ?? s.t('غير مذكور', 'Not given'),
          ),
          _Field(
            label: s.t('الرقم الضريبي', 'VAT number'),
            // Absent is a fact, not a blank: Oman's VAT registration is
            // turnover-based, so plenty of real garages have none.
            value:
                provider.vatNumber ??
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
              s.t(
                'سبب الرفض السابق: ${provider.rejectionReason}',
                'Previously rejected: ${provider.rejectionReason}',
              ),
              style: context.text.bodySecondary.copyWith(
                height: 1.5,
                color: ak.inkSub,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (provider.crDocument != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: ak.inkSub),
                onPressed: () => _showDocument(context, provider),
                icon: const Icon(LucideIcons.fileText, size: 15),
                label: Text(s.t('فتح وثيقة السجل التجاري', 'Open CR document')),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'لم تُرفق وثيقة سجل تجاري — لا يمكن الاعتماد بلا وثيقة.',
                    'No CR document attached — approval needs one.',
                  ),
                  style: context.text.bodySecondary.copyWith(
                    color: ak.dangerText,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _showDocument(context, provider),
                    icon: const Icon(LucideIcons.upload, size: 15),
                    label: Text(
                      s.t(
                        'رفع وثيقة نيابةً عن الورشة',
                        'Upload on their behalf',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              InkPill(
                label: s.t('اعتماد', 'Approve'),
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg + 2,
                  vertical: AppSpacing.sm + 2,
                ),
                onTap: _submitting
                    ? () {}
                    : provider.crDocument == null
                    ? () => _needsDocument(context, s)
                    : () => _decide(stage: ProviderOnboardingStage.approved),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkPill(
                label: s.t('رفض', 'Reject'),
                outlined: true,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg + 2,
                  vertical: AppSpacing.sm + 2,
                ),
                onTap: _submitting
                    ? () {}
                    : () => _decide(stage: ProviderOnboardingStage.suspended),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _needsDocument(BuildContext context, S s) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'لا يمكن اعتماد ورشة بلا وثيقة سجل تجاري.',
              'A workshop cannot be approved without a CR document.',
            ),
          ),
        ),
      );

  /// The certificate itself, rendered from the bytes stored on the record —
  /// and, unlike the read-only view this replaced, a way for the founder to
  /// pick a fresh photo/scan and upload it *for* the applicant. Added for the
  /// illegible-scan case: rejecting a whole application just to ask for a
  /// clearer photo of the same real business was the only option before.
  ///
  /// A PDF still cannot be drawn without a decoder the app does not ship;
  /// [AttachmentDocumentCard] names the file and its size in that case rather
  /// than showing an empty frame that could pass for a checked document.
  void _showDocument(BuildContext context, ServiceProvider provider) =>
      showCrDocumentDialog(context, provider);

  Future<void> _decide({required ProviderOnboardingStage stage}) async {
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
    if (!mounted) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(adminActionsProvider)
          .setStage(provider.id, stage, reason: reason);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rejecting
              ? s.t(
                  'سُجِّل الرفض — سيرى صاحب الورشة السبب ويستطيع إعادة الإرسال.',
                  'Rejection recorded — the owner sees the reason and can re-submit.',
                )
              : s.t(
                  'اعتُمدت الورشة — تظهر الآن للعملاء وتستقبل الحجوزات.',
                  'Approved — the workshop is now visible to customers and takes bookings.',
                ),
        ),
      ),
    );
  }
}

/// The applicant's phone, with a call/WhatsApp button beside it once one is
/// known — the founder's only way to actually reach someone whose
/// application does not have a usable CR document, or whose photo needs a
/// follow-up question before a decision.
///
/// [ServiceProvider.ownerPhone] (the account/login phone) is preferred over
/// [ServiceProvider.phone] (the workshop's own published contact) because
/// the latter is almost always still null at this stage — it is only ever
/// set once the owner reaches "My workshop", which a pending applicant has
/// no access to yet.
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final phone = provider.ownerPhone ?? provider.phone;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              s.t('رقم الهاتف', 'Phone'),
              style: context.text.bodySecondary,
            ),
          ),
          Expanded(
            child: phone == null
                ? Text(
                    s.t('غير متاح', 'Not available'),
                    style: context.text.bodyPrimary.copyWith(height: 1.5),
                  )
                // A phone number reads left-to-right whatever the app
                // language is — under RTL, an un-directioned "+968 9200
                // 1234" renders with the dial code and digits reversed (same
                // fix `register_screen.dart`'s phone field already applies).
                : Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      phone,
                      textAlign: TextAlign.left,
                      style: context.text.bodyPrimary.copyWith(height: 1.5),
                    ),
                  ),
          ),
          if (phone != null) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.phone, size: 16, color: ak.inkSub),
              tooltip: s.t('اتصال', 'Call'),
              onPressed: () => Contact.call(context, phone),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                LucideIcons.messageCircle,
                size: 16,
                color: ak.success,
              ),
              tooltip: s.t('واتساب', 'WhatsApp'),
              onPressed: () => Contact.whatsapp(context, phone),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opens [CrDocumentDialog] — shared by the pending-application card and the
/// "manage workshop" profile screen, so a founder can view or replace the CR
/// certificate from either place.
void showCrDocumentDialog(BuildContext context, ServiceProvider provider) =>
    showDialog<void>(
      context: context,
      builder: (_) => CrDocumentDialog(provider: provider),
    );

/// The CR-document viewer, now with a way for the founder to pick a fresh
/// photo/scan and upload it in place of whatever the applicant submitted.
class CrDocumentDialog extends ConsumerStatefulWidget {
  const CrDocumentDialog({super.key, required this.provider});

  final ServiceProvider provider;

  @override
  ConsumerState<CrDocumentDialog> createState() => CrDocumentDialogState();
}

class CrDocumentDialogState extends ConsumerState<CrDocumentDialog> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _replace(ImageSource source) async {
    final s = S.of(context);
    setState(() => _busy = true);
    final result = await pickAttachments(_picker, source);
    if (!mounted) return;
    if (result.oversized > 0) showOversizedNotice(context, s, result);
    final picked = result.media.isEmpty ? null : result.media.first;
    if (picked == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      await ref
          .read(adminActionsProvider)
          .updateCrDocument(widget.provider.id, picked);
      // Only when the "manage workshop" screen for this exact provider is
      // open in this session — see `_ifBuilt` in `session_refresh.dart` for
      // why an unconditional `ref.invalidate` on a family provider would be
      // wrong here (it would build-then-fetch one that was never opened).
      final detail = adminWorkshopProfileProvider(widget.provider.id);
      if (ref.exists(detail)) ref.invalidate(detail);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('تم تحديث الوثيقة.', 'Document updated.'))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'تعذّر رفع الوثيقة — حاول مرة أخرى.',
              "Couldn't upload the document — try again.",
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = widget.provider;

    return AlertDialog(
      title: Text(s.t('وثيقة السجل التجاري', 'CR document')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${provider.name.of(s)} · ${provider.crNumber ?? ''}',
              style: context.text.bodyPrimary,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (provider.crDocument case final doc?)
              AttachmentDocumentCard(attachment: doc)
            else
              Text(
                s.t('لا توجد وثيقة مرفقة.', 'No document attached.'),
                style: context.text.bodySecondary,
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              s.t(
                'يمكنك رفع صورة أوضح أو مستند بديل نيابةً عن الورشة — مثلاً إذا كانت الصورة المرفقة غير واضحة.',
                "You can upload a clearer photo or a replacement on the workshop's behalf — e.g. if the attached scan is illegible.",
              ),
              style: context.text.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _replace(ImageSource.camera),
                    icon: const Icon(LucideIcons.camera, size: 16),
                    label: Text(s.t('تصوير', 'Camera')),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _replace(ImageSource.gallery),
                    icon: const Icon(LucideIcons.images, size: 16),
                    label: Text(s.t('من المعرض', 'Gallery')),
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: AppSpacing.sm),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(s.t('إغلاق', 'Close')),
        ),
      ],
    );
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
              hintText: s.t(
                'مثال: صورة السجل غير واضحة',
                'e.g. the CR image is not legible',
              ),
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
/// One workshop already on the roster — approved or stopped.
///
/// Same card shape as the rest of the panel: who it is at the top, the facts
/// about it as chips, and the two things you can do to it along the bottom.
class _RosterCard extends ConsumerWidget {
  const _RosterCard({required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final approved = provider.isApproved;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                IconTile(
                  LucideIcons.store,
                  size: 42,
                  radius: 14,
                  background: approved ? ak.successSoft : ak.surfaceDim,
                  foreground: approved ? ak.success : ak.inkFaint,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    provider.name.of(s),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.cardTitle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                approved
                    ? StatusBadge.good(s.t('معتمدة', 'Approved'))
                    : StatusBadge.bad(s.t('موقوفة', 'Suspended')),
              ],
            ),
          ),
          const AdminInsetDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: [
                    AdminMetaChip(
                      icon: LucideIcons.mapPin,
                      label: '${provider.area} · ${provider.region}',
                    ),
                    AdminMetaChip(
                      icon: provider.stage.icon,
                      tone: approved ? AdminChipTone.good : AdminChipTone.dim,
                      label: provider.stage.label(s),
                    ),
                  ],
                ),
                if (provider.rejectionReason != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: ak.surfaceDim,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ak.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.messageCircle,
                          size: 14,
                          color: ak.inkFaint,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          // The reason the owner was given, verbatim — this is
                          // the record of what they were told, not a summary
                          // of it.
                          child: Text(
                            provider.rejectionReason!,
                            style: context.text.bodySecondary.copyWith(
                              height: 1.5,
                              color: ak.inkSub,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const AdminInsetDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _toggle(context, ref, approved: approved),
                      icon: Icon(
                        approved ? LucideIcons.ban : LucideIcons.badgeCheck,
                        size: 16,
                      ),
                      label: Text(
                        approved
                            ? s.t('إيقاف', 'Suspend')
                            : s.t('إعادة الاعتماد', 'Re-approve'),
                      ),
                    ),
                  ),
                ),
                AdminCardAction(
                  icon: LucideIcons.settings2,
                  tooltip: s.t('إدارة', 'Manage'),
                  onTap: () => context.push('/admin/workshops/${provider.id}'),
                ),
              ],
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

    await ref
        .read(adminActionsProvider)
        .setStage(
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
          child: Text(
            value,
            style: context.text.bodyPrimary.copyWith(height: 1.5),
          ),
        ),
      ],
    ),
  );
}
