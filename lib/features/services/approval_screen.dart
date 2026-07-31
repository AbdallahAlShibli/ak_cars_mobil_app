import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/media/local_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// The customer's half of the escrow: review the workshop's proof, then
/// approve (release) or raise an issue (dispute).
///
/// Both buttons fire named escrow events; neither sets a state directly, so
/// this screen cannot produce a transition the table forbids.
class ApprovalScreen extends ConsumerStatefulWidget {
  const ApprovalScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends ConsumerState<ApprovalScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final request = ref
        .watch(requestsProvider)
        .where((r) => r.id == widget.requestId)
        .firstOrNull;

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('مراجعة', 'Review'))),
        body: Center(child: Text(s.t('الطلب غير موجود', 'Request not found'))),
      );
    }

    final config = ref.watch(appConfigProvider);
    final open = request.escrow == EscrowState.awaitingApproval;
    final proof = request.proof;
    final deadline = request.approvalDeadline(config.approvalWindow);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('اكتمل العمل — للمراجعة', 'Work completed — review')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            AppCard(
              child: Row(
                children: [
                  const IconTile(
                    Icons.fact_check_outlined,
                    background: AppColors.goodSoft,
                    foreground: AppColors.good,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.offering.provider.name.of(s),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          proof == null
                              ? s.t('لم يصل إثبات بعد', 'No proof yet')
                              : s.t(
                                  'رُفع الإثبات ${_when(s, proof.submittedAt)}',
                                  'Proof submitted ${_when(s, proof.submittedAt)}',
                                ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  open
                      ? StatusBadge.warn(s.t('بانتظارك', 'Awaiting you'))
                      : StatusBadge(request.escrow.label(s)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              s.t('إثبات الإنجاز من الورشة', 'Proof of work from the workshop'),
            ),
            const SizedBox(height: 9),
            _ProofBody(proof: proof),
            // The workshop's declaration, shown to the person it was made to.
            // The app cannot verify what is in a photo, so it says who claimed
            // what rather than asserting the part is genuine (spec §6).
            if (request.type == BookingType.customQuote && proof != null) ...[
              const SizedBox(height: 10),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      proof.includesPartBoxPhoto
                          ? Icons.inventory_2_outlined
                          : Icons.help_outline_rounded,
                      size: 17,
                      color: AppColors.ink3,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        proof.includesPartBoxPhoto
                            ? s.t(
                                'أقرّت الورشة بأن الإثبات يتضمن علبة القطعة أو ملصقها. راجعها قبل الموافقة.',
                                'The workshop declared that the proof includes the part’s box or label. Check it before approving.',
                              )
                            : s.t(
                                'لم تقرّ الورشة بإرفاق علبة القطعة. اسألها في المحادثة قبل الموافقة.',
                                'The workshop did not declare a photo of the part’s box. Ask them in the chat before approving.',
                              ),
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: AppColors.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (request.partWarrantyDays != null) ...[
                const SizedBox(height: 10),
                AppCard(
                  child: Text(
                    s.t(
                      'كفالة الورشة على القطعة: ${s.days(request.partWarrantyDays!)}. تبدأ بعد التحرير، وهي منفصلة عن ضمان الدفع الذي ينتهي بموافقتك.',
                      "Workshop's warranty on the part: ${s.days(request.partWarrantyDays!)}. It starts after release and is separate from the payment escrow, which ends with your approval.",
                    ),
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.6,
                      color: AppColors.ink3,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      s.t('المبلغ المُحرَّر', 'Total to release'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.ink2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${s.omr} ${request.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandDark,
                    ),
                  ),
                ],
              ),
            ),
            if (open && deadline != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  _deadlineLabel(s, deadline),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.ink3),
                ),
              ),
            ],
            if (request.escrow == EscrowState.disputed &&
                request.disputeNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('ملاحظتك', 'Your note'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.disputeNote,
                      style: const TextStyle(fontSize: 12.5, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: open ? AppColors.good : AppColors.ink3,
              ),
              onPressed: open && !_busy ? () => _approve(request) : null,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(
                open
                    ? s.t('الموافقة وتحرير الدفعة', 'Approve & release payment')
                    : request.escrow.label(s),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bad,
                side: const BorderSide(color: Color(0xFFF3D2D2), width: 1.5),
              ),
              onPressed: open && !_busy ? () => _raiseIssue(request) : null,
              child: Text(s.t('لديّ ملاحظة', 'I have an issue')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(ServiceRequest request) async {
    final s = S.of(context);
    setState(() => _busy = true);
    await ref
        .read(requestsProvider.notifier)
        .fire(request.id, EscrowEvent.approve, actor: EscrowActor.customer);
    if (!mounted) return;
    setState(() => _busy = false);
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'تم تحرير الدفعة للورشة — شكراً لك',
            'Payment released to the workshop — thank you',
          ),
        ),
      ),
    );
    context.go(AppFlags.startLocation);
  }

  /// A dispute without the customer's own words is a dispute the founder
  /// cannot resolve, so the note is required rather than optional.
  Future<void> _raiseIssue(ServiceRequest request) async {
    final s = S.of(context);
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _IssueSheet(s: s),
    );
    if (note == null || note.trim().isEmpty || !mounted) return;

    setState(() => _busy = true);
    await ref
        .read(requestsProvider.notifier)
        .fire(
          request.id,
          EscrowEvent.raiseIssue,
          actor: EscrowActor.customer,
          disputeNote: note.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'سُجّلت ملاحظتك — المبلغ ما زال محجوزاً حتى نراجع الطرفين',
            'Your note is logged — the funds stay held until we review both sides',
          ),
        ),
      ),
    );
    context.go('/track/${request.id}');
  }

  String _deadlineLabel(S s, DateTime deadline) {
    final left = deadline.difference(DateTime.now());
    if (left.isNegative) {
      return s.t(
        'انتهت المهلة — التحرير التلقائي جارٍ.',
        'The window has closed — the automatic release is running.',
      );
    }
    final hours = left.inHours;
    // Rounded up: with 71 hours left, "in 2 days" understates the window the
    // customer actually has.
    final days = (hours / 24).ceil();
    return hours >= 24
        ? s.t(
            'يُحرَّر تلقائياً خلال $days أيام إن لم تتخذ إجراءً',
            'Auto-releases in $days day(s) if you take no action',
          )
        : s.t(
            'يُحرَّر تلقائياً بعد $hours ساعة إن لم تتخذ إجراءً',
            'Auto-releases in $hours hours if you take no action',
          );
  }

  String _when(S s, DateTime at) {
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return s.t('الآن', 'just now');
    if (ago.inHours < 1) {
      return s.t('قبل ${ago.inMinutes} دقيقة', '${ago.inMinutes} min ago');
    }
    if (ago.inDays < 1) {
      return s.t('قبل ${ago.inHours} ساعة', '${ago.inHours}h ago');
    }
    return s.t('قبل ${ago.inDays} يوم', '${ago.inDays}d ago');
  }
}

