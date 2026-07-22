# AK Cars mobile — architecture

Staging-ready structure: real layering, real async data flow, **mock data**.
No HTTP client exists yet; the seams where one plugs in are all in place.

---

## 1. Layers

```
UI (features/)  →  State (state/)  →  Repositories (data/repositories/)
                                           ↓
                                    Services (data/services/)
                                           ↓
                                Mock datasources (data/datasources/mock/)
                                    ── replaced in Phase 2 by ──
                                       ApiClient → REST API
```

Each arrow is one-directional. A widget never sees a service; a service never
sees a widget.

| Directory | Holds | Rule |
|---|---|---|
| `lib/app/` | `AkCarsApp`, `AppBootstrap` | Composition + start-up only |
| `lib/config/` | `AppEnvironment`, `AppConfig` | The only reader of `dart-define`s |
| `lib/core/` | i18n, theme, router, widgets, `constants/`, `error/`, `json/`, `network/` | No feature or data knowledge |
| `lib/data/models/` | Immutable domain models | `fromJson`/`toJson`/`copyWith`, value equality |
| `lib/data/datasources/mock/` | The demo dataset | Read **only** by `Mock*Service` |
| `lib/data/services/` | `XService` interface + `MockXService` | Shaped like a REST client |
| `lib/data/repositories/` | `XRepository` interface + `XRepositoryImpl` | Caching, composition, domain rules |
| `lib/state/` | Riverpod notifiers and derived providers | Calls repositories; holds no data logic |
| `lib/di/providers.dart` | Every service/repository binding | **The only file naming a concrete impl** |
| `lib/features/` | Screens and widgets | Reads providers; builds no data |

---

## 2. How a read works

`ServicesScreen` needs the service categories:

```dart
final marketplace = ref.watch(serviceMarketplaceRepositoryProvider);
final categories = marketplace.primaryCategories;
```

`serviceMarketplaceRepositoryProvider` (di) → `ServiceMarketplaceRepositoryImpl`
→ warm cache filled at bootstrap from `MockServiceMarketplaceService`
→ `MockServiceData.categories`.

### Why the reads are synchronous

Most screens read reference data (spec vocabulary, makes, locations, the parts
catalogue, the cars feed) **inline while building**, and the design has no
loading states to render. Rather than push `AsyncValue` handling into widgets
that have nowhere to show it, `AppBootstrap` fetches that data once before the
first frame and repositories expose it through a `WarmCache`:

```dart
Future<void> warmUp();   // bootstrap awaits this
SpecCatalog get specs;   // widgets read this
```

The services are still fully asynchronous, so the code path is the real one —
only the *timing* is front-loaded. `test/bootstrap_test.dart` guards the
invariant that every warmed repository is populated.

The garage is warmed the same way, and is the one warm cache that is
legitimately empty for a fresh install — `GarageNotifier.build()` seeds itself
from `GarageRepository.cars` so a returning user's saved cars are on the first
frame rather than only existing for the session that created them.

Transactional work (booking, checkout, chat) is asynchronous end to end and
always was.

---

## 3. Phase 2: connecting the real backend

The intended change is confined to **two** places.

**Step 1 — implement the transport** (`lib/core/network/api_client.dart` is
already the contract):

```dart
class DioApiClient implements ApiClient { /* … */ }
```

It must translate transport and non-2xx responses into the `AppException`
subtypes in `lib/core/error/app_exception.dart`. Nothing above it should ever
see a package-specific error type.

**Step 2 — write one REST service per interface.** They are already spec'd:
paths in `lib/core/constants/api_endpoints.dart`, and every filter already
knows its own query string (`CarsFilter.toQueryParameters`,
`ShopFilter.toQueryParameters`).

```dart
class RestCatalogService implements CatalogService {
  RestCatalogService(this._api);
  final ApiClient _api;

  @override
  Future<SpecCatalog> fetchSpecCatalog() async =>
      SpecCatalog.fromJson(await _api.get(ApiEndpoints.carSpecOptions));
}
```

**Step 3 — flip the binding in `lib/di/providers.dart`:**

```dart
final catalogServiceProvider = Provider<CatalogService>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.useMockData
      ? MockCatalogService(config: config)
      : RestCatalogService(ref.watch(apiClientProvider));
});
```

`AppConfig.useMockData` is already `false` for production. Repositories, state
and all 34 screens compile unchanged.

### What will need a decision at that point

