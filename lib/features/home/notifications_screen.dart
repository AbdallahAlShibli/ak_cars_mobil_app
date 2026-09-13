import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/app_notification.dart';
import '../../state/app_state.dart';

/// Notifications — fed by booking, escrow, order, and ad events.
///
/// **Opening this screen no longer marks everything read.** It used to, from
/// `initState`, which made the unread count a number that could only ever be
/// zero by the time anybody looked at it, and left "mark as read" with nothing
/// to do. Reading is now something the reader does: tapping a card marks that
/// one, its menu marks it without opening it, and the app-bar action marks the
/// lot.
///
/// **Removing a card hides it; the row stays.** See
/// `NotificationService.dismiss` — whether a customer was told their money
/// moved is a question support answers months later, and an inbox is the first
/// thing anybody clears out. The wording here says "delete", because from the
/// reader's side that is exactly what it is.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final items = ref.watch(notificationsProvider);
    final unread = items.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: AkColors.of(context).bg,
      appBar: AppBar(
        title: Text(s.t('الإشعارات', 'Notifications')),
        actions: [
          if (items.isNotEmpty)
            PopupMenuButton<_InboxAction>(
              icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
              tooltip: s.t('خيارات', 'Options'),
              onSelected: (action) => switch (action) {
                _InboxAction.markAllRead => _run(
                  context,
                  ref,
                  (n) => n.markAllRead(),
                ),
                _InboxAction.deleteAll => _confirmDeleteAll(context, ref),
              },
              itemBuilder: (context) => [
                if (unread > 0)
                  PopupMenuItem(
                    value: _InboxAction.markAllRead,
                    child: _MenuLine(
                      icon: LucideIcons.mailOpen,
                      label: s.t('تعليم الكل كمقروء', 'Mark all as read'),
                    ),
                  ),
                PopupMenuItem(
                  value: _InboxAction.deleteAll,
                  child: _MenuLine(
                    icon: LucideIcons.trash2,
                    danger: true,
                    label: s.t('حذف الكل', 'Delete all'),
                  ),
                ),
              ],
            ),
        ],
      ),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.xs,
                  AppSpacing.screenMargin,
                  AppSpacing.xl,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.itemGap + 2),
                itemBuilder: (context, i) => Entrance(
                  // Keyed by the notification, not by its position: without
                  // this the list matches elements by index, so deleting a
                  // card hands its element — and its live `_DismissibleState`
                  // — to whichever notification moved up into that slot.
                  key: ValueKey(items[i].id),
                  delayMs: 35 * i,
                  child: _NotificationCard(notification: items[i]),
                ),
              ),
      ),
    );
  }

  static Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('حذف كل الإشعارات؟', 'Delete all notifications?')),
        content: Text(
          s.t(
            'ستختفي من قائمتك. لا يؤثر ذلك على حجوزاتك ولا على مدفوعاتك.',
            'They disappear from your list. This changes nothing about your '
                'bookings or your payments.',
          ),
          style: const TextStyle(height: 1.5),
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
            child: Text(s.t('حذف الكل', 'Delete all')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, ref, (n) => n.dismissAll());
  }

  /// Runs one inbox action, and says whether it worked.
  ///
  /// A failure is reported rather than swallowed: the notifier leaves the list
  /// exactly as it was, so without a message the control would simply look
  /// dead. The boolean is what lets a swipe spring the card back instead of
  /// completing.
  static Future<bool> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(NotificationsNotifier) action,
  ) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(ref.read(notificationsProvider.notifier));
      return true;
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(s.t('تعذّر تنفيذ الإجراء.', "That didn't go through.")),
        ),
      );
      return false;
    }
  }
}

