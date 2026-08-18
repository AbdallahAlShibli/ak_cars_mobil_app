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
import 'offering_editor_sheet.dart';

class OfferingsScreen extends ConsumerWidget {
  const OfferingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final offerings = ref.watch(workshopOfferingsProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('الخدمات', 'Offerings'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showOfferingEditorSheet(context),
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(workshopOfferingsProvider.notifier).refresh(),
          child: offerings.when(
            loading: () => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: const [ListSkeleton()],
            ),
            error: (error, _) => ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                EmptyState(
                  icon: LucideIcons.circleAlert,
                  message: s.t(
                    'تعذّر تحميل الخدمات.',
                    'Couldn\'t load offerings.',
                  ),
                  action: FilledButton(
                    onPressed: () =>
                        ref.read(workshopOfferingsProvider.notifier).refresh(),
                    child: Text(s.t('إعادة المحاولة', 'Retry')),
                  ),
                ),
              ],
            ),
            data: (list) => list.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    children: [
                      EmptyState(
                        icon: LucideIcons.wrench,
                        title: s.t('لا خدمات بعد', 'No offerings yet'),
                        message: s.t(
                          'أضف أول خدمة تقدمها ورشتك.',
                          'Add the first service your workshop offers.',
                        ),
                        action: FilledButton.icon(
                          onPressed: () => showOfferingEditorSheet(context),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: Text(s.t('إضافة خدمة', 'Add offering')),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenMargin),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _OfferingCard(offering: list[index]),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OfferingCard extends ConsumerWidget {
  const _OfferingCard({required this.offering});

  final ServiceOffering offering;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, S s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('حذف الخدمة؟', 'Delete this offering?')),
        content: Text(
          s.t(
            'ستُخفى عن العملاء. إذا كان لها حجز مفتوح سيرفض الطلب.',
            'It will be hidden from customers. If it still has an open booking, this will be refused.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AkColors.of(dialogContext).danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(workshopOfferingsProvider.notifier).delete(offering.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t(
                'لا يمكن الحذف — يوجد حجز مفتوح على هذه الخدمة.',
                'Can\'t delete — this offering still has an open booking.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        offering.name.of(s),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    offering.isActive
                        ? StatusBadge.good(s.t('منشورة', 'Live'))
                        : StatusBadge(s.t('مخفية', 'Hidden')),
                  ],
                ),
                const SizedBox(height: 4),
                offering.quoteOnly
                    ? Text(
                        s.t('عرض سعر بعد الفحص', 'Quote after inspection'),
                        style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                      )
                    : RialAmount(
                        offering.price!,
                        style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                      ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'edit':
                  await showOfferingEditorSheet(context, existing: offering);
                case 'toggle':
                  await ref
                      .read(workshopOfferingsProvider.notifier)
                      .setActive(offering.id, isActive: !offering.isActive);
                case 'delete':
                  await _confirmDelete(context, ref, s);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(s.t('تعديل', 'Edit'))),
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  offering.isActive
                      ? s.t('إخفاء', 'Unpublish')
                      : s.t('نشر', 'Publish'),
                ),
              ),
              PopupMenuItem(value: 'delete', child: Text(s.t('حذف', 'Delete'))),
            ],
          ),
        ],
      ),
    );
  }
}
