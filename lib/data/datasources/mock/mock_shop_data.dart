import 'package:flutter/material.dart';

import '../../../core/i18n/strings.dart';
import '../../models/product.dart';

/// Demo catalogue for the parts shop. Read only by `MockShopService`.
abstract final class MockShopData {
  static const partCategories = <String, L>{
    'filters': L('فلاتر', 'Filters'),
    'batteries': L('بطاريات', 'Batteries'),
    'brakes': L('فرامل', 'Brakes'),
    'tyres': L('إطارات', 'Tyres'),
    'lights': L('إضاءة', 'Lights'),
  };

  static const products = <Product>[
    Product(
      id: 'pr1',
      name: L('فلتر زيت أصلي', 'Genuine oil filter'),
      price: 3.5,
      categoryId: 'filters',
      providerId: 'p1',
      region: 'Muscat',
      icon: Icons.filter_alt_outlined,
      fits: {'Toyota Camry'},
      rating: 4.8,
    ),
    Product(
      id: 'pr2',
      name: L('بطارية 70 أمبير AGM', 'Battery 70Ah AGM'),
      price: 28,
      categoryId: 'batteries',
      providerId: 'p2',
      region: 'Muscat',
      icon: Icons.battery_full_rounded,
      fits: {'any'},
      rating: 4.6,
      oldPrice: 32,
    ),
    Product(
      id: 'pr3',
      name: L('فحمات فرامل — أمامية', 'Brake pads — front'),
      price: 18,
      categoryId: 'brakes',
      providerId: 'p1',
      region: 'Muscat',
      icon: Icons.album_outlined,
      fits: {'Toyota Camry', 'Nissan Patrol'},
      rating: 4.7,
    ),
    Product(
      id: 'pr4',
      name: L('طقم إضاءة LED أمامية', 'LED headlight kit'),
      price: 9.5,
      categoryId: 'lights',
      providerId: 'p2',
      region: 'Muscat',
      icon: Icons.lightbulb_outline_rounded,
      fits: {'any'},
      rating: 4.3,
      oldPrice: 12,
    ),
    Product(
      id: 'pr5',
      name: L('إطار جميع التضاريس 265/60R18', 'All-terrain tyre 265/60R18'),
      price: 38,
      categoryId: 'tyres',
      providerId: 'p3',
      region: 'North Al Batinah',
      icon: Icons.trip_origin_rounded,
      fits: {'Nissan Patrol'},
      rating: 4.5,
    ),
    Product(
      id: 'pr6',
      name: L('فلتر هواء المقصورة', 'Cabin air filter'),
      price: 4,
      categoryId: 'filters',
      providerId: 'p2',
      region: 'Muscat',
      icon: Icons.air_rounded,
      fits: {'any'},
      rating: 4.2,
      oldPrice: 5,
    ),
  ];
}
