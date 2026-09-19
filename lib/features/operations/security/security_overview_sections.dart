import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/security_overview.dart';
import 'security_alerts_screen.dart';
import 'security_charts.dart';
import 'security_visuals.dart';

/// A titled card: the shell every dashboard section sits in.
class SecurityPanel extends StatelessWidget {
  const SecurityPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconTile(icon, size: 32, radius: 10),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.cardTitle),
                  if (subtitle != null)
                    Text(subtitle!, style: context.text.bodySecondary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    ),
  );
}

/// The addresses behind the most suspicious calls. Tapping one lists every
/// alert from it.
class TopAttackersPanel extends StatelessWidget {
  const TopAttackersPanel({super.key, required this.attackers});

  final List<Attacker> attackers;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return SecurityPanel(
      icon: LucideIcons.userX,
      title: s.t('أبرز المهاجمين', 'Top attackers'),
      subtitle: s.t('العناوين الأكثر نشاطاً', 'Most active addresses'),
      child: Column(
        children: [
          for (final (i, a) in attackers.indexed) ...[
            if (i > 0) Divider(height: AppSpacing.lg, color: ak.divider),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => SecurityAlertsScreen.open(context, ip: a.ip),
              child: _AttackerRow(attacker: a),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttackerRow extends StatelessWidget {
  const _AttackerRow({required this.attacker});

  final Attacker attacker;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final a = attacker;
    final place = [
      ?a.city,
      a.country ?? a.countryCode ?? s.t('موقع غير معروف', 'Unknown location'),
    ].join(', ');

    return Row(
      children: [
        FlagBadge(countryCode: a.countryCode),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.ip,
                textDirection: TextDirection.ltr,
                style: context.text.labelStrong.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySecondary,
              ),
              if (a.isp != null)
                Text(
                  a.isp!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySecondary.copyWith(
                    color: ak.inkFaint,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SeverityPill(a.worstSeverity, dense: true),
            const SizedBox(height: 4),
            Text(
              s.t('${a.events} طلب', '${a.events} calls'),
              style: AppTheme.numeric(size: 12, color: ak.inkSub),
            ),
          ],
        ),
      ],
    );
  }
}

/// The endpoints attackers went for.
class TopTargetsPanel extends StatelessWidget {
  const TopTargetsPanel({super.key, required this.targets});

  final List<TargetCount> targets;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final max = targets.fold<int>(0, (m, t) => t.events > m ? t.events : m);
    return SecurityPanel(
      icon: LucideIcons.crosshair,
      title: s.t('النقاط المستهدفة', 'Most targeted'),
      subtitle: s.t('ما الذي يحاولون الوصول إليه', 'What they are going for'),
      child: Column(
        children: [
          for (final t in targets)
            // Paths read left-to-right in either language.
            Directionality(
              textDirection: TextDirection.ltr,
              child: RankBar(
                leading: MethodBadge(method: t.method),
                label: t.path,
                value: t.events,
                max: max,
                color: ak.danger,
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the attacks came from, by country.
class TopCountriesPanel extends StatelessWidget {
  const TopCountriesPanel({super.key, required this.countries});

  final List<CountryCount> countries;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final max = countries.fold<int>(0, (m, c) => c.events > m ? c.events : m);
    return SecurityPanel(
      icon: LucideIcons.earth,
      title: s.t('مصادر الهجمات', 'Attack origins'),
      subtitle: s.t('حسب الدولة', 'By country'),
      child: Column(
        children: [
          for (final c in countries)
            RankBar(
              leading: FlagBadge(countryCode: c.countryCode, size: 32),
              label: c.country ?? c.countryCode ?? s.t('غير معروف', 'Unknown'),
              caption: s.t('${c.alerts} تنبيه', '${c.alerts} alerts'),
              value: c.events,
              max: max,
              color: ak.amberDeep,
            ),
        ],
      ),
    );
  }
}

/// An HTTP verb as a small coloured tag.
class MethodBadge extends StatelessWidget {
  const MethodBadge({super.key, required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final color = switch (method.toUpperCase()) {
      'GET' => ak.success,
      'POST' => ak.primary,
      'PUT' || 'PATCH' => ak.amberDeep,
      'DELETE' => ak.danger,
      _ => ak.inkSub,
    };
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// A country flag in a round badge (a globe when the country is unknown).
class FlagBadge extends StatelessWidget {
  const FlagBadge({super.key, required this.countryCode, this.size = 40});

  final String? countryCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        shape: BoxShape.circle,
        border: Border.all(color: ak.border),
      ),
      child: Text(
        flagEmoji(countryCode),
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}
