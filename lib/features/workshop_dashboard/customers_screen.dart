import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/provider_dashboard_state.dart';

/// A workshop's derived customer list — a projection over its own bookings,
/// never a stored contact book (see `provider_dashboard_state.dart`'s
/// `WorkshopCustomersNotifier`). Search and the tag filter both re-fetch
/// server-side rather than filtering a client-held list, so the list always
/// reflects the same derivation the server just computed.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _query = TextEditingController();
  WorkshopCustomerTag? _tag;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _applyFilter() => ref
      .read(workshopCustomersProvider.notifier)
      .applyFilter(
        WorkshopCustomersFilter(
          query: _query.text.trim().isEmpty ? null : _query.text.trim(),
          tag: _tag,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final customers = ref.watch(workshopCustomersProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('العملاء', 'Customers'))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(workshopCustomersProvider.notifier).refresh(),
          // Slivers rather than one `ListView(children:)` — same change and
          // same reason as `orders_screen.dart`: the customer list is
          // server-driven and unbounded, and the plain form builds every row
          // in it, on screen or not.
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  AppSpacing.screenMargin,
                  AppSpacing.screenMargin,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              TextField(
                controller: _query,
                decoration: InputDecoration(
                  hintText: s.t(
                    'ابحث بالاسم أو الهاتف',
                    'Search by name or phone',
                  ),
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                ),
                onSubmitted: (_) => _applyFilter(),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tagChip(s.t('الكل', 'All'), null),
                    _tagChip(
                      s.t('متكرر', 'Repeat'),
                      WorkshopCustomerTag.repeat,
                    ),
                    _tagChip(
                      s.t('جديد', 'New'),
                      WorkshopCustomerTag.newCustomer,
                    ),
                    _tagChip(
                      s.t('نزاع سابق', 'Disputed'),
                      WorkshopCustomerTag.disputed,
                    ),
                    _tagChip(
                      s.t('متباعد', 'Lapsed'),
                      WorkshopCustomerTag.lapsed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenMargin,
                  0,
                  AppSpacing.screenMargin,
                  AppSpacing.screenMargin,
                ),
                sliver: customers.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: ListSkeleton()),
                  error: (error, _) => SliverToBoxAdapter(
                    child: EmptyState(
                      icon: LucideIcons.circleAlert,
                      message: s.t(
                        'تعذّر تحميل العملاء.',
                        'Couldn\'t load customers.',
                      ),
                      action: FilledButton(
                        onPressed: _applyFilter,
                        child: Text(s.t('إعادة المحاولة', 'Retry')),
                      ),
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? SliverToBoxAdapter(
                          child: EmptyState(
                            icon: LucideIcons.contact,
                            title: s.t('لا عملاء', 'No customers'),
                            message: s.t(
                              'يظهر العملاء هنا بعد أول حجز.',
                              'Customers appear here after their first '
                                  'booking.',
                            ),
                          ),
                        )
                      : SliverList.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _CustomerRow(customer: list[index]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagChip(String label, WorkshopCustomerTag? tag) => Padding(
    padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
    child: ChoiceChip(
      label: Text(label),
      selected: _tag == tag,
      onSelected: (_) {
        setState(() => _tag = tag);
        _applyFilter();
      },
    ),
  );
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer});

  final WorkshopCustomer customer;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          context.push('/workshop/dashboard/customers/${customer.userId}'),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      for (final tag in customer.tags) _TagBadge(tag: tag),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.t(
                      '${customer.bookingsCount} حجوزات · ${customer.carCount} سيارات',
                      '${customer.bookingsCount} bookings · ${customer.carCount} cars',
                    ),
                    style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                  ),
                ],
              ),
            ),
            RialAmount(
              customer.lifetimeGross,
              style: TextStyle(fontSize: 12, color: ak.inkSub),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(LucideIcons.chevronLeft, size: 15, color: ak.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.tag});

  final WorkshopCustomerTag tag;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final label = switch (tag) {
      WorkshopCustomerTag.repeat => s.t('متكرر', 'Repeat'),
      WorkshopCustomerTag.newCustomer => s.t('جديد', 'New'),
      WorkshopCustomerTag.disputed => s.t('نزاع', 'Disputed'),
      WorkshopCustomerTag.lapsed => s.t('متباعد', 'Lapsed'),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
      child: tag == WorkshopCustomerTag.disputed
          ? StatusBadge.warn(label)
          : StatusBadge(label),
    );
  }
}
