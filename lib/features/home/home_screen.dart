import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../data/app_state.dart';
import '../../data/challenge_state.dart';
import '../../data/gallery_data.dart';
import '../../data/maintenance_state.dart';

final _fmt = intl.NumberFormat('#,###', 'en');

/// Home — Sand & Ink (handoff #3b AR / #4b EN / #4c dark): greeting +
/// bell, search pill, amber promo banner, maintenance follow-up mini card,
/// 4-action grid (SOS is the only red), most-searched cars grid.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final auth = ref.watch(authProvider);
    final listings = ref.watch(galleryFeedProvider).take(4).toList();
    final firstName = auth.profile?.name.split(' ').first;

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            // ------------------------------------------------ greeting row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(color: ak.primary, shape: BoxShape.circle),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName != null
                            ? s.greeting(firstName)
                            : s.t('أهلاً بك!', 'Welcome!'),
                        style: const TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        s.greetingSub,
                        style: TextStyle(fontSize: 11, color: ak.inkSub),
                      ),
                    ],
                  ),
                ),
                _BellButton(
                  hasUnread: ref.watch(unreadCountProvider) > 0,
                  onTap: () => context.push('/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            // ------------------------------------------------ search pill
            GestureDetector(
              onTap: () => context.go('/services'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: ak.surface,
                  border: Border.all(color: ak.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.search, size: 16, color: ak.inkSub),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.searchHint,
                        style: TextStyle(fontSize: 12, color: ak.inkSub),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: ak.primary, shape: BoxShape.circle),
                      child: Icon(LucideIcons.slidersHorizontal,
                          size: 13, color: ak.onPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            // ------------------------------------------------ promo banner
            _PromoBanner(s: s),
            const SizedBox(height: 15),
            // ------------------------------------------------ maintenance
            const _MaintenanceMiniCard(),
            const SizedBox(height: 15),
            // ------------------------------------------------ 4 actions
            Row(
              children: [
                _ActionTile(
                  icon: LucideIcons.wrench,
                  label: s.bookService,
                  onTap: () => context.go('/services'),
                ),
                const SizedBox(width: 10),
                _ActionTile(
                  icon: LucideIcons.zap,
                  label: s.roadside,
                  sos: true,
                  onTap: () => context.go('/services'),
                ),
                const SizedBox(width: 10),
                _ActionTile(
                  icon: LucideIcons.shoppingBag,
                  label: s.parts,
                  onTap: () => context.go('/shop'),
                ),
                const SizedBox(width: 10),
                _ActionTile(
                  icon: LucideIcons.car,
                  label: s.sellCar,
                  onTap: () {
                    if (!ensureRegistered(context, ref)) return;
                    context.push('/post-ad');
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),
            // ------------------------------------------------ challenge strip
            const _ChallengeStrip(),
            const SizedBox(height: 15),
            // ------------------------------------------------ most searched
            SandSectionHeader(
              s.mostSearched,
              action: s.viewAll,
              onAction: () => context.go('/cars'),
            ),
            const SizedBox(height: 11),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 1.16,
              children: [
                for (final l in listings)
                  _ListingTile(
                    title: l.displayTitle,
                    price: l.price,
                    make: l.make,
                    model: l.model,
                    onTap: () => context.push('/cars/listing/${l.id}'),
                  ),
              ],
            ),
          ],
        ),
      ),
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
                decoration:
                    BoxDecoration(color: ak.danger, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ak.promoBgA, ak.promoBgB],
        ),
        border: Border.all(color: ak.promoBorder),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('جهّز سيارتك للصيف', 'Get summer-ready'),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: ak.promoTitle,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s.t('فحص تكييف + سائل تبريد بسعر واحد',
                      'AC check + coolant top-up, one price'),
                  style: TextStyle(
                      fontSize: 10.5, color: ak.promoSub, height: 1.6),
                ),
                const SizedBox(height: 9),
                InkPill(
                  label: s.t('احجز بـ 9 ر.ع', 'Book · OMR 9'),
                  fontSize: 10.5,
                  onTap: () => context.go('/services'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: const CarImage(
                  make: 'Toyota', model: 'Land Cruiser', height: 80),
            ),
          ),
        ],
      ),
    );
  }
}