/// Renders whatever the workshop actually submitted.
///
/// No placeholder tiles: a proof with notes but no photos says so, and a
/// booking with no proof at all says that. Drawing three grey rectangles that
/// look like photos would make an empty proof read as a loading failure.
class _ProofBody extends StatelessWidget {
  const _ProofBody({required this.proof});

  final ProofOfWork? proof;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (proof == null) {
      return AppCard(
        child: Text(
          s.t(
            'لم ترفع الورشة إثباتاً بعد.',
            'The workshop has not submitted any proof yet.',
          ),
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.ink3,
            height: 1.6,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (proof!.hasMedia)
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: proof!.media.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, i) => _ProofTile(media: proof!.media[i]),
            ),
          )
        else
          AppCard(
            child: Text(
              s.t(
                'لا توجد صور مرفقة — أرسلت الورشة ملاحظات مكتوبة فقط.',
                'No photos attached — the workshop submitted written notes only.',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink3,
                height: 1.6,
              ),
            ),
          ),
        if (proof!.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Text(
              proof!.notes,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.ink2,
                height: 1.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProofTile extends StatelessWidget {
  const _ProofTile({required this.media});

  final ProofMedia media;

  @override
  Widget build(BuildContext context) {
    // Two sources, both normal. A backend-hosted proof arrives as an https
    // URL; one the workshop shot on this device is still a local file, because
    // the pilot has no upload step yet. `localImage` is the conditional-import
    // shim that keeps `dart:io` out of the web build.
    final remote = media.uri.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 112,
        height: 86,
        child: remote
            ? Image.network(
                media.uri,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ProofTileFallback(),
              )
            : localImage(media.uri, onError: (_) => const _ProofTileFallback()),
      ),
    );
  }
}

class _ProofTileFallback extends StatelessWidget {
  const _ProofTileFallback();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.field,
    alignment: Alignment.center,
    child: const Icon(
      Icons.broken_image_outlined,
      size: 22,
      color: AppColors.ink3,
    ),
  );
}

class _IssueSheet extends StatefulWidget {
  const _IssueSheet({required this.s});

  final S s;

  @override
  State<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends State<_IssueSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('ما المشكلة؟', "What's wrong?"),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            s.t(
              'اكتبها بكلماتك — تصل كما هي إلى من سيراجع النزاع. يبقى المبلغ محجوزاً حتى ذلك الحين.',
              'In your own words — it reaches whoever reviews the dispute exactly as written. The funds stay held until then.',
            ),
            style: const TextStyle(fontSize: 12, color: AppColors.ink3),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text),
            child: Text(s.t('إرسال الملاحظة', 'Submit issue')),
          ),
        ],
      ),
    );
  }
}
