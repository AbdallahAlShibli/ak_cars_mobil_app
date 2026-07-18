import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';

/// Selected add-ons for the in-flight booking (shared with BookingScreen).
final selectedAddOnsProvider = StateProvider<Set<String>>((ref) => {});

/// Rule 7: service details + the provider's suggested services and parts.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.offeringId});

  final String offeringId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offering =
        MockData.offerings.firstWhere((o) => o.id == offeringId);
    final provider = offering.provider;
    final car = ref.watch(primaryCarProvider);
    final selected = ref.watch(selectedAddOnsProvider);
    final addOns = MockData.addOnsByProvider[provider.id] ?? const <AddOn>[];
    final services = addOns.where((a) => !a.isPart).toList();
    final parts = addOns.where((a) => a.isPart).toList();

    final addOnTotal = addOns
        .where((a) => selected.contains(a.id))
        .fold<double>(0, (sum, a) => sum + a.price);
    final total = (offering.price ?? 0) + addOnTotal;

    return Scaffold(
      appBar: AppBar(title: Text(offering.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const IconTile(Icons.storefront_rounded,
                                radius: 999),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          provider.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w700),
                                        ),
                                      ),
                                      if (provider.verified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified_rounded,
                                            size: 15,
                                            color: AppColors.brand),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${provider.area}, ${provider.region} · ${provider.distanceKm} km',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.ink3),
                                  ),
                                ],
                              ),
                            ),
                            const StatusBadge.good('Open'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Stat(
                              value: offering.price != null
                                  ? 'OMR ${offering.price!.toStringAsFixed(0)}'
                                  : 'Quote',
                              label: offering.price != null
                                  ? 'Fixed price'
                                  : 'After inspection',
                            ),
                            const SizedBox(width: 8),
                            _Stat(
                              value: offering.durationMin != null
                                  ? '${offering.durationMin} min'
                                  : '—',
                              label: 'Duration',
                            ),
                            const SizedBox(width: 8),
                            _Stat(
                              value: car != null ? '✓ Fits' : 'Any car',
                              label: car?.label ?? 'Select at booking',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            offering.description,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.ink2,
                                height: 1.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionHeader('Also from this provider'),
                    const SizedBox(height: 8),
                    _AddOnRow(addOns: services, selected: selected, ref: ref),
                  ],
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionHeader('Parts they stock for your car'),
                    const SizedBox(height: 8),
                    _AddOnRow(addOns: parts, selected: selected, ref: ref),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: () {
                  // Rule 4: registration gate before any service request.
                  if (!ensureRegistered(context, ref)) return;
                  context.push('/book/${offering.id}');
                },
                child: Text(
                  offering.price != null
                      ? 'Choose time & place — OMR ${total.toStringAsFixed(2)}'
                      : 'Request inspection & quote',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 10.5, color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOnRow extends StatelessWidget {
  const _AddOnRow({
    required this.addOns,
    required this.selected,
    required this.ref,
  });

  final List<AddOn> addOns;
  final Set<String> selected;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, a) in addOns.indexed) ...[
          if (i > 0) const SizedBox(width: 9),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(11),
              onTap: () {
                final next = Set<String>.from(selected);
                if (!next.add(a.id)) next.remove(a.id);
                ref.read(selectedAddOnsProvider.notifier).state = next;
              },
              border: Border.all(
                color: selected.contains(a.id)
                    ? AppColors.brand
                    : Colors.transparent,
                width: 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('+ OMR ${a.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.ink3)),
                      selected.contains(a.id)
                          ? const StatusBadge.good('✓ Added')
                          : const StatusBadge('+ Add'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
