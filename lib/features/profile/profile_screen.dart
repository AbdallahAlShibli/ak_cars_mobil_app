import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/bidi_text.dart';
import '../../core/utils/contact.dart';
import '../../di/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Rule 11: details, cars, requests, orders, ads, payments — one hub.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final auth = ref.watch(authProvider);
    final garage = ref.watch(garageProvider);
    final requests = ref.watch(requestsProvider);
    final orders = ref.watch(ordersProvider);
    final ads = ref.watch(myAdsProvider);
    final cart = ref.watch(cartProvider);
    final settings = ref.watch(settingsProvider);

    final activeCount = requests.where((r) => !r.escrow.isTerminal).length;
    final openOrders = orders.where((o) => o.status.held).length;
    // Held payments = bookings whose escrow is actually holding money, plus
    // unconfirmed shop orders. A booking still awaiting its funds
    // confirmation is *not* holding anything, so it must not be counted.
    final heldCount =
        requests.where((r) => r.escrow.holdsFunds).length + openOrders;

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          children: [
            // ------------------------------------------------- header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.navProfile,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
                _CircleButton(
                  icon: LucideIcons.settings2,
                  tooltip: s.settings,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _IdentityCard(auth: auth),
            if (!auth.isRegistered) ...[
              const SizedBox(height: 10),
              _RegisterPrompt(onTap: () => context.push('/auth')),
            ],
            // §11 step 5. A workshop applicant's only window onto their own
            // application — they have no access to the panel, so without this
            // card the wait is entirely silent.
            if (auth.profile?.isWorkshopAccount ?? false) ...[
              const SizedBox(height: 10),
              const _WorkshopApplicationCard(),
            ],
            const SizedBox(height: 14),
            // ----------------------------------------------- stat tiles
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.carFront,
                    value: '${garage.length}',
                    label: s.t('المرآب', 'Garage'),
                    onTap: () => context.push('/garage'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.wrench,
                    value: '$activeCount',
                    label: s.t('نشط', 'Active'),
                    highlight: activeCount > 0,
                    onTap: () => context.go('/bookings'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.shieldCheck,
                    value: '$heldCount',
                    label: s.t('محتجز', 'Held'),
                    warm: heldCount > 0,
                    onTap: () => context.push('/payments'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SandSectionHeader(s.t('نشاطي', 'My activity')),
            const SizedBox(height: 10),
            _MenuGroup(
              children: [
                _MenuRow(
                  icon: LucideIcons.carFront,
                  label: s.t('سياراتي', 'My cars'),
                  trailing: garage.isEmpty
                      ? null
                      : StatusBadge('${garage.length}'),
                  onTap: () => context.push('/garage'),
                ),
                _MenuRow(
                  icon: LucideIcons.wrench,
                  label: s.t('حجوزاتي', 'My bookings'),
                  trailing: activeCount > 0
                      ? StatusBadge.good(
                          s.t('$activeCount نشط', '$activeCount active'))
                      : null,
                  onTap: () => context.go('/bookings'),
                ),
                // Phase-2 pillars: the rows come back with their flags
                // (lib/config/app_flags.dart), and there is no route to push
                // to while they are off.
                if (AppFlags.partsStoreEnabled) ...[
                  _MenuRow(
                    icon: LucideIcons.package,
                    label: s.t('طلبات المتجر', 'Shop orders'),
                    // Was showing the CART count on the ORDERS row.
                    trailing: openOrders > 0
                        ? StatusBadge.good(
                            s.t('$openOrders جارٍ', '$openOrders open'))
                        : (orders.isEmpty
                            ? null
                            : StatusBadge('${orders.length}')),
                    onTap: () => context.push('/orders'),
                  ),
                  if (cart.isNotEmpty)
                    _MenuRow(
                      icon: LucideIcons.shoppingBag,
                      label: s.t('سلة المشتريات', 'Shopping cart'),
                      trailing: StatusBadge.warn(s.t(
                          '${cart.length} قطعة', '${cart.length} items')),
                      onTap: () => context.push('/cart'),
                    ),
                ],
                if (AppFlags.carMarketplaceEnabled)
                  _MenuRow(
                    icon: LucideIcons.megaphone,
                    label: s.t('إعلاناتي', 'My car ads'),
                    trailing:
                        ads.isEmpty ? null : StatusBadge('${ads.length}'),
                    // Was context.go('/cars') — the whole market, not my ads.
                    onTap: () => context.push('/my-ads'),
                  ),
                _MenuRow(
                  icon: LucideIcons.creditCard,
                  label: s.t('المدفوعات', 'Payments'),
                  warm: true,
                  trailing: heldCount > 0
                      ? StatusBadge.warn(
                          s.t('$heldCount محتجز', '$heldCount held'))
                      : null,
                  onTap: () => context.push('/payments'),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SandSectionHeader(s.t('الحساب', 'Account')),
            const SizedBox(height: 10),
            _MenuGroup(
              children: [
                _MenuRow(
                  icon: LucideIcons.userCog,
                  label: auth.isRegistered
                      ? s.t('بياناتي', 'My details')
                      : s.t('أكمل بياناتك', 'Complete your details'),
                  gray: true,
                  onTap: () =>
                      context.push(auth.isRegistered ? '/register' : '/auth'),
                ),
                _MenuRow(
                  icon: LucideIcons.languages,
                  label: s.t('اللغة والمظهر', 'Language & appearance'),
                  gray: true,
                  // Reflects the live setting instead of a fixed label.
                  trailing: Text(
                    settings.isArabic ? 'العربية' : 'English',
                    style: TextStyle(fontSize: 12, color: ak.inkSub),
                  ),
                  onTap: () => context.push('/settings'),
                ),
                _MenuRow(
                  icon: LucideIcons.headset,
                  label: s.t('الدعم', 'Support'),
                  gray: true,
                  // Was a no-op onTap.
                  onTap: () => _openSupport(context, s),
                ),
                if (auth.isRegistered)
                  _MenuRow(
                    icon: LucideIcons.logOut,
                    label: s.t('تسجيل الخروج', 'Sign out'),
                    danger: true,
                    onTap: () => _confirmSignOut(context, ref, s, ak),
                    last: true,
                  )
                else
                  _MenuRow(
                    icon: LucideIcons.info,
                    label: s.t('عن التطبيق', 'About AK Cars'),
                    gray: true,
                    trailing: Text('v1.0.0',
                        style: TextStyle(fontSize: 12, color: ak.inkFaint)),
                    onTap: () => _showAbout(context, s),
                    last: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- actions

  Future<void> _openSupport(BuildContext context, S s) async {
    final ak = AkColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ak.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle — signals "this sheet can be swiped away" before
              // the user reads a word of it.
              Align(
                alignment: Alignment.center,
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
              Row(
                children: [
                  IconTile(
                    LucideIcons.headset,
                    size: 44,
                    radius: 14,
                    background: ak.amberSoft,
                    foreground: ak.amberText,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('كيف نساعدك؟', 'How can we help?'),
                          style: context.text.cardTitle
                              .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isolateNumbers(
                              s.t('فريق دعم AK Cars متاح من 8 صباحاً حتى 8 مساءً.',
                                  'AK Cars support is available 8am – 8pm.'),
                              rtl: s.isAr),
                          style: context.text.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _SupportOption(
                icon: LucideIcons.messageCircle,
                color: const Color(0xFF25A55A),
                label: s.t('واتساب', 'WhatsApp'),
                subtitle: '+968 9200 0000',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Contact.whatsapp(context, '96892000000',
                      message: s.t('مرحباً، أحتاج مساعدة في تطبيق AK Cars.',
                          'Hi, I need help with the AK Cars app.'));
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _SupportOption(
                icon: LucideIcons.phone,
                color: ak.ink,
                label: s.t('اتصال هاتفي', 'Call us'),
                subtitle: '+968 2400 0000',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Contact.call(context, '+96824000000');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAbout(BuildContext context, S s) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('AK Cars'),
        content: Text(
          s.t('سوق ومنصة خدمات السيارات في سلطنة عُمان.\nالإصدار 1.0.0',
              'Car marketplace and services platform for Oman.\nVersion 1.0.0'),
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('حسناً', 'OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    S s,
    AkColors ak,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.t('تسجيل الخروج؟', 'Sign out?')),
        content: Text(s.t(
            'ستحتاج إلى إدخال بياناتك مرة أخرى قبل إجراء أي معاملة. سياراتك وطلباتك تبقى محفوظة.',
            'You will need to enter your details again before transacting. Your cars and requests stay saved.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ak.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('خروج', 'Sign out')),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      HapticFeedback.mediumImpact();
      ref.read(authProvider.notifier).signOut();
    }
  }
}

/// Identity header. The ink gradient is light-theme only — in dark it would
/// invert to near-white, so dark uses a raised surface instead.
class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.auth});

  final AuthState auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationCatalogProvider);
    final ak = AkColors.of(context);
    final s = S.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final profile = auth.profile;
    final initial = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim().characters.first.toUpperCase()
        : '?';
    final fg = dark ? ak.ink : const Color(0xFFF6F3EE);
    final fgSub = dark ? ak.inkSub : const Color(0xFFD8D2C6);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(auth.isRegistered ? '/register' : '/auth');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: dark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ak.surfaceDim, ak.surface],
                )
              : AppColors.brandGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dark ? ak.border : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: dark
                    ? ak.surface
                    : Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: dark ? ak.border : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
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
                    profile?.name ?? s.t('زائر', 'Guest'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (auth.isRegistered) ...[
                    Row(
                      children: [
                        Icon(LucideIcons.badgeCheck, size: 13, color: fgSub),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            // Region is stored as a canonical English key,
                            // and can be empty on a profile saved before the
                            // field was required — no dangling " · " then.
                            [
                              // Narrowest first — "Seeb, Muscat" — and each
                              // part only when it is actually on file.
                              if (profile!.wilayat.trim().isNotEmpty ||
                                  profile.region.trim().isNotEmpty)
                                [
                                  if (profile.wilayat.trim().isNotEmpty)
                                    locations.localized(profile.wilayat, s.isAr),
                                  if (profile.region.trim().isNotEmpty)
                                    locations.localized(profile.region, s.isAr),
                                ].join(s.isAr ? '، ' : ', '),
                              s.t('حساب موثّق', 'Verified account'),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: fgSub),
                          ),
                        ),
                      ],
                    ),
                    if (profile.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      // A bare "+968 9200 1234" reads left-to-right in both
                      // languages — under RTL it otherwise bidi-reorders to
                      // "1234 9200 968+", same fix as the register form's
                      // phone field (register_screen.dart's `forceLtr`).
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          profile.phone,
                          style: AppTheme.numeric(
                              size: 11, weight: FontWeight.w600, color: fgSub),
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      s.t('لم يتم التسجيل بعد', 'Not registered yet'),
                      style: TextStyle(fontSize: 11.5, color: fgSub),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // A pencil on a guest card promised an editor for details that
            // do not exist yet — a guest is starting registration.
            Icon(
              auth.isRegistered
                  ? LucideIcons.pencil
                  : LucideIcons.chevronRight,
              size: auth.isRegistered ? 17 : 20,
              color: fgSub,
            ),
          ],
        ),
      ),
    );
  }
}

/// Amber call-to-action shown until the user completes registration —
/// transactions are gated behind it, so it should not be a quiet menu row.
/// Where a workshop applicant stands (§11 step 5).
///
/// Renders the three outcomes the onboarding path can be in, and nothing else:
///
/// * **under review** — submitted, nobody has decided. No promises, no ETA the
///   app cannot keep.
/// * **approved** — the panel is open, with the link to it. This is the only
///   place in the customer-facing app that offers that link, and it appears
///   only when the guard would actually let them through (§7).
/// * **needs a change** — the founder's *own words* for why, verbatim, plus
///   the way back in. A rejection the applicant cannot read is a rejection
///   they cannot act on, which is why the reason is mandatory at the point it
///   is recorded.
///
/// Reads the workshop from the marketplace roster rather than from the profile:
/// the profile holds what was *submitted*, and the stage is what the founder
/// *decided*. Showing the second is the whole point of the card.
class _WorkshopApplicationCard extends ConsumerWidget {
  const _WorkshopApplicationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final profile = ref.watch(authProvider).profile;
    if (profile == null) return const SizedBox.shrink();

    final ownerId = profile.id ?? profile.phone;
    final workshop =
        ref.watch(serviceMarketplaceRepositoryProvider).providerOwnedBy(ownerId);
    // Submitted but not yet visible in the roster — treat it as under review
    // rather than as nothing, which is what it is.
    final stage = workshop?.stage ?? ProviderOnboardingStage.documentsSubmitted;
    final rejected = stage == ProviderOnboardingStage.suspended;
    final approved = stage == ProviderOnboardingStage.approved;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: approved
            ? ak.successSoft
            : rejected
                ? ak.dangerSoft
                : ak.amberBgSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: approved
              ? ak.success.withValues(alpha: 0.35)
              : rejected
                  ? ak.dangerBorder
                  : ak.amberBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(stage.icon,
                  size: 17,
                  color: approved
                      ? ak.success
                      : rejected
                          ? ak.dangerText
                          : ak.amberText),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(stage.ownerStatus(s), style: context.text.cardTitle),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            approved
                ? s.t(
                    'ورشتك تظهر الآن للعملاء ويمكنها استقبال الحجوزات.',
                    'Your workshop is now visible to customers and can take bookings.')
                : rejected
                    // The founder's own sentence, unedited. Paraphrasing it
                    // would paraphrase the instruction the owner has to follow.
                    ? '"${workshop?.rejectionReason ?? ''}"'
                    : s.t(
                        'نراجع بيانات ورشتك ووثيقة السجل التجاري. عادة خلال يوم إلى يومي عمل.',
                        'We are checking your details and your commercial registration. Usually within one to two working days.'),
            style: context.text.bodyPrimary.copyWith(height: 1.65),
          ),
          if (approved || rejected) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: InkPill(
                label: approved
                    ? s.t('افتح لوحة الورشة', 'Open the workshop panel')
                    : s.t('عدّل وأعد الإرسال', 'Edit and re-submit'),
                fontSize: 12,
                onTap: () => context.push(approved ? '/workshop' : '/register'),
              ),
            ),
          ],
          if (approved) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              // The role switch is device-local and separate from approval, so
              // an approved workshop that has not switched roles would tap the
              // button and land back in Settings without knowing why.
              s.t('إن لم تفتح اللوحة، بدّل الدور إلى «ورشة» من الإعدادات.',
                  'If the panel does not open, switch your role to "Workshop" in Settings.'),
              style: context.text.bodySecondary.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return SandCard(
      color: ak.amberBgSoft,
      border: Border.all(color: ak.amberBorder),
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 19, color: ak.amberText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.t('أكمل بياناتك لطلب الخدمات وحجز الصيانة.',
                  'Complete your details to request services and book maintenance.'),
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: ak.amberText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkPill(label: s.t('إكمال', 'Complete'), onTap: onTap),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.warm = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final accent = warm
        ? ak.amberText
        : highlight
            ? ak.success
            : ak.ink;
    return SandCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 6),
          Text(value,
              style: AppTheme.numeric(size: 18, color: accent)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: ak.inkSub,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded group that clips its children's ink splashes to the card radius.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ak.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(children: children),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.gray = false,
    this.warm = false,
    this.danger = false,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool gray;
  final bool warm;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: ak.divider, width: 1)),
        ),
        child: Row(
          children: [
            IconTile(
              icon,
              size: 36,
              radius: 11,
              background: danger
                  ? ak.dangerSoft
                  : warm
                      ? ak.amberSoft
                      : ak.surfaceDim,
              foreground: danger
                  ? ak.danger
                  : warm
                      ? ak.amberText
                      : gray
                          ? ak.inkSub
                          : ak.ink,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: danger ? ak.danger : ak.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  // Lucide icons carry no `matchTextDirection`, so the
                  // "go on" chevron is chosen by direction rather than
                  // flipped by the framework.
                  Directionality.of(context) == TextDirection.rtl
                      ? LucideIcons.chevronLeft
                      : LucideIcons.chevronRight,
                  size: 20,
                  color: ak.inkFaint,
                ),
          ],
        ),
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return SandCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          IconTile(icon,
              size: 40,
              radius: 12,
              background: color.withValues(alpha: 0.12),
              foreground: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                // A bare phone number is entirely Latin — pin it to LTR
                // rather than isolate-wrapping it, so the leading "+" can
                // never bidi-jump to the wrong end under an RTL ancestor.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(subtitle,
                      style: AppTheme.numeric(
                          size: 11,
                          weight: FontWeight.w600,
                          color: ak.inkSub)),
                ),
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronLeft
                : LucideIcons.chevronRight,
            size: 20,
            color: ak.inkFaint,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: ak.surface,
          shape: BoxShape.circle,
          border: Border.all(color: ak.border),
        ),
        child: Icon(icon, size: 18, color: ak.ink),
      ),
    );
    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, child: button);
  }
}
