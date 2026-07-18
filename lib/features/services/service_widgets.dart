import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';

void _openCategory(BuildContext context, ServiceCategory category) {
  HapticFeedback.selectionClick();
  final offerings = MockData.offeringsFor(category.id)
    ..sort((a, b) => (a.price ?? 999).compareTo(b.price ?? 999));
  if (offerings.isEmpty) return;
  if (offerings.length == 1) {
    context.push('/service/${offerings.first.id}');
    return;
  }
  // Multiple workshops offer this — let the user compare.
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name.replaceAll('\n', ' '),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '${offerings.length} workshops — compare and choose',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.ink2),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: offerings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, i) => _ProviderOfferRow(
                    offering: offerings[i],
                    cheapest: i == 0 && offerings[i].price != null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push('/service/${offerings[i].id}');
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProviderOfferRow extends StatelessWidget {
  const _ProviderOfferRow({
    required this.offering,
    required this.onTap,
    this.cheapest = false,
  });

  final ServiceOffering offering;
  final VoidCallback onTap;
  final bool cheapest;

  @override
  Widget build(BuildContext context) {
    final p = offering.provider;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cheapest ? AppColors.brand : AppColors.border,
            width: cheapest ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (p.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 14, color: AppColors.brand),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${p.area}, ${p.region}'
                    '${offering.durationMin != null ? ' · ${offering.durationMin} min' : ''}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.ink3),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      for (final f in p.fulfillments) ...[
                        Icon(f.icon, size: 13, color: AppColors.ink3),
                        const SizedBox(width: 6),
                      ],
                      if (cheapest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.goodSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Best price',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.good,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              offering.price != null
                  ? 'OMR ${offering.price!.toStringAsFixed(0)}'
                  : 'Quote',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.brandDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big "Car service" package card (reference style) — the first card is
/// brand-filled and can carry a promo ribbon like "FREE OIL".
class ServicePackageCard extends StatelessWidget {
  const ServicePackageCard({
    super.key,
    required this.category,
    this.filled = false,
    this.height = 150,
  });

  final ServiceCategory category;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openCategory(context, category),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 148,
            height: height,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: filled ? AppColors.brandGradient : null,
              color: filled ? null : AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border:
                  filled ? null : Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(category.icon,
                    size: 22,
                    color: filled ? Colors.white70 : AppColors.brand),
                const Spacer(),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: filled ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (category.fromPrice != null)
                      'from OMR ${category.fromPrice!.toStringAsFixed(0)}'
                    else if (category.note != null)
                      category.note!,
                    '${MockData.providerCountFor(category.id)} workshops',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: filled
                        ? const Color(0xFFB9C9F5)
                        : AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          if (category.badge != null)
            PositionedDirectional(
              top: -10,
              end: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.badge!,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small "Other service" tile — icon that visualises the service + label.
class OtherServiceTile extends StatelessWidget {
  const OtherServiceTile({super.key, required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    final danger = category.emergency;
    return GestureDetector(
      onTap: () => _openCategory(context, category),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: danger ? const Color(0xFFF3D2D2) : AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon,
                size: 30, color: danger ? AppColors.bad : AppColors.ink),
            const SizedBox(height: 8),
            Text(
              category.name.replaceAll('\n', ' '),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: danger ? AppColors.bad : AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Car service" + "Other service" rails, shared by Home and Services.
class ServiceRails extends StatelessWidget {
  const ServiceRails({super.key, this.packageHeight = 150});

  final double packageHeight;

  @override
  Widget build(BuildContext context) {
    final primaries = MockData.primaryCategories;
    final others = MockData.otherCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Car service',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: packageHeight + 4,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: primaries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => ServicePackageCard(
              category: primaries[i],
              filled: i == 0,
              height: packageHeight,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Other services',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: others.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) =>
                OtherServiceTile(category: others[i]),
          ),
        ),
      ],
    );
  }
}
