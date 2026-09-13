import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import 'admin_form_widgets.dart';
import 'admin_panel_widgets.dart';
import 'offer_editor_sheet.dart';

/// The founder panel's Offers tab — every discount the platform holds, and the
/// full authority over it: create, edit, enable/stop, delete.
///
/// It used to be an approval switch and nothing else, on the reasoning that a
/// screen which could quietly adjust a price would hollow out the validation it
/// existed to enforce. That reasoning survives, but as a constraint on the
/// *editor* rather than on the screen: [Offer.referencePrice] is still never
/// typed — it is copied from the catalogue's published price for the selected
/// service — and the rules in `ServiceMarketplaceRepository.rejectionFor` still
/// run on every read here exactly as they run on the home page. What changed is
/// that the founder no longer needs a second surface to originate an offer, and
/// there is no longer a list on the Content tab saying almost the same thing as
/// this one.
///
/// Two things worth knowing about the data:
///
/// * It reads [adminOfferAuditProvider] (`/offers/all`), not the warm public
///   catalogue. The public endpoint returns only approved, in-window offers, so
///   a management list built on it could never show the row it had just
///   created.
/// * Every reason a row is not live is printed on the row. "Why is my discount
///   not showing?" is the question this screen exists to answer, and the answer
///   comes from the same validation the home page runs rather than a second
///   opinion.
class AdminOffersTab extends ConsumerStatefulWidget {
  const AdminOffersTab({super.key});

  @override
  ConsumerState<AdminOffersTab> createState() => _AdminOffersTabState();
}

/// Which slice of the list is on screen.
enum _OfferFilter { all, live, blocked, expired }

