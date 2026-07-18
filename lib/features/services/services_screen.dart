import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/oman_locations.dart';
import 'service_widgets.dart';

/// Services — search across all workshops, "Car service" package cards,
/// "Other services" icon tiles, and popular offerings near you.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  bool _loading = true;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRegion() async {
    final region = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in OmanLocations.governorates.keys)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(r),
                  onTap: () => Navigator.pop(context, r),
                ),
            ],
          ),
        ),
      ),
    );
    if (region != null) {
      ref.read(regionProvider.notifier).state = region;
    }
  }

  List<ServiceOffering> _results(String region) {
    final q = _query.toLowerCase();
    final list = MockData.offerings.where((o) {
      if (q.isEmpty) return true;
      final category = MockData.categories
          .firstWhere((c) => c.id == o.categoryId)
          .name
          .replaceAll('\n', ' ')
          .toLowerCase();
      return o.name.toLowerCase().contains(q) ||
          o.provider.name.toLowerCase().contains(q) ||
          o.provider.region.toLowerCase().contains(q) ||
          category.contains(q);
    }).toList()
      ..sort((a, b) {
        final aLocal = a.provider.region == region ? 0 : 1;
        final bLocal = b.provider.region == region ? 0 : 1;
        return aLocal != bLocal
            ? aLocal.compareTo(bLocal)
            : (a.price ?? 999).compareTo(b.price ?? 999);
      });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(regionProvider);
    final car = ref.watch(primaryCarProvider);
    final searching = _query.trim().isNotEmpty;
    final results = _results(region);

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: SafeArea(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const Skeleton(height: 48, radius: 16),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        const Expanded(
                            child: Skeleton(height: 150, radius: 20)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Skeleton(height: 96, radius: 16),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 3; i++) ...[
                    const Skeleton(height: 72, radius: 20),
                    const SizedBox(height: 10),
                  ],
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText:
                            'Search services or workshops…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searching
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        SelectChip(
                          label: region,
                          icon: Icons.location_on_outlined,
                          selected: true,
                          onTap: _pickRegion,
                        ),
                        SelectChip(
                          label: car?.label ?? 'Add your car',
                          icon: Icons.directions_car_outlined,
                          selected: true,
                          onTap: () => context
                              .push(car == null ? '/add-car' : '/garage'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!searching) ...[
                    const ServiceRails(),
                    const SizedBox(height: 22),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: SectionHeader('Popular near you'),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '${results.length} results for "${_query.trim()}"',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink2),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (searching && results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 40, color: AppColors.ink3),
                            SizedBox(height: 8),
                            Text('No services match your search',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.ink2)),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final (i, o)
                        in results.take(searching ? 25 : 6).indexed) ...[
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: Entrance(
                          delayMs: 35 * i,
                          child: _OfferingCard(
                              offering: o, localRegion: region),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
      ),
    );
  }
}

class _OfferingCard extends StatelessWidget {
  const _OfferingCard({required this.offering, required this.localRegion});

  final ServiceOffering offering;
  final String localRegion;

  @override
  Widget build(BuildContext context) {
    final category = MockData.categories
        .firstWhere((c) => c.id == offering.categoryId);
    final local = offering.provider.region == localRegion;

    return AppCard(
      onTap: () => context.push('/service/${offering.id}'),
      child: Row(
        children: [
          IconTile(category.icon,
              background:
                  category.emergency ? AppColors.badSoft : AppColors.brandSoft,
              foreground:
                  category.emergency ? AppColors.bad : AppColors.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(offering.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (offering.provider.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          size: 13, color: AppColors.brand),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${offering.provider.name} · ${offering.provider.area}'
                  '${local ? '' : ' · ${offering.provider.region}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.ink3),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                offering.price != null
                    ? 'OMR ${offering.price!.toStringAsFixed(0)}'
                    : 'Quote',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandDark,
                ),
              ),
              if (local)
                const StatusBadge.good('Near you')
              else
                const SizedBox(height: 18),
            ],
          ),
        ],
      ),
    );
  }
}
