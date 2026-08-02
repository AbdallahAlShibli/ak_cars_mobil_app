# AK Cars mobile — architecture

Staging-ready structure: real layering, real async data flow, **mock data**.
No HTTP client exists yet; the seams where one plugs in are all in place.

Since 2026-07-27 the app is scoped to one pillar and a half —
**booking → escrow → approval**, plus maintenance follow-up — per
`MobileApp-Design/AK_Cars_مواصفات_تعديل_التطبيق.md`. The parts store and the
cars marketplace are hidden behind feature flags, not deleted; see §0 and §8.

---

## 0. Feature flags — hide, do not delete

`lib/config/app_flags.dart` holds compile-time switches. `false` removes the
bottom-navigation branch, the routes, and every entry point that would push
into that pillar. It removes no code: the screens, models, services and their
tests all still build.

| Flag | Default | Hides |
|---|---|---|
| `partsStoreEnabled` | `false` | Shop tab, `/shop/**`, `/cart`, `/orders`, profile rows, parts in search |
| `carMarketplaceEnabled` | `false` | Cars tab, `/cars/**`, `/post-ad`, `/my-ads`, home ads rail, cars in search |
| `homeTabEnabled` | `true` | The home page — see §8 and §11 |
| `maintenanceEnabled` | `true` | The "سيارتي" tab |
| `weekChallengeEnabled` | `true` | The weekly challenge and `/challenge` |
| `requestPartInstall` | `true` | "Request a part + fitting": `/request-part`, `/quote/:id`, the services-tab CTA — see §12 |
| `verifiedReviews` | `true` | `/review/:id`, ratings on provider cards, the "rate your experience" prompt — see §13 |
| `operatorPanelsEnabled` | `true` | `/workshop`, `/admin`, the Settings role switcher |

Override for a local check:
`flutter run --dart-define=AK_PARTS_STORE=true`.

They are `const` rather than fields on `AppConfig` because the router and the
shell read them while building the tree, below the DI layer — and a `const`
keeps a hidden pillar out of the release bundle's reachable code.

**The cost to know about:** a compile-time flag cannot be flipped from a test,
so the assertions that covered the hidden pillars' *reachability* (shop rows
on the profile, parts and cars in search) were rewritten to assert their
absence. The pillars' own screens are still covered. If they come back, those
assertions come back with them.

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
| `lib/core/` | i18n, theme, router, widgets, `constants/`, `error/`, `json/`, `media/`, `network/` | No feature or data knowledge |
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
- **Lifecycle simulation.** `RequestsNotifier._simulateLifecycle` and
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

**Identity: every record's `id` is a GUID.** A lowercase, hyphenated v4 from
`core/utils/guid.dart` — the same value the database column holds as its
primary key. Nothing in the app derives meaning from an id, and nothing
branches on one; a record composed offline is born with the id it will keep.

Where code genuinely has to recognise *what kind* of thing a record is, that
is a **slug**, not an id: `ServiceCategory.slug` (`express`, `tyres`, `sos`)
is what `MaintenanceTypeX.forCategory` and the booking screen's emergency
check read. This split is load-bearing — those switches used to run on `id`
back when ids were hand-written words, and a category re-seeded with a
different primary key would have silently stopped resetting the oil-change
countdown.

Ids come from three places and nowhere else:

| Call | Use |
|---|---|
| `newGuid()` | a record the user just created |
| `derivedGuid(namespace, a, b)` | a record *composed* from others, which must compare equal across rebuilds (the part-install stand-in offering, a booking's service record) |
| `mockId*` in `data/datasources/mock/mock_ids.dart` | the demo dataset's frozen ids |

Four non-obvious encodings:

- **Attachments (`MediaAttachment`)** → the file's bytes, base64, on the
  record. See §4.1.

- **`L` (bilingual text)** → `{"ar": …, "en": …}`. Both languages live on the
  record because stored content (notifications) must render in whatever
  language is active when it is *read*, not when it was written.
- **`IconData`** → a stable string key via `IconCodec`. Building `IconData`
  from a runtime integer would defeat `--tree-shake-icons` and ship the whole
  Material font; the registry keeps tree-shaking working (verified: 98.5%
  reduction in the release build). Unknown keys degrade to `IconCodec.fallback`.
- **`Color`** → `#AARRGGBB` via `ColorCodec`.

### 4.1 Attachments travel as base64

Every file a user supplies — a completion-proof photo, a workshop's
commercial-registration certificate — is a `MediaAttachment`: a GUID, the
bytes as base64, a MIME type, a file name and an optional caption. There is no
upload endpoint, no bucket and no URL. The bytes sit in the column next to the
row that owns them.

```
pick  →  XFile.readAsBytes()  →  base64Encode  →  MediaAttachment on the record
show  →  base64Decode (cached) →  Image.memory  →  AttachmentView
```

- **Capture** is `pickAttachments` in `features/services/proof_upload_sheet.dart`,
  shared by the proof sheet and the registration form. It encodes on the spot,
  because a picked file is a temp file the OS may delete and a path held across
  a process death points at nothing.
- **Encoding and MIME resolution** are `core/media/media_codec.dart` — pure
  functions on bytes, no Flutter binding needed to test them.
- **Display** is `core/widgets/attachment_view.dart`. Images decode and draw
  from memory; a PDF or video, which the app ships no decoder for, gets a tile
  naming the file and its size rather than an empty frame that could pass for a
  checked document.
- **`kind` is derived from `mimeType`**, never stored, so a record cannot claim
  to be a photo over PDF bytes.

The costs, taken deliberately: a 400 KB photo is ~533 KB of base64 in every
request and response that carries it, so captures are downscaled
(`maxWidth: 1600, imageQuality: 82`) and anything over `maxAttachmentBytes`
(4 MB) is refused with a message naming the limit. Decoded bytes are cached by
attachment id, bounded at 16 MB, because `Image.memory` keys Flutter's own
image cache on byte-list identity — handing it a fresh list each build would
re-decode the bitmap as well as the base64.

What it bought: one code path on every platform. The app used to need a
conditional import (`Image.file` behind `dart:io`, `Image.network` on a web
`blob:` URL) because an attachment was a path and a path means something
different on each. `core/media/local_image{,_io,_web}.dart` are gone.

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
| Maintenance countdown, distance **and** time, whichever runs out first | `MaintenanceRepositoryImpl.dueItems` |
| Projected odometer, and whether it is an estimate | `MaintenanceBook.avgKmPerDay` / `projectedOdometerKm` / `isProjected` |
| Which car a maintenance record belongs to | `MaintenanceBook.carId` — one book per registered car, keyed by car id, never shared |
| Which schedule line a booked category resets | `MaintenanceTypeX.forCategory`, checked against the car's own powertrain |
| When a booking may write a maintenance record | `RequestsNotifier.fire` → only on `EscrowState.releasedToWorkshop`; `MaintenanceBook.hasRecordForBooking` makes a repeat harmless |
| Which escrow transition may happen, and who may fire it | `escrowTransitions` (`models/escrow.dart`) — see §9 |
| Applying a transition to a booking | `ServiceRequest.apply`, the only writer of `escrow` |
| Escrow released only by the customer (or the 72-hour timer) | the table: `awaitingApproval → releasedToWorkshop` is `customer` or `system`, never `workshop` |
| Notification copy for every lifecycle event | `NotificationRepositoryImpl.notify*` |
| Product matching | `ShopFilter.matches` — shared by the local and remote paths |
| Which maintenance items a car *has* | `MaintenanceTypeX.appliesTo` / `forPowertrain`, applied by `MaintenanceRepositoryImpl.dueItems(powertrain:)` — an electric car has no engine-oil countdown |
| Which services a car can book | `ServiceCategory.powertrains` / `appliesTo`, ordered by `ServiceMarketplaceRepository.categoriesFor` |
| Which workshop may sell EV work | `ServiceCategory.requires` matched against `ServiceProvider.capabilities` |
| Which parts fit a car | `Product.fitsCar` = make/model **and** `fitsPowertrain` |
| Which weekly challenge is offered | `ChallengeTrack` (`challenge_service.dart`), one board per track, selected by the default car |
| Whether a service is work a given car can use | `categoryServes` (`models/recommendation.dart`) — the one predicate behind the home page's offers rail, suggestions and most-booked list; see §11 for why it is not `MaintenanceTypeX.appliesTo` |
| What the home page suggests, and in what order | `buildRecommendations` (`models/recommendation.dart`) — pure, seeded, ranked by reason; see §11 |
| Whether a promoted offer may be shown | `ServiceMarketplaceRepositoryImpl.promotions` — live, in-region, target resolves, suits the car |
| Whether a workshop rating may be ranked | `ServiceMarketplaceRepositoryImpl.topRatedWorkshops(minReviews:)` — 25 reviews minimum |

### The powertrain rule

`Car.powertrain` is optional and is the single input to everything above. Three
properties of it are load-bearing and worth keeping:

- **`null` means "not recorded", never a guess.** It resolves to combustion
  behaviour, which is what the app did before the field existed, so an existing
  saved car is unaffected.
- **An unknown powertrain hides nothing.** `ServiceCategory.appliesTo(null)` and
  `Product.fitsPowertrain(null)` are both true — a blank field must never make
  the catalogue look smaller than it is.
- **The app reads nothing from the car.** There is no charge level, no range and
  no battery state of health anywhere; `MaintenanceType.evBattery` reports
  `DueStatus.noRecord` until a real inspection is logged, and the maintenance
  screen says so in words.

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
4. **Session-scoped stores.** `MockOrderService` and
   `MockServiceMarketplaceService` still keep state in memory, so a restart
   clears the order history and any open service request. Real persistence
   arrives with the API. The three stores holding what the user *typed in* —
   `MockAuthService` (profile), `MockGarageService` (cars) and
   `MockMaintenanceService` (books) — write to SharedPreferences via
   `PrefsCollection`, because losing those on a restart is indistinguishable
   from the Save button not working.
5. **`ServiceOffering` embeds its full `ServiceProvider`.** Fine as an expanded
   relation, but confirm the API returns it that way or the mapper will need a
   join.
6. **Lifecycle timers live in notifiers**, not in a service. Gated behind a
   config flag and easy to delete, but they are the one place the staging build
   fakes server behaviour above the data layer. The 72-hour auto-release timer
   has the same shape and the same caveat: it only fires while the app is
   running, which is why `RequestsNotifier.sweepExpiredApprovals` re-checks on
   every visit to the bookings tab. A real deployment needs this server-side.
7. **Attachments are base64 on the record, which is a scaling ceiling, not a
   bug.** Resolved the old "capture is local-only" gap: a picked file is
   encoded at capture and travels with the record (§4.1), so proof media
   survives a reinstall and renders on any device that reads the row. The
   trade is size. Every response carrying a booking carries its proof photos
   inline, list endpoints returning many such rows will be large, and there is
   no way to fetch a record without its attachments or to serve a thumbnail
   separately. Below a few hundred bookings this is fine; past that the
   answer is object storage plus a URL, and the seam for it is narrow — the
   codec, `MediaAttachment`, and `AttachmentView`. Nothing else touches bytes.
8. **Escrow money movement is manual by design** (spec §3, note 2). The app
   records state; the founder moves the funds. `AdminScreen` says so on the
   screen, so its totals are not mistaken for a ledger of completed transfers.
9. **The home page's aggregates are fixtures, not measurements.** Booking counts
   (`MockServiceData.categoryDemand`) and workshop ratings (`.workshopRatings`)
   are demo data like every other mock in the app, and the page prints them as
   facts — because that is what they will be once the endpoints in §11 exist.
   Nothing in the client can derive them, so there is no honest fallback to show
   instead: until the API is wired, treat those two sections as demo content and
   do not put the build in front of real customers with them in it.

---

## 7. Verification

```
flutter analyze lib test   # 1 pre-existing info (core/utils/contact.dart)
flutter test               # 332 passing
flutter build web          # release build succeeds, icon tree-shaking intact
```

The 2026-07-27 refocus added four test files: `escrow_test.dart` (the
transition table's invariants, actor permissions, the automatic proof hand-off,
the approval window), `maintenance_projection_test.dart` (usage rate,
projection, whichever-comes-first), `focus_flags_test.dart` (the tab bar tracks
the flags and the start location is always a tab that exists) and
`operator_panels_test.dart`. `widget_test.dart` now also boots the real router
and visits every branch — the only place the tab list and the shell's branch
indices are proved to agree.

The 2026-07-28 home page added `home_test.dart` (the four sections' honesty
rules: a card that points at nothing, an expired campaign, a rating with four
reviews behind it, a shuffle that reorders what matters — see §11). Its
recommendation cases override `sessionSeedProvider`, which is the only way to make
that rail deterministic.

---

## 8. Navigation

Five tabs: **الرئيسية · الخدمات · حجوزاتي · سيارتي · حسابي** — spec §2's four,
plus home, which came back on 2026-07-28 rebuilt around this build's own pillars
(see §11).

`lib/features/shell/shell_tabs.dart` is the single source of truth. The router
builds one `StatefulShellBranch` per entry and `ShellScreen` builds one button
per entry, so the bar and the branch indices cannot drift apart. Adding a tab
is one entry in `buildShellTabs()`.

Home was the tab that went in the 2026-07-27 refocus, because most of what it
aggregated was the shop and the cars gallery. It is back, rebuilt (§11), and it
is again the first tab and the cold-start destination. `AuthState.initialRoute`
and every "back to the top" navigation still resolve `AppFlags.startLocation`
rather than naming `/home` or `/services` directly, so neither can point at a
route the build does not register — which is what makes turning the tab off again
a one-line change.

Routes that outlived the home tab moved to the tab that owns them: the garage
and the weekly challenge are reached from "سيارتي", and each maintenance
reminder deep-links into `/services?q=…` for the item it is about.

---

## 9. The escrow state machine

The product's core (spec §3), in `lib/data/models/escrow.dart`.

A booking's position is **one `EscrowState`**, never a set of booleans, so
`isAccepted && isRefunded` is not a reachable state. Thirteen of them:
`createdPendingPayment → fundsHeld → acceptedByWorkshop → inProgress →
proofSubmitted → awaitingApproval → releasedToWorkshop`, with `disputed`,
`cancelled` and `refunded` off to the side — and three ahead of the start,
`requested → quoted → quoteAccepted`, which only a `BookingType.customQuote`
booking passes through (§12). `EscrowState.isQuotePhase` names those three; they
hold no funds and carry no amount.

`escrowTransitions` is the spec's transition table, transcribed, and the only
authority on what may happen next. Every row names an `EscrowEvent` and the
`EscrowActor` allowed to fire it, which is what makes the rest fall out:

- **Operator panels build their own buttons.** `EscrowActionBar` renders
  `state.transitionsFor(actor)` — the workshop is never shown "resolve
  dispute", because the table does not give it one. Adding a row adds the
  button, in the right panel, on the right jobs.
- **Screens cannot invent a transition.** They call
  `RequestsNotifier.fire(id, event, actor:)`; an event the current state does
  not offer returns null and changes nothing. `MockServiceMarketplaceService`
  throws a `BusinessRuleException` for the same case at the service boundary,
  which is where the real API will enforce it.
- **`ServiceRequest.apply` is the only writer of `escrow`.** It appends an
  `EscrowEntry` (state, actor, timestamp, event) to `history` on every move —
  the audit trail the founder resolves disputes from, and the only honest
  source for when a customer's approval window actually opened.

Four behaviours worth naming:

- **`proofSubmitted → awaitingApproval` is automatic.** The notifier fires it
  itself as `EscrowActor.system`, so a customer never watches a booking sit in
  a state waiting for something invisible. The intermediate state is still
  recorded in `history`.
- **`quoteAccepted → createdPendingPayment` is automatic**, for the same
  reason: accepting a price *is* agreeing to pay it, and asking for a second
  button meaning the same thing would only invite a booking to stall between
  them.
- **`fundsHeld → acceptedByWorkshop` is automatic for a custom quote.** A
  workshop that priced the job already committed to doing it, so it is not
  asked to accept it again. A catalogue booking still is — nobody there has
  agreed to anything yet.
- **The 72-hour window** (`AppConfig.approvalWindow`) protects the workshop
  from a customer who disappears after collecting their car. A warning goes out
  `approvalReminderLead` (24h) before the deadline — a silent automatic release
  is indistinguishable from the app taking the workshop's side.

`EscrowState.customerStepIndex` collapses the ten states into the six steps the
tracking screen tells. The customer's story and the machine are deliberately
not the same shape.

Telling that story takes **two** questions, not one, because the collapse is
lossy: all four endings land on the last step, so "where the customer is" does
not say which steps were passed to get there. `EscrowState.reachedStepIndex`
answers the second question — how far a state *proves* a booking got, and
`null` for `disputed`/`cancelled`/`refunded`, which prove nothing on their own —
and `ServiceRequest.reachedStepIndex` walks the escrow `history` for the
furthest step actually reached. The timeline ticks a row only when it is both
behind the current row and one the booking reached, so a booking cancelled
before payment cannot show "funds held" as done.

### Roles

`AppRole` (customer / workshop / founder, spec §6) is device-local, stored in
SharedPreferences and switched at the bottom of Settings. It is not a
permissions system — the backend will own that. `AppRole.actor` maps it onto
the `EscrowActor` the transition table speaks, and that mapping is the whole of
the integration: a role is a person, an actor is a party in the table.

---

## 10. Maintenance follow-up

Spec §4, and the governing rule has not changed: **honest, or absent**. The app
reads nothing from the car.

### One book per car

`MaintenanceBook` is keyed by `carId` and holds everything about that one
vehicle: its odometer, its service records, the owner's own extra items, and
its interval overrides. `MaintenanceRepository` holds a `Map<carId, book>`;
`GarageNotifier` opens a book when a car is registered and closes it when the
car is removed.

The dependency between the two notifiers runs one way — **garage → maintenance**.
`GarageNotifier.setOdometer` is the single entry point for mileage and writes
the saved car *and* its book, so the garage card and the My Car page cannot
show two different readings for the same vehicle. `MaintenanceNotifier` reads
nothing from the garage, which keeps the two out of a Riverpod cycle and stops
a garage edit from invalidating a maintenance write already in flight. The
providers that genuinely need both (`maintenanceCarProvider`,
`maintenanceDueForCarProvider`) sit outside either notifier.

This replaced a single global log. Under that design a user who registered
their first car was shown an oil change and a wheel alignment that car had
never had, at a mileage that was not theirs; a second car showed the first
car's countdowns; and the "maintenance" mileage silently belonged to whichever
car happened to be default. **Nothing is seeded** now — `MockMaintenanceService`
starts empty and a new book starts empty, with the correct default items for
its powertrain and no history it did not have.

### The first-run state

A book with no records is `isFresh`, and the page says so rather than drawing a
countdown from numbers nobody entered: a setup banner instead of the "where
these numbers come from" notice, "No record yet" on every item, and the two
ways out — *Add last service* (the manual-entry sheet: date, odometer,
workshop, notes, and the interval) or *Book service*. Saving one manual record
starts that item's countdown from the owner's real history.

### Custom items

`CustomMaintenanceItem` is an extra line the owner adds to **one** car — wipers,
spark plugs, gearbox oil, a home-charger inspection. Its `title` is stored as
typed and rendered identically in both languages: the app does not invent a
translation of the owner's words. Deleting one deletes the records filed under
it, since they would otherwise have no line to reset. `MaintenanceItem` is the
resolved schedule line the UI renders, built either from a `MaintenanceType` or
from a custom item, so no screen branches on which kind it is.

### The projection

Two odometer readings give a usage rate (`MaintenanceBook.avgKmPerDay`); the
rate projects today's reading (`projectedOdometerKm`); the distance countdown
measures against that rather than against a number entered three weeks ago.
Three properties keep it honest:

- **One reading gives no rate**, and no rate means no projection — the entered
  value is used unchanged. There is no fallback national average.
- **An odometer that went backwards gives no rate** either: a correction is not
  a second data point.
- **Anything projected is labelled.** `DueItem.estimated` drives a
  "(تقديري) / (estimated)" suffix, and the screen's source notice changes
  wording when a projection is in play.

Items carry a distance interval *and* a time interval where both apply
(`MaintenanceRule.resolve`) and come due on whichever runs out first — which is
how a workshop quotes them. An item with neither computable still reports
`DueStatus.noRecord`, and carries its last record so the screen can show the
history without claiming progress it cannot justify.

### Booking → record

`ServiceRequest.maintenanceItemKey` carries which schedule line a booking was
raised from (set from `maintenanceBookingIntentProvider` when the owner taps
Book on an item); with none, `MaintenanceTypeX.forCategory` maps the offering's
category, and the result is discarded if the car does not have that item — an
"express service" on an EV has no engine oil to reset.

The record is written **only** on `EscrowState.releasedToWorkshop`. Placing a
booking writes nothing; cancelled, rejected, refunded and still-disputed
bookings write nothing, because none of them is evidence that work happened. A
dispute the founder resolves for the workshop does reach `releasedToWorkshop`,
and does write. The record's id is derived from the booking id and carries
`bookingId`, and the service upserts by id, so a lifecycle event that arrives
twice (the approval timer and `sweepExpiredApprovals` can both land) produces
one row.

Every due reminder is a booking button (spec §4): reminder → booking → service
record → sharper next reminder. The buttons carry no price; what a job costs is
the workshop's business, and the real prices are one tap away.

---

## 11. The home page

Rebuilt 2026-07-29 against `MobileApp-Design/AK_Cars_تعليمات_الصفحة_الرئيسية.md`.
It is not a display case; it is a starting point for a booking, and its running
order is the sequence that handoff fixes: **حاجة → فرصة → طمأنة** ("your car
needs this" → "here is an opportunity now" → "from workshops you can trust").

`home_screen.dart` is layout only; every section lives in `home_widgets.dart`
and reads one provider from `lib/state/home_state.dart`.

| # | Section | Provider | Data behind it |
|---|---|---|---|
| 1 | حالة سيارتي · My car status | `garageProvider` + `maintenanceDueForCarProvider` | the owner's cars and their own books |
| 2 | عروض هذا الأسبوع · This week's offers | `homeOffersProvider` | `Offer` — validated discounts on listed services |
| 3 | ورش موثوقة · Trusted workshops | `topRatedWorkshopsProvider`, `mostRequestedWorkshopsProvider`, `approvedWorkshopsProvider` | `WorkshopRating`, `WorkshopDemand`, `ServiceProvider.isApproved` |
| — | مقترح لسيارتك · Suggested for your car | `homeRecommendationsProvider` | `buildRecommendations` over sections 1 and 3 |
| — | الأكثر حجزاً · Most booked | `mostBookedServicesProvider` | `CategoryDemand` — a marketplace-wide counter |
| — | من AK Cars · Announcements | `homeAnnouncementsProvider` | `Promotion` — platform cards, no price |

The first three are the spine and their order is fixed; a widget test asserts
their vertical positions rather than merely their presence, because the sequence
is the requirement. Everything below them is supporting material, ordered by how
personal it is, and each is omitted when it has nothing to say.

### The rule this page is built on

Every claim on it is the sort a marketplace is tempted to invent. So:

- **Nothing ranks on money.** No section has a paid slot, a boost or a sponsored
  row. `Offer` has no field money could buy; the offers rail sorts on the size of
  the discount, the workshop boards on rating and on completed bookings, and the
  suggestion rail on the owner's own mileage. The thresholds and windows live in
  one file, `config/home_ranking_config.dart`, and nothing is stored — every
  order is computed on read from live data.
- **No section pads itself.** The page composes only the sections that have
  something to say (`HomeScreen.sections`), so a hidden one does not leave its
  spacing behind. With an empty garage section 1 is a single "register your car"
  card, not a stand-in vehicle; with nothing discounted section 2 does not exist.
- **A heading never claims data the app does not have.** When no workshop has
  enough reviews to rank, section 3 does not show an empty "top rated" board and
  does not lower the bar — it changes to *ورش معتمدة قريبة منك* (approved,
  nearest first), which is a claim the data supports. The "most requested" tab is
  not offered at all until something has actually been completed.
- **Nothing is computed on the phone that the phone cannot see.** "Most booked"
  and "most requested" are every customer's bookings; this app sees only the
  signed-in user's. `CategoryDemand`, `WorkshopDemand` and `WorkshopRating` are
  therefore *fetched* aggregates, each carrying the window or the review count
  that makes it mean anything.
- **A rating needs enough reviews to be one.** `topRatedWorkshops` refuses to
  rank below `HomeRankingConfig.minReviewsForRanking`. **This is 25, not the 3
  the handoff gives as an illustration** — the handoff's own reasoning ("لتجنّب
  ورشة بتقييم 5 من مراجعة واحدة تتصدّر") argues for the higher bar, and the demo
  data carries a 4.9 on four reviews precisely so the rule is exercised. Change
  it in one place if the pilot wants it looser.
- **Every reminder is a booking button.** Each car card ends in an action: *احجز
  الآن* when there is a countdown, *متأخّر — احجز الآن* in the alert colour when
  it has run out, and *أضف آخر [الخدمة]* — naming the service — when there is no
  record to count from. All of them go through `bookMaintenanceItem`, the same
  function the My Car page uses, so a booking started from either place carries
  the same intent and writes its record to the same countdown.
- **No oil nudge for a car with no engine.** `categoryServes`
  (`models/recommendation.dart`) is the single predicate for "is this work this
  car can use", and every marketplace-facing section goes through it — offers
  included.

### Offers are governed, not just rendered

An `Offer` (`models/offer.dart`) is a claim about money, so it is validated
against the live catalogue on **every** read, by one method —
`ServiceMarketplaceRepositoryImpl._reject` — implementing the handoff's six
rules. An offer appears only when all of them hold:

1. the reference price equals the price the platform publishes for that
   offering (the seller cannot type a "was" price and manufacture a discount);
2. the workshop is `isApproved`;
3. the service is listed, and listed *by that workshop*;
4. `activeByFounder` is set;
5. today is inside `startsAt`–`endsAt`;
6. the discounted price is genuinely below the reference.

`auditOffers()` returns every offer with the rule that is holding it back, which
is what the founder panel's offers section renders — a workshop asking why its
discount is not showing gets an answer from the same code the home page runs.
The panel's only control is the founder's on/off switch; there is deliberately
no way to edit a price there, and no way to feature or boost an offer.

`ServiceProvider.isApproved` is separate from `verified` and gates only
*promotion* — offers and the home boards. An unapproved workshop still sells and
still appears in the services list.

### One price, everywhere

A discount that only existed on the home card would be a lie by the time the
user reached the confirmation screen. So the split is:

- `offerings` / `offeringById` — the **raw** catalogue. Only offer validation
  reads it (a discount that could validate against a discounted price would
  validate against itself), plus the struck-through "was" price.
- `pricedOffering(id)` / `pricedOfferings` / `offeringsFor(...)` — the catalogue
  **with live discounts applied**. Everything else reads these: the services
  list, search, the category "from" prices, the suggestion rail, the service
  page, and the booking screen — which means the total, the escrow amount and
  the record all inherit the discount without knowing offers exist.

Prices are formatted with `#,##0.##` (`omrAmount`), not `toStringAsFixed(0)`:
whole-number rounding was harmless while every published price was an integer,
but it rendered a service discounted to 4.5 as "5".

### The suggestion rail

`buildRecommendations` is a pure function (same shape as
`calculateRequestTotal`), so the ordering rule is testable without a widget tree.
Each card carries the reason it exists, and cards are ranked by that reason:
`dueNow → dueSoon → electric → noRecord → popular`.

Two properties are load-bearing:

- **"Changes each time you open the app" is a shuffle inside a band, never
  across one.** `sessionSeedProvider` draws one number per app process; the
  shuffle happens before a stable sort by reason. A genuinely overdue oil change
  therefore cannot be pushed below "most booked this month" by a dice roll, and
  the rail does not reshuffle when the user scrolls, changes language, or opens a
  sheet — a seed read inside `build` would do exactly that, and would make the
  rail untestable.
- **One card per schedule line, and the cheapest of them.** Major, Full and
  Express service all reset engine oil; three cards saying "no record for engine
  oil" is one suggestion printed three times.
- `electric` outranks `noRecord` because "this car plugs in" is a fact about the
  car, while "we have no record" is a fact about our own ignorance — and true of
  every item on a car registered five minutes ago.

### Phase 2

Five endpoints, already named in `ApiEndpoints` (`servicePromotions`,
`serviceOffers`, `serviceCategoryDemand`, `serviceWorkshopDemand`,
`serviceWorkshopRatings`), and nothing above the service layer changes when they
land. The warm caches are already in `ServiceMarketplaceRepositoryImpl.warmUp`,
and `MockServiceData.offers`, `.promotions`, `.categoryDemand`,
`.workshopDemand` and `.workshopRatings` are the demo stand-ins — fixtures, not
measurements. `MockServiceData.offers` deliberately contains four invalid
offers, one per failure mode, so the validation is exercised rather than
assumed; the real endpoint is expected to pre-filter, and the client validates
anyway.

---

## 12. Request a part + fitting

The custom-quote transaction (spec §6), behind `AppFlags.requestPartInstall`.

**What it is not, first.** There is no parts catalogue, no inventory, no
supplier onboarding, no fitment/compatibility database, no shipping and no
returns. The workshop is the compatibility expert: the customer describes the
part or the fault and the car, and one workshop answers with a price. That is
the whole feature, and every one of the absent pieces is absent on purpose.

**It rides the existing escrow machine.** `BookingType` (on `ServiceRequest`)
distinguishes the two transactions; a `customQuote` booking simply enters the
machine three states earlier. There is no second money flow, no second operator
panel and no second set of rules — which is why the quote phase lives in
`escrow.dart` as states rather than beside it as a parallel workflow.

```
requested → quoted → quoteAccepted ─┐
                                     ├→ createdPendingPayment → … (shared path)
      catalogService starts here ────┘
```

### Three decisions worth knowing

- **The offering is synthesised, not nullable.** A custom request has no
  catalogue entry, but every screen reads the workshop, the title and the price
  off `request.offering`. `ServiceOffering.partInstall(...)` builds a
  quote-only offering describing exactly that — this workshop, this part, no
  published price. Making the field nullable would have taught a dozen widgets
  to branch on something none of them care about.
- **The quote is structurally itemised.** `Quote` has `partPrice` and
  `laborPrice` and *no* total field — `total` is a getter. A workshop cannot
  submit a lump sum through this model, and the customer therefore cannot be
  shown one. That split is the reason the transaction is in the app at all
  rather than over the phone.
- **The part warranty is not the escrow.** `Quote.warrantyDays` is the
  workshop's own guarantee on the part; it *starts* where the payment escrow
  ends. Every screen that shows one says so. The app records it and displays
  it; it does not enforce it, and post-release claims are out of scope.

### The two rules the transition table cannot express

Both are rules about the *payload* rather than the ordering, so they live in
`ServiceRequest.proofSatisfiesRules` and are enforced in four places —
`ProofUploadSheet` (disables submit and names the unmet rule), `apply` (no-op),
`RequestsNotifier.fire` (returns null) and the mock service
(`BusinessRuleException`, where the real API will enforce it).

**1. Every proof needs at least one photo or video** (spec §3). The customer
releases real money on the strength of it, and notes alone are a claim rather
than evidence. This applies to catalogue services and part jobs alike; there is
no "notes only" proof.

**2. A `customQuote` job additionally needs `includesPartBoxPhoto`** (spec §6):
the customer paid for a specific part, and a photo of a closed bonnet speaks to
neither which part went in nor whose it was.

Rule 2 is a **declaration, not a verification**: the app cannot inspect a photo.
So the workshop ticks it and the approval screen tells the customer that it was
ticked — or that it was not.

The staging lifecycle simulator stops at `submitProof` for *every* booking type
for the same reason: a demo timer is not entitled to manufacture a workshop's
photographs, and rule 1 now means it would have to.

---

## 13. Verified reviews

Spec §8, behind `AppFlags.verifiedReviews`.

**The mechanism is one sentence:** a review can only be created from a booking
that reached `releasedToWorkshop`, and `(bookingId, direction)` is unique.
There is no separate verification step, no badge to award, no bot detection and
no moderation queue — and none of those is missing, because faking a review
here costs a real booking with real money in it.

`ReviewRepository.submitFor(request, …)` is the **only** way a `Review` is
constructed anywhere in the app; it takes a booking, not a workshop id, and
refuses anything not released. `ReviewsNotifier` exposes no free-form "add a
review". The `/review/:id` route is likewise per-booking.

- **A review is an event, not a state.** No escrow state was added for it,
  nothing is held back pending one, and the release does not wait. All that
  happens at `releasedToWorkshop` is a notification and an unlocked form.
- **Bidirectional, one entity.** `ReviewDirection` decides who is rating whom;
  both directions unlock on the same release. Two model classes would have
  duplicated every rule.
- **The rating is derived, never stored.** There is no editable `rating` field
  on `ServiceProvider` and there must never be one.
  `providerRatingProvider(id)` folds this device's reviews into the
  marketplace's own aggregate and returns **null** — not 0, not 5 — for a
  workshop nobody has rated. Every screen that prints a rating renders that
  null as words.
- **Nothing is seeded.** `MockReviewService` starts empty. Inventing reviews
  would manufacture precisely the fake social proof this design exists to make
  impossible; the aggregate counts in `MockServiceData.workshopRatings` are a
  different thing — figures a backend computed, standing in for an endpoint.
- **Edit, never delete.** A 24-hour correction window (`editWindow`), and
  `edited` is shown. A review that can be withdrawn on demand is a review a
  workshop can pressure someone into withdrawing.
- **Disputes are labelled, not hidden.** A booking that went through a dispute
  before settling still earns a review, tagged "after a resolved dispute".

### Phase 2

`ApiEndpoints.reviews`, `.review(id)` and `.providerReviews(id)` are named and
unused. The uniqueness constraint has to be a real
`UNIQUE (bookingId, direction)` index server-side, and the released-booking
check has to be re-run there: the client mirrors both rules for the UI's sake,
and mirrors are not guarantees.