- **Warm-up failure.** `AppBootstrap.warmUp` currently cannot fail. Against a
  real API you must choose: retry, fall back to a cached snapshot, or show an
  error screen. That decision belongs in `bootstrap.dart` and nowhere else.
- **Large collections.** Once inventory outgrows a warm cache, move the cars
  feed and parts catalogue to per-screen `FutureProvider`s. Both repositories
  already expose the async `fetchListings` / `fetchProducts` path for this.
- **Lifecycle simulation.** `RequestsNotifier._simulateProviderLifecycle` and
  `OrdersNotifier._simulateStoreLifecycle` stand in for server-pushed status
  events. They are gated behind `AppConfig.simulateProviderLifecycle` — turn it
  off and subscribe to the real event stream instead.
- **Auth tokens.** `AuthService` deals in `UserProfile`, not tokens. The REST
  implementation adds token storage under `AppConstants.prefsAuthToken` and the
  `ApiClient` attaches it.

---

## 4. Model conventions

Every model is immutable with a `const` constructor and supports `fromJson`,
`toJson`, `copyWith` and value equality. There is no parallel DTO hierarchy —
the models *are* the wire format.

Three non-obvious encodings:

- **`L` (bilingual text)** → `{"ar": …, "en": …}`. Both languages live on the
  record because stored content (notifications) must render in whatever
  language is active when it is *read*, not when it was written.
- **`IconData`** → a stable string key via `IconCodec`. Building `IconData`
  from a runtime integer would defeat `--tree-shake-icons` and ship the whole
  Material font; the registry keeps tree-shaking working (verified: 98.5%
  reduction in the release build). Unknown keys degrade to `IconCodec.fallback`.
- **`Color`** → `#AARRGGBB` via `ColorCodec`.

`fromJson` uses the null-safe readers in `core/json/json_utils.dart`: identity
fields are required and throw `SerializationException` when absent, everything
else has a documented default, and unknown enum values fall back rather than
crash. `test/models_json_test.dart` round-trips every model through real
`jsonEncode`/`jsonDecode`.

### Nullable `copyWith`

Fields where "clear this" differs from "leave unchanged" use a function
setter, so the two cases stay distinguishable:

```dart
filter.copyWith(categoryId: () => null);  // clear
filter.copyWith(minPrice: 5);             // change one field
```

---

## 5. Where the business rules live

Deliberately *not* in widgets:

| Rule | Location |
|---|---|
| Booking total = offering + add-ons + pickup fee | `calculateRequestTotal` (`models/service_request.dart`) — used by both the screen's running total and the service that prices the request, so they cannot diverge |
| Maintenance countdown (`remaining = interval − used`) | `MaintenanceRepositoryImpl.dueItems` |
| Escrow released only by the buyer | `OrderRepository.confirmReceipt`, separate from `advance` |
| Notification copy for every lifecycle event | `NotificationRepositoryImpl.notify*` |
| Product matching | `ShopFilter.matches` — shared by the local and remote paths |
| Request status progression | `RequestStatusX.next` |

---

## 6. Known technical debt

1. **Warm-up is all-or-nothing.** Seven repositories load in parallel at start-up.
   With a real API this becomes a visible cost and needs a splash-time progress
   or partial-failure story.
2. **No HTTP implementation.** `ApiClient` is a contract with no concrete class
   — intentional for this phase, but it means the transport error mapping is
   unproven.
3. **No refresh-token flow.** Matches the backend, which does not have one
   either (see the project's `CLAUDE.md`).
4. **Session-scoped stores.** `MockAuthService`, `MockGarageService`,
   `MockOrderService` and `MockServiceMarketplaceService` keep state in memory,
   so a restart clears the garage and order history. Real persistence arrives
   with the API.
5. **`ServiceOffering` embeds its full `ServiceProvider`.** Fine as an expanded
   relation, but confirm the API returns it that way or the mapper will need a
   join.
6. **Lifecycle timers live in notifiers**, not in a service. Gated behind a
   config flag and easy to delete, but they are the one place the staging build
   fakes server behaviour above the data layer.

---

## 7. Verification

```
flutter analyze     # 1 pre-existing info (core/utils/contact.dart)
flutter test        # 94 passing
flutter build web   # release build succeeds, icon tree-shaking intact
```

Behaviour parity with the pre-refactor app is covered by the 72 original tests,
which still pass unchanged in intent; the 22 new ones cover bootstrap and JSON.
