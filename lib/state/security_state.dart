import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/security_alert.dart';
import '../data/models/security_alert_detail.dart';
import '../data/models/security_overview.dart';
import '../di/providers.dart';

/// The founder's security dashboard.
///
/// Fetched on demand and auto-disposed: it is a screen the founder opens to
/// look at what is happening now, so a cached copy from an hour ago would be
/// worse than a short spinner.

/// The look-back window the dashboard shows, in hours (24, 168 or 720).
final securityWindowProvider = StateProvider<int>((ref) => 24);

/// Bumped after the founder changes an alert's status, so every view of the
/// alerts re-reads rather than showing the status it had before.
final securityRevisionProvider = StateProvider<int>((ref) => 0);

final securityOverviewProvider = FutureProvider.autoDispose<SecurityOverview>((
  ref,
) {
  ref.watch(securityRevisionProvider);
  final hours = ref.watch(securityWindowProvider);
  return ref.watch(securityServiceProvider).overview(hours: hours);
});

final securityAlertDetailProvider = FutureProvider.autoDispose
    .family<SecurityAlertDetail, String>((ref, alertId) {
      ref.watch(securityRevisionProvider);
      return ref.watch(securityServiceProvider).alert(alertId);
    });

/// Which alerts the list shows. `status` is `active`, a
/// [SecurityAlertStatus] name, or null for all; `ip` narrows to one attacker.
typedef SecurityAlertFilter = ({
  String? status,
  SecuritySeverity? severity,
  String? ip,
});

class SecurityAlertList {
  const SecurityAlertList({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<SecurityAlertSummary> items;
  final int total;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  SecurityAlertList copyWith({
    List<SecurityAlertSummary>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) => SecurityAlertList(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final securityAlertListProvider = AsyncNotifierProvider.autoDispose
    .family<SecurityAlertListNotifier, SecurityAlertList, SecurityAlertFilter>(
      SecurityAlertListNotifier.new,
    );

class SecurityAlertListNotifier
    extends AutoDisposeFamilyAsyncNotifier<SecurityAlertList, SecurityAlertFilter> {
  static const pageSize = 30;

  @override
  Future<SecurityAlertList> build(SecurityAlertFilter filter) async {
    ref.watch(securityRevisionProvider);
    final page = await _fetch(1);
    return SecurityAlertList(
      items: page.items,
      total: page.total,
      page: 1,
      hasMore: page.hasMore,
    );
  }

  Future<SecurityAlertPage> _fetch(int page) =>
      ref.read(securityServiceProvider).alerts(
        status: arg.status,
        severity: arg.severity,
        ip: arg.ip,
        page: page,
        pageSize: pageSize,
      );

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(current.page + 1);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          total: next.total,
          page: current.page + 1,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } catch (_) {
      // Keep what is already on screen; the next scroll to the end retries.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

/// Moves an alert to [status] and makes every security view re-read.
Future<SecurityAlertSummary> setSecurityAlertStatus(
  WidgetRef ref,
  String alertId,
  SecurityAlertStatus status, {
  String? note,
}) async {
  final updated = await ref
      .read(securityServiceProvider)
      .setStatus(alertId, status, note: note);
  ref.read(securityRevisionProvider.notifier).state++;
  return updated;
}
