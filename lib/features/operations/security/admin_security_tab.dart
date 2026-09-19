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
import '../../../data/models/security_overview.dart';
import '../../../state/app_state.dart';
import '../admin_form_widgets.dart';
import '../admin_panel_widgets.dart';
import 'security_alert_card.dart';
import 'security_alerts_screen.dart';
import 'security_charts.dart';
import 'security_overview_sections.dart';
import 'security_visuals.dart';

/// The founder panel's Security tab: what the API's security monitor has seen.
///
/// Read top to bottom it answers, in order: how threatened are we right now
/// (the gauge), how much is going on (the tiles), when (the timeline), what
/// kind (the donut), who and from where (attackers, countries), at what
/// (targeted endpoints), and which alerts to open (the list).
class AdminSecurityTab extends ConsumerWidget {
  const AdminSecurityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final overview = ref.watch(securityOverviewProvider);
    final hours = ref.watch(securityWindowProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        AdminFilterRow<int>(
          selected: hours,
          onSelect: (value) =>
              ref.read(securityWindowProvider.notifier).state = value,
          filters: [
            AdminFilter(value: 24, label: s.t('٢٤ ساعة', '24 hours')),
            AdminFilter(value: 168, label: s.t('٧ أيام', '7 days')),
            AdminFilter(value: 720, label: s.t('٣٠ يوماً', '30 days')),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        ...overview.when(
          skipLoadingOnReload: true,
          data: (data) => _sections(context, data),
          loading: () => const [
            MetricSkeleton(count: 3),
            SizedBox(height: AppSpacing.lg),
            ListSkeleton(rows: 4, height: 120),
          ],
          error: (_, _) => [
            AdminErrorBlock(
              message: s.t(
                'تعذّر تحميل لوحة الأمان.',
                'Could not load the security dashboard.',
              ),
              onRetry: () => ref.invalidate(securityOverviewProvider),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _sections(BuildContext context, SecurityOverview data) {
    final s = S.of(context);
    const gap = SizedBox(height: AppSpacing.sectionGap);

    return [
      _ThreatHero(data: data),
      const SizedBox(height: AppSpacing.md),
      _KpiRow(data: data),
      gap,
      if (data.alertsInWindow == 0)
        EmptyState(
          icon: LucideIcons.shieldCheck,
          title: s.t('كل شيء هادئ', 'All quiet'),
          message: s.t(
            'لم يُرصد أي نشاط مريب في هذه الفترة. المراقبة تعمل على كل طلب يصل إلى الواجهة.',
            'No suspicious activity in this window. Every call to the API is being watched.',
          ),
        )
      else ...[
        SecurityPanel(
          icon: LucideIcons.activity,
          title: s.t('نشاط الهجمات', 'Attack activity'),
          subtitle: s.t(
            'الطلبات المريبة المسجّلة عبر الزمن',
            'Suspicious calls recorded over time',
          ),
          child: SecurityTimelineChart(
            buckets: data.timeline,
            hourly: data.hours <= 48,
          ),
        ),
        gap,
        SecurityPanel(
          icon: LucideIcons.chartPie,
          title: s.t('أنواع التهديدات', 'Threat mix'),
          subtitle: s.t('ماذا يحاول المهاجمون', 'What attackers are trying'),
          child: ThreatMixDonut(types: data.byType),
        ),
        gap,
        TopAttackersPanel(attackers: data.topAttackers),
        gap,
        TopTargetsPanel(targets: data.topTargets),
        gap,
        TopCountriesPanel(countries: data.topCountries),
        gap,
        SectionHeader(
          s.t('أحدث التنبيهات', 'Latest alerts'),
          action: s.t('عرض الكل', 'View all'),
          onAction: () => SecurityAlertsScreen.open(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (i, alert) in data.recent.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.itemGap),
          SecurityAlertCard(alert: alert),
        ],
      ],
      gap,
      const _HowItWorks(),
    ];
  }
}

class _ThreatHero extends StatelessWidget {
  const _ThreatHero({required this.data});

  final SecurityOverview data;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final tone = threatLevelColor(ak, data.threatLevel);

    return AppCard(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tone.withValues(alpha: 0.16), ak.surface],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(
                LucideIcons.shieldHalf,
                size: 40,
                radius: 14,
                foreground: tone,
                background: tone.withValues(alpha: 0.14),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('مركز الأمان', 'Security center'),
                      style: context.text.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.t(
                        'مستوى التهديد الحالي للواجهة',
                        'Current threat level for the API',
                      ),
                      style: context.text.bodySecondary,
                    ),
                  ],
                ),
              ),
              const _LiveDot(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ThreatGauge(score: data.threatScore, level: data.threatLevel),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _HeroFact(
                value: data.criticalOpen,
                label: s.t('حرجة مفتوحة', 'Critical open'),
                color: ak.danger,
              ),
              _HeroFact(
                value: data.highOpen,
                label: s.t('مرتفعة مفتوحة', 'High open'),
                color: ak.amberDeep,
              ),
              _HeroFact(
                value: data.openAlerts,
                label: s.t('كل المفتوحة', 'All open'),
                color: ak.ink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: AppTheme.numeric(
            size: 20,
            weight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.text.bodySecondary,
        ),
      ],
    ),
  );
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.data});

  final SecurityOverview data;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tiles = [
      (LucideIcons.siren, data.alertsInWindow, s.t('تنبيهات', 'Alerts')),
      (LucideIcons.zap, data.eventsInWindow, s.t('طلبات مريبة', 'Bad calls')),
      (LucideIcons.userX, data.uniqueAttackers, s.t('مهاجمون', 'Attackers')),
      (LucideIcons.earth, data.countries, s.t('دول', 'Countries')),
    ];
    return Row(
      children: [
        for (final (i, (icon, value, label)) in tiles.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _Kpi(icon: icon, value: value, label: label),
          ),
        ],
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ak.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: ak.inkSub),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value',
              style: AppTheme.numeric(
                size: 18,
                weight: FontWeight.w800,
                color: ak.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ak.success,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          s.t('مباشر', 'LIVE'),
          style: TextStyle(
            color: ak.success,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    return Text(
      s.t(
        'كل طلب يصل إلى الواجهة يُفحص بحثاً عن حقن SQL وXSS وتجاوز المسارات وأدوات الهجوم والتواقيع المزوّرة، '
            'ويُراقَب تكرار الأخطاء (رموز خاطئة، دخول محظور، تجاوز الحدود) من كل عنوان. '
            'تُحفظ التنبيهات ٩٠ يوماً، ويصلك إشعار فوري بأي تنبيه مرتفع أو حرج.',
        'Every call to the API is checked for SQL injection, XSS, path traversal, attack tools and forged '
            'signatures, and each address is watched for repeated failures (wrong codes, forbidden areas, '
            'rate limits). Alerts are kept for 90 days, and you get a push for anything High or Critical.',
      ),
      style: context.text.bodySecondary.copyWith(
        color: ak.inkFaint,
        height: 1.5,
      ),
    );
  }
}
