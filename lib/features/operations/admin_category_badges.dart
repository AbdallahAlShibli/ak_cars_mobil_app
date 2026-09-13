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
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'admin_panel_widgets.dart';
import 'category_editor_sheet.dart';

/// The founder's control over the yellow ribbon on a service-category card —
/// the "زيت مجاني" / "FREE OIL" pill in the corner of the big package cards on
/// Home and Services.
///
/// It sits on the Content tab, next to announcements, because both are the same
/// job: copy the founder writes that appears on the home page on top of data
/// they did not write. It is deliberately *not* on the Offers tab, because a
/// badge is not an offer — it names no price, has no window, and is validated
/// against nothing. That difference is why the section states it outright: an
/// offer that lies is a mispriced booking the platform has to honour, while a
/// badge that lies is only wrong wording on a card. Which is exactly why a
/// badge must never be used to announce a discount.
///
/// The badge is the only editable field on a category, here and in the API.
/// Slug, name, icon and the powertrain restrictions are catalogue structure the
/// app branches on — the slug drives the maintenance-schedule reset and the
/// emergency booking path — so retyping them from an admin screen would break
/// bookings rather than change wording.
/// Which categories the list is showing.
enum _BadgeFilter { all, withBadge, without }

class AdminCategoryBadgesSection extends ConsumerStatefulWidget {
  const AdminCategoryBadgesSection({super.key});

  @override
  ConsumerState<AdminCategoryBadgesSection> createState() =>
      _AdminCategoryBadgesSectionState();
}

class _AdminCategoryBadgesSectionState
    extends ConsumerState<AdminCategoryBadgesSection> {
  _BadgeFilter _filter = _BadgeFilter.all;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final categories = ref.watch(adminCategoriesProvider);
    final badged = [
      for (final c in categories)
        if (c.badge != null) c,
    ];
    final plain = [
      for (final c in categories)
        if (c.badge == null) c,
    ];
    final withBadge = badged.length;
    final shown = switch (_filter) {
      _BadgeFilter.all => categories,
      _BadgeFilter.withBadge => badged,
      _BadgeFilter.without => plain,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSummaryCard(
          icon: LucideIcons.layoutGrid,
          title: s.t('أنواع الخدمات', 'Service types'),
          subtitle: s.t(
            'العائلات التي تُصنَّف تحتها خدمات الورش.',
            "The families a workshop's services are filed under.",
          ),
          stats: [
            AdminStat.count(categories.length, label: s.t('نوع', 'Types')),
            AdminStat.count(
              withBadge,
              label: s.t('عليها شارة', 'With a badge'),
              color: ak.amberText,
            ),
          ],
          actionLabel: s.t('نوع جديد', 'New service type'),
          actionIcon: LucideIcons.plus,
          onAction: () => showCategoryEditorSheet(context),
          footnote: s.t(
            'اضغط أي صف لتعديل النوع. الورش تُسعّر خدماتها داخل هذه الأنواع، '
                'فحذف نوع ما زالت تحته خدمات مرفوض.',
            'Tap any row to edit the type. Workshops price their services '
                'inside these, so deleting one that still has services under '
                'it is refused.',
          ),
        ),
        if (badged.isNotEmpty && plain.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AdminFilterRow<_BadgeFilter>(
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
            filters: [
              AdminFilter(
                value: _BadgeFilter.all,
                label: s.t('الكل', 'All'),
                count: categories.length,
              ),
              AdminFilter(
                value: _BadgeFilter.withBadge,
                label: s.t('عليها شارة', 'With a badge'),
                count: badged.length,
              ),
              AdminFilter(
                value: _BadgeFilter.without,
                label: s.t('بلا شارة', 'Without'),
                count: plain.length,
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.headingGap),
        if (categories.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.sparkles,
            message: s.t(
              'لا خدمات في الكتالوج بعد.',
              'No services in the catalogue yet.',
            ),
          )
        else
          for (final (i, category) in shown.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.itemGap),
            _CategoryBadgeRow(category: category),
          ],
      ],
    );
  }
}

