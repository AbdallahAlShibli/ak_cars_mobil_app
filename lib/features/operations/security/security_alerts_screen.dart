import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/security_alert.dart';
import '../../../state/app_state.dart';
import '../admin_form_widgets.dart';
import '../admin_panel_widgets.dart';
import 'security_alert_card.dart';

/// Every security alert, newest activity first — filterable by where the
/// founder has got to with it and by how bad it is, or narrowed to one
/// attacker's address.
class SecurityAlertsScreen extends ConsumerStatefulWidget {
  const SecurityAlertsScreen({super.key, this.ip});

  /// When set, only this address's alerts.
  final String? ip;

  static Future<void> open(BuildContext context, {String? ip}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SecurityAlertsScreen(ip: ip)),
      );

  @override
  ConsumerState<SecurityAlertsScreen> createState() =>
      _SecurityAlertsScreenState();
}

class _SecurityAlertsScreenState extends ConsumerState<SecurityAlertsScreen> {
  // Looking at one attacker means everything from it, closed alerts included.
  late String? _status = widget.ip == null ? 'active' : null;
  SecuritySeverity? _severity;

  SecurityAlertFilter get _filter =>
      (status: _status, severity: _severity, ip: widget.ip);

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 400) {
      ref.read(securityAlertListProvider(_filter).notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final list = ref.watch(securityAlertListProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ip == null
              ? s.t('تنبيهات الأمان', 'Security alerts')
              : s.t('تنبيهات العنوان', 'Alerts from address'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(securityAlertListProvider(_filter));
          await ref.read(securityAlertListProvider(_filter).future);
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.lg,
              AppSpacing.screenMargin,
              AppSpacing.xxl,
            ),
            children: [
              if (widget.ip != null) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AdminMetaChip(
                    icon: LucideIcons.userX,
                    label: widget.ip,
                    tone: AdminChipTone.warn,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AdminFilterRow<String?>(
                selected: _status,
                onSelect: (value) => setState(() => _status = value),
                filters: [
                  AdminFilter(value: 'active', label: s.t('نشطة', 'Active')),
                  AdminFilter(
                    value: SecurityAlertStatus.resolved.name,
                    label: SecurityAlertStatus.resolved.label(s),
                  ),
                  AdminFilter(
                    value: SecurityAlertStatus.falsePositive.name,
                    label: SecurityAlertStatus.falsePositive.label(s),
                  ),
                  AdminFilter(value: null, label: s.t('الكل', 'All')),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AdminFilterRow<SecuritySeverity?>(
                selected: _severity,
                onSelect: (value) => setState(() => _severity = value),
                filters: [
                  AdminFilter(
                    value: null,
                    label: s.t('كل الدرجات', 'Any severity'),
                  ),
                  for (final severity in SecuritySeverity.values.reversed)
                    AdminFilter(value: severity, label: severity.label(s)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ...list.when(
                skipLoadingOnReload: true,
                data: (data) => [
                  Text(
                    s.t('${data.total} تنبيه', '${data.total} alerts'),
                    style: context.text.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.items.isEmpty)
                    EmptyState(
                      compact: true,
                      icon: LucideIcons.shieldCheck,
                      message: s.t(
                        'لا توجد تنبيهات بهذا التصنيف.',
                        'No alerts match this filter.',
                      ),
                    ),
                  for (final (i, alert) in data.items.indexed) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.itemGap),
                    SecurityAlertCard(alert: alert),
                  ],
                  if (data.loadingMore)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: ak.inkSub,
                          ),
                        ),
                      ),
                    ),
                ],
                loading: () => const [ListSkeleton(rows: 5, height: 130)],
                error: (_, _) => [
                  AdminErrorBlock(
                    message: s.t(
                      'تعذّر تحميل التنبيهات.',
                      'Could not load the alerts.',
                    ),
                    onRetry: () =>
                        ref.invalidate(securityAlertListProvider(_filter)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
