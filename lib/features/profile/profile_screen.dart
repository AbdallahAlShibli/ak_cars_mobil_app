import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// Rule 11: details, cars, requests, orders, ads, payments — one hub.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final auth = ref.watch(authProvider);
    final garage = ref.watch(garageProvider);
    final requests = ref.watch(requestsProvider);
    final cart = ref.watch(cartProvider);

    final orders = ref.watch(ordersProvider);
    final activeCount = requests
        .where((r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.disputed)
        .length;
    // Held payments = active service requests + unconfirmed shop orders.
    final heldCount =
        activeCount + orders.where((o) => o.status.held).length;

    return Scaffold(
      appBar: AppBar(title: Text(s.navProfile)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
          children: [
            AppCard(
              gradient: AppColors.brandGradient,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (auth.profile?.name.isNotEmpty ?? false)
                            ? auth.profile!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
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
                          auth.profile?.name ?? s.t('زائر', 'Guest'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              auth.isRegistered
                                  ? Icons.verified_rounded
                                  : Icons.info_outline_rounded,
                              size: 13,
                              color: const Color(0xFFD8D2C6),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                auth.isRegistered
                                    ? s.t('${auth.profile!.region} · حساب موثّق',
                                        '${auth.profile!.region} · Verified account')
                                    : s.t('لم يتم التسجيل بعد · اضغط لإكمال البيانات',
                                        'Not registered yet · Tap to complete details'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFD8D2C6)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!auth.isRegistered)
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.directions_car_filled_rounded,
                    label: s.t('سياراتي', 'My cars'),
                    trailing: StatusBadge('${garage.length}'),
                    onTap: () => context.push('/garage'),
                  ),
                  _MenuRow(
                    icon: Icons.build_rounded,
                    label: s.t('طلبات الصيانة', 'Service requests'),
                    trailing: activeCount > 0
                        ? StatusBadge.good(
                            s.t('$activeCount نشط', '$activeCount active'))
                        : null,
                    onTap: () => context.push('/requests'),
                  ),
                  _MenuRow(
                    icon: Icons.inventory_2_outlined,
                    label: s.t('طلبات المتجر', 'Shop orders'),
                    trailing: cart.isNotEmpty
                        ? StatusBadge(s.t('${cart.length} في السلة',
                            '${cart.length} in cart'))
                        : null,
                    onTap: () => context.push('/orders'),
                  ),
                  _MenuRow(
                    icon: Icons.campaign_outlined,
                    label: s.t('إعلاناتي', 'My car ads'),
                    onTap: () => context.go('/cars'),
                  ),
                  _MenuRow(
                    icon: Icons.credit_card_rounded,
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
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.manage_accounts_outlined,
                    label: s.t('بياناتي', 'My details'),
                    gray: true,
                    onTap: () => context.push('/register'),
                  ),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    label: s.t('الإعدادات — اللغة والمظهر',
                        'Settings — language & appearance'),
                    gray: true,
                    trailing: Text(
                      'العربية / EN',
                      style: TextStyle(
                          fontSize: 12,
                          color: AkColors.of(context).inkSub),
                    ),
                    onTap: () => context.push('/settings'),
                  ),
                  _MenuRow(
                    icon: Icons.support_agent_rounded,
                    label: s.t('الدعم', 'Support'),
                    gray: true,
                    onTap: () {},
                    last: true,
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.gray = false,
    this.warm = false,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool gray;
  final bool warm;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(color: ak.divider, width: 1),
                ),
        ),
        child: Row(
          children: [
            IconTile(
              icon,
              size: 36,
              radius: 11,
              background: warm ? ak.amberSoft : ak.surfaceDim,
              foreground: warm
                  ? ak.amberText
                  : gray
                      ? ak.inkSub
                      : ak.ink,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, color: ak.inkFaint),
          ],
        ),
      ),
    );
  }
}
