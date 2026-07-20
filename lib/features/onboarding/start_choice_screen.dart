import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';

/// Rule 3 — start with a registered car, or skip and choose per request.
class StartChoiceScreen extends ConsumerStatefulWidget {
  const StartChoiceScreen({super.key});

  @override
  ConsumerState<StartChoiceScreen> createState() => _StartChoiceScreenState();
}

class _StartChoiceScreenState extends ConsumerState<StartChoiceScreen> {
  bool _addCar = true;

  void _continue() {
    if (_addCar) {
      // Website-style picker: make grid → model → year + Oman plate.
      context.push('/add-car');
    } else {
      ref.read(authProvider.notifier).markStartChoiceMade();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'How would you like to start?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'You can change this anytime from your profile.',
                style: TextStyle(fontSize: 13, color: AppColors.ink2),
              ),
              const SizedBox(height: 20),
              AppCard(
                onTap: () => setState(() => _addCar = true),
                border: Border.all(
                  color: _addCar ? AppColors.brand : Colors.transparent,
                  width: 2.5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconTile(Icons.directions_car_filled_rounded),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add my car now',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              Text('Recommended',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.ink3)),
                            ],
                          ),
                        ),
                        Icon(
                          _addCar
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: _addCar
                              ? AppColors.brand
                              : const Color(0xFFD8D1C4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pick your make and model from the catalog, add your Oman plate, and get services, parts, and reminders matched to your exact car.',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.ink2,
                          height: 1.55),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const StatusBadge('1 Make'),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            size: 15, color: AppColors.ink3),
                        const SizedBox(width: 6),
                        const StatusBadge('2 Model'),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            size: 15, color: AppColors.ink3),
                        const SizedBox(width: 6),
                        const StatusBadge('3 Year & plate'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                onTap: () => setState(() => _addCar = false),
                border: Border.all(
                  color: !_addCar ? AppColors.brand : Colors.transparent,
                  width: 2.5,
                ),
                child: Row(
                  children: [
                    const IconTile(
                      Icons.schedule_rounded,
                      background: AppColors.field,
                      foreground: AppColors.ink2,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Not now',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            'Browse freely — pick the car details each time you make a request.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.ink2,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      !_addCar
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: !_addCar
                          ? AppColors.brand
                          : const Color(0xFFD8D1C4),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _continue,
                child: Text(_addCar ? 'Choose my car' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
