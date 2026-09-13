import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/json/icon_codec.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/service_marketplace_repository.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'admin_category_badges.dart';
import 'admin_form_widgets.dart';
import 'admin_panel_widgets.dart';

/// The Content tab: the two places the founder writes **wording** that lands on
/// a customer's home page on top of data they did not write.
///
/// The tab opens with [_ContentIntro] because that sentence is the whole reason
/// the two sections share a tab, and without it the page reads as two unrelated
/// lists someone stacked. It also states the one thing a founder can get
/// expensively wrong here: a real discount is not written on this tab. Neither
/// a badge nor an announcement is validated against a published price, so a
/// discount announced from here is a promise nothing checked. That belongs on
/// the Offers tab.
///
/// Offers used to be managed here too, in a second list beside this one. They
/// are not any more: the Offers tab owns them end to end (see
/// `admin_offers_tab.dart`). Two screens that could each create an offer is how
/// a founder ends up making a row on one, not finding it on the other, and
/// concluding the app lost it.
class AdminContentTab extends StatelessWidget {
  const AdminContentTab({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenMargin,
      AppSpacing.lg,
      AppSpacing.screenMargin,
      AppSpacing.xl,
    ),
    children: const [
      _ContentIntro(),
      SizedBox(height: AppSpacing.sectionGap),
      AdminCategoryBadgesSection(),
      SizedBox(height: AppSpacing.sectionGap * 1.5),
      _PromotionsManagementSection(),
    ],
  );
}

