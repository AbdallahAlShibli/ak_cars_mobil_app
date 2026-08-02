import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// What a workshop applicant sees the moment they submit (§11 step 4).
///
/// **A receipt, not a welcome.** This exists as its own screen precisely so it
/// cannot be confused with the customer's "account verified — you can now
/// transact" message. Nothing has been approved at this point: a person still
/// has to open the commercial registration document and read it. Telling an
/// applicant they are live and then rejecting them two days later is a worse
/// outcome than a plainly worded wait.
///
/// It therefore promises exactly three things, all of which are true:
/// the submission arrived, a human will read it, and the applicant will be told
/// either way. It does not promise approval, and it does not offer a link to
/// the workshop panel — which the role guard would refuse anyway (§7).
class WorkshopApplicationReceivedScreen extends ConsumerWidget {
  const WorkshopApplicationReceivedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: ak.successSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(LucideIcons.inbox, size: 26, color: ak.success),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  s.t('تم استلام طلبك', 'We have your application'),
                  style: context.text.screenTitle,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  s.t(
                    'فريقنا يراجع بيانات ورشتك — عادة خلال يوم إلى يومي عمل.',
                    'Our team is reviewing your workshop details — usually within one to two working days.',
                  ),
                  style: context.text.bodyPrimary.copyWith(height: 1.7),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  s.t(
                    'بنبلغك فور الاعتماد لتبدأ استقبال الطلبات.',
                    'We will tell you as soon as it is approved, so you can start taking jobs.',
                  ),
                  style: context.text.bodyPrimary.copyWith(height: 1.7),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: ak.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ak.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('إلى أن يتم الاعتماد', 'Until then'),
                          style: context.text.cardTitle),
                      const SizedBox(height: AppSpacing.sm),
                      // Said plainly rather than discovered later: an applicant
                      // who goes looking for the workshop panel and finds it
                      // locked will read that as the app being broken.
                      Text(
                        s.t(
                          'ورشتك لا تظهر للعملاء ولا تستقبل حجوزات، ولوحة الورشة تفتح بعد الاعتماد فقط. تتابع حالة طلبك من صفحة حسابك في أي وقت.',
                          'Your workshop is not shown to customers and takes no bookings, and the workshop panel opens only once you are approved. You can check your application status from your profile at any time.',
                        ),
                        style: context.text.bodySecondary.copyWith(height: 1.7),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.go('/profile'),
                    child: Text(s.t('إلى حسابي', 'Go to my profile')),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.go(AppFlags.startLocation),
                    child: Text(s.t('تصفّح التطبيق', 'Browse the app')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
