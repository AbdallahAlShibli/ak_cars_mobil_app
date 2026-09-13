import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import 'home_widgets.dart';

/// The app's front page.
///
/// Not a display case — a starting point for a booking. The home-page spec
/// puts it as a sequence the reader moves through: **حاجة → فرصة → طمأنة**
/// ("your car needs this" → "here is an opportunity now" → "from workshops you
/// can trust"), and fixes the three sections that carry it, in this order:
///
///  1. **حالة سيارتي** — [_CarStatusSection]: each registered car with the one
///     countdown closest to running out and a direct booking button. With an
///     empty garage it is the single "register your car" card.
///  2. **عروض هذا الأسبوع** — [HomeOffersRail]: validated discounts only, and
///     the section is omitted entirely when nothing is discounted.
///  3. **ورش موثوقة** — [HomeTrustedWorkshopsSection]: the two merit-ranked
///     boards, or approved-and-nearby under its own honest heading when there
///     are not enough ratings to rank.
///
/// Everything after those three is supporting material and is ordered by how
/// personal it is: per-car suggestions, then the marketplace's own aggregates,
/// then platform announcements. They are kept because they are real and
/// useful, not because the page would otherwise look short.
///
/// **Nothing here ranks on money.** No section has a paid slot, a boost or a
/// sponsored row (spec §2); every order on this page is computed from live
/// ratings, live booking counts or the user's own mileage.
///
/// **What is on this page is real.** Every section is fed by a provider over
/// the data layer, and each one renders its own empty state rather than
/// filler: the offers rail hides itself when nothing is discounted in the
/// user's governorate, the recommendation rail is empty until there is a car
/// to recommend for, and a workshop nobody has rated does not appear on the
/// ratings board. Nothing is generated to make the page look full.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final auth = ref.watch(authProvider);
    final cars = ref.watch(garageProvider);
    final firstName = auth.profile?.name.split(' ').first;

    // Section 3 has three possible bodies and can end up with none of them —
    // a brand-new marketplace with no approved workshop at all.
    final hasWorkshopsToShow =
        ref.watch(topRatedWorkshopsProvider).items.isNotEmpty ||
        ref.watch(mostRequestedWorkshopsProvider).items.isNotEmpty ||
        ref.watch(approvedWorkshopsProvider).isNotEmpty;

    // Each section is included only when it has something to say. The page asks
    // rather than letting the section render an empty box, because a hidden
    // section that still occupies its spacing leaves a double gap — which reads
    // as a layout bug on the app's front page.
    final sections = <Widget>[
      // ---- the three the spec fixes, in the order it fixes them
      _CarStatusSection(cars: cars),
      if (ref.watch(homeOffersProvider).isNotEmpty) const HomeOffersRail(),
      if (hasWorkshopsToShow) const HomeTrustedWorkshopsSection(),
      // ---- supporting material, most personal first
      if (ref.watch(homeRecommendationsProvider).isNotEmpty)
        const HomeRecommendationsRail(),
      if (ref.watch(mostBookedServicesProvider).isNotEmpty)
        const HomeMostBookedSection(),
      if (ref.watch(homeAnnouncementsProvider).isNotEmpty)
        const HomeAnnouncementsRail(),
      if (AppFlags.weekChallengeEnabled) const _ChallengeStrip(),
    ];

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        bottom: false,
        child: SandRefresh(
          onRefresh: () =>
              ref.read(sessionRefreshProvider).refreshVisibleData(),
          child: ListView(
            // The page can be shorter than the viewport — an empty garage with
            // every optional section hidden is two cards — and a list that
            // does not overscroll cannot be pulled.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.md,
              AppSpacing.screenMargin,
              AppSpacing.xxl,
            ),
            children: [
              // ------------------------------------------------ greeting row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ak.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        firstName?.characters.first.toUpperCase() ??
                            s.t('أ', 'A'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ak.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName != null
                              ? s.greeting(firstName)
                              : s.t('أهلاً بك!', 'Welcome!'),
                          style: context.text.cardTitle,
                        ),
                        Text(s.greetingSub, style: context.text.bodySecondary),
                      ],
                    ),
                  ),
                  _BellButton(
                    hasUnread: ref.watch(unreadCountProvider) > 0,
                    onTap: () => context.push('/notifications'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // ------------------------------------------------ search pill
              GestureDetector(
                onTap: () => context.push('/search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md + 3,
                  ),
                  decoration: BoxDecoration(
                    color: ak.surface,
                    border: Border.all(color: ak.border),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.search, size: 16, color: ak.inkSub),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          s.searchHint,
                          style: context.text.bodySecondary,
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: ak.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.arrowRight,
                          size: 14,
                          color: ak.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // ------------------------------------------------ quick actions
              Row(
                children: [
                  _ActionTile(
                    icon: LucideIcons.wrench,
                    label: s.bookService,
                    onTap: () => context.go('/services'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _ActionTile(
                    icon: LucideIcons.zap,
                    label: s.roadside,
                    sos: true,
                    onTap: () => context.go(
                      '/services?q=${Uri.encodeQueryComponent('roadside')}',
                    ),
                  ),
                  // Phase-2 shortcuts, hidden with their pillars.
                  if (AppFlags.partsStoreEnabled) ...[
                    const SizedBox(width: AppSpacing.md),
                    _ActionTile(
                      icon: LucideIcons.shoppingBag,
                      label: s.parts,
                      onTap: () => context.go('/shop'),
                    ),
                  ],
                  if (AppFlags.carMarketplaceEnabled) ...[
                    const SizedBox(width: AppSpacing.md),
                    _ActionTile(
                      icon: LucideIcons.car,
                      label: s.sellCar,
                      onTap: () {
                        if (!ensureRegistered(context, ref)) return;
                        context.push('/post-ad');
                      },
                    ),
                  ],
                ],
              ),
              // ---------------------------------------------- the sections
              for (final (i, section) in sections.indexed) ...[
                const SizedBox(height: AppSpacing.sectionGap),
                Entrance(delayMs: 60 * i, child: section),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Section 1 — "حالة سيارتي": the user's cars, each with what it needs next.
///
/// A vertical list rather than a horizontal rail because the countdown and the
/// booking button under each picture are the point of the card, and a rail
/// would cut them off. The spec's multi-car note is satisfied by showing every
/// car with its own soonest item; the garage is small by nature (this is one
/// household's cars), so there is no need to collapse it to a single "most
/// urgent overall" card and hide the rest.
///
/// "سياراتي" is deliberately *not* repeated anywhere else on this page (spec
/// §1, closing note): browsing the garage lives on the My Car tab, and here
/// the cars exist to prompt an action.
class _CarStatusSection extends StatelessWidget {
  const _CarStatusSection({required this.cars});

  final List<Car> cars;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SandSectionHeader(
          cars.isEmpty ? s.myCarsTitle : s.carStatusTitle,
          action: cars.isEmpty ? null : s.addCar,
          onAction: cars.isEmpty ? null : () => context.push('/add-car'),
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (cars.isEmpty)
          const HomeAddCarCard()
        else
          for (final (i, car) in cars.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            HomeCarCard(car: car, primary: i == 0),
          ],
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.hasUnread, required this.onTap});

  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ak.surface,
              shape: BoxShape.circle,
              border: Border.all(color: ak.border),
            ),
            child: Icon(LucideIcons.bell, size: 17, color: ak.ink),
          ),
          if (hasUnread)
            PositionedDirectional(
              top: 9,
              end: 11,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: ak.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChallengeStrip extends ConsumerWidget {
  const _ChallengeStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final challenge = ref.watch(challengeProvider);
    final current = challenge.current;

    return SandCard(
      onTap: () => context.push('/challenge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ak.amberBgSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.flame, size: 18, color: ak.amber),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.weeklyChallenge,
                  style: context.text.bodyPrimary.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (current != null)
                  Text(
                    current.title.of(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySecondary,
                  ),
              ],
            ),
          ),
          SandStatusPill(
            s.t(
              '${challenge.streakWeeks} أسابيع',
              '${challenge.streakWeeks}-week streak',
            ),
            background: ak.amberBgSoft,
            foreground: ak.amberText,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sos = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Roadside SOS — the only red tile on the screen.
  final bool sos;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Expanded(
      child: SandPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md + 2,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: sos ? ak.dangerSoft : ak.surface,
            border: Border.all(color: sos ? ak.dangerBorder : ak.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: sos ? ak.danger : ak.ink),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                // Was 9.5px — below the size at which a label is read rather
                // than guessed at from its icon. On the type scale it is
                // `bodySecondary` at label weight, like every other caption
                // that names a control.
                style: context.text.bodySecondary.copyWith(
                  fontWeight: FontWeight.w700,
                  color: sos ? ak.dangerText : ak.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