/// What this tab is, where each half of it shows up, and the one thing that
/// does not belong on it.
///
/// Deliberately not a third [AdminSummaryCard]: the two sections below each
/// open with one, and three stacked summary cards is how a page stops being
/// read at all. This is a plain block, and its job is to say where the writing
/// actually appears — the question the tab could not previously answer without
/// leaving the panel to go and look.
class _ContentIntro extends StatelessWidget {
  const _ContentIntro();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.t('المحتوى', 'Content'), style: context.text.screenTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          s.t(
            'الكلمات التي تكتبها أنت وتظهر فوق بيانات الكتالوج. لا شيء هنا '
                'يغيّر سعراً أو خدمة — الكلام فقط.',
            'The wording you write that sits on top of the catalogue. Nothing '
                'here changes a price or a service — only the words.',
          ),
          style: context.text.bodySecondary.copyWith(height: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        _WhereItShows(
          icon: LucideIcons.sparkles,
          what: s.t('شارات الخدمات', 'Service badges'),
          where: s.t(
            'الشريط الأصفر في زاوية بطاقة الخدمة — في الرئيسية والخدمات.',
            'The yellow ribbon in the corner of a service card — on Home and '
                'Services.',
          ),
        ),
        const SizedBox(height: AppSpacing.itemGap),
        _WhereItShows(
          icon: LucideIcons.megaphone,
          what: s.t('الإعلانات', 'Announcements'),
          where: s.t(
            'بطاقات الشريط المتحرّك في الرئيسية.',
            "The cards on the Home page's announcements rail.",
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // The expensive mistake, stated once and up front rather than as a
        // footnote under each of the two sections.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md - 2,
          ),
          decoration: BoxDecoration(
            color: ak.amberBgSoft,
            border: Border.all(color: ak.amberBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.triangleAlert,
                  size: 15,
                  color: ak.amberText,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 1),
              Expanded(
                child: Text(
                  s.t(
                    'لا تُعلن خصماً من هنا. لا الشارة ولا الإعلان يُقارَن بسعر '
                        'الكتالوج، فالخصم المكتوب هنا وعدٌ لا يتحقق منه شيء. '
                        'الخصم الحقيقي في تبويب "العروض".',
                    'Do not announce a discount from here. Neither a badge nor '
                        'an announcement is checked against the catalogue '
                        'price, so a discount written here is a promise nothing '
                        'validated. Real discounts live on the Offers tab.',
                  ),
                  style: context.text.bodySecondary.copyWith(
                    color: ak.amberDeep,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhereItShows extends StatelessWidget {
  const _WhereItShows({
    required this.icon,
    required this.what,
    required this.where,
  });

  final IconData icon;
  final String what;
  final String where;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon, size: 30, radius: 10),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: what,
                  style: context.text.bodySecondary.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ak.ink,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: where, style: context.text.bodySecondary),
              ],
            ),
            style: context.text.bodySecondary.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

// ========================================================== promotions

/// Which announcements the list is showing.
enum _PromoFilter { all, live, expired }

class _PromotionsManagementSection extends ConsumerStatefulWidget {
  const _PromotionsManagementSection();

  @override
  ConsumerState<_PromotionsManagementSection> createState() =>
      _PromotionsManagementSectionState();
}

class _PromotionsManagementSectionState
    extends ConsumerState<_PromotionsManagementSection> {
  _PromoFilter _filter = _PromoFilter.all;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final promotions = ref.watch(adminPromotionsProvider);

    final now = DateTime.now();
    bool isExpired(Promotion p) => p.endsAt != null && !p.endsAt!.isAfter(now);

    final all = promotions.valueOrNull ?? const <Promotion>[];
    final expired = [
      for (final p in all)
        if (isExpired(p)) p,
    ];
    final live = [
      for (final p in all)
        if (!isExpired(p)) p,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSummaryCard(
          icon: LucideIcons.megaphone,
          title: s.t('الإعلانات', 'Announcements'),
          subtitle: s.t(
            'بطاقات شريط الرئيسية.',
            "The cards on the Home page's rail.",
          ),
          stats: [
            AdminStat.count(
              live.length,
              label: s.t('ظاهر الآن', 'Live now'),
              color: ak.success,
            ),
            AdminStat.count(
              expired.length,
              label: s.t('منتهٍ', 'Expired'),
              color: ak.inkFaint,
            ),
          ],
          actionLabel: s.t('إعلان جديد', 'New announcement'),
          actionIcon: LucideIcons.plus,
          onAction: () => showPromotionEditorSheet(context),
          footnote: s.t(
            'لا تحمل سعراً — إن كانت تخص خدمة مسعّرة فسيُعرض سعرها من '
                'الكتالوج مباشرة. المنتهي يبقى هنا ولا يراه العميل.',
            'Carries no price of its own — if it points at a priced service, '
                'that price comes straight from the catalogue. Expired ones '
                'stay here and are not shown to customers.',
          ),
        ),
        // The filter earns its place only once there is a split to make: with
        // everything live, three chips explain a list you can already see all
        // of.
        if (expired.isNotEmpty && live.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AdminFilterRow<_PromoFilter>(
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
            filters: [
              AdminFilter(
                value: _PromoFilter.all,
                label: s.t('الكل', 'All'),
                count: all.length,
              ),
              AdminFilter(
                value: _PromoFilter.live,
                label: s.t('ظاهر', 'Live'),
                count: live.length,
              ),
              AdminFilter(
                value: _PromoFilter.expired,
                label: s.t('منتهٍ', 'Expired'),
                count: expired.length,
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.sectionGap),
        promotions.when(
          loading: () => const AdminLoadingBlock(),
          error: (_, _) => AdminErrorBlock(
            message: s.t(
              'تعذّر تحميل الإعلانات.',
              'Could not load announcements.',
            ),
            onRetry: () => ref.read(adminPromotionsProvider.notifier).refresh(),
          ),
          data: (_) {
            if (all.isEmpty) {
              return EmptyState(
                compact: true,
                icon: LucideIcons.megaphone,
                message: s.t(
                  'لا إعلانات بعد. اكتب أول واحد من زر "إعلان جديد" أعلاه — '
                      'ستراه كما يراه العميل قبل أن تحفظه.',
                  'No announcements yet. Write the first one with "New '
                      'announcement" above — you will see it exactly as a '
                      'customer does before you save it.',
                ),
              );
            }
            final shown = switch (_filter) {
              _PromoFilter.all => all,
              _PromoFilter.live => live,
              _PromoFilter.expired => expired,
            };
            return Column(
              children: [
                for (final (i, promo) in shown.indexed) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.itemGap),
                  _AdminPromotionRow(promotion: promo),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AdminPromotionRow extends ConsumerWidget {
  const _AdminPromotionRow({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final locations = ref.watch(locationCatalogProvider);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final expired =
        promotion.endsAt != null && !promotion.endsAt!.isAfter(DateTime.now());

    return AppCard(
      padding: EdgeInsets.zero,
      // The whole card opens the editor, not only the pencil. A row whose sole
      // affordance is an 18px icon in one corner reads as a list you look at
      // rather than one you edit — which was most of why this page felt closed.
      onTap: () => showPromotionEditorSheet(context, existing: promotion),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  promotion.icon,
                  size: 42,
                  radius: 14,
                  background: expired ? ak.surfaceDim : ak.primary,
                  foreground: expired ? ak.inkFaint : ak.onPrimary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promotion.title.of(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.cardTitle,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        promotion.body.of(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                expired
                    ? StatusBadge(s.t('منتهٍ', 'Expired'))
                    : StatusBadge.good(s.t('ظاهر', 'Live')),
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
                AdminMetaChip(
                  icon: promotion.endsAt == null
                      ? LucideIcons.infinity
                      : LucideIcons.calendar,
                  tone: expired ? AdminChipTone.dim : AdminChipTone.normal,
                  label: promotion.endsAt == null
                      ? s.t('بلا تاريخ انتهاء', 'No end date')
                      : s.t(
                          'ينتهي ${formatAdminDate(promotion.endsAt!)}',
                          'Ends ${formatAdminDate(promotion.endsAt!)}',
                        ),
                ),
                // Where the card sends whoever taps it. Previously invisible
                // from the list, so checking a destination meant opening the
                // editor on every row in turn.
                AdminMetaChip(
                  icon: _destinationIcon(promotion),
                  label: _destinationLabel(promotion, s, marketplace),
                ),
                // Governorates are stored as canonical English keys; the panel
                // shows them the way every other screen in the app does.
                AdminMetaChip(
                  icon: LucideIcons.mapPin,
                  label: promotion.regions.isEmpty
                      ? s.t('كل المحافظات', 'Everywhere')
                      : [
                          for (final r in promotion.regions)
                            locations.localized(r, s.isAr),
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
                  icon: LucideIcons.pencil,
                  tooltip: s.t('تعديل', 'Edit'),
                  onTap: () =>
                      showPromotionEditorSheet(context, existing: promotion),
                ),
                AdminCardAction(
                  icon: LucideIcons.trash2,
                  tooltip: s.t('حذف', 'Delete'),
                  danger: true,
                  onTap: () => _delete(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('حذف الإعلان؟', 'Delete this announcement?')),
        content: Text(
          s.t(
            'سيختفي فوراً من الرئيسية، ولا يمكن التراجع.',
            'It disappears from Home immediately, and cannot be undone.',
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
      await ref.read(adminPromotionsProvider.notifier).delete(promotion.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('تعذّر الحذف.', 'Could not delete.'))),
        );
      }
    }
  }
}

// ------------------------------------------------------------- destination

/// The three things tapping an announcement can do, in the order the Home card
/// actually resolves them (`HomeAnnouncementsRail`): a specific service wins,
/// then a search, and otherwise the Services tab unfiltered.
IconData _destinationIcon(Promotion p) {
  if (p.offeringId != null) return LucideIcons.wrench;
  if ((p.query ?? '').trim().isNotEmpty) return LucideIcons.search;
  return LucideIcons.layoutGrid;
}

String _destinationLabel(
  Promotion p,
  S s,
  ServiceMarketplaceRepository marketplace,
) {
  final offeringId = p.offeringId;
  if (offeringId != null) {
    final offering = marketplace.offeringById(offeringId);
    final name = offering == null
        ? s.t('خدمة محذوفة', 'a deleted service')
        : offering.name.of(s).replaceAll('\n', ' ');
    return s.t('يفتح: $name', 'Opens: $name');
  }
  final query = (p.query ?? '').trim();
  if (query.isNotEmpty) {
    return s.t('يبحث: $query', 'Searches: $query');
  }
  return s.t('يفتح تبويب الخدمات', 'Opens the Services tab');
}

// ---------------------------------------------------------------- editor

/// The curated set of announcement icons — the notification-flavoured ones
/// already in [IconCodec] — each paired with the wording a founder would pick
/// it by.
///
/// The keys are the wire format and used to be shown raw in a dropdown, so the
/// choice on offer was between `fact_check` and `lock_clock`: names that
/// describe the asset rather than the announcement.
const _promotionIcons = <String, (String, String)>{
  'campaign': ('إعلان عام', 'General notice'),
  'notification': ('تنبيه', 'Alert'),
  'thumb_up': ('خبر جيد', 'Good news'),
  'fact_check': ('تعليمات أو شروط', 'Rules or terms'),
  'inventory': ('قطع غيار', 'Parts'),
  'shipping': ('استلام وتسليم', 'Pickup & delivery'),
  'lock_open': ('تحرير المبلغ', 'Money released'),
  'lock_clock': ('المبلغ محجوز', 'Money held'),
};

Future<void> showPromotionEditorSheet(
  BuildContext context, {
  Promotion? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PromotionEditorSheet(existing: existing),
  );
}

class _PromotionEditorSheet extends ConsumerStatefulWidget {
  const _PromotionEditorSheet({this.existing});

  final Promotion? existing;

  @override
  ConsumerState<_PromotionEditorSheet> createState() =>
      _PromotionEditorSheetState();
}

class _PromotionEditorSheetState extends ConsumerState<_PromotionEditorSheet> {
  late final _titleAr = TextEditingController(text: widget.existing?.title.ar);
  late final _titleEn = TextEditingController(text: widget.existing?.title.en);
  late final _bodyAr = TextEditingController(text: widget.existing?.body.ar);
  late final _bodyEn = TextEditingController(text: widget.existing?.body.en);
  late final _badgeAr = TextEditingController(text: widget.existing?.badge?.ar);
  late final _badgeEn = TextEditingController(text: widget.existing?.badge?.en);
  late final _query = TextEditingController(text: widget.existing?.query);
  late String _iconKey = () {
    final current = widget.existing == null
        ? null
        : IconCodec.encode(widget.existing!.icon);
    return current != null && _promotionIcons.containsKey(current)
        ? current
        : _promotionIcons.keys.first;
  }();
  late String? _providerId = widget.existing?.providerId;
  late String? _offeringId = widget.existing?.offeringId;
  late final Set<String> _regions = {...?widget.existing?.regions};
  DateTime? _endsAt;
  bool _hasEndDate = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _endsAt = widget.existing?.endsAt;
    _hasEndDate = _endsAt != null;
  }

  @override
  void dispose() {
    _titleAr.dispose();
    _titleEn.dispose();
    _bodyAr.dispose();
    _bodyEn.dispose();
    _badgeAr.dispose();
    _badgeEn.dispose();
    _query.dispose();
    super.dispose();
  }

  String get _badgeArText => _badgeAr.text.trim();
  String get _badgeEnText => _badgeEn.text.trim();

  /// Both languages or neither — the same rule the category badge already
  /// enforces, and for the same reason: `L('عرض', '')` paints an empty yellow
  /// pill for every English reader, which reads as a broken card rather than as
  /// a missing translation. This editor used to accept it silently.
  bool get _badgeBalanced => _badgeArText.isEmpty == _badgeEnText.isEmpty;

  /// What is still missing, in the order the form asks for it — or null when it
  /// can be saved.
  ///
  /// A reason rather than a bool, because a disabled Save button that will not
  /// say why is the commonest way an admin form wastes somebody's afternoon.
  String? _blocker(S s) {
    if (_titleAr.text.trim().isEmpty || _titleEn.text.trim().isEmpty) {
      return s.t(
        'اكتب العنوان باللغتين.',
        'Write the title in both languages.',
      );
    }
    if (_bodyAr.text.trim().isEmpty || _bodyEn.text.trim().isEmpty) {
      return s.t('اكتب النص باللغتين.', 'Write the body in both languages.');
    }
    if (!_badgeBalanced) {
      return s.t(
        'الشارة باللغتين، أو امسحهما معاً.',
        'Fill the badge in both languages, or clear both.',
      );
    }
    return null;
  }

  Future<void> _submit() async {
    final s = S.of(context);
    setState(() => _saving = true);
    try {
      final notifier = ref.read(adminPromotionsProvider.notifier);
      final badge = _badgeArText.isEmpty && _badgeEnText.isEmpty
          ? null
          : L(_badgeArText, _badgeEnText);
      if (widget.existing == null) {
        await notifier.create(
          title: L(_titleAr.text.trim(), _titleEn.text.trim()),
          body: L(_bodyAr.text.trim(), _bodyEn.text.trim()),
          icon: IconCodec.decode(_iconKey),
          badge: badge,
          providerId: _providerId,
          offeringId: _offeringId,
          query: _query.text.trim().isEmpty ? null : _query.text.trim(),
          regions: _regions,
          endsAt: _hasEndDate ? _endsAt : null,
        );
      } else {
        await notifier.edit(
          widget.existing!.id,
          title: L(_titleAr.text.trim(), _titleEn.text.trim()),
          body: L(_bodyAr.text.trim(), _bodyEn.text.trim()),
          icon: IconCodec.decode(_iconKey),
          badge: badge,
          providerId: _providerId,
          offeringId: _offeringId,
          query: _query.text.trim().isEmpty ? null : _query.text.trim(),
          regions: _regions,
          endsAt: _hasEndDate ? _endsAt : null,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t('تعذّر الحفظ — حاول مرة أخرى.', "Couldn't save — try again."),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsAt ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _endsAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final locations = ref.watch(locationCatalogProvider);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final offeringsForProvider = _providerId == null
        ? const <ServiceOffering>[]
        : marketplace.offerings
              .where((o) => o.provider.id == _providerId)
              .toList();
    final blocker = _blocker(s);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: ak.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.sm,
                AppSpacing.screenMargin,
                AppSpacing.screenMargin,
              ),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: ak.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  widget.existing == null
                      ? s.t('إعلان جديد', 'New announcement')
                      : s.t('تعديل الإعلان', 'Edit announcement'),
                  style: context.text.screenTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.t(
                    'بطاقة في شريط الرئيسية. لا تحمل سعراً، ولا تُغني عن عرض '
                        'حقيقي في تبويب "العروض".',
                    'A card on the Home rail. It carries no price, and it is '
                        'not a substitute for a real offer on the Offers tab.',
                  ),
                  style: context.text.bodySecondary.copyWith(height: 1.5),
                ),

                // ------------------------------------------------- preview
                const SizedBox(height: AppSpacing.lg),
                _PreviewPane(
                  face: _previewFace(s, marketplace),
                  caption: s.t(
                    'هكذا يراها العميل — بالحجم نفسه، فما لا يتّسع هنا لن '
                        'يتّسع على هاتفه.',
                    'Exactly what a customer sees, at the real size — what does '
                        'not fit here will not fit on their phone either.',
                  ),
                ),

                // -------------------------------------------- 1. the words
                const SizedBox(height: AppSpacing.sectionGap),
                _StepHeader(
                  step: 1,
                  title: s.t('ما تقوله البطاقة', 'What the card says'),
                  hint: s.t(
                    'اللغتان مطلوبتان — كل عميل يرى واحدة منهما فقط.',
                    'Both languages are required — each customer only ever '
                        'sees one of them.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _titleAr,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'العنوان (عربي)',
                    hintText: 'مبلغك محجوز حتى تستلم سيارتك',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _titleEn,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'Title (English)',
                    hintText: 'Your money is held until you collect the car',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _bodyAr,
                  maxLines: 2,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'النص (عربي)',
                    helperText: 'سطران على الأكثر',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _bodyEn,
                  maxLines: 2,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'Body (English)',
                    helperText: 'Two lines at most',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                _FieldLabel(s.t('الأيقونة', 'Icon')),
                const SizedBox(height: AppSpacing.sm),
                _IconPicker(
                  selected: _iconKey,
                  onSelect: (key) => setState(() => _iconKey = key),
                ),
                const SizedBox(height: AppSpacing.lg),
                _FieldLabel(s.t('الشارة (اختيارية)', 'Badge (optional)')),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.t(
                    'كلمة واحدة في زاوية البطاقة — "جديد"، "مهم". اتركها فارغة '
                        'إن لم تحتجها.',
                    'One word in the corner of the card — "New", "Important". '
                        'Leave it empty if you do not need it.',
                  ),
                  style: context.text.bodySecondary.copyWith(height: 1.45),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _badgeAr,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          labelText: 'شارة (عربي)',
                          hintText: 'جديد',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _badgeEn,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'Badge (English)',
                          hintText: 'NEW',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (!_badgeBalanced) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _InlineWarning(
                    s.t(
                      'اكتب الشارة باللغتين، أو امسحهما معاً — وإلا ظهرت شارة '
                          'فارغة لقرّاء اللغة الأخرى.',
                      'Fill the badge in both languages or clear both — '
                          'otherwise it renders as an empty pill for readers of '
                          'the other one.',
                    ),
                  ),
                ],

                // --------------------------------------- 2. the destination
                const SizedBox(height: AppSpacing.sectionGap),
                _StepHeader(
                  step: 2,
                  title: s.t('إلى أين تنقل الضغطة', 'Where tapping it goes'),
                  hint: s.t(
                    'بالأولوية: خدمة محدّدة، ثم بحث، وإلا فتبويب الخدمات '
                        'كاملاً.',
                    'In priority order: a specific service, then a search, '
                        'otherwise the whole Services tab.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: _providerId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: s.t('الورشة', 'Workshop'),
                    helperText: s.t(
                      'لتصفية قائمة الخدمات تحتها فقط.',
                      'Only narrows the service list below it.',
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(s.t('بلا', 'None')),
                    ),
                    for (final w in marketplace.providers)
                      DropdownMenuItem(value: w.id, child: Text(w.name.of(s))),
                  ],
                  onChanged: (v) => setState(() {
                    _providerId = v;
                    _offeringId = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: _offeringId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: s.t('الخدمة', 'Service'),
                    helperText: _providerId == null
                        ? s.t('اختر ورشة أولاً.', 'Pick a workshop first.')
                        : s.t(
                            'تفتح صفحة الخدمة بسعرها الحقيقي.',
                            'Opens the service page at its real price.',
                          ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(s.t('بلا', 'None')),
                    ),
                    for (final o in offeringsForProvider)
                      DropdownMenuItem(
                        value: o.id,
                        child: Text(
                          o.name.of(s).replaceAll('\n', ' '),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _providerId == null
                      ? null
                      : (v) => setState(() => _offeringId = v),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _query,
                  enabled: _offeringId == null,
                  decoration: InputDecoration(
                    labelText: s.t('أو بحث', 'Or a search'),
                    hintText: s.t('تكييف', 'air conditioning'),
                    helperText: _offeringId == null
                        ? s.t(
                            'تُفتح صفحة الخدمات وهذه الكلمة مكتوبة في البحث.',
                            'Opens Services with this word already typed in.',
                          )
                        : s.t(
                            'غير مستخدم — الخدمة المحدّدة أعلاه لها الأولوية.',
                            'Unused — the service picked above wins.',
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                _DestinationSummary(
                  offeringId: _offeringId,
                  query: _query.text,
                  marketplace: marketplace,
                ),

                // ------------------------------------- 3. audience & window
                const SizedBox(height: AppSpacing.sectionGap),
                _StepHeader(
                  step: 3,
                  title: s.t(
                    'من يراها، وحتى متى',
                    'Who sees it, and until when',
                  ),
                  hint: s.t(
                    'بلا محافظات = كل عُمان. بلا تاريخ = تبقى حتى تحذفها.',
                    'No governorates = all of Oman. No date = it stays until '
                        'you delete it.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _FieldLabel(
                  _regions.isEmpty
                      ? s.t(
                          'المحافظات — لم تُحدَّد، أي كل عُمان',
                          'Governorates — none picked, so everywhere',
                        )
                      : s.t(
                          'المحافظات — ${_regions.length} مختارة',
                          'Governorates — ${_regions.length} selected',
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: [
                    for (final region in marketplace.providerRegions)
                      SelectChip(
                        // Localised, not the canonical English key the record
                        // stores — a founder picks a place, not a slug.
                        label: locations.localized(region, s.isAr),
                        selected: _regions.contains(region),
                        onTap: () => setState(() {
                          if (!_regions.add(region)) _regions.remove(region);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('له تاريخ انتهاء', 'Has an end date')),
                  subtitle: Text(
                    s.t(
                      'بعده تختفي من الرئيسية وتبقى هنا كـ"منتهٍ".',
                      'After it, the card leaves Home and stays here as '
                          '"Expired".',
                    ),
                    style: context.text.bodySecondary,
                  ),
                  value: _hasEndDate,
                  onChanged: (v) => setState(() => _hasEndDate = v),
                ),
                if (_hasEndDate) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AdminDatePickerField(
                    label: s.t('ينتهي', 'Ends'),
                    date: _endsAt ?? DateTime.now(),
                    onTap: _pickEndDate,
                  ),
                ],

                // ------------------------------------------------- actions
                const SizedBox(height: AppSpacing.sectionGap),
                if (blocker != null) ...[
                  _InlineWarning(blocker),
                  const SizedBox(height: AppSpacing.sm),
                ],
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: blocker == null && !_saving ? _submit : null,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.existing == null
                                ? s.t('نشر الإعلان', 'Publish announcement')
                                : s.t('حفظ التعديل', 'Save changes'),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(s.t('إلغاء', 'Cancel')),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The form's current contents, as the card a customer would get.
  ///
  /// Falls back to placeholder wording rather than rendering an empty card: a
  /// blank rectangle tells a founder nothing about what they are making, and
  /// the placeholders read visibly as placeholders.
  Widget _previewFace(S s, ServiceMarketplaceRepository marketplace) {
    final ak = AkColors.of(context);
    final title = s.isAr ? _titleAr.text.trim() : _titleEn.text.trim();
    final body = s.isAr ? _bodyAr.text.trim() : _bodyEn.text.trim();
    final badge = s.isAr ? _badgeArText : _badgeEnText;
    final offeringId = _offeringId;
    final offering = offeringId == null
        ? null
        : marketplace.pricedOffering(offeringId);
    final price = offering?.price;

    // Same clamp as `Promotion.daysLeft`, so the preview cannot read "3 days"
    // where the real card would read "last day".
    int? days;
    if (_hasEndDate && _endsAt != null) {
      final diff = _endsAt!.difference(DateTime.now()).inDays;
      days = diff < 0 ? 0 : diff;
    }

    return PromotionCardFace(
      icon: IconCodec.decode(_iconKey),
      title: title.isEmpty
          ? s.t('العنوان يظهر هنا', 'Your title appears here')
          : title,
      body: body.isEmpty
          ? s.t(
              'والنص هنا، في سطرين على الأكثر.',
              'And the body here, over two lines at most.',
            )
          : body,
      badge: badge,
      deadline: days == null
          ? null
          : days <= 0
          ? s.t('آخر يوم', 'last day')
          : s.t('باقي ${s.days(days)}', '${s.days(days)} left'),
      trailing: price != null
          ? RialAmount(
              price,
              prefix: s.t('من ', 'from '),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ak.promoTitle,
              ),
            )
          : offering != null
          ? Text(
              s.t('عرض سعر بعد الفحص', 'quote after inspection'),
              style: TextStyle(fontSize: 12.5, color: ak.promoSub),
            )
          : null,
    );
  }
}

/// The preview, in a frame that says it is a preview.
///
/// On a dim panel rather than a white card, at the rail's own height, so what
/// the founder sees is dimensionally the customer's card and not a stretched
/// approximation of it.
class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.face, required this.caption});

  final Widget face;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.eye, size: 14, color: ak.inkSub),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                s.t('المعاينة', 'Preview'),
                style: context.text.bodySecondary.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(height: PromotionCardFace.railHeight, child: face),
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption,
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

/// A numbered heading inside the editor.
///
/// The form used to be twelve controls at one level, which is readable only by
/// someone who already knows what each one does. Three numbered steps say how
/// far through it you are, and group the fields that answer the same question.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, this.hint});

  final int step;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: ak.primary, shape: BoxShape.circle),
          child: Text(
            '$step',
            style: context.text.labelStrong.copyWith(color: ak.onPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.cardTitle),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: context.text.bodySecondary.copyWith(height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The heading above a control that has no `labelText` of its own — the icon
/// grid and the region chips.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.bodySecondary.copyWith(
      fontWeight: FontWeight.w700,
      color: AkColors.of(context).ink,
    ),
  );
}

/// Where the current settings would actually send a customer, in one sentence,
/// recomputed as the fields change.
///
/// The three destination fields interact by precedence, and a founder typing
/// into the search box under an already-chosen service has no way to know it
/// will be ignored. This says so.
class _DestinationSummary extends StatelessWidget {
  const _DestinationSummary({
    required this.offeringId,
    required this.query,
    required this.marketplace,
  });

  final String? offeringId;
  final String query;
  final ServiceMarketplaceRepository marketplace;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final trimmed = query.trim();
    final id = offeringId;

    final IconData icon;
    final String text;
    if (id != null) {
      final offering = marketplace.offeringById(id);
      final name = offering == null
          ? s.t('خدمة محذوفة', 'a deleted service')
          : offering.name.of(s).replaceAll('\n', ' ');
      icon = LucideIcons.wrench;
      text = s.t('الضغط يفتح: $name', 'Tapping opens: $name');
    } else if (trimmed.isNotEmpty) {
      icon = LucideIcons.search;
      text = s.t(
        'الضغط يبحث عن "$trimmed" في الخدمات',
        'Tapping searches Services for "$trimmed"',
      );
    } else {
      icon = LucideIcons.layoutGrid;
      text = s.t(
        'الضغط يفتح تبويب الخدمات كاملاً',
        'Tapping opens the whole Services tab',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: ak.inkSub),
          const SizedBox(width: AppSpacing.sm + 1),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySecondary.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// The eight allowed icons, as icons — with the wording a founder picks by.
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in _promotionIcons.entries)
          _IconChoice(
            icon: IconCodec.decode(entry.key),
            label: s.t(entry.value.$1, entry.value.$2),
            active: entry.key == selected,
            ak: ak,
            onTap: () => onSelect(entry.key),
          ),
      ],
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.label,
    required this.active,
    required this.ak,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final AkColors ak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 94,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm + 2,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: active ? ak.primary : ak.surface,
        border: Border.all(color: active ? ak.primary : ak.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: active ? ak.onPrimary : ak.ink),
          const SizedBox(height: AppSpacing.xs + 1),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySecondary.copyWith(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: active ? ak.onPrimary : ak.inkSub,
            ),
          ),
        ],
      ),
    ),
  );
}

/// An amber sentence explaining why the form will not save yet, or what a
/// half-filled field would do to a customer.
class _InlineWarning extends StatelessWidget {
  const _InlineWarning(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: ak.amberBgSoft,
        border: Border.all(color: ak.amberBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.info, size: 14, color: ak.amberText),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.text.bodySecondary.copyWith(
                color: ak.amberDeep,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
