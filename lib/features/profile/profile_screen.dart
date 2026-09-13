import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/constants/app_constants.dart';
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
import '../auth/auth_gate_screen.dart';

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
        child: SandRefresh(
          onRefresh: () =>
              ref.read(sessionRefreshProvider).refreshVisibleData(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.md,
              AppSpacing.screenMargin,
              90,
            ),
            children: [
              // ------------------------------------------------- header row
              // No settings cog: it was a second door to the same screen the
              // "Language & appearance" row in the Account section below already
              // opens, and the header reads cleaner as a plain title. The
              // subtitle is the one fact a customer opens this tab to check.
              SandTabHeader(
                s.navProfile,
                subtitle: auth.isRegistered
                    ? s.t(
                        'سياراتك، حجوزاتك، ومدفوعاتك في مكان واحد',
                        'Your cars, bookings and payments in one place',
                      )
                    : s.t(
                        'سجّل لتحجز وتتابع مدفوعاتك',
                        'Register to book and follow your payments',
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _IdentityCard(auth: auth),
              if (!auth.isRegistered) ...[
                const SizedBox(height: AppSpacing.itemGap + 2),
                _RegisterPrompt(onTap: () => showAuthGate(context)),
              ],
              // §11 step 5. A workshop applicant's only window onto their own
              // application — they have no access to the panel, so without this
              // card the wait is entirely silent. Dismissible once read; the
              // always-visible status row further down is what guarantees the
              // fact itself is never hidden, only the paragraph explaining it.
              if (auth.profile?.isWorkshopAccount ?? false) ...[
                const SizedBox(height: 10),
                const _WorkshopApplicationCard(),
              ],
              // The way into an operator panel, for the accounts that have one.
              // It lives here rather than only in Settings because opening your
              // own dashboard is a thing you do daily, and Settings is where
              // you change how the app behaves — not where you go to work.
              const _BusinessPanelSection(),
              const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _StatTile(
                      icon: LucideIcons.wrench,
                      value: '$activeCount',
                      label: s.t('نشط', 'Active'),
                      highlight: activeCount > 0,
                      onTap: () => context.go('/bookings'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.sectionGap - 2),
              SandSectionHeader(s.t('نشاطي', 'My activity')),
              const SizedBox(height: AppSpacing.headingGap),
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
                            s.t('$activeCount نشط', '$activeCount active'),
                          )
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
                              s.t('$openOrders جارٍ', '$openOrders open'),
                            )
                          : (orders.isEmpty
                                ? null
                                : StatusBadge('${orders.length}')),
                      onTap: () => context.push('/orders'),
                    ),
                    if (cart.isNotEmpty)
                      _MenuRow(
                        icon: LucideIcons.shoppingBag,
                        label: s.t('سلة المشتريات', 'Shopping cart'),
                        trailing: StatusBadge.warn(
                          s.t('${cart.length} قطعة', '${cart.length} items'),
                        ),
                        onTap: () => context.push('/cart'),
                      ),
                  ],
                  if (AppFlags.carMarketplaceEnabled)
                    _MenuRow(
                      icon: LucideIcons.megaphone,
                      label: s.t('إعلاناتي', 'My car ads'),
                      trailing: ads.isEmpty
                          ? null
                          : StatusBadge('${ads.length}'),
                      // Was context.go('/cars') — the whole market, not my ads.
                      onTap: () => context.push('/my-ads'),
                    ),
                  _MenuRow(
                    icon: LucideIcons.creditCard,
                    label: s.t('المدفوعات', 'Payments'),
                    warm: true,
                    trailing: heldCount > 0
                        ? StatusBadge.warn(
                            s.t('$heldCount محتجز', '$heldCount held'),
                          )
                        : null,
                    onTap: () => context.push('/payments'),
                    last: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap - 2),
              SandSectionHeader(s.t('الحساب', 'Account')),
              const SizedBox(height: AppSpacing.headingGap),
              _MenuGroup(
                children: [
                  _MenuRow(
                    icon: LucideIcons.userCog,
                    label: auth.isRegistered
                        ? s.t('بياناتي', 'My details')
                        : s.t('أكمل بياناتك', 'Complete your details'),
                    gray: true,
                    onTap: () => auth.isRegistered
                        ? context.push('/register')
                        : showAuthGate(context),
                  ),
                  // Always here for a workshop account, dismissed card or not.
                  // The card above explains the decision; this row is the fact,
                  // and the fact is not something an owner should ever have to
                  // remember on their own.
                  if (auth.profile?.isWorkshopAccount ?? false)
                    const _WorkshopStatusRow(),
                  _MenuRow(
                    icon: LucideIcons.languages,
                    label: s.t('اللغة والمظهر', 'Language & appearance'),
                    gray: true,
                    // Reflects the live setting instead of a fixed label.
                    trailing: Text(
                      settings.isArabic ? 'العربية' : 'English',
                      style: TextStyle(fontSize: 12.5, color: ak.inkSub),
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
                      trailing: Text(
                        'v${AppConstants.appVersion}',
                        style: TextStyle(fontSize: 12.5, color: ak.inkFaint),
                      ),
                      onTap: () => _showAbout(context, s),
                      last: true,
                    ),
                ],
              ),
            ],
          ),
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
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
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
                          style: context.text.cardTitle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isolateNumbers(
                            s.t(
                              'فريق دعم AK Cars متاح من 8 صباحاً حتى 8 مساءً.',
                              'AK Cars support is available 8am – 8pm.',
                            ),
                            rtl: s.isAr,
                          ),
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
                  Contact.whatsapp(
                    context,
                    '96892000000',
                    message: s.t(
                      'مرحباً، أحتاج مساعدة في تطبيق AK Cars.',
                      'Hi, I need help with the AK Cars app.',
                    ),
                  );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('AK Cars'),
        content: Text(
          s.t(
            'سوق ومنصة خدمات السيارات في سلطنة عُمان.\nالإصدار 1.0.0',
            'Car marketplace and services platform for Oman.\nVersion 1.0.0',
          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.t('تسجيل الخروج؟', 'Sign out?')),
        content: Text(
          s.t(
            'ستحتاج إلى إدخال بياناتك مرة أخرى قبل إجراء أي معاملة. سياراتك وطلباتك تبقى محفوظة.',
            'You will need to enter your details again before transacting. Your cars and requests stay saved.',
          ),
        ),
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
        if (auth.isRegistered) {
          context.push('/register');
        } else {
          unawaited(showAuthGate(context));
        }
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
                color: dark ? ak.surface : Colors.white.withValues(alpha: 0.16),
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
                                    locations.localized(
                                      profile.wilayat,
                                      s.isAr,
                                    ),
                                  if (profile.region.trim().isNotEmpty)
                                    locations.localized(profile.region, s.isAr),
                                ].join(s.isAr ? '، ' : ', '),
                              s.t('حساب موثّق', 'Verified account'),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: fgSub),
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
                            size: 12,
                            weight: FontWeight.w600,
                            color: fgSub,
                          ),
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      s.t('لم يتم التسجيل بعد', 'Not registered yet'),
                      style: TextStyle(fontSize: 12.5, color: fgSub),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // A pencil on a guest card promised an editor for details that
            // do not exist yet — a guest is starting registration.
            Icon(
              auth.isRegistered ? LucideIcons.pencil : LucideIcons.chevronRight,
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
/// Resolves the signed-in account's own workshop, or null when it has never
/// applied. One place, because three widgets on this screen now ask the same
/// question, and asking it three slightly different ways is how they end up
/// disagreeing on screen.
ServiceProvider? _myWorkshop(WidgetRef ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return null;
  return ref
      .watch(serviceMarketplaceRepositoryProvider)
      .providerOwnedBy(profile.id ?? profile.phone);
}

/// Submitted but not yet visible in the roster — "under review" is what that
/// is, and it is closer to the truth than "nothing".
ProviderOnboardingStage _myStage(WidgetRef ref) =>
    _myWorkshop(ref)?.stage ?? ProviderOnboardingStage.documentsSubmitted;

class _WorkshopApplicationCard extends ConsumerWidget {
  const _WorkshopApplicationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final profile = ref.watch(authProvider).profile;
    if (profile == null) return const SizedBox.shrink();

    final workshop = _myWorkshop(ref);
    final stage = _myStage(ref);
    final rejected = stage == ProviderOnboardingStage.suspended;
    final approved = stage == ProviderOnboardingStage.approved;

    // Dismissal is keyed on the stage, so putting away "you're approved"
    // never also puts away a later "your workshop was stopped" — see
    // `WorkshopNoticeDismissalNotifier`.
    if (ref.watch(workshopNoticeDismissalProvider) == stage.key) {
      return const SizedBox.shrink();
    }

    final accent = approved
        ? ak.success
        : rejected
        ? ak.dangerText
        : ak.amberText;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(stage.icon, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    stage.ownerStatus(s),
                    style: context.text.cardTitle,
                  ),
                ),
              ),
              // Sized down to the glyph: a default 48pt IconButton would
              // stretch the header row and push the title off its own
              // baseline.
              SizedBox(
                width: 26,
                height: 26,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  iconSize: 15,
                  tooltip: s.t('إخفاء هذه البطاقة', 'Hide this card'),
                  icon: Icon(LucideIcons.x, color: accent),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(workshopNoticeDismissalProvider.notifier)
                        .dismiss(stage.key);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.t(
                            'أُخفيت. حالة ورشتك تبقى ظاهرة في قسم الحساب بالأسفل.',
                            'Hidden. Your workshop status stays in the Account section below.',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            approved
                ? s.t(
                    'ورشتك تظهر الآن للعملاء ويمكنها استقبال الحجوزات.',
                    'Your workshop is now visible to customers and can take bookings.',
                  )
                : rejected
                // The founder's own sentence, unedited. Paraphrasing it
                // would paraphrase the instruction the owner has to
                // follow.
                ? '"${workshop?.rejectionReason ?? ''}"'
                : s.t(
                    'نراجع بيانات ورشتك ووثيقة السجل التجاري. عادة خلال يوم إلى يومي عمل.',
                    'We are checking your details and your commercial registration. Usually within one to two working days.',
                  ),
            style: context.text.bodyPrimary.copyWith(height: 1.65),
          ),
          if (rejected) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: InkPill(
                label: s.t('عدّل وأعد الإرسال', 'Edit and re-submit'),
                fontSize: 12.5,
                onTap: () => context.push('/register'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The always-visible "is my workshop live or not" row, in the Account
/// section. Never dismissible: the card at the top of this screen carries the
/// explanation and can be put away once read, but the status itself has to
/// stay somewhere an owner can find without re-reading a notice they already
/// closed.
///
/// Tapping opens [_WorkshopStatusDialog] — the row shows the verdict, the
/// dialog shows the record behind it, which is the level of detail an owner
/// wants when they are checking rather than working.
class _WorkshopStatusRow extends ConsumerWidget {
  const _WorkshopStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final stage = _myStage(ref);

    return _MenuRow(
      icon: stage.icon,
      label: s.t('حالة الورشة', 'Workshop status'),
      gray: true,
      trailing: _stageBadge(stage, s),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _WorkshopStatusDialog(),
      ),
    );
  }
}

StatusBadge _stageBadge(ProviderOnboardingStage stage, S s) => switch (stage) {
  ProviderOnboardingStage.approved => StatusBadge.good(stage.label(s)),
  ProviderOnboardingStage.suspended => StatusBadge.bad(stage.label(s)),
  _ => StatusBadge.warn(stage.label(s)),
};

/// The workshop at a glance: what it is called, where it is, how it is
/// reachable, and where it stands with the platform.
///
/// Read-only on purpose. Everything here is either the founder's decision
/// (the stage, the rejection reason) or the registered record behind it —
/// neither is something to edit from a status popup, and both have a proper
/// home elsewhere (the founder's workshop screen, and re-submission).
///
/// Laid out as a sheet rather than as a title-and-body alert: a tinted header
/// carries the identity and the verdict, the body carries the one sentence
/// that explains it and a four-step rail showing where in the review the
/// application actually is, and the registered record sits in its own grouped
/// card. Still an [AlertDialog] — the shape is entirely in the content, so
/// the barrier, the dismiss behaviour and the platform padding stay standard.
class _WorkshopStatusDialog extends ConsumerWidget {
  const _WorkshopStatusDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final workshop = _myWorkshop(ref);
    final stage = _myStage(ref);
    final approved = stage == ProviderOnboardingStage.approved;
    final rejected = stage == ProviderOnboardingStage.suspended;
    final hidden = ref.watch(workshopNoticeDismissalProvider) == stage.key;

    final accent = approved
        ? ak.success
        : rejected
        ? ak.dangerText
        : ak.amberText;
    final band = approved
        ? ak.successSoft
        : rejected
        ? ak.dangerSoft
        : ak.amberBgSoft;

    final where = workshop == null
        ? ''
        : [
            workshop.area,
            workshop.region,
          ].where((p) => p.trim().isNotEmpty).join(' · ');

    return AlertDialog(
      backgroundColor: ak.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: band,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: ak.surface,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(stage.icon, size: 20, color: accent),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                // Falls back to the name on the filed
                                // application: a workshop still under review
                                // has no roster entry yet, and an em-dash
                                // would read as data loss rather than "not
                                // live".
                                workshop?.name.of(s) ??
                                    ref
                                        .watch(authProvider)
                                        .profile
                                        ?.workshop
                                        ?.businessNameAr ??
                                    s.t('ورشتك', 'Your workshop'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                              if (where.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  where,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: ak.inkSub,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _stageBadge(stage, s),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.ownerStatus(s),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      approved
                          ? s.t(
                              'ورشتك تظهر للعملاء ويمكنها استقبال الحجوزات.',
                              'Your workshop is visible to customers and can take bookings.',
                            )
                          : rejected
                          // The founder's own sentence, unedited —
                          // paraphrasing it would paraphrase the instruction
                          // the owner has to follow.
                          ? '"${workshop?.rejectionReason ?? ''}"'
                          : s.t(
                              'نراجع بياناتك ووثيقة السجل التجاري. عادة خلال يوم إلى يومي عمل.',
                              'We are checking your details and your commercial registration. Usually within one to two working days.',
                            ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: ak.inkSub,
                        height: 1.6,
                      ),
                    ),
                    if (!rejected) ...[
                      const SizedBox(height: AppSpacing.md),
                      _StageRail(stage: stage, accent: accent),
                    ],
                    if (workshop != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: ak.surfaceDim,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            if ((workshop.phone ?? '').isNotEmpty)
                              _DialogFact(
                                icon: LucideIcons.phone,
                                label: s.t('الهاتف', 'Phone'),
                                value: workshop.phone!,
                              ),
                            if ((workshop.whatsapp ?? '').isNotEmpty)
                              _DialogFact(
                                icon: LucideIcons.messageCircle,
                                label: s.t('واتساب', 'WhatsApp'),
                                value: workshop.whatsapp!,
                              ),
                            if ((workshop.hours?.of(s) ?? '').isNotEmpty)
                              _DialogFact(
                                icon: LucideIcons.clock,
                                label: s.t('ساعات العمل', 'Working hours'),
                                value: workshop.hours!.of(s),
                              ),
                            if ((workshop.crNumber ?? '').isNotEmpty)
                              _DialogFact(
                                icon: LucideIcons.fileText,
                                label: s.t('رقم السجل التجاري', 'CR number'),
                                value: workshop.crNumber!,
                              ),
                            _DialogFact(
                              icon: LucideIcons.badgeCheck,
                              label: s.t('التوثيق', 'Verification'),
                              value: workshop.verified
                                  ? s.t('موثّقة', 'Verified')
                                  : s.t('غير موثّقة بعد', 'Not verified yet'),
                              last: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Only offered while the card is actually hidden —
                    // otherwise it would be a button that does nothing
                    // visible.
                    if (hidden) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          icon: const Icon(LucideIcons.eye, size: 15),
                          label: Text(
                            s.t(
                              'أعد إظهار بطاقة الحالة',
                              'Show the status card again',
                            ),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          onPressed: () {
                            ref
                                .read(workshopNoticeDismissalProvider.notifier)
                                .restore();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (approved)
                      _DialogAction(
                        icon: LucideIcons.layoutDashboard,
                        label: s.t('لوحة الورشة', 'Dashboard'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/workshop/dashboard');
                        },
                      )
                    else if (rejected)
                      _DialogAction(
                        icon: LucideIcons.pencil,
                        label: s.t('عدّل وأعد الإرسال', 'Edit and re-submit'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/register');
                        },
                      ),
                    if (approved || rejected)
                      const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      height: 44,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(s.t('إغلاق', 'Close')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the application sits in the founder's review, as the four stages the
/// backend actually has — not a spinner and not a percentage.
///
/// Suspended is deliberately absent: it is not a step on this path, it is the
/// path ending, and the reason above already says so.
class _StageRail extends StatelessWidget {
  const _StageRail({required this.stage, required this.accent});

  final ProviderOnboardingStage stage;
  final Color accent;

  static const _steps = [
    ProviderOnboardingStage.applied,
    ProviderOnboardingStage.documentsSubmitted,
    ProviderOnboardingStage.verified,
    ProviderOnboardingStage.approved,
  ];

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final index = _steps.indexOf(stage);
    if (index < 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= index ? accent : ak.surfaceDim,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Text(
          isolateNumbers(
            s.t(
              'الخطوة ${index + 1} من ${_steps.length} · ${stage.label(s)}',
              'Step ${index + 1} of ${_steps.length} · ${stage.label(s)}',
            ),
            rtl: s.isAr,
          ),
          style: TextStyle(fontSize: 12.5, color: ak.inkFaint),
        ),
      ],
    );
  }
}

/// The dialog's primary action — full width, so the one thing to do next is
/// not a small word in a corner.
class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
    ),
  );
}

/// One labelled fact inside [_WorkshopStatusDialog]'s record card.
class _DialogFact extends StatelessWidget {
  const _DialogFact({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Suppresses the divider under the last row of the card.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: ak.inkFaint),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isolateNumbers(value, rtl: S.of(context).isAr),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last) Divider(color: ak.divider, height: 1),
      ],
    );
  }
}

/// The entry into an operator panel — the workshop dashboard for an approved
/// owner, the founder panel for a founder, both for an account that is both.
///
/// A card at the top of "My account" rather than only a row in Settings: for
/// these accounts this is the most-used destination in the whole app, and
/// Settings is where you change how the app behaves, not where you go to
/// work. Renders nothing for an ordinary customer, and nothing for a workshop
/// owner whose application has not been approved — there is no panel behind
/// the button yet, and `_guardOperatorPanels` would bounce them straight back
/// to Settings if they pressed it.
class _BusinessPanelSection extends ConsumerWidget {
  const _BusinessPanelSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppFlags.operatorPanelsEnabled) return const SizedBox.shrink();

    final auth = ref.watch(authProvider);
    final isFounder = auth.isFounder;
    final ownsWorkshop = auth.profile?.isWorkshopAccount ?? false;
    final workshop = ownsWorkshop ? _myWorkshop(ref) : null;
    final approved = workshop?.isApproved ?? false;

    if (!isFounder && !approved) return const SizedBox.shrink();

    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        SandSectionHeader(s.t('عملي', 'My business')),
        const SizedBox(height: 10),
        if (approved)
          _PanelCard(
            icon: LucideIcons.store,
            title: s.t('لوحة الورشة', 'Workshop dashboard'),
            subtitle: workshop == null
                ? s.t('طلباتك ومخزونك وفريقك', 'Your jobs, stock and team')
                : workshop.name.of(s),
            badge: StatusBadge.good(s.t('مفتوحة', 'Live')),
            onTap: () => context.go('/workshop/dashboard'),
          ),
        if (approved && isFounder) const SizedBox(height: 10),
        if (isFounder)
          _PanelCard(
            icon: LucideIcons.shieldCheck,
            title: s.t('لوحة المؤسس', 'Founder panel'),
            subtitle: s.t(
              'الورش والطلبات ومحتوى المنصة',
              'Workshops, requests and platform content',
            ),
            onTap: () => context.go('/admin'),
          ),
      ],
    );
  }
}

