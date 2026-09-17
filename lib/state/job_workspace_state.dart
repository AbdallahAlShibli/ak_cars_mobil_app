import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../core/i18n/strings.dart';
import '../data/models/models.dart';
import '../di/providers.dart';

/// Read-side state for the job workspace (2026-09-15).
///
/// Every provider here is `autoDispose`: each one backs a single screen or
/// section a person opens on purpose, and none of them is worth holding in
/// memory — or refreshing on sign-in — once that screen is gone. The
/// check-in, inspection and extra work themselves are not here at all: they
/// travel on the booking DTO, so the booking lists already own them.

/// A booking's internal job card — the workshop's view.
final jobCardProvider = FutureProvider.autoDispose.family<JobCard, String>(
  (ref, requestId) =>
      ref.read(jobWorkspaceServiceProvider).getJobCard(requestId),
);

/// A booking's invoice. A `NotFoundException` means none has been issued.
final invoiceProvider = FutureProvider.autoDispose.family<Invoice, String>(
  (ref, requestId) =>
      ref.read(jobWorkspaceServiceProvider).getInvoice(requestId),
);

/// The founder's per-workshop performance table, over a window in days.
final founderWorkshopPerformanceProvider = FutureProvider.autoDispose
    .family<List<WorkshopPerformanceRow>, int>(
      (ref, windowDays) => ref
          .read(jobWorkspaceServiceProvider)
          .getWorkshopPerformance(windowDays: windowDays),
    );

/// Approved extra work waiting for the founder to confirm the funds.
final founderExtraWorkQueueProvider =
    FutureProvider.autoDispose<List<ExtraWorkQueueItem>>(
      (ref) => ref
          .read(jobWorkspaceServiceProvider)
          .getExtraWorkQueue(status: ExtraWorkStatus.approved),
    );

/// Mirrors the server's stage rules (`JobWorkspaceAccess`) so a control the
/// server would refuse is disabled rather than tapped and refused. The server
/// stays the authority — these only decide what is offered.
abstract final class JobStages {
  static const checkIn = {
    EscrowState.fundsHeld,
    EscrowState.acceptedByWorkshop,
    EscrowState.inProgress,
  };

  static const work = {EscrowState.acceptedByWorkshop, EscrowState.inProgress};

  static const jobCard = {
    EscrowState.fundsHeld,
    EscrowState.acceptedByWorkshop,
    EscrowState.inProgress,
    EscrowState.proofSubmitted,
    EscrowState.awaitingApproval,
    EscrowState.disputed,
  };

  static const invoice = {
    EscrowState.awaitingApproval,
    EscrowState.releasedToWorkshop,
    EscrowState.disputed,
  };
}

/// One sentence for a failed job-workspace call. Chosen from the exception's
/// type and code — never from its developer-facing message.
String jobWorkspaceErrorText(S s, Object error) => switch (error) {
  ApiException(errorCode: 'job_stage_not_allowed') ||
  BusinessRuleException() => s.t(
    'غير متاح في هذه المرحلة من الحجز.',
    'Not possible at this stage of the booking.',
  ),
  ApiException(errorCode: 'extra_work_not_pending') => s.t(
    'تم الرد على هذا الطلب مسبقاً.',
    'This request has already been answered.',
  ),
  ApiException(errorCode: 'extra_work_not_approved') => s.t(
    'لم يوافق العميل على هذا العمل بعد.',
    'The customer has not approved this work yet.',
  ),
  ApiException(errorCode: 'invoice_not_allowed') => s.t(
    'تصدر الفاتورة بعد رفع إثبات الإنجاز.',
    'The invoice can be issued once proof of work is in.',
  ),
  ValidationException() ||
  ApiException(statusCode: 400) => s.t(
    'تحقق من البيانات المدخلة.',
    'Check the details you entered.',
  ),
  ForbiddenException() => s.t(
    'لا تملك صلاحية هذا الإجراء.',
    "You don't have permission to do this.",
  ),
  NetworkException() || RequestTimeoutException() => s.t(
    'تعذّر الاتصال — حاول مرة أخرى.',
    "Couldn't connect — try again.",
  ),
  _ => s.t('حدث خطأ — حاول مرة أخرى.', 'Something went wrong — try again.'),
};