enum _InboxAction { markAllRead, deleteAll }

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final n = notification;
    final unread = !n.read;

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.horizontal,
      // `confirmDismiss`, not `onDismissed`: the swipe is held open across the
      // round trip and only completes if the server agreed. Dismissing first
      // and undoing on failure is what `Dismissible` forbids — the same key
      // returning to a tree that has recorded it as dismissed asserts — and it
      // also meant a refused delete quietly lost the card. Returning false
      // springs it back, which is the honest answer to "that did not work".
      //
      // No *confirmation dialog*, though: a swipe is already deliberate, and
      // what it removes is a message about something, not the something.
      confirmDismiss: (_) async {
        final ok = await NotificationsScreen._run(
          context,
          ref,
          (notifier) => notifier.dismiss(n.id),
        );
        return ok;
      },
      background: _SwipeBackground(ak: ak, label: s.t('حذف', 'Delete')),
      secondaryBackground: _SwipeBackground(
        ak: ak,
        label: s.t('حذف', 'Delete'),
        trailing: true,
      ),
      child: AppCard(
        // Unread is carried by a tinted surface *and* a dot, not by weight
        // alone: a bold title beside a less-bold one only reads as a state
        // when both happen to be on screen together.
        color: unread ? ak.surfaceDim : null,
        onTap: () {
          if (unread) {
            NotificationsScreen._run(
              context,
              ref,
              (notifier) => notifier.markRead(n.id),
            );
          }
          if (n.route != null) context.push(n.route!);
        },
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg - 2,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(
              n.icon,
              size: 40,
              radius: 13,
              background: unread ? ak.primary : null,
              foreground: unread ? ak.onPrimary : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (unread) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: ak.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm - 2),
                      ],
                      Expanded(
                        child: Text(
                          n.title.of(s),
                          style: context.text.bodyPrimary.copyWith(
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body.of(s),
                    style: context.text.bodySecondary.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormat(
                      'd MMM · h:mm a',
                      s.isAr ? 'ar' : 'en',
                    ).format(n.time),
                    style: context.text.bodySecondary.copyWith(
                      color: ak.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            // The menu says out loud what a swipe cannot, and is the only way
            // to these actions for a reader who never discovers the gesture.
            PopupMenuButton<_CardAction>(
              icon: Icon(
                LucideIcons.ellipsisVertical,
                size: 18,
                color: ak.inkFaint,
              ),
              tooltip: s.t('خيارات الإشعار', 'Notification options'),
              onSelected: (action) => switch (action) {
                _CardAction.markRead => NotificationsScreen._run(
                  context,
                  ref,
                  (notifier) => notifier.markRead(n.id),
                ),
                _CardAction.delete => NotificationsScreen._run(
                  context,
                  ref,
                  (notifier) => notifier.dismiss(n.id),
                ),
              },
              itemBuilder: (context) => [
                if (unread)
                  PopupMenuItem(
                    value: _CardAction.markRead,
                    child: _MenuLine(
                      icon: LucideIcons.mailOpen,
                      label: s.t('تعليم كمقروء', 'Mark as read'),
                    ),
                  ),
                PopupMenuItem(
                  value: _CardAction.delete,
                  child: _MenuLine(
                    icon: LucideIcons.trash2,
                    danger: true,
                    label: s.t('حذف', 'Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardAction { markRead, delete }

/// What sits behind a card mid-swipe. Red and captioned, so the gesture states
/// its outcome before the finger lifts.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.ak,
    required this.label,
    this.trailing = false,
  });

  final AkColors ak;
  final String label;
  final bool trailing;

  @override
  Widget build(BuildContext context) => Container(
    alignment: trailing
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    decoration: BoxDecoration(
      color: ak.dangerSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.trash2, size: 16, color: ak.dangerText),
        const SizedBox(width: AppSpacing.sm - 2),
        Text(
          label,
          style: context.text.bodySecondary.copyWith(
            fontWeight: FontWeight.w700,
            color: ak.dangerText,
          ),
        ),
      ],
    ),
  );
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final color = danger ? ak.dangerText : ak.ink;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm + 2),
        Text(label, style: context.text.bodyPrimary.copyWith(color: color)),
      ],
    );
  }
}
