import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/guid.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../state/provider_dashboard_state.dart';
import 'check_in_tab.dart';
import 'extra_work_tab.dart';
import 'inspection_tab.dart';
import 'invoice_tab.dart';
import 'job_card_tab.dart';

/// Everything a workshop records about one booking while the car is with it
/// (2026-09-15): check-in, inspection, extra work, the internal job card and
/// the invoice. Reached from a job card in the Orders screen, and from the
/// notifications the API sends (`/workshop/dashboard/jobs/{id}`).
///
/// The booking comes from [workshopRequestsProvider]. A tab that saves hands
/// back the booking with its change applied, which is shown at once while the
/// list refreshes from the server behind it.
class JobWorkspaceScreen extends ConsumerStatefulWidget {
  const JobWorkspaceScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<JobWorkspaceScreen> createState() => _JobWorkspaceScreenState();
}

class _JobWorkspaceScreenState extends ConsumerState<JobWorkspaceScreen> {
  ServiceRequest? _known;

  void _changed(ServiceRequest updated) {
    setState(() => _known = updated);
    unawaited(ref.read(workshopRequestsProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final requests = ref.watch(workshopRequestsProvider);
    final fresh = requests.valueOrNull
        ?.where((r) => r.id == widget.requestId)
        .firstOrNull;
    if (fresh != null) _known = fresh;
    final request = _known;

    if (request == null) {
      final loading = requests.isLoading || !requests.hasValue && !requests.hasError;
      return Scaffold(
        backgroundColor: ak.bg,
        appBar: AppBar(title: Text(s.t('ملف العمل', 'Job workspace'))),
        body: loading
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.screenMargin),
                child: Column(
                  children: [
                    Skeleton(height: 120),
                    SizedBox(height: AppSpacing.md),
                    Skeleton(height: 220),
                  ],
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  child: EmptyState(
                    icon: LucideIcons.searchX,
                    message: s.t(
                      'لم نجد هذا الحجز ضمن طلبات ورشتك.',
                      "This booking isn't among your workshop's jobs.",
                    ),
                  ),
                ),
              ),
      );
    }

    final pending = request.pendingExtraWork.length;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: ak.bg,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.t(
                  'ملف العمل #${shortRef(request.id)}',
                  'Job #${shortRef(request.id)}',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${request.car.label} · ${request.plate}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySecondary,
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: s.t('الاستلام', 'Check-in')),
              Tab(text: s.t('الفحص', 'Inspection')),
              Tab(
                text: pending == 0
                    ? s.t('أعمال إضافية', 'Extra work')
                    : s.t('أعمال إضافية ($pending)', 'Extra work ($pending)'),
              ),
              Tab(text: s.t('بطاقة العمل', 'Job card')),
              Tab(text: s.t('الفاتورة', 'Invoice')),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              CheckInTab(request: request, onChanged: _changed),
              InspectionTab(request: request, onChanged: _changed),
              ExtraWorkTab(request: request, onChanged: _changed),
              JobCardTab(request: request),
              InvoiceTab(request: request, onChanged: _changed),
            ],
          ),
        ),
      ),
    );
  }
}
