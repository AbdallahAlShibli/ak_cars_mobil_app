import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/provider_dashboard_state.dart';
import 'staff_editor_sheet.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final staff = ref.watch(workshopStaffProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('الفريق', 'Staff'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showStaffEditorSheet(context),
        child: const Icon(LucideIcons.userPlus),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(workshopStaffProvider.notifier).refresh(),
          child: staff.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: const [ListSkeleton()],
            ),
            error: (error, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                EmptyState(
                  icon: LucideIcons.circleAlert,
                  message: s.t('تعذّر تحميل الفريق.', 'Couldn\'t load staff.'),
                  action: FilledButton(
                    onPressed: () =>
                        ref.read(workshopStaffProvider.notifier).refresh(),
                    child: Text(s.t('إعادة المحاولة', 'Retry')),
                  ),
                ),
              ],
            ),
            data: (list) {
              final active = [
                for (final m in list)
                  if (m.isActive) m,
              ];
              final inactive = [
                for (final m in list)
                  if (!m.isActive) m,
              ];
              if (list.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  children: [
                    EmptyState(
                      icon: LucideIcons.users,
                      title: s.t('لا فريق بعد', 'No team members yet'),
                      message: s.t(
                        'أضف أول عضو في فريق الورشة.',
                        'Add the first member of your workshop\'s team.',
                      ),
                      action: FilledButton.icon(
                        onPressed: () => showStaffEditorSheet(context),
                        icon: const Icon(LucideIcons.userPlus, size: 16),
                        label: Text(s.t('إضافة', 'Add')),
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                children: [
                  for (final member in active)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _StaffRow(member: member),
                    ),
                  if (inactive.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SectionHeader(s.t('غير نشِط', 'Inactive')),
                    const SizedBox(height: AppSpacing.sm),
                    for (final member in inactive)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _StaffRow(member: member),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StaffRow extends ConsumerWidget {
  const _StaffRow({required this.member});

  final WorkshopStaff member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Opacity(
      opacity: member.isActive ? 1 : 0.55,
      child: AppCard(
        child: Row(
          children: [
            IconTile(
              member.role.icon,
              background: ak.surfaceDim,
              foreground: ak.ink,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${member.role.label(s)}'
                    '${member.specialties.isEmpty ? '' : ' · ${member.specialties.join(', ')}'}',
                    style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                  ),
                  if (member.openJobCount > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      s.t(
                        '${member.openJobCount} طلبات مفتوحة',
                        '${member.openJobCount} open jobs',
                      ),
                      style: TextStyle(fontSize: 11, color: ak.inkFaint),
                    ),
                  ],
                ],
              ),
            ),
            if (member.isActive)
              PopupMenuButton<String>(
                onSelected: (action) async {
                  switch (action) {
                    case 'edit':
                      await showStaffEditorSheet(context, existing: member);
                    case 'deactivate':
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(
                            s.t('إيقاف هذا العضو؟', 'Deactivate this member?'),
                          ),
                          content: Text(
                            s.t(
                              'لن يظهر في قائمة التعيين، لكن سجل عمله يبقى محفوظاً.',
                              'They\'ll no longer be assignable, but their job history stays on record.',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: Text(s.t('إلغاء', 'Cancel')),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: ak.danger,
                              ),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: Text(s.t('إيقاف', 'Deactivate')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(workshopStaffProvider.notifier)
                            .deactivate(member.id);
                      }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(s.t('تعديل', 'Edit')),
                  ),
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Text(s.t('إيقاف', 'Deactivate')),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
