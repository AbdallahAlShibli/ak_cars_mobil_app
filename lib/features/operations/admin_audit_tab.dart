import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import 'admin_panel_widgets.dart';

/// The audit trail (§6), filterable by subject.
///
/// Read-only by construction: there is no control on this screen that writes a
/// line, because every line is written by the action it records. A log you can
/// edit is a log, not an audit trail — which is also why the summary card here
/// is the one in the panel with no action button.
class AdminAuditTab extends ConsumerStatefulWidget {
  const AdminAuditTab({super.key});

  @override
  ConsumerState<AdminAuditTab> createState() => _AdminAuditTabState();
}

class _AdminAuditTabState extends ConsumerState<AdminAuditTab> {
  AuditSubjectType? _filter;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final all = ref.watch(auditLogProvider);
    final entries = all.ofType(_filter);

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final today = all.where((e) => !e.at.isBefore(startOfToday)).length;
    final subjects = {
      for (final e in all) '${e.subjectType.name}:${e.subjectId}',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        AdminSummaryCard(
          icon: LucideIcons.scrollText,
          title: s.t('السجل', 'Audit log'),
          subtitle: s.t('من غيّر ماذا، ومتى.', 'Who changed what, and when.'),
          stats: [
            AdminStat.count(all.length, label: s.t('إجمالي', 'Entries')),
            AdminStat.count(today, label: s.t('اليوم', 'Today')),
            AdminStat.count(
              subjects.length,
              label: s.t('سجلات متأثرة', 'Records touched'),
            ),
          ],
          footnote: s.t(
            'لا يمكن تحرير هذا السجل — كل سطر يكتبه الإجراء الذي يسجّله.',
            'Nothing here can be edited — each line is written by the action '
                'it records.',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminFilterRow<AuditSubjectType?>(
          selected: _filter,
          onSelect: (value) => setState(() => _filter = value),
          filters: [
            AdminFilter(
              value: null,
              label: s.t('الكل', 'All'),
              count: all.length,
            ),
            for (final type in AuditSubjectType.values)
              AdminFilter(
                value: type,
                label: type.label(s),
                count: all.ofType(type).length,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (entries.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.scrollText,
            message: s.t(
              'لا سجلات في هذا التصنيف بعد.',
              'Nothing recorded under this filter yet.',
            ),
          )
        else
          for (final (i, entry) in entries.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _AuditCard(entry: entry),
          ],
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final moved = entry.fromState != null || entry.toState != null;

    return AppCard(
      color: ak.surfaceDim,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                _icon(entry.subjectType),
                size: 34,
                radius: 12,
                background: ak.surface,
                foreground: ak.inkSub,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // The machine key, verbatim. This is an audit trail, and
                      // a prettified sentence is a translation of the record
                      // rather than the record.
                      entry.action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelStrong,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.subjectType.label(s)} ${entry.subjectId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySecondary.copyWith(
                        color: ak.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs + 2,
            children: [
              AdminMetaChip(
                icon: LucideIcons.clock,
                tone: AdminChipTone.dim,
                label: _stamp(entry.at),
              ),
              AdminMetaChip(
                icon: LucideIcons.user,
                label: entry.actor.label.of(s),
              ),
              if (moved)
                AdminMetaChip(
                  icon: LucideIcons.arrowLeftRight,
                  label: '${entry.fromState ?? '—'} → ${entry.toState ?? '—'}',
                ),
            ],
          ),
          if (entry.note != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: ak.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ak.border),
              ),
              child: Text(
                entry.note!,
                style: context.text.bodySecondary.copyWith(
                  height: 1.5,
                  color: ak.inkSub,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One icon per kind of record, so a filtered log still reads as a list of
  /// different things rather than a wall of identical rows.
  static IconData _icon(AuditSubjectType type) => switch (type) {
    AuditSubjectType.booking => LucideIcons.clipboardList,
    AuditSubjectType.provider => LucideIcons.store,
    AuditSubjectType.offer => LucideIcons.tag,
    AuditSubjectType.payout => LucideIcons.banknote,
    AuditSubjectType.inventory => LucideIcons.boxes,
    AuditSubjectType.staff => LucideIcons.users,
    AuditSubjectType.customer => LucideIcons.contact,
  };

  static String _stamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