/// Maintenance follow-up mini card — computed only from user-entered
/// odometer + in-app service history (replaces the old fake health score).
class _MaintenanceMiniCard extends ConsumerWidget {
  const _MaintenanceMiniCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final due = ref.watch(maintenanceDueProvider);
    final m = ref.watch(maintenanceProvider);
    final car = ref.watch(primaryCarProvider);
    final carLabel =
        car != null ? '${car.model} ${car.year}' : s.t('كامري 2017', 'Camry 2017');

    final oil = due.firstWhere((d) => d.type == MaintenanceType.oil);
    final tyres = due.firstWhere((d) => d.type == MaintenanceType.tyres);

    return SandCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => context.push('/maintenance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.maintenanceTitle} — $carLabel',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text('${s.details} ›',
                  style: TextStyle(fontSize: 10.5, color: ak.inkSub)),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(child: _dueColumn(context, s, oil)),
              Container(
                width: 1,
                height: 30,
                color: ak.border,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Expanded(child: _dueColumn(context, s, tyres)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${s.t('يُحسب من الممشى الذي تدخله وسجل خدماتك', 'Based on your entered mileage & service history')} · ${_updatedLabel(s, m.odometerUpdatedAt)}',
            style: TextStyle(fontSize: 9.5, color: ak.inkFaint),
          ),
        ],
      ),
    );
  }

  String _updatedLabel(S s, DateTime? at) {
    if (at == null) return s.t('لم يُحدّث بعد', 'not updated yet');
    final days = DateTime.now().difference(at).inDays;
    final when = days <= 0
        ? s.t('اليوم', 'today')
        : days == 1
            ? s.t('أمس', 'yesterday')
            : s.t('قبل $days أيام', '$days days ago');
    return s.t('آخر تحديث: $when', 'updated $when');
  }

  Widget _dueColumn(BuildContext context, S s, DueItem d) {
    final ak = AkColors.of(context);
    final near = d.status == DueStatus.near || d.status == DueStatus.due;
    final color = near ? ak.amber : ak.success;
    final valueColor = near ? ak.amberText : ak.success;

    Widget value;
    if (d.status == DueStatus.noRecord || d.progress == null) {
      value = Text(s.t('لا سجل', 'no record'),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: ak.inkFaint));
    } else if (d.remainingKm != null) {
      value = Text.rich(
        TextSpan(children: [
          TextSpan(text: s.t('باقي ', '')),
          TextSpan(
            text: _fmt.format(d.remainingKm),
            style: AppTheme.numeric(size: 11, color: valueColor),
          ),
          TextSpan(text: s.t(' كم', ' km left')),
        ]),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: valueColor),
      );
    } else {
      final months = d.remainingMonths ?? 0;
      value = Text(
        months <= 0
            ? s.t('حان الآن', 'due now')
            : s.t('بعد $months أشهر', 'in $months months'),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: valueColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(d.type.shortTitle.of(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: ak.inkSub)),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: value),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SandProgressBar(value: d.progress ?? 0, color: color),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: ak.amberBgSoft, shape: BoxShape.circle),
            child: Icon(LucideIcons.flame, size: 17, color: ak.amber),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.weeklyChallenge,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                if (current != null)
                  Text(
                    current.title.of(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: ak.inkSub),
                  ),
              ],
            ),
          ),
          SandStatusPill(
            s.t('${challenge.streakWeeks} أسابيع', '${challenge.streakWeeks}-week streak'),
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          decoration: BoxDecoration(
            color: sos ? ak.dangerSoft : ak.surface,
            border: Border.all(color: sos ? ak.dangerBorder : ak.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(icon, size: 19, color: sos ? ak.danger : ak.ink),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
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

class _ListingTile extends StatelessWidget {
  const _ListingTile({
    required this.title,
    required this.price,
    required this.make,
    required this.model,
    required this.onTap,
  });

  final String title;
  final double? price;
  final String make;
  final String model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: ak.surface,
          border: Border.all(color: ak.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: ak.surfaceDim,
                child: CarImage(make: make, model: model, height: 84),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  price == null
                      ? Text(
                          s.t('السعر عند الطلب', 'Ask for price'),
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: ak.inkSub),
                        )
                      : Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: _fmt.format(price),
                              style: AppTheme.numeric(
                                size: 12.5,
                                color: dark ? ak.amberText : ak.ink,
                              ),
                            ),
                            TextSpan(
                              text: ' ${s.omr}',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: ak.inkSub),
                            ),
                          ]),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
