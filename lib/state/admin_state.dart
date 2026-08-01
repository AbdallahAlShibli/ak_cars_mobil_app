import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/audit_entry.dart';
import '../data/models/payout_record.dart';
import '../data/models/service_provider.dart';
import '../di/providers.dart';
import 'offers_state.dart';
import 'operator_queue_state.dart';

/// Bumped after any founder write — an onboarding decision or a payout.
///
/// Same mechanism, and the same reason, as `offersRevisionProvider`: the
/// marketplace repository keeps its roster and its ledger in warm caches so
/// every screen can read them synchronously, which means a write has to
/// announce itself or the panel goes on showing the world as it was when it
/// was opened.
final adminRevisionProvider = StateProvider<int>((ref) => 0);

/// The whole workshop roster, every stage included — the founder's view.
final rosterProvider = Provider<List<ServiceProvider>>((ref) {
  ref.watch(adminRevisionProvider);
  return ref.watch(serviceMarketplaceRepositoryProvider).providers;
});

/// How many workshops sit in each onboarding stage (§5, tab 2).
final onboardingPipelineProvider =
    Provider<Map<ProviderOnboardingStage, int>>((ref) {
  ref.watch(adminRevisionProvider);
  return ref.watch(serviceMarketplaceRepositoryProvider).onboardingPipeline;
});

/// Applications waiting on the founder, oldest first.
///
/// The three pre-approval stages in one list rather than three queues:
/// `documentsSubmitted` and `verified` are internal positions, and what the
/// founder is actually looking at is "workshops I have not decided about yet".
final pendingApplicationsProvider = Provider<List<ServiceProvider>>((ref) {
  final roster = ref.watch(rosterProvider);
  final pending = [
    for (final p in roster)
      if (p.stage.awaitsFounder) p,
  ]..sort((a, b) {
      final aAt = a.stageSince;
      final bAt = b.stageSince;
      if (aAt == null || bAt == null) return 0;
      return aAt.compareTo(bAt);
    });
  return List.unmodifiable(pending);
});

/// The payout ledger, newest first.
final payoutsProvider = Provider<List<PayoutRecord>>((ref) {
  ref.watch(adminRevisionProvider);
  return ref.watch(serviceMarketplaceRepositoryProvider).payouts;
});

/// The platform-wide audit trail (§6), newest first.
final auditLogProvider = Provider<List<AuditEntry>>((ref) {
  // Watches both revisions: an audit line is written by onboarding and payout
  // decisions *and* by offer switches, and the log has to repaint for either.
  ref.watch(adminRevisionProvider);
  ref.watch(offersRevisionProvider);
  ref.watch(operatorQueueProvider);
  return ref.watch(serviceMarketplaceRepositoryProvider).auditLog;
});

/// What each workshop is still owed: released to it, net of commission, less
/// what the founder has already recorded as transferred.
final outstandingByProviderProvider = Provider<Map<String, double>>((ref) {
  final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
  final queue = ref.watch(operatorQueueProvider);
  ref.watch(adminRevisionProvider);
  return {
    for (final provider in marketplace.visibleProviders)
      provider.id: marketplace.outstandingFor(provider.id, queue),
  };
});

/// The founder's two write actions.
///
/// Deliberately a thin pair of methods rather than a notifier holding state:
/// the repository is the authority on both, and this exists only so a screen
/// has one call to make and the revision is bumped exactly once afterwards.
class AdminActions {
  const AdminActions(this._ref);

  final Ref _ref;

  /// Approves, verifies, rejects or suspends a workshop.
  ///
  /// [reason] is mandatory for [ProviderOnboardingStage.suspended]; the
  /// repository throws without one, and the panel's dialog will not submit
  /// without one either. Two gates rather than one because the rule is about
  /// what the *workshop owner* gets told, and losing it would be silent.
  Future<ServiceProvider> setStage(
    String providerId,
    ProviderOnboardingStage stage, {
    String? reason,
  }) async {
    final updated = await _ref
        .read(serviceMarketplaceRepositoryProvider)
        .setProviderStage(providerId, stage, reason: reason);
    _ref.read(adminRevisionProvider.notifier).state++;
    return updated;
  }

  /// Records a transfer that happened outside the app.
  Future<PayoutRecord> markPaid({
    required String providerId,
    required double amount,
    required DateTime periodFrom,
    required DateTime periodTo,
    String? note,
  }) async {
    final record = await _ref
        .read(serviceMarketplaceRepositoryProvider)
        .recordPayout(
          providerId: providerId,
          amount: amount,
          periodFrom: periodFrom,
          periodTo: periodTo,
          note: note,
        );
    _ref.read(adminRevisionProvider.notifier).state++;
    return record;
  }
}

final adminActionsProvider = Provider<AdminActions>(AdminActions.new);
