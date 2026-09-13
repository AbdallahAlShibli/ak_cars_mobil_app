import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';

import '../../di/providers.dart';

import '../../state/app_state.dart';

import 'admin_content_screen.dart';
import 'admin_audit_tab.dart';
import 'admin_money_tab.dart';
import 'admin_offers_tab.dart';
import 'admin_today_tab.dart';
import 'admin_workshops_tab.dart';

import 'operator_shell.dart';

/// The founder's panel (spec §3 note 2 and §6, restructured by phase 2.5 §5).
///
/// It used to be one scrolling column of queues with the offers list bolted to
/// the bottom. That shape stopped working the moment there was more than one
/// kind of decision to make on it: onboarding, disputes, money and offers are
/// four different jobs done at four different times, and stacking them meant
/// scrolling past three of them to reach the fourth.
///
/// Five tabs now — the spec's four, plus the audit log §6 asks to be
/// filterable inside this panel:
///
/// * **Today** — everything waiting on the founder right now, SLA-coloured.
/// * **Workshops** — the onboarding pipeline and the approve/reject decision.
/// * **Money** — the escrow ledger and what each workshop is owed.
/// * **Offers** — the discounts themselves: create, edit, enable, delete.
/// * **Log** — who changed what, when, and why.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);

    return OperatorShell(
      title: s.t('لوحة المؤسس', 'Founder panel'),
      leading: IconButton(
        icon: const BackButtonIcon(),
        // Back to My account, not Settings: the founder-panel door moved
        // there with the workshop-dashboard one, so landing on Settings would
        // drop the user on a screen that no longer has a way back in.
        tooltip: s.t('العودة إلى حسابي', 'Back to my account'),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
      ),
      onRefresh: () async {
        // Re-fetches the roster, ledger and audit log from the server rather
        // than trusting the warm cache taken at this session's last sign-in
        // — a founder whose app was already open when a workshop applied
        // would otherwise never see it without signing out and back in.
        await ref
            .read(serviceMarketplaceRepositoryProvider)
            .warmUp(includeFounderLedger: true);
        await ref.read(operatorQueueProvider.notifier).refresh();
        ref.read(adminRevisionProvider.notifier).state++;
        // Only if the Content tab has actually been opened this session —
        // reading a not-yet-built AsyncNotifierProvider would build it (and
        // fire its first fetch) from every other tab's pull-to-refresh too.
        if (ref.exists(adminOffersProvider)) {
          await ref.read(adminOffersProvider.notifier).refresh();
        }
        if (ref.exists(adminPromotionsProvider)) {
          await ref.read(adminPromotionsProvider.notifier).refresh();
        }
      },
      banner: OffAppTransferNotice(
        s.t(
          'الأرقام هنا تعكس ما سجّله التطبيق فقط. تحويل المبالغ فعلياً يتم خارجه في هذه المرحلة.',
          'These figures reflect only what the app recorded. Actual transfers happen outside it at this stage.',
        ),
      ),
      tabs: [
        OperatorTab(
          label: s.t('اليوم', 'Today'),
          builder: (context) => const AdminTodayTab(),
        ),
        OperatorTab(
          label: s.t('الورش', 'Workshops'),
          builder: (context) => const AdminWorkshopsTab(),
        ),
        OperatorTab(
          label: s.t('المال', 'Money'),
          builder: (context) => const AdminMoneyTab(),
        ),
        OperatorTab(
          label: s.t('العروض', 'Offers'),
          builder: (context) => const AdminOffersTab(),
        ),
        OperatorTab(
          label: s.t('المحتوى', 'Content'),
          builder: (context) => const AdminContentTab(),
        ),
        OperatorTab(
          label: s.t('السجل', 'Log'),
          builder: (context) => const AdminAuditTab(),
        ),
      ],
    );
  }
}