/// One tappable panel entry: icon tile, title, one line of context, an
/// optional status badge, and a chevron that follows the text direction.
class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return SandCard(
      radius: 18,
      padding: const EdgeInsets.all(13),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          IconTile(
            icon,
            size: 42,
            radius: 14,
            background: ak.amberSoft,
            foreground: ak.amberText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: 8), badge!],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronLeft
                : LucideIcons.chevronRight,
            size: 18,
            color: ak.inkSub,
          ),
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
              s.t(
                'أكمل بياناتك لطلب الخدمات وحجز الصيانة.',
                'Complete your details to request services and book maintenance.',
              ),
              style: TextStyle(
                fontSize: 12.5,
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
    return SandPressable(
      onTap: onTap,
      child: SandCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg - 2,
          horizontal: AppSpacing.sm,
        ),
        // The dip comes from [SandPressable]; the card keeps the haptic.
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, size: 19, color: accent),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: AppTheme.numeric(size: 20, color: accent)),
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySecondary.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                  fontSize: 14,
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
          IconTile(
            icon,
            size: 40,
            radius: 12,
            background: color.withValues(alpha: 0.12),
            foreground: color,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // A bare phone number is entirely Latin — pin it to LTR
                // rather than isolate-wrapping it, so the leading "+" can
                // never bidi-jump to the wrong end under an RTL ancestor.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    subtitle,
                    style: AppTheme.numeric(
                      size: 12,
                      weight: FontWeight.w600,
                      color: ak.inkSub,
                    ),
                  ),
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