class _CategoryBadgeRow extends ConsumerWidget {
  const _CategoryBadgeRow({required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final badge = category.badge;
    final offerings = ref
        .watch(serviceMarketplaceRepositoryProvider)
        .offeringCountFor(category.id);

    return AppCard(
      padding: EdgeInsets.zero,
      // The row is the control. A pencil in the corner was the only thing on
      // this page saying a category could be touched at all, and a founder who
      // did not spot it concluded the list was read-only.
      onTap: () => showCategoryEditorSheet(context, existing: category),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.md,
              AppSpacing.cardPadding,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                IconTile(
                  category.icon,
                  size: 38,
                  radius: 13,
                  background: category.emergency ? ak.dangerSoft : null,
                  foreground: category.emergency ? ak.danger : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name.of(s).replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyPrimary.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (badge == null)
                        Text(
                          s.t('بلا شارة', 'No badge'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySecondary.copyWith(
                            color: ak.inkFaint,
                          ),
                        )
                      else
                        // The ribbon exactly as a customer sees it, rather than
                        // the text in a neutral chip: the founder is choosing
                        // wording for a small yellow pill, and a preview in a
                        // different shape hides the one thing that actually
                        // goes wrong — it not fitting.
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: BadgeRibbon(text: badge.of(s)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AdminInsetDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.md,
            ),
            child: Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs + 2,
              children: [
                // The key is on the card because it is now editable *and*
                // behavioural — a founder about to rename one should be able to
                // see which types carry a key the app reads, without opening
                // each of them in turn.
                AdminMetaChip(
                  icon: LucideIcons.key,
                  label: category.slug,
                  tone: isBehaviouralSlug(category.slug)
                      ? AdminChipTone.warn
                      : AdminChipTone.normal,
                ),
                AdminMetaChip(
                  icon: LucideIcons.wrench,
                  tone: offerings == 0
                      ? AdminChipTone.dim
                      : AdminChipTone.normal,
                  label: s.t(
                    '$offerings خدمة',
                    offerings == 1 ? '1 service' : '$offerings services',
                  ),
                ),
                if (category.primary)
                  AdminMetaChip(
                    icon: LucideIcons.layoutGrid,
                    label: s.t('بطاقة كبيرة', 'Big card'),
                  ),
                if (category.emergency)
                  AdminMetaChip(
                    icon: LucideIcons.siren,
                    tone: AdminChipTone.warn,
                    label: s.t('طوارئ', 'Emergency'),
                  ),
                if (category.powertrains.isNotEmpty)
                  AdminMetaChip(
                    icon: LucideIcons.fuel,
                    label: [
                      for (final p in category.powertrains) p.badge.of(s),
                    ].join(s.t('، ', ', ')),
                  ),
              ],
            ),
          ),
          const AdminInsetDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdminCardAction(
                  icon: LucideIcons.sparkles,
                  tooltip: badge == null
                      ? s.t('إضافة شارة', 'Add a badge')
                      : s.t('تعديل الشارة', 'Edit badge'),
                  onTap: () => showCategoryBadgeDialog(context, category),
                ),
                AdminCardAction(
                  icon: LucideIcons.pencil,
                  tooltip: s.t('تعديل النوع', 'Edit type'),
                  onTap: () =>
                      showCategoryEditorSheet(context, existing: category),
                ),
                AdminCardAction(
                  icon: LucideIcons.trash2,
                  tooltip: s.t('حذف النوع', 'Delete type'),
                  danger: true,
                  onTap: () => confirmDeleteCategory(context, ref, category),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The badge as it is painted on a service card — the same colour, radius, size
/// and letter-spacing `service_widgets.dart` uses to draw it.
class BadgeRibbon extends StatelessWidget {
  const BadgeRibbon({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AkColors.of(context).amber,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: Color(0xFF1D1B17),
      ),
    ),
  );
}

Future<void> showCategoryBadgeDialog(
  BuildContext context,
  ServiceCategory category,
) => showDialog<void>(
  context: context,
  builder: (_) => _CategoryBadgeDialog(category: category),
);

class _CategoryBadgeDialog extends ConsumerStatefulWidget {
  const _CategoryBadgeDialog({required this.category});

  final ServiceCategory category;

  @override
  ConsumerState<_CategoryBadgeDialog> createState() =>
      _CategoryBadgeDialogState();
}

class _CategoryBadgeDialogState extends ConsumerState<_CategoryBadgeDialog> {
  /// Matches the API's own limit. The ribbon is a small pill on a 148px-wide
  /// card: anything longer is clipped on the device rather than wrapped, so the
  /// cap belongs on the input rather than in a message after saving.
  static const _maxLength = 24;

  late final _ar = TextEditingController(text: widget.category.badge?.ar ?? '');
  late final _en = TextEditingController(text: widget.category.badge?.en ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _ar.dispose();
    _en.dispose();
    super.dispose();
  }

  String get _arText => _ar.text.trim();
  String get _enText => _en.text.trim();

  /// Both languages or neither — the same rule the API enforces. A badge set in
  /// one language only renders as an empty yellow box in the other, which reads
  /// as a bug on the customer's home page rather than as a missing translation.
  bool get _balanced => _arText.isEmpty == _enText.isEmpty;

  Future<void> _save({required bool clear}) async {
    final s = S.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(categoryBadgeAdminProvider)
          .setBadge(
            widget.category.id,
            badge: clear ? null : L(_arText, _enText),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t('تعذّر الحفظ — حاول مرة أخرى.', "Couldn't save — try again."),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final hasText = _arText.isNotEmpty || _enText.isNotEmpty;

    return AlertDialog(
      title: Text(
        widget.category.name.of(s).replaceAll('\n', ' '),
        style: context.text.cardTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.t(
                'نص قصير يظهر في زاوية بطاقة الخدمة. امسح اللغتين لإزالته.',
                'Short wording shown in the corner of the service card. Clear '
                    'both languages to remove it.',
              ),
              style: context.text.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _ar,
              maxLength: _maxLength,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                labelText: s.t('بالعربية', 'Arabic'),
                hintText: 'زيت مجاني',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _en,
              maxLength: _maxLength,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: s.t('بالإنجليزية', 'English'),
                hintText: 'FREE OIL',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (!_balanced) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                s.t(
                  'اكتب الشارة باللغتين، أو امسحهما معاً.',
                  'Fill both languages, or clear both.',
                ),
                style: context.text.bodySecondary.copyWith(
                  color: ak.dangerText,
                ),
              ),
            ],
            if (hasText) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                s.t('المعاينة', 'Preview'),
                style: context.text.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: BadgeRibbon(
                  text: s.isAr
                      ? (_arText.isEmpty ? _enText : _arText)
                      : (_enText.isEmpty ? _arText : _enText),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.category.badge != null)
          TextButton(
            onPressed: _saving ? null : () => _save(clear: true),
            child: Text(
              s.t('إزالة الشارة', 'Remove badge'),
              style: TextStyle(color: ak.dangerText),
            ),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(s.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _balanced && !_saving
              ? () => _save(clear: !hasText)
              : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(s.t('حفظ', 'Save')),
        ),
      ],
    );
  }
}
