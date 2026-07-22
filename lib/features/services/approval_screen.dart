import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

/// Rule 10: provider's photo proof → user approval → payment release.
class ApprovalScreen extends ConsumerWidget {
  const ApprovalScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final request = ref
        .watch(requestsProvider)
        .where((r) => r.id == requestId)
        .firstOrNull;

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('مراجعة', 'Review'))),
        body: Center(
            child: Text(s.t('الطلب غير موجود', 'Request not found'))),
      );
    }

    final completed = request.status == RequestStatus.completed;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              s.t('اكتمل العمل — للمراجعة', 'Work completed — review'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            AppCard(
              child: Row(
                children: [
                  const IconTile(
                    Icons.fact_check_outlined,
                    background: AppColors.goodSoft,
                    foreground: AppColors.good,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.offering.provider.name.of(s),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        Text(
                            s.t('اكتمل · الثلاثاء 10:20 ص',
                                'Marked done · Tue 10:20 am'),
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                  completed
                      ? StatusBadge.good(s.t('تمت الموافقة', 'Approved'))
                      : StatusBadge.warn(s.t('بانتظارك', 'Awaiting you')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(
                s.t('صور الإثبات من المزود', "Provider's proof photos")),
            const SizedBox(height: 9),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 9),
                  Expanded(
                    child: Container(
                      height: 86,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFD8D1C4), Color(0xFFB0A996)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.photo_outlined,
                          size: 26, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Text(
                s.t('"تم تركيب زيت جديد وفلتر أصلي — الفلتر القديم في الصورة 2. اجتاز فحص الـ10 نقاط، وتم ضبط ضغط الإطارات."',
                    '"New oil and genuine filter installed — old filter shown in photo 2. 10-point check passed, tyre pressure adjusted."'),
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.ink2, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.t('المبلغ المُحرَّر', 'Total to release'),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.ink2)),
                  Text(
                    '${s.omr} ${request.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                s.t('يُحرَّر تلقائياً خلال 48 ساعة إذا لم تتخذ أي إجراء',
                    'Auto-releases in 48h if no action is taken'),
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.ink3),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: completed ? AppColors.ink3 : AppColors.good,
              ),
              onPressed: completed
                  ? null
                  : () async {
                      await ref
                          .read(requestsProvider.notifier)
                          .setStatus(request.id, RequestStatus.completed);
                      if (!context.mounted) return;
                      ref.read(notificationsProvider.notifier).adopt(
                            await ref
                                .read(notificationRepositoryProvider)
                                .notifyRequestApproved(request),
                          );
                      if (!context.mounted) return;
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(s.t(
                                'تم تحرير الدفعة للمزود — شكراً لك',
                                'Payment released to the provider — thank you'))),
                      );
                      context.go('/home');
                    },
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(completed
                  ? s.t('تم تحرير الدفعة', 'Payment released')
                  : s.t('الموافقة وتحرير الدفعة',
                      'Approve & release payment')),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bad,
                side: const BorderSide(color: Color(0xFFF3D2D2), width: 1.5),
              ),
              onPressed: completed
                  ? null
                  : () {
                      ref
                          .read(requestsProvider.notifier)
                          .setStatus(request.id, RequestStatus.disputed);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(s.t(
                                'تم فتح نزاع — سيراجع فريقنا الطرفين',
                                'Dispute opened — our team will review both sides'))),
                      );
                      context.go('/home');
                    },
              child: Text(s.t('الإبلاغ عن مشكلة', 'Report a problem')),
            ),
          ],
        ),
      ),
    );
  }
}
