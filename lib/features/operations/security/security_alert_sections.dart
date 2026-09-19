import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/security_alert_detail.dart';
import 'security_alert_card.dart';
import 'security_charts.dart';
import 'security_overview_sections.dart';
import 'security_visuals.dart';

/// The sections of one alert's page: where it came from, what it came with,
/// what it went for, whose session it used, the calls themselves, and what
/// else the same address has done.

TextStyle _mono(BuildContext context) =>
    context.text.bodySecondary.copyWith(fontFamily: 'monospace', height: 1.45);

Future<void> copyToClipboard(BuildContext context, String text) async {
  final s = S.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(SnackBar(content: Text(s.t('تم النسخ', 'Copied'))));
}

Color statusColor(AkColors ak, int status) => switch (status) {
  >= 500 => ak.danger,
  >= 400 => ak.amberDeep,
  >= 300 => ak.inkSub,
  _ => ak.success,
};

/// A label on the start side, a value on the end side.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ak.inkFaint),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: Text(label, style: context.text.bodySecondary),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: mono ? TextDirection.ltr : null,
              textAlign: TextAlign.end,
              style: mono
                  ? _mono(context).copyWith(color: ak.ink)
                  : context.text.labelStrong,
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(LucideIcons.copy, size: 15, color: ak.inkSub),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OriginSection extends StatelessWidget {
  const OriginSection({super.key, required this.detail});

  final SecurityAlertDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final l = detail.location;
    final place = [?l.city, ?l.region, ?(l.country ?? l.countryCode)].join(', ');

    return SecurityPanel(
      icon: LucideIcons.mapPinned,
      title: s.t('مصدر الهجوم', 'Where it came from'),
      subtitle: s.t(
        'العنوان والموقع ومزوّد الخدمة',
        'Address, location and network',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (l.hasCoordinates) ...[
            AttackPathMap(
              latitude: l.latitude!,
              longitude: l.longitude!,
              color: severityColor(ak, detail.alert.severity),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.t(
                'المسار من المهاجم إلى خادم AK Cars في مسقط',
                'Path from the attacker to the AK Cars server in Muscat',
              ),
              textAlign: TextAlign.center,
              style: context.text.bodySecondary.copyWith(color: ak.inkFaint),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              FlagBadge(countryCode: l.countryCode, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.ip,
                      textDirection: TextDirection.ltr,
                      style: AppTheme.numeric(
                        size: 18,
                        weight: FontWeight.w800,
                        color: ak.ink,
                      ),
                    ),
                    Text(
                      place.isEmpty
                          ? s.t('الموقع غير معروف', 'Location unknown')
                          : place,
                      style: context.text.bodySecondary,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: s.t('نسخ العنوان', 'Copy address'),
                icon: Icon(LucideIcons.copy, size: 18, color: ak.inkSub),
                onPressed: () => copyToClipboard(context, l.ip),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (l.isp != null)
            _Fact(
              icon: LucideIcons.server,
              label: s.t('المزوّد', 'Network'),
              value: l.isp!,
            ),
          if (l.asn != null)
            _Fact(
              icon: LucideIcons.network,
              label: 'ASN',
              value: l.asn!,
              mono: true,
            ),
          if (l.timeZone != null)
            _Fact(
              icon: LucideIcons.clock,
              label: s.t('المنطقة الزمنية', 'Time zone'),
              value: l.timeZone!,
              mono: true,
            ),
          if (l.hasCoordinates)
            _Fact(
              icon: LucideIcons.navigation,
              label: s.t('الإحداثيات', 'Coordinates'),
              value:
                  '${l.latitude!.toStringAsFixed(4)}, ${l.longitude!.toStringAsFixed(4)}',
              mono: true,
            ),
          const SizedBox(height: AppSpacing.md),
          _OriginLinks(location: l),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.t(
              'الموقع تقديري ويُستنتج من عنوان IP. قد يخفي المهاجم موقعه الحقيقي عبر VPN أو خادم وسيط.',
              "Location is estimated from the IP address. An attacker behind a VPN or proxy shows that server's location, not their own.",
            ),
            style: context.text.bodySecondary.copyWith(
              color: ak.inkFaint,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginLinks extends StatelessWidget {
  const _OriginLinks({required this.location});

  final SecurityLocation location;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final l = location;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (l.hasCoordinates)
          OutlinedButton.icon(
            icon: const Icon(LucideIcons.map, size: 16),
            label: Text(s.t('فتح في الخرائط', 'Open in Maps')),
            onPressed: () => launchUrl(
              Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${l.latitude},${l.longitude}',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(LucideIcons.externalLink, size: 16),
          label: Text(s.t('سمعة العنوان', 'Check reputation')),
          onPressed: () => launchUrl(
            Uri.parse(
              'https://www.abuseipdb.com/check/${Uri.encodeComponent(l.ip)}',
            ),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}

class DeviceSection extends StatelessWidget {
  const DeviceSection({super.key, required this.device});

  final SecurityDevice device;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final tone = device.isAutomatedClient ? ak.danger : ak.success;
    return SecurityPanel(
      icon: LucideIcons.cpu,
      title: s.t('الجهاز والأداة', 'Device and tool'),
      subtitle: s.t('كما عرّف المتصل نفسه', 'As the caller described itself'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ak.surfaceDim, ak.surface],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ak.border),
                ),
                child: Icon(
                  deviceIcon(device.deviceType),
                  size: 30,
                  color: ak.ink,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceLabel(s, device.deviceType),
                      style: context.text.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          device.isAutomatedClient
                              ? LucideIcons.bot
                              : LucideIcons.user,
                          size: 14,
                          color: tone,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          device.isAutomatedClient
                              ? s.t('عميل آلي / سكربت', 'Automated client')
                              : s.t('متصفح أو تطبيق', 'Browser or app'),
                          style: context.text.bodySecondary.copyWith(
                            color: tone,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Fact(
            icon: LucideIcons.layers,
            label: s.t('النظام', 'System'),
            value: device.operatingSystem ?? s.t('غير معروف', 'Unknown'),
          ),
          _Fact(
            icon: LucideIcons.appWindow,
            label: s.t('العميل', 'Client'),
            value: device.client ?? s.t('غير معروف', 'Unknown'),
          ),
          if (device.userAgent != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _CodeBox(label: 'User-Agent', text: device.userAgent!),
          ],
        ],
      ),
    );
  }
}

class TargetSection extends StatelessWidget {
  const TargetSection({super.key, required this.detail});

  final SecurityAlertDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final max = detail.targets.fold<int>(
      0,
      (m, t) => t.events > m ? t.events : m,
    );
    return SecurityPanel(
      icon: LucideIcons.crosshair,
      title: s.t('ماذا استهدف', 'What it went for'),
      subtitle: s.t(
        'النقاط والقواعد التي أطلقت التنبيه',
        'Endpoints hit and the rules that fired',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in detail.targets.take(8))
            Directionality(
              textDirection: TextDirection.ltr,
              child: RankBar(
                leading: MethodBadge(method: t.method),
                label: t.path,
                value: t.events,
                max: max,
                color: severityColor(ak, detail.alert.severity),
              ),
            ),
          if (detail.rules.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              s.t('قواعد الكشف', 'Detection rules'),
              style: context.text.labelStrong,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs + 2,
              children: [
                for (final entry in detail.rules.entries)
                  _Tag(text: '${entry.key} × ${entry.value}', color: ak.inkSub),
              ],
            ),
          ],
          if (detail.responses.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              s.t('ردود الخادم', 'Server responses'),
              style: context.text.labelStrong,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs + 2,
              children: [
                for (final entry in detail.responses.entries)
                  _Tag(
                    text: 'HTTP ${entry.key} × ${entry.value}',
                    color: statusColor(ak, entry.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.t(
                'رد 2xx يعني أن الواجهة أجابت على الطلب — تأكد من أن الإجابة لم تكشف ما لا ينبغي.',
                'A 2xx means the API answered the call — worth checking the answer revealed nothing it should not.',
              ),
              style: context.text.bodySecondary.copyWith(color: ak.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.account});

  final SecurityAccount account;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SecurityPanel(
      icon: LucideIcons.userRound,
      title: s.t('الحساب المستخدم', 'Account used'),
      subtitle: s.t(
        'حملت الطلبات جلسة هذا الحساب',
        "The calls carried this account's session",
      ),
      child: Column(
        children: [
          _Fact(
            icon: LucideIcons.user,
            label: s.t('الاسم', 'Name'),
            value: account.name ?? s.t('حساب محذوف', 'Deleted account'),
          ),
          if (account.phone != null)
            _Fact(
              icon: LucideIcons.phone,
              label: s.t('الهاتف', 'Phone'),
              value: account.phone!,
              mono: true,
            ),
          if (account.kind != null)
            _Fact(
              icon: LucideIcons.badgeInfo,
              label: s.t('النوع', 'Kind'),
              value: account.kind == 'workshop'
                  ? s.t('ورشة', 'Workshop')
                  : s.t('عميل', 'Customer'),
            ),
          _Fact(
            icon: LucideIcons.hash,
            label: s.t('المعرّف', 'User ID'),
            value: account.userId,
            mono: true,
            onCopy: () => copyToClipboard(context, account.userId),
          ),
        ],
      ),
    );
  }
}

/// The calls themselves, newest first, each expandable to its full evidence.
class EvidenceSection extends StatelessWidget {
  const EvidenceSection({super.key, required this.detail});

  final SecurityAlertDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final shown = detail.events.length;
    final kept = detail.eventsStored;
    final total = detail.alert.eventCount;
    return SecurityPanel(
      icon: LucideIcons.fileSearch,
      title: s.t('سجل الأدلة', 'Evidence log'),
      subtitle: s.t(
        'آخر $shown من $kept محفوظة · $total طلب إجمالاً',
        'Latest $shown of $kept kept · $total calls in all',
      ),
      // Its own Material: the expansion tiles paint their ink on the nearest
      // one, and the card's coloured box would otherwise hide it.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (i, event) in detail.events.indexed) ...[
              if (i > 0) Divider(height: 1, color: ak.divider),
              _EventTile(event: event, initiallyExpanded: i == 0),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.initiallyExpanded});

  final SecurityEvent event;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: statusColor(ak, event.statusCode),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          '${event.method} ${event.path}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: _mono(
            context,
          ).copyWith(color: ak.ink, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${stamp(event.at)}  ·  HTTP ${event.statusCode}  ·  ${event.rule}',
          style: context.text.bodySecondary,
        ),
        children: [
          if (event.evidence != null)
            _CodeBox(
              label: s.t('الدليل', 'Evidence'),
              text: event.evidence!,
              tone: ak.danger,
            ),
          if (event.queryString != null)
            _CodeBox(label: 'Query', text: event.queryString!),
          if (event.referer != null)
            _CodeBox(label: 'Referer', text: event.referer!),
          if (event.headers.isNotEmpty)
            _CodeBox(
              label: s.t('الترويسات', 'Headers'),
              text: event.headers.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n'),
            ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Tag(text: '${event.durationMs} ms', color: ak.inkSub),
              if (event.traceId != null)
                _Tag(text: 'trace ${event.traceId}', color: ak.inkSub),
            ],
          ),
        ],
      ),
    );
  }
}

class RelatedSection extends StatelessWidget {
  const RelatedSection({super.key, required this.detail});

  final SecurityAlertDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return SecurityPanel(
      icon: LucideIcons.link,
      title: s.t('نشاط آخر من هذا العنوان', 'More from this address'),
      subtitle: detail.location.ip,
      child: Column(
        children: [
          for (final (i, r) in detail.related.indexed) ...[
            if (i > 0) Divider(height: AppSpacing.lg, color: ak.divider),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/admin/security/${r.id}'),
              child: Row(
                children: [
                  ThreatIconTile(type: r.type, severity: r.severity, size: 34),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title.of(s), style: context.text.labelStrong),
                        Text(
                          '×${r.eventCount}  ·  ${agoLabel(s, r.lastSeenAt)}',
                          style: context.text.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  SecurityStatusChip(status: r.status),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.label, required this.text, this.tone});

  final String label;
  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: context.text.bodySecondary)),
              InkWell(
                onTap: () => copyToClipboard(context, text),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(LucideIcons.copy, size: 14, color: ak.inkSub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: ak.surfaceDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tone ?? ak.border),
            ),
            child: SelectableText(
              text,
              textDirection: TextDirection.ltr,
              style: _mono(context).copyWith(color: ak.ink, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      text,
      textDirection: TextDirection.ltr,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
      ),
    ),
  );
}
