import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/car_media.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/gallery_data.dart';
import '../../data/models.dart';
import '../services/service_widgets.dart';

enum _JobTab { now, inProgress, ready }

/// Home — "service station" layout: header with search, job status tabs
/// (Now / In progress / Ready), the selected car with its live photo,
/// service menu, and the cars-for-sale rail.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _JobTab _tab = _JobTab.now;

  List<ServiceRequest> _requestsFor(
      _JobTab tab, List<ServiceRequest> all) {
    return all.where((r) {
      return switch (tab) {
        _JobTab.now => r.status == RequestStatus.requested ||
            r.status == RequestStatus.accepted,
        _JobTab.inProgress => r.status == RequestStatus.inProgress,
        _JobTab.ready => r.status == RequestStatus.proofSubmitted ||
            r.status == RequestStatus.completed,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cars = ref.watch(garageProvider);
    final requests = ref.watch(requestsProvider);
    final listings = ref.watch(galleryFeedProvider).take(5).toList();
    final name = auth.profile?.name.split(' ').first ?? 'there';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final tabRequests = _requestsFor(_tab, requests);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ------------------------------------------------ header
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Stack(
              children: [
                // decorative glow circles
                Positioned(
                  top: -46,
                  right: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -54,
                  left: -24,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6A5CFF).withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB9C9F5))),
                            Text(
                              'Hi, $name',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 21),
                            ),
                            if (ref.watch(unreadCountProvider) > 0)
                              Positioned(
                                top: 9,
                                right: 10,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF87171),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (auth.profile?.name.isNotEmpty ?? false)
                                  ? auth.profile!.name[0].toUpperCase()
                                  : '؟',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.go('/services'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 19, color: AppColors.ink3),
                          SizedBox(width: 9),
                          Text(
                            'Search services, parts, cars…',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.ink3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ------------------------------------------------ job tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                for (final t in _JobTab.values) ...[
                  _TabChip(
                    label: switch (t) {
                      _JobTab.now => 'Now',
                      _JobTab.inProgress => 'In progress',
                      _JobTab.ready => 'Ready',
                    },
                    count: _requestsFor(t, requests).length,
                    selected: _tab == t,
                    onTap: () => setState(() => _tab = t),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: tabRequests.isEmpty
                  ? Container(
                      key: ValueKey('empty-$_tab'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        switch (_tab) {
                          _JobTab.now =>
                            'No waiting requests — book a service below.',
                          _JobTab.inProgress =>
                            'Nothing being worked on right now.',
                          _JobTab.ready =>
                            'Completed jobs will appear here.',
                        },
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.ink2),
                      ),
                    )
                  : Column(
                      key: ValueKey('list-$_tab'),
                      children: [
                        for (final r in tabRequests.take(2)) ...[
                          AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            onTap: () => context.push(
                              r.status == RequestStatus.proofSubmitted
                                  ? '/approve/${r.id}'
                                  : '/track/${r.id}',
                            ),
                            child: Row(
                              children: [
                                IconTile(
                                  r.status == RequestStatus.completed
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.build_rounded,
                                  size: 38,
                                  radius: 12,
                                  background: AppColors.brandSoft,
                                  foreground: AppColors.brand,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '#${r.id} · ${r.offering.name}',
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        r.offering.provider.name,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.ink3),
                                      ),
                                    ],
                                  ),
                                ),
                                r.status == RequestStatus.proofSubmitted
                                    ? const StatusBadge.warn('Review')
                                    : StatusBadge(r.status.label),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ),
          // ------------------------------------------------ my car card
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: cars.isEmpty
                ? AppCard(
                    onTap: () => context.push('/add-car'),
                    child: const Row(
                      children: [
                        IconTile(Icons.add_rounded),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add your car',
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                'See its photo here and get matched services.',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.ink2),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  )
                : SizedBox(
                    height: 250,
                    child: PageView.builder(
                      controller: PageController(viewportFraction: 0.94),
                      itemCount: cars.length,
                      itemBuilder: (context, i) =>
                          _MyCarCard(car: cars[i]),
                    ),
                  ),
          ),
          // ------------------------------------------------ services
          const SizedBox(height: 20),
          const ServiceRails(packageHeight: 132),
          // ------------------------------------------------ cars for sale
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader('Cars for sale',
                action: 'Browse all', onAction: () => context.go('/cars')),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: listings.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final l = listings[i];
                return AppCard(
                  onTap: () => context.push('/cars/listing/${l.id}'),
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: 170,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 70,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.field,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CarImage(
                            make: l.make,
                            model: l.model,
                            height: 70,
                            fallbackIcon: l.icon,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(l.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                        Text(
                          l.price != null
                              ? 'OMR ${l.price!.toStringAsFixed(0)}'
                              : 'Ask for price',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Reference-style car card: make on top, live car photo, model + CTA.
class _MyCarCard extends StatelessWidget {
  const _MyCarCard({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    car.make,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                if (car.serviceDueKm != null)
                  StatusBadge.warn('Service in ${car.serviceDueKm} km'),
              ],
            ),
            Expanded(
              child: CarImage(make: car.make, model: car.model, height: 130),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${car.model} · ${car.year}',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text(
                        car.plate ?? 'No plate saved',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.ink3,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => context.go('/services'),
                  child: const Text('Book service',
                      style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink3,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

