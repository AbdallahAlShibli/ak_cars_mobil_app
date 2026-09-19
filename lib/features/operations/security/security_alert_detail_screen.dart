import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/security_alert.dart';
import '../../../data/models/security_alert_detail.dart';
import '../../../state/app_state.dart';
import '../admin_form_widgets.dart';
import 'security_alert_card.dart';
import 'security_alert_sections.dart';
import 'security_visuals.dart';

/// One security alert in full — `/admin/security/:alertId`, which is also
/// where a founder's security push notification lands.
class SecurityAlertDetailScreen extends ConsumerWidget {
  const SecurityAlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final detail = ref.watch(securityAlertDetailProvider(alertId));
    final loaded = detail.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('تفاصيل التنبيه', 'Alert details')),
        actions: [
          if (loaded != null)
            IconButton(
              tooltip: s.t('نسخ تقرير', 'Copy report'),
              icon: const Icon(LucideIcons.clipboardCopy),
              onPressed: () => copyToClipboard(context, _report(loaded)),
            ),
        ],
      ),
      body: detail.when(
        skipLoadingOnReload: true,
        data: (d) => _Body(detail: d),
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenMargin),
          child: ListSkeleton(rows: 4, height: 160),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: AdminErrorBlock(
            message: s.t('تعذّر تحميل التنبيه.', 'Could not load this alert.'),
            onRetry: () => ref.invalidate(securityAlertDetailProvider(alertId)),
          ),
        ),
      ),
      bottomNavigationBar: loaded == null
          ? null
          : _ActionBar(alert: loaded.alert),
    );
  }

  /// A plain-text summary to paste into an abuse report or a message.
  static String _report(SecurityAlertDetail d) {
    final a = d.alert;
    final l = d.location;
    final evidence = d.events.isEmpty ? null : d.events.first.evidence;
    return [
      'AK Cars security alert — ${a.title.en}',
      'Severity: ${a.severity.name} · Status: ${a.status.name}',
      'Source IP: ${l.ip}',
      'Location: ${[?l.city, ?l.region, ?l.country].join(', ')}',
      if (l.isp != null) 'Network: ${l.isp} ${l.asn ?? ''}',
      'Target: ${a.targetMethod} ${a.targetPath}',
      'Client: ${d.device.client ?? d.device.deviceType} '
          '(${d.device.operatingSystem ?? 'unknown OS'})',
      if (d.device.userAgent != null) 'User-Agent: ${d.device.userAgent}',
      'Calls: ${a.eventCount}',
      'First seen: ${stamp(a.firstSeenAt)} · Last seen: ${stamp(a.lastSeenAt)}',
      if (evidence != null) 'Evidence: $evidence',
    ].join('\n');
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final SecurityAlertDetail detail;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.sectionGap);
    final account = detail.account;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        _Hero(detail: detail),
        gap,
        _WhatHappened(detail: detail),
        gap,
        OriginSection(detail: detail),
        gap,
        DeviceSection(device: detail.device),
        gap,
        TargetSection(detail: detail),
        if (account != null) ...[gap, AccountSection(account: account)],
        if (detail.events.isNotEmpty) ...[
          gap,
          EvidenceSection(detail: detail),
        ],
        if (detail.related.isNotEmpty) ...[
          gap,
          RelatedSection(detail: detail),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail});

  final SecurityAlertDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final a = detail.alert;
    final tone = severityColor(ak, a.severity);
    final span = a.lastSeenAt.difference(a.firstSeenAt);

    return AppCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tone.withValues(alpha: 0.18), ak.surface],
      ),
      border: Border.all(color: tone.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThreatIconTile(type: a.type, severity: a.severity, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title.of(s), style: context.text.screenTitle),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Wrap(
                      spacing: AppSpacing.xs + 2,
                      runSpacing: AppSpacing.xs,
                      children: [
                        SeverityPill(a.severity),
                        SecurityStatusChip(status: a.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            a.summary,
            textDirection: TextDirection.ltr,
            style: context.text.bodySecondary.copyWith(
              color: ak.ink,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _HeroStat(
                value: '${a.eventCount}',
                label: s.t('طلب', 'Calls'),
                color: tone,
              ),
              _HeroStat(
                value: agoLabel(s, a.firstSeenAt),
                label: s.t('أول ظهور', 'First seen'),
              ),
              _HeroStat(
                value: agoLabel(s, a.lastSeenAt),
                label: s.t('آخر ظهور', 'Last seen'),
              ),
              _HeroStat(
                value: _duration(s, span),
                label: s.t('المدة', 'Span'),
              ),
            ],
          ),
          if (detail.note != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: ak.surfaceDim,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.stickyNote, size: 16, color: ak.inkSub),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(detail.note!, style: context.text.bodyPrimary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _duration(S s, Duration d) {
    if (d.inMinutes < 1) return s.t('${d.inSeconds} ث', '${d.inSeconds}s');
    if (d.inHours < 1) return s.t('${d.inMinutes} د', '${d.inMinutes}m');
    if (d.inDays < 1) return s.t('${d.inHours} س', '${d.inHours}h');
    return s.t('${d.inDays} ي', '${d.inDays}d');
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTheme.numeric(
                size: 16,
                weight: FontWeight.w800,
                color: color ?? ak.ink,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _WhatHappened extends StatelessWidget {
  const _WhatHappened({required this.detail});

  final SecurityAlertDetail detail;

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
              const IconTile(LucideIcons.info, size: 32, radius: 10),
              const SizedBox(width: AppSpacing.md),
              Text(
                s.t('ماذا حدث', 'What happened'),
                style: context.text.cardTitle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            detail.explanation.of(s),
            style: context.text.bodyPrimary.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: ak.amberBgSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ak.amberBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lightbulb, size: 18, color: ak.amberText),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.t('الإجراء المقترح', 'What to do'),
                        style: context.text.labelStrong.copyWith(
                          color: ak.amberText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.advice.of(s),
                        style: context.text.bodySecondary.copyWith(
                          color: ak.amberText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Triage: the only thing the founder can change about an alert.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.alert});

  final SecurityAlertSummary alert;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  Future<void> _move(SecurityAlertStatus status) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final note = await _askNote(status);
    if (note == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await setSecurityAlertStatus(
        ref,
        widget.alert.id,
        status,
        note: note.isEmpty ? null : note,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.t('تم التحديث: ${status.label(s)}', 'Updated: ${status.label(s)}'),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.t('تعذّر تحديث التنبيه.', 'Could not update the alert.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The note to attach, "" for none, or null when the founder backed out.
  Future<String?> _askNote(SecurityAlertStatus status) async {
    final s = S.of(context);
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(status.label(s)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: s.t(
                'ملاحظة (اختياري) — مثلاً: حُظر في Cloudflare',
                'Note (optional) — e.g. blocked at Cloudflare',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(s.t('تأكيد', 'Confirm')),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final status = widget.alert.status;

    final actions = <Widget>[
      if (status == SecurityAlertStatus.open)
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _move(SecurityAlertStatus.investigating),
          child: Text(s.t('تحقيق', 'Investigate')),
        ),
      if (status.isActive) ...[
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _move(SecurityAlertStatus.falsePositive),
          child: Text(s.t('إنذار كاذب', 'False alarm')),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _move(SecurityAlertStatus.resolved),
          child: Text(s.t('معالجة', 'Resolve')),
        ),
      ] else
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _move(SecurityAlertStatus.open),
          icon: const Icon(LucideIcons.rotateCcw, size: 16),
          label: Text(s.t('إعادة فتح', 'Reopen')),
        ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.sm,
          AppSpacing.screenMargin,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: ak.surface,
          border: Border(top: BorderSide(color: ak.border)),
        ),
        child: Row(
          children: [
            for (final (i, action) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: SizedBox(height: 44, child: action)),
            ],
          ],
        ),
      ),
    );
  }
}
