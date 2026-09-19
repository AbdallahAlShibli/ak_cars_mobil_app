import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/security_alert.dart';
import 'security_visuals.dart';

/// One alert as a card: what, how bad, from where, at what, with what, and how
/// often — everything needed to decide whether to open it.
class SecurityAlertCard extends StatelessWidget {
  const SecurityAlertCard({super.key, required this.alert});

  final SecurityAlertSummary alert;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final severity = severityColor(ak, alert.severity);

    return Opacity(
      opacity: alert.status.isActive ? 1 : 0.72,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/admin/security/${alert.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Severity stripe down the leading edge.
              Container(width: 4, color: severity),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(alert: alert, severity: severity),
                      const SizedBox(height: AppSpacing.md),
                      SecurityFactLine(
                        leading: Text(
                          flagEmoji(alert.countryCode),
                          style: const TextStyle(fontSize: 14),
                        ),
                        text: alert.place.isEmpty
                            ? alert.sourceIp
                            : '${alert.sourceIp}  ·  ${alert.place}',
                        mono: true,
                      ),
                      const SizedBox(height: 4),
                      SecurityFactLine(
                        leading: Icon(
                          LucideIcons.crosshair,
                          size: 14,
                          color: ak.inkSub,
                        ),
                        text: '${alert.targetMethod} ${alert.targetPath}',
                        mono: true,
                      ),
                      const SizedBox(height: 4),
                      SecurityFactLine(
                        leading: Icon(
                          deviceIcon(alert.deviceType),
                          size: 14,
                          color: ak.inkSub,
                        ),
                        text: [
                          deviceLabel(s, alert.deviceType),
                          ?alert.client,
                          if (alert.isAutomatedClient) s.t('آلي', 'automated'),
                        ].join('  ·  '),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.alert, required this.severity});

  final SecurityAlertSummary alert;
  final Color severity;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThreatIconTile(type: alert.type, severity: alert.severity, size: 40),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.title.of(s),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.cardTitle,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: AppSpacing.xs + 2,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SeverityPill(alert.severity, dense: true),
                  SecurityStatusChip(status: alert.status),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '×${alert.eventCount}',
              style: AppTheme.numeric(
                size: 16,
                weight: FontWeight.w800,
                color: severity,
              ),
            ),
            Text(
              agoLabel(s, alert.lastSeenAt),
              style: context.text.bodySecondary,
            ),
          ],
        ),
      ],
    );
  }
}

/// An icon (or flag) and one line of fact. [mono] for addresses and paths,
/// which read left-to-right even in Arabic.
class SecurityFactLine extends StatelessWidget {
  const SecurityFactLine({
    super.key,
    required this.leading,
    required this.text,
    this.mono = false,
  });

  final Widget leading;
  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      children: [
        SizedBox(width: 18, child: Center(child: leading)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: mono ? TextDirection.ltr : null,
            textAlign: TextAlign.start,
            style: context.text.bodySecondary.copyWith(
              color: ak.inkSub,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

class SecurityStatusChip extends StatelessWidget {
  const SecurityStatusChip({super.key, required this.status});

  final SecurityAlertStatus status;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return switch (status) {
      SecurityAlertStatus.resolved => StatusBadge.good(status.label(s)),
      SecurityAlertStatus.falsePositive => StatusBadge(status.label(s)),
      SecurityAlertStatus.investigating => StatusBadge.warn(status.label(s)),
      SecurityAlertStatus.open => StatusBadge.bad(status.label(s)),
    };
  }
}
