import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';

/// Notifications — fed by booking, escrow, order, and ad events.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('الإشعارات', 'Notifications'))),
      body: SafeArea(
        child: items.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: LucideIcons.bell,
                    title: s.t('لا جديد لديك', "You're all caught up"),
                    message: s.t(
                      'لا شيء ينتظرك الآن — تحديثات الحجز وأحداث الدفع تصلك هنا فور حدوثها.',
                      'Nothing is waiting on you — booking updates and payment events reach you here the moment they happen.',
                    ),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = items[i];
                  return Entrance(
                    delayMs: 35 * i,
                    child: AppCard(
                      onTap: n.route == null
                          ? null
                          : () => context.push(n.route!),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          IconTile(n.icon, size: 40, radius: 13),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(n.title.of(s),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(n.body.of(s),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: ak.inkSub,
                                        height: 1.4)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d MMM · h:mm a',
                                          s.isAr ? 'ar' : 'en')
                                      .format(n.time),
                                  style: TextStyle(
                                      fontSize: 10.5, color: ak.inkFaint),
                                ),
                              ],
                            ),
                          ),
                          if (n.route != null)
                            Icon(LucideIcons.chevronRight,
                                color: ak.inkFaint),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