class _AdminOffersTabState extends ConsumerState<AdminOffersTab> {
  _OfferFilter _filter = _OfferFilter.all;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final audit = ref.watch(adminOfferAuditProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: [
        audit.when(
          loading: () => const AdminLoadingBlock(),
          error: (_, _) => AdminErrorBlock(
            message: s.t('تعذّر تحميل العروض.', 'Could not load offers.'),
            onRetry: () => ref.read(adminOffersProvider.notifier).refresh(),
          ),
          data: _buildList,
        ),
      ],
    );
  }

  Widget _buildList(List<({Offer offer, OfferRejection? rejection})> rows) {
    final s = S.of(context);
    final now = DateTime.now();
    final ak = AkColors.of(context);

    final counts = <_OfferFilter, int>{
      _OfferFilter.all: rows.length,
      _OfferFilter.live: 0,
      _OfferFilter.blocked: 0,
      _OfferFilter.expired: 0,
    };
    for (final row in rows) {
      final bucket = _bucketOf(row, now);
      counts[bucket] = counts[bucket]! + 1;
    }

    final visible =
        [
          for (final row in rows)
            if (_filter == _OfferFilter.all || _bucketOf(row, now) == _filter)
              row,
        ]..sort((a, b) {
          // Anything waiting on a decision comes first, expired last: a founder
          // opening this tab is here to unblock something, and a live offer
          // needs nothing from them.
          final byRank = _rank(a, now).compareTo(_rank(b, now));
          if (byRank != 0) return byRank;
          return a.offer.endsAt.compareTo(b.offer.endsAt);
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSummaryCard(
          icon: LucideIcons.tag,
          title: s.t('العروض', 'Offers'),
          subtitle: s.t(
            'الخصومات المؤقتة على الخدمات المسعّرة.',
            'Time-boxed discounts on priced services.',
          ),
          // "Live" is the only figure a customer would recognise; the other two
          // are the founder's own backlog. An offer that exists and an offer
          // that is showing are different facts, so the card states both.
          stats: [
            AdminStat.count(
              counts[_OfferFilter.live] ?? 0,
              label: s.t('ظاهر الآن', 'Live now'),
              color: ak.success,
            ),
            AdminStat.count(
              counts[_OfferFilter.blocked] ?? 0,
              label: s.t('محجوب', 'Blocked'),
              color: ak.amberText,
            ),
            AdminStat.count(
              counts[_OfferFilter.expired] ?? 0,
              label: s.t('منتهٍ', 'Expired'),
              color: ak.inkFaint,
            ),
          ],
          actionLabel: s.t('عرض جديد', 'New offer'),
          actionIcon: LucideIcons.plus,
          onAction: () => showOfferEditorSheet(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (rows.isNotEmpty) ...[
          AdminFilterRow<_OfferFilter>(
            selected: _filter,
            onSelect: (filter) => setState(() => _filter = filter),
            filters: [
              for (final filter in _OfferFilter.values)
                AdminFilter(
                  value: filter,
                  label: _filterLabel(s, filter),
                  count: counts[filter],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (rows.isEmpty)
          EmptyState(
            icon: LucideIcons.tag,
            title: s.t('لا عروض بعد', 'No offers yet'),
            message: s.t(
              'العرض خصم محدَّد بمدة على خدمة لها سعر معلن. أنشئ أول عرض '
                  'وسيظهر في الرئيسية وصفحة الخدمات فور تفعيله.',
              'An offer is a time-boxed discount on a service that already has '
                  'a published price. Create one and it shows on Home and the '
                  'Services page as soon as it is enabled.',
            ),
            action: InkPill(
              label: s.t('عرض جديد', 'New offer'),
              icon: LucideIcons.plus,
              fontSize: 12,
              onTap: () => showOfferEditorSheet(context),
            ),
          )
        else if (visible.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.funnel,
            message: s.t(
              'لا عروض في هذا التصنيف.',
              'No offers under this filter.',
            ),
          )
        else
          for (final (i, row) in visible.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _OfferCard(offer: row.offer, rejection: row.rejection, now: now),
          ],
      ],
    );
  }

  static _OfferFilter _bucketOf(
    ({Offer offer, OfferRejection? rejection}) row,
    DateTime now,
  ) {
    if (row.offer.endsAt.isBefore(now)) return _OfferFilter.expired;
    if (row.rejection == null) return _OfferFilter.live;
    return _OfferFilter.blocked;
  }

  static int _rank(
    ({Offer offer, OfferRejection? rejection}) row,
    DateTime now,
  ) => switch (_bucketOf(row, now)) {
    _OfferFilter.expired => 2,
    _OfferFilter.live => 1,
    _ => 0,
  };

  static String _filterLabel(S s, _OfferFilter filter) => switch (filter) {
    _OfferFilter.all => s.t('الكل', 'All'),
    _OfferFilter.live => s.t('ظاهر', 'Live'),
    _OfferFilter.blocked => s.t('محجوب', 'Blocked'),
    _OfferFilter.expired => s.t('منتهٍ', 'Expired'),
  };
}

// ==================================================================== card

/// One offer, as the founder sees it.
///
/// The card leads with the thing the customer would see — the percentage off
/// and the price it lands at — because that is what makes an offer worth
/// running or worth stopping. Everything under it is the platform's own view:
/// the window, the regions, and, when it is not showing, the single rule that
/// is keeping it off the page.
class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({
    required this.offer,
    required this.rejection,
    required this.now,
  });

  final Offer offer;
  final OfferRejection? rejection;
  final DateTime now;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _busy = false;

  Offer get _offer => widget.offer;

  bool get _expired => _offer.endsAt.isBefore(widget.now);

  bool get _live => widget.rejection == null;

  /// A rejection the founder's switch cannot clear. Flipping the switch on an
  /// offer whose reference price is wrong changes nothing, and the card says so
  /// rather than letting the founder toggle at it.
  bool get _blockedByOther =>
      widget.rejection != null &&
      widget.rejection != OfferRejection.notApprovedByFounder;

  Future<void> _setActive(bool active) async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(adminOffersProvider.notifier)
          .setActive(_offer.id, active: active);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t('تعذّر تغيير الحالة.', "Couldn't change the status."),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('حذف العرض؟', 'Delete this offer?')),
        content: Text(
          s.t(
            'سيختفي فوراً من الرئيسية وصفحة الخدمات. لا يمكن التراجع.',
            'It disappears from Home and the Services page immediately. This '
                'cannot be undone.',
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

    setState(() => _busy = true);
    try {
      await ref.read(adminOffersProvider.notifier).delete(_offer.id);
    } catch (_) {
      // Only reset the flag on failure: on success this card is already gone
      // from the list, and calling setState on a disposed element throws.
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('تعذّر الحذف.', 'Could not delete.'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
    final offering = marketplace.offeringById(_offer.serviceOfferingId);
    final workshop = marketplace.providerById(_offer.workshopId);

    return AppCard(
      padding: EdgeInsets.zero,
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
                _DiscountBadge(
                  percent: _offer.discountPercent.round(),
                  live: _live,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offering?.name.of(s).replaceAll('\n', ' ') ??
                            s.t('خدمة محذوفة', 'Deleted service'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.cardTitle,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(LucideIcons.store, size: 12, color: ak.inkFaint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              workshop?.name.of(s) ??
                                  offering?.provider.name.of(s) ??
                                  _offer.workshopId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _statusBadge(s),
              ],
            ),
          ),
          AdminInsetDivider(color: ak.divider),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RialAmount(
                      _offer.discountedPrice,
                      style: context.text.price,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: RialAmount(
                        _offer.referencePrice,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySecondary.copyWith(
                          color: ak.inkFaint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs + 2,
                  children: [
                    AdminMetaChip(
                      icon: LucideIcons.banknote,
                      child: RialAmount(
                        _offer.savings,
                        prefix: '${s.t('توفير', 'Saves')} ',
                        style: context.text.bodySecondary.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: ak.success,
                        ),
                      ),
                    ),
                    AdminMetaChip(
                      icon: LucideIcons.calendar,
                      label:
                          '${formatAdminDate(_offer.startsAt)} → '
                          '${formatAdminDate(_offer.endsAt)}',
                    ),
                    AdminMetaChip(
                      icon: _expired
                          ? LucideIcons.calendarOff
                          : LucideIcons.clock,
                      label: _windowLabel(s),
                      tone: _expired
                          ? AdminChipTone.dim
                          : (_offer.daysLeft(widget.now) <= 3
                                ? AdminChipTone.warn
                                : AdminChipTone.normal),
                    ),
                    if (_offer.regions.isNotEmpty)
                      AdminMetaChip(
                        icon: LucideIcons.mapPin,
                        label: _offer.regions.join(s.t('، ', ', ')),
                      ),
                  ],
                ),
                if (widget.rejection != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ReasonNote(
                    rejection: widget.rejection!,
                    actionable: _blockedByOther,
                  ),
                ],
              ],
            ),
          ),
          AdminInsetDivider(color: ak.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Semantics(
                  label: s.t('ظاهر للعملاء', 'Visible to customers'),
                  child: Switch(
                    value: _offer.activeByFounder,
                    onChanged: _busy ? null : _setActive,
                  ),
                ),
                Expanded(
                  child: Text(
                    _offer.activeByFounder
                        ? s.t('مفعّل', 'Enabled')
                        : s.t('موقوف', 'Stopped'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySecondary.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _offer.activeByFounder ? ak.ink : ak.inkFaint,
                    ),
                  ),
                ),
                AdminCardAction(
                  icon: LucideIcons.pencil,
                  tooltip: s.t('تعديل', 'Edit'),
                  onTap: _busy
                      ? null
                      : () => showOfferEditorSheet(context, existing: _offer),
                ),
                AdminCardAction(
                  icon: LucideIcons.trash2,
                  tooltip: s.t('حذف', 'Delete'),
                  danger: true,
                  onTap: _busy ? null : _delete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(S s) {
    if (_expired) return StatusBadge(s.t('منتهٍ', 'Expired'));
    if (_live) return StatusBadge.good(s.t('ظاهر', 'Live'));
    return StatusBadge.warn(s.t('محجوب', 'Blocked'));
  }

  String _windowLabel(S s) {
    if (_expired) return s.t('انتهى', 'Ended');
    if (_offer.startsAt.isAfter(widget.now)) {
      return s.t('لم يبدأ بعد', 'Not started');
    }
    final left = _offer.daysLeft(widget.now);
    if (left == 0) return s.t('آخر يوم', 'Last day');
    return s.t('يتبقى ${s.days(left)}', '${s.days(left)} left');
  }
}

/// The headline number, as a tile rather than a line of text.
///
/// A percentage is the one part of an offer that can be read at a glance while
/// scrolling, and it is also the platform's only ranking signal on the home
/// page (spec §2: biggest real saving first, nothing buyable) — so it gets the
/// weight here that it gets there.
class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.percent, required this.live});

  final int percent;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final bg = live ? ak.primary : ak.surfaceDim;
    final fg = live ? ak.onPrimary : ak.inkSub;

    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: fg,
              height: 1.05,
            ),
          ),
          Text(
            s.t('خصم', 'off'),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: fg.withValues(alpha: 0.75),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the offer is not showing, in the platform's own words.
///
/// [actionable] separates the two very different cases that used to look
/// identical: an offer merely awaiting the founder's switch (normal, one tap
/// away, stated plainly) and an offer the switch cannot rescue — a stale
/// reference price, an unapproved workshop — which needs someone to go and fix
/// the underlying record.
class _ReasonNote extends StatelessWidget {
  const _ReasonNote({required this.rejection, required this.actionable});

  final OfferRejection rejection;
  final bool actionable;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final reason = s.isAr ? rejection.reason.$1 : rejection.reason.$2;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: actionable ? ak.amberBgSoft : ak.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: actionable ? ak.amberBorder : ak.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            actionable ? LucideIcons.triangleAlert : LucideIcons.info,
            size: 14,
            color: actionable ? ak.amberText : ak.inkFaint,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: context.text.bodySecondary.copyWith(
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: actionable ? ak.amberText : ak.inkSub,
                  ),
                ),
                if (actionable) ...[
                  const SizedBox(height: 2),
                  Text(
                    s.t(
                      'التفعيل وحده لن يُظهره — عالج السبب أولاً.',
                      'Enabling alone will not show it — fix the cause first.',
                    ),
                    style: context.text.bodySecondary.copyWith(
                      fontSize: 11,
                      height: 1.4,
                      color: ak.amberText.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A square icon button on the card's action bar.
