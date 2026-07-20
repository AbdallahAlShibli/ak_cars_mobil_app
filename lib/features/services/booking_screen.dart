import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/oman_plate_input.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import 'service_detail_screen.dart';

/// Time & place:
/// - fulfillment options come from real provider capacity;
/// - emergency services default to roadside and skip time slots (ASAP);
/// - the plate uses the same Oman plate widget as car registration,
///   prefilled from the garage and saved back to the car.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.offeringId});

  final String offeringId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late Fulfillment _fulfillment;
  String _slot = MockData.slots.first;
  late final TextEditingController _plateNumber;
  String _plateLetters = 'A';
  bool _confirming = false;

  ServiceOffering get _offering =>
      MockData.offerings.firstWhere((o) => o.id == widget.offeringId);

  bool get _isEmergency => _offering.categoryId == 'sos';

  bool get _needsSlot => _fulfillment != Fulfillment.roadside;

  @override
  void initState() {
    super.initState();
    final car = ref.read(primaryCarProvider);
    // Same plate as registered with the car — prefilled and editable.
    final (number, letters) = OmanPlateInput.parse(car?.plate);
    _plateNumber = TextEditingController(text: number);
    _plateLetters = letters;

    // Emergency services go roadside by default; otherwise workshop,
    // falling back to whatever the provider actually offers.
    final offered = _offering.provider.fulfillments;
    if (_isEmergency && offered.contains(Fulfillment.roadside)) {
      _fulfillment = Fulfillment.roadside;
    } else if (offered.contains(Fulfillment.workshop)) {
      _fulfillment = Fulfillment.workshop;
    } else {
      _fulfillment = offered.first;
    }
  }

  @override
  void dispose() {
    _plateNumber.dispose();
    super.dispose();
  }

  double get _total {
    final addOns =
        MockData.addOnsByProvider[_offering.provider.id] ?? const <AddOn>[];
    final selected = ref.read(selectedAddOnsProvider);
    final addOnTotal = addOns
        .where((a) => selected.contains(a.id))
        .fold<double>(0, (sum, a) => sum + a.price);
    final pickup = _fulfillment == Fulfillment.pickup
        ? _offering.provider.pickupFee
        : 0.0;
    return (_offering.price ?? 0) + addOnTotal + pickup;
  }

  String get _slotLabel {
    if (!_needsSlot) return 'ASAP · provider heads to you';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return '${DateFormat('EEE d MMM').format(tomorrow)} · $_slot';
  }

  Future<void> _pickPlateLetters() async {
    final letters = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => PlateLettersPicker(initial: _plateLetters),
    );
    if (letters != null && letters.isNotEmpty) {
      setState(() => _plateLetters = letters);
    }
  }

  Future<void> _confirm() async {
    // Rule 8: plate number is mandatory on every service request.
    if (_plateNumber.text.trim().isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter the car plate number to continue')),
      );
      return;
    }
    setState(() => _confirming = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final car = ref.read(primaryCarProvider) ??
        Car(id: 'adhoc', make: 'Selected', model: 'car', year: 2020);
    final plate =
        '${_plateNumber.text.trim()} $_plateLetters'.toUpperCase();
    final addOns =
        (MockData.addOnsByProvider[_offering.provider.id] ?? const <AddOn>[])
            .where((a) => ref.read(selectedAddOnsProvider).contains(a.id))
            .toList();

    final request = ServiceRequest(
      id: '${1042 + ref.read(requestsProvider).length}',
      offering: _offering,
      car: car,
      plate: plate,
      fulfillment: _fulfillment,
      slot: _slotLabel,
      addOns: addOns,
      total: _total,
      status: RequestStatus.requested,
    );
    ref.read(requestsProvider.notifier).add(request);
    // Keep the garage in sync — the plate entered here becomes the
    // car's registered plate.
    if (car.id != 'adhoc' && car.plate != plate) {
      ref.read(garageProvider.notifier).setPlate(car.id, plate);
    }
    ref.read(selectedAddOnsProvider.notifier).state = {};
    ref.read(notificationsProvider.notifier).push(
          title: 'Request #${request.id} sent',
          body:
              'OMR ${request.total.toStringAsFixed(2)} held in escrow — waiting for ${request.offering.provider.name} to accept.',
          icon: Icons.schedule_send_outlined,
          route: '/track/${request.id}',
        );
    HapticFeedback.heavyImpact();
    context.go('/track/${request.id}');
  }

  @override
  Widget build(BuildContext context) {
    final provider = _offering.provider;
    final car = ref.watch(primaryCarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Time & place')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  if (_isEmergency) ...[
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.badSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppColors.bad, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Emergency request — the provider is dispatched to your location as soon as they accept.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF991B1B),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final f in Fulfillment.values) ...[
                    _FulfillmentCard(
                      fulfillment: f,
                      offered: provider.fulfillments.contains(f),
                      selected: _fulfillment == f,
                      fee: f == Fulfillment.pickup ? provider.pickupFee : null,
                      onTap: () => setState(() => _fulfillment = f),
                    ),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 6),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _needsSlot
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tomorrow · ${DateFormat('EEE d MMM').format(DateTime.now().add(const Duration(days: 1)))}',
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final s in MockData.slots)
                                    _SlotChip(
                                      label: s,
                                      booked: MockData.bookedSlots
                                          .contains(s),
                                      selected: _slot == s,
                                      onTap: () =>
                                          setState(() => _slot = s),
                                    ),
                                ],
                              ),
                            ],
                          )
                        : Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded,
                                    color: AppColors.brand, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No booking slot needed — average response time is 25 minutes.',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Car plate',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      if (car?.plate != null)
                        const StatusBadge.good('From your garage')
                      else
                        const StatusBadge.warn('Required'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    car != null
                        ? 'Registered to your ${car.label} — it updates your garage too.'
                        : 'Enter the plate of the car for this request.',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.ink3),
                  ),
                  const SizedBox(height: 10),
                  OmanPlateInput(
                    numberController: _plateNumber,
                    letters: _plateLetters,
                    onLettersTap: _pickPlateLetters,
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: _offering.name,
                          value: _offering.price != null
                              ? 'OMR ${_offering.price!.toStringAsFixed(2)}'
                              : 'Quote after inspection',
                        ),
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: 'Fulfillment',
                          value: switch (_fulfillment) {
                            Fulfillment.pickup =>
                              '${_fulfillment.label} · +OMR ${provider.pickupFee.toStringAsFixed(0)}',
                            Fulfillment.roadside =>
                              '${_fulfillment.label} · ASAP',
                            _ => '${_fulfillment.label} · free',
                          },
                        ),
                        const SizedBox(height: 6),
                        _SummaryRow(label: 'When', value: _slotLabel),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              'OMR ${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const EscrowBanner(
                          'Held safely — released only after you approve the finished work.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                style: _isEmergency
                    ? FilledButton.styleFrom(backgroundColor: AppColors.bad)
                    : null,
                onPressed: _confirming ? null : _confirm,
                child: _confirming
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isEmergency
                        ? 'Request help now — OMR ${_total.toStringAsFixed(2)}'
                        : 'Confirm & pay OMR ${_total.toStringAsFixed(2)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FulfillmentCard extends StatelessWidget {
  const _FulfillmentCard({
    required this.fulfillment,
    required this.offered,
    required this.selected,
    required this.onTap,
    this.fee,
  });

  final Fulfillment fulfillment;
  final bool offered;
  final bool selected;
  final VoidCallback onTap;
  final double? fee;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (fulfillment) {
      _ when !offered => 'Not offered by this provider',
      Fulfillment.workshop => 'Free · pick a slot below',
      Fulfillment.pickup =>
        '+ OMR ${fee?.toStringAsFixed(0)} · offered by this provider',
      Fulfillment.roadside => 'ASAP · avg 25 min response',
    };

    return Opacity(
      opacity: offered ? 1 : 0.45,
      child: AppCard(
        onTap: offered ? onTap : null,
        border: Border.all(
          color: selected && offered ? AppColors.brand : Colors.transparent,
          width: 2.5,
        ),
        child: Row(
          children: [
            IconTile(
              fulfillment.icon,
              background: selected && offered
                  ? AppColors.brandSoft
                  : AppColors.field,
              foreground: selected && offered
                  ? AppColors.brand
                  : AppColors.ink2,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fulfillment.label,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.ink3)),
                ],
              ),
            ),
            if (offered)
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected
                    ? AppColors.brand
                    : const Color(0xFFD8D1C4),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.booked,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool booked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: booked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient:
              !booked && selected ? AppColors.brandGradient : null,
          color: booked
              ? AppColors.field
              : selected
                  ? null
                  : AppColors.card,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          booked ? '$label · full' : label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: booked
                ? const Color(0xFFC3CBD8)
                : selected
                    ? Colors.white
                    : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
