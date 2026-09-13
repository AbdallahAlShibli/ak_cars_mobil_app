import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/json/icon_codec.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// The founder's control over the catalogue's service *types*.
///
/// Until this existed the badge was the only writable field on a category, on
/// the grounds that everything else is structure the app branches on. It is
/// writable now, so what these pin is the guards that make that safe rather
/// than the writes themselves: a key stays unique, a rename carries every
/// offering's denormalised copy with it, and a type still holding services
/// cannot be deleted out from under them.
void main() {
  ServiceCategory categoryInUse(ProviderContainer container) {
    final marketplace = container.read(serviceMarketplaceRepositoryProvider);
    return marketplace.categories.firstWhere(
      (c) => marketplace.offeringCountFor(c.id) > 0,
    );
  }

  ServiceCategoryDraft draft({
    String slug = 'window-tint',
    String nameAr = 'تظليل',
    String nameEn = 'Window tint',
  }) => ServiceCategoryDraft(
    slug: slug,
    name: L(nameAr, nameEn),
    icon: IconCodec.decode('build'),
  );

  ServiceCategoryDraft renamed(
    ServiceCategory c, {
    String? slug,
    L? name,
  }) => ServiceCategoryDraft(
    slug: slug ?? c.slug,
    name: name ?? c.name,
    icon: c.icon,
    note: c.note,
    emergency: c.emergency,
    primary: c.primary,
    powertrains: c.powertrains,
    requires: c.requires,
  );

  test('a new type joins the catalogue and is offered to every car', () async {
    final container = await createTestContainer();
    final admin = container.read(categoryBadgeAdminProvider);
    final before = container
        .read(serviceMarketplaceRepositoryProvider)
        .categories
        .length;

    final created = await admin.create(draft());

    final marketplace = container.read(serviceMarketplaceRepositoryProvider);
    expect(marketplace.categories, hasLength(before + 1));
    expect(marketplace.categories.map((c) => c.id), contains(created.id));
    expect(created.slug, 'window-tint');
    // Empty powertrains is the "every car" case, and it is the default — a new
    // type that silently applied to nothing would be invisible.
    expect(created.appliesTo(Powertrain.petrol), isTrue);
    expect(created.appliesTo(Powertrain.electric), isTrue);
  });

  test('two types cannot share one key', () async {
    final container = await createTestContainer();
    final admin = container.read(categoryBadgeAdminProvider);
    final existing = container
        .read(serviceMarketplaceRepositoryProvider)
        .categories
        .first;

    await expectLater(
      admin.create(draft(slug: existing.slug)),
      throwsA(
        isA<BusinessRuleException>().having((e) => e.code, 'code', 'slug_taken'),
      ),
    );
  });

  test('editing a type rewrites it and keeps its badge', () async {
    final container = await createTestContainer();
    final admin = container.read(categoryBadgeAdminProvider);
    final target = container
        .read(serviceMarketplaceRepositoryProvider)
        .categories
        .firstWhere((c) => c.badge != null);

    final updated = await admin.update(
      target.id,
      renamed(target, name: const L('اسم جديد', 'Renamed')),
    );

    expect(updated.name.en, 'Renamed');
    // The badge is not part of a draft — it has its own write. A save that
    // dropped it would be a ribbon vanishing every time a founder renamed
    // something.
    expect(updated.badge, target.badge);
  });

  test('renaming a key carries every offering under it along', () async {
    final container = await createTestContainer();
    final admin = container.read(categoryBadgeAdminProvider);
    final target = categoryInUse(container);

    await admin.update(target.id, renamed(target, slug: 'renamed-key'));

    // The booking screen reads `categorySlug` off the offering, not off the
    // category, so a rename that stopped at the category would leave every
    // service already sold under it answering to a key that no longer exists.
    final orphaned = container
        .read(serviceMarketplaceRepositoryProvider)
        .offerings
        .where(
          (o) => o.categoryId == target.id && o.categorySlug != 'renamed-key',
        );
    expect(orphaned, isEmpty);
  });

  test('a type still holding services cannot be deleted', () async {
    final container = await createTestContainer();
    final admin = container.read(categoryBadgeAdminProvider);
    final used = categoryInUse(container);

    expect(admin.offeringCount(used.id), greaterThan(0));
    await expectLater(
      admin.delete(used.id),
      throwsA(
        isA<BusinessRuleException>().having(
          (e) => e.code,
          'code',
          'category_in_use',
        ),
      ),
    );
    expect(
      container
          .read(serviceMarketplaceRepositoryProvider)
          .categories
          .map((c) => c.id),
      contains(used.id),
      reason: 'a refused delete must leave the catalogue alone',
    );
  });

  test('a type nothing is sold under can be deleted', () async {
    final container = await createTestContainer();
    final admin = container.read(categoryBadgeAdminProvider);
    // Created here rather than hunted for in the fixture: whether the demo
    // catalogue happens to contain an unused type is not this test's subject.
    final fresh = await admin.create(draft(slug: 'temporary-type'));
    expect(admin.offeringCount(fresh.id), 0);

    await admin.delete(fresh.id);

    expect(
      container
          .read(serviceMarketplaceRepositoryProvider)
          .categories
          .map((c) => c.id),
      isNot(contains(fresh.id)),
    );
  });
}
