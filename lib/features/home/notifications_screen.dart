import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';

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
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconTile(Icons.notifications_none_rounded,
                        size: 64,
                        radius: 22,
                        background: AppColors.field,
                        foreground: AppColors.ink3),
                    const SizedBox(height: 12),
                    const Text("You're all caught up",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Booking updates and payment events land here.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.ink2),
                    ),
                  ],
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
                                Text(n.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(n.body,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.ink2,
                                        height: 1.4)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d MMM · h:mm a')
                                      .format(n.time),
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.ink3),
                                ),
                              ],
                            ),
                          ),
                          if (n.route != null)
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFFCBD5E1)),
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
