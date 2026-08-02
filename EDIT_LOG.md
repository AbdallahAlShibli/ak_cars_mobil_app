# Edit Log

Running history of changes made to this app by Claude Code, newest first.

**Why this file exists:** when a bug turns up later, this is the record that says
what changed, why it changed, and what was verified at the time — so a
regression can be traced back to the decision that caused it instead of being
re-diagnosed from scratch.

**Conventions**
- Newest entry at the top. Never rewrite an old entry; if something turns out to
  be wrong, add a new entry that corrects it and link back.
- `Baseline` is the commit the work started from — `git diff <baseline>` shows
  everything the entry covers.
- `Verified` records what was actually run, including anything that was *not*
  checked. An unverified change says so.

---

## 2026-08-03 · GUID primary keys everywhere, and attachments stored as base64

**Baseline:** `dd6253e` ("Fix splash-screen hang, add API data-source layer…").
**Request:** "check what are the docs and images data types and update them to
follow this scenario which when user upload document or image will send them to
the backend as base64 in the database, and when this files should display for
the app users must converted to the appropriate format to view. also, each
record should has id. and each id must be as GUID. and it should be a primary
in each database table."

**Scope confirmed with the user before starting:** the mobile app only ("we
don't have an api for now"), and *real* GUIDs in the demo dataset rather than
keeping readable ids.

### 1. Attachments

There was no upload step at all. `ProofMedia.uri` and
`WorkshopApplication.crDocumentUrl` held whatever `image_picker` handed back —
an Android cache path, or a `blob:` URL on web — and `core/media/local_image
{,_io,_web}.dart` was a conditional-import shim that rendered one or the other.
A picked file therefore did not survive a reinstall and could not be seen on
another device, and the founder's "open CR document" dialog printed the path as
selectable text because there was nothing to draw.

Replaced by one type, `MediaAttachment` (`data/models/media_attachment.dart`):
GUID, `base64Data`, `mimeType`, `fileName`, `caption`. `kind` (image / video /
document) is **derived** from the MIME type rather than stored, so a record
cannot claim to be a photo over PDF bytes.

- `core/media/media_codec.dart` — encode, decode, MIME resolution, a 4 MB
  pre-encoding ceiling, byte-size formatting. Pure functions; no Flutter
  binding needed to test them.
- `core/widgets/attachment_view.dart` — decode and draw. Images go through
  `Image.memory`; a PDF or video gets a tile naming the file and its size,
  because a grey rectangle that might be a failed image is worse than no
  preview on the screen where a business gets approved.
- `pickAttachments` now reads and encodes **at capture**, and reports how many
  files it refused for size so the picker cannot appear to do nothing.
- Deleted `core/media/local_image.dart`, `_io.dart` and `_web.dart`. Bytes mean
  the same thing on every platform, so the conditional import had nothing left
  to do.
- The admin CR dialog now renders the certificate instead of printing its URL.

The cost is recorded rather than hidden: every response carrying a booking now
carries its proof photos inline. See ARCHITECTURE.md §4.1 and the rewritten
debt item 7 — the fix, when it is needed, is object storage, and the seam is
three files wide.

### 2. GUIDs

`core/utils/guid.dart`: `newGuid()` (v4, `Random.secure()`), `isGuid`,
`emptyGuid`, `coerceGuid`, and `derivedGuid(namespace, a, b)` for records that
are *composed* rather than stored and must compare equal across rebuilds.
Written by hand rather than adding `package:uuid` for one function.

Replaced every id scheme in the app: `'rev-${_nextId++}'` (a counter seeded at
500 to clear the mock data), `'my-${millisecondsSinceEpoch}'`,
`'manual-…'`, `'custom-…'`, `'challenge-…'`,
`'m${microsecondsSinceEpoch}-0'`, and `DateTime.now().millisecondsSinceEpoch
.toString()`. All 162 demo-dataset ids became frozen v4 GUIDs in
`data/datasources/mock/mock_ids.dart`, named (`mockIdP3`) so call sites read
as well as they did before.

### 3. The part that was not mechanical — slugs

Production code *did* branch on ids, in three places a first grep missed
because the ids were bare words:

- `MaintenanceTypeX.forCategory` switched on `'express' | 'full' | 'major' |
  'tyres' | 'battery' | 'ac' | 'ev-battery' | 'ev-check'` to decide which
  maintenance line a completed booking resets.
- `booking_screen.dart` treated `categoryId == 'sos'` as an emergency callout.
- `ServiceOffering.partInstallCategoryId` matched `'part-install'`.

Turning those ids into GUIDs would have silently stopped the oil-change
countdown from resetting. So `ServiceCategory` gained a `slug`, and
`ServiceOffering` a denormalized `categorySlug` (the model already expands
`provider` inline for the same reason — the screens that need it hold an
offering and nothing else). Behaviour now reads the slug; the id says only
which row. This is the change most likely to matter later: **if a new
`switch` on a category appears, it must switch on `slug`.**

One near-miss worth recording: `'tyres'` is both a service-category id and, in
a different namespace, a parts-shop category slug (`shop_screen.dart`'s icon
map, `mock_shop_data.dart`'s `categoryId`). A blanket literal replacement would
have broken the shop's tyre icon and filter. The replacement was scoped
per-file and per-call-site instead.

### Verified

- `flutter analyze` — clean apart from one pre-existing info in
  `core/utils/contact.dart:23` (untouched by this change).
- `flutter test` — **450 passing**, up from 426 at baseline. All 426 existing
  tests still pass; 24 are new.
- New `test/identity_and_attachments_test.dart` asserts the two rules over the
  whole dataset rather than on one example: every seeded record of every kind
  carries a GUID, every cross-reference resolves, every category has a slug
  that maps back to its id, base64 round-trips byte-for-byte, malformed base64
  degrades to a "cannot preview" tile instead of throwing, a PDF is named
  rather than drawn, and the decode cache returns the same byte-list instance
  twice.
- `test/proof_upload_test.dart`'s picker stub now returns **real bytes**
  (`XFile.fromData`) rather than a path — with encoding at capture, a
  path-only stub would have exercised none of the new pipeline.

**Not checked:** no run on a device or emulator this session; camera and
gallery capture were exercised only through the stubbed picker. The image
`assets/` pipeline and remote car imagery (`carImageUrl`, `CarMake.logoUrl`)
were deliberately left alone — those are catalogue images, not user uploads.

**Not done, deliberately:** test-local fixture ids (`'c1'`, `'r1'`, `'n1'` in
throwaway objects inside test files) are still short strings. They identify
nothing in a database and changing them is churn without behaviour.

---

## 2026-08-02 · Onboarding/profile stopped advertising the hidden car-marketplace and parts-store pillars

**Baseline:** on top of the "no longer hang on splash" entry below, same day.
**Request:** "test and check the app features using adb. see all app screens,
fix any bugs... see the first app page after splash screen. there is card for
sell and buy cars. remove it. see other features."

### What was actually wrong

Walked the whole first-launch flow and every bottom-tab screen live on a
physical device (SM S918B) via `adb`, clearing app data between passes to see
it as a new install would. `AppFlags.carMarketplaceEnabled` and
`AppFlags.partsStoreEnabled` are both `false` by default (phase-1 scope, see
`app_flags.dart`) — neither pillar is reachable from the shell. But five
always-reachable screens still advertised them as if they were live:

1. `onboarding_screen.dart` — the third onboarding slide ("Buy & sell cars
   with confidence" / "بِع واشترِ السيارات بثقة") was the literal "card" the
   request pointed at: it sold a feature with no route behind it.
2. `start_choice_screen.dart` — the "Add my car now" card's benefit list
   promised "Parts filtered to your model and year"; the "Not now" card's
   benefit list promised "Browse listings, workshops, and parts across Oman".
3. `register_screen.dart` — the lock notice above the form said registration
   was required "before requesting services, ordering parts, or posting a car
   ad."
4. `profile_screen.dart` — the guest banner said "Complete your details to
   request services, buy parts and post ads."

Tapping any of these promises would strand the user — there is no route to
push into once account-completion "unlocks" parts/listings, because those
routes are compiled out of reachability by the same flags.

### Fix

Removed the third onboarding slide entirely (workshops and parts slides
remain — 2 total). Reworded the four leftover benefit/notice strings (both
languages, register + profile + both start-choice cards) to
only reference what phase-1 actually ships: workshop bookings, roadside
assistance, maintenance reminders. Did not touch the underlying
marketplace/parts feature code, models, or routes — per `AppFlags`'s own
"hide, do not delete" principle, those stay intact for the Phase-2 flip.

### Verified

- `flutter test` — full suite, 426 tests, all passing (updated
  `test/onboarding_test.dart`'s slide-count-dependent assertions to match the
  now-2-slide carousel).
- Rebuilt debug APK, reinstalled on the physical device, walked the fresh-install
  flow (splash → onboarding → start-choice) and the profile/register screens
  again to confirm the corrected copy renders and no slide/benefit still
  mentions listings or parts.
- Did not verify the workshop-provider or founder operator panels
  (`AppFlags.operatorPanelsEnabled`) — out of scope for this pass, no
  marketplace-copy issue was seen there while browsing casually.

---

## 2026-08-02 · The app can no longer hang on the splash screen

**Baseline:** `8fd25ac`, on top of the uncommitted phase-2.5 work.
**Request:** "when close the app then return to open it keep hang on splash
screen. fix it"

### What was actually wrong

`main()` awaited the entire bootstrap — `SharedPreferences`, every repository
warm-up, the session restore — and only then called `runApp`. Nothing wrapped
that. So **any** failure in start-up meant `runApp` was never reached, Flutter
never painted a frame, and the OS launch screen (the app icon on a plain
background) stayed up indefinitely with no error, no spinner and no way out.
Reopening the app failed at the same place, which is exactly what "it keeps
hanging on the splash screen" looks like from the outside.

Two shapes of failure produced it, and neither was handled:

1. **A throw** — reproduced on a physical device (SM S918B, Android 16) by
   building with `--dart-define=AK_DATA_SOURCE=api`, where
   `UnconfiguredApiClient` throws `NetworkException` inside
   `ServiceMarketplaceRepositoryImpl.warmUp`. The app sat on the launch icon
   forever; the stack was only visible in `adb logcat`.
2. **A future that never completes** — nothing had a timeout, so a service that
   accepts and never answers would suspend `main()` permanently. No exception
   exists to catch in that case, so only a deadline can end it.

### The fix

- **`lib/app/app_launcher.dart` (new)** — `AppLauncher.launch()` owns the path
  from `main()` to the first frame. It wraps the bootstrap in a try/catch *and*
  a timeout, reports the failure through `FlutterError.reportError`, and paints
  a failure screen instead of nothing. The guarantee it enforces: **a frame is
  painted no matter what.**
- **`lib/app/boot_failure_screen.dart` (new)** — Sand & Ink themed, bilingual
  (platform locale, since there is no container to read the stored preference
  from), with a "Try again" button and the error text behind a disclosure. The
  message names what could not be reached, which is the difference between a
  bug report and "it doesn't work".
- **`lib/app/bootstrap.dart`** — `bootTimeout` (20s) applied to each awaited
  stage, and a half-built container is now disposed before the throw
  propagates, so a retry does not leave the first one's notifiers and timers
  running.
- **`lib/main.dart`** — reduced to `AppLauncher.launch()`.

A defect in the first version of the fix, caught on-device and then covered by
a test: a *failed* retry called `runApp` with the same widget type, so Flutter
updated the existing element tree and kept the old state — the button stayed on
a disabled "Trying…" forever. `BootFailureApp` is now keyed by attempt number.

### What this does not claim

The exact failure on the user's device was **not** identified — with a customer
account, a workshop-less profile and a fresh install, debug and release builds
both cold-started correctly through every stage of the first-run flow on the
test device. What is fixed is the reason *any* such failure presented as a
permanent, silent hang. If it recurs, the screen now names the error.

**Verified:** `flutter analyze` clean; full suite 426 tests + the 5 new ones in
`test/boot_failure_test.dart` passing; on-device — the api-mode build that
previously hung on the launch icon now shows the failure screen, and tapping
"Try again" after a repeat failure returns a usable button. Note: the test
device's app data was cleared during diagnosis (`adb shell pm clear`), so the
demo account and garage on it are gone.

---

## 2026-08-01 · Phase 2.5 — the operational gap, and workshop registration

**Baseline:** `99118bd` — the Sand & Ink polish pass, which is where this brief
starts from. Note that `8fd25ac` ("add workshops scinerio") is a **partial
commit of this same work**, taken while it was still in progress; `git diff
99118bd` is what shows the whole change.
**Request:** `@"C:\Projects\Cars Project\MobileApp-Design\AK_Cars_تعليمات_المرحلة_2_5_موحد.md"` —
"analize this new instructions with current project files then apply them"

A 16-section brief in two halves: the operational gap left after the Sand & Ink
polish pass, and a new scenario — registering a workshop account. All sixteen
sections are implemented. The brief's §15 execution order was followed, because
its dependencies are real: §11 calls §5, §6 and §7 directly.

### The one thing that was actually broken

The panels had no data. `MockServiceMarketplaceService` started with an **empty**
booking list, so both operator screens opened on an empty state and *no SLA
colour was reachable* — the amber and red states added in the previous pass had
never been seen by anyone, because reaching them required placing a booking by
hand and then waiting a day. Everything else in the brief builds on fixing that.

### §2 — `mock_seed.dart`

New: `lib/data/datasources/mock/mock_seed.dart`. One `now`, every timestamp
relative to it, `Random(42)`, so two runs see the same world and it never goes
stale.

- **40 bookings covering all 13 `EscrowState` values** (the old data reached
  one). Ages are chosen against specific `QueueSla` thresholds and commented
  where they are: 3 `createdPendingPayment` either side of the founder's 4h,
  3 `awaitingApproval` including one past the 72h window, 2 `disputed` either
  side of 4h, 4 `customQuote` across its phases.
- Histories are **walked, not fabricated** — `_booking` fires real events
  through `ServiceRequest.apply`, so a seeded booking cannot sit in a state the
  transition table could not have produced. That matters because the panels
  derive "how long has this been stuck" from the history.
- 15 workshops (not 12 — see *Deviations*), reviews in both directions
  including one after a resolved dispute, payouts, audit lines.

`MockServiceData` keeps the catalogue and reads its roster from the seed.

**Not seeded, deliberately:** the user's garage and maintenance books. This
project already removed a global maintenance seed once, for the reason recorded
in `mock_garage_data.dart` — a user who has just registered their first car must
not be shown services that car never had. The seeded cars belong to the seeded
*bookings*.

### §3–§4 — the workshop panel

`OperatorShell` (shared by both panels) + three tabs. Earnings shows held,
released-net-of-commission, and **total commission as a headline figure** — a
workshop that discovers the platform's cut by subtracting two numbers trusts the
platform less than one that was told plainly. Performance is backed by the new
`WorkshopMetrics`, computed in `ServiceMarketplaceRepository.metricsFor`.

Every rate renders as `—` when its denominator is zero. A workshop that has
never been sent a job has not refused any, and "0% acceptance" would be an
accusation the data does not support.

`AppConfig.platformCommission` is the single rate both panels read, so they
cannot quote different commissions for the same job.

### §5 — the founder panel, and `ProviderOnboardingStage`

Five tabs (the brief's four plus §6's log). `isApproved` is now a **derived
getter** over the new stage; every existing reader kept working and gained the
guarantee that nothing can be `isApproved: true` mid-application.

The brief's rule — *"a non-approved workshop is not shown to customers, takes no
bookings, and runs no offers"* — is enforced in the repository:
`visibleProviders` filters the customer-facing reads, and `_requireBookable`
refuses a booking outright. Hiding a button is not a rule: a stale deep link, a
cached list, or a workshop suspended between opening a page and pressing "book"
all reach that path with the button already gone.

`providers` stays unfiltered — the founder's pipeline is the one place pending
applications must be visible.

### §6 — the audit trail

`AuditEntry` + **one** write point: `ServiceMarketplaceRepositoryImpl._audit`,
called by exactly four methods. No screen can write a line, because a screen
that can write one can also forget to, and a log with holes is worse than none —
it is believed. Recording is best-effort: a booking that could not be approved
because the log was unreachable is a worse outcome than an unlogged approval.

### §7 — real role guards

`redirect` in `app_router.dart`, so it fires on **every** navigation rather than
once per route build. `/workshop` additionally requires
`stage == approved`, re-checked each entry — a workshop suspended an hour ago
must not still be inside its panel because its session predates the suspension.

An account with **no** application falls through to the role check alone. The
pilot's device-local role switcher is a demo tool the brief says to build on, not
replace; the stage check applies where a real onboarding decision exists.

### §8–§11 — workshop registration

`AccountKind`, `WorkshopApplication` (in `ServiceProvider`'s own field names, so
approval copies across with no mapping step), `UserProfile.kind`/`.workshop`.

`register_screen.dart` gained a step-zero picker (first registration only) and a
conditional workshop section — **not** a second registration screen, per §14. It
is the same account, the same OTP and the same `_errors` map; a parallel screen
would be a parallel copy of all three.

The flow, end to end: submit → filed at `documentsSubmitted` (not `applied`,
because the certificate came with it) → invisible and unbookable → the founder's
pipeline → approve, or reject **with a mandatory written reason** → the owner
sees that reason verbatim on their profile and can correct and re-submit, which
re-files the same workshop rather than opening a second one.

The mandatory reason is enforced three deep — dialog, repository, mock service —
because it is the only thing standing between "rejected" and an owner with no
idea what to fix.

A workshop gets its own receipt screen, not the customer's "you can now
transact" snackbar. Nothing has been approved at that point.

### §12 — API readiness

`DataSourceMode`, `apiClientProvider`, five `Api*` services, every binding in
`di/providers.dart` conditional, `docs/api_contract.md`.

`UnconfiguredApiClient` throws `NetworkException` naming the base URL. That is
the acceptance behaviour and it is deliberate: an app that silently falls back to
demo data while talking to nothing looks healthy, which is the failure this
switch exists to make impossible. Phase 2 replaces one class.

### §13 — scenario integrity

`test/scenario_integrity_test.dart` — all twelve journeys, plus seed and
derived-metric assertions. `test/data_source_switch_test.dart` covers §12's
acceptance criterion as a test rather than a manual step.

### Deviations from the brief, and why

- **15 workshops, not 12.** The region-coverage rule (`services_region_test`)
  needs every governorate's *approved* workshops to sell every category between
  them, which takes 11 approved on its own; §11 then needs applications actually
  sitting in the queue. Twelve cannot be both. The four applicants carry no
  catalogue entries — a workshop that has not been approved has never listed a
  service — so they do not affect coverage.
- **The audit log is a 5th tab, not a sub-tab.** §6 asks for "a filterable
  sub-tab inside the founder panel"; a peer tab is the same thing without
  nesting a tab bar inside a tab bar.
- **`ProofUploadSheet` is reused as `MediaStrip` + `pickAttachments`, not
  wholesale.** The sheet is built around a `ServiceRequest` and its part-box
  rule; reusing it literally would mean fabricating a booking to attach a
  commercial registration to. The *picker* — the part §0 actually names — is now
  shared, and there is still exactly one uploader in the app.
- **The operator panels read a new `operatorQueueProvider`, not
  `requestsProvider`.** The seed's 40 bookings belong to other people; putting
  them in a customer's "My bookings" would be the app claiming they are theirs.
  `fetchRequests` (mine) and `fetchOperatorQueue` (the platform's) are separate
  endpoints because they are authorised differently.

### Files

**New models** — `audit_entry.dart`, `payout_record.dart`,
`workshop_metrics.dart`, `workshop_earnings.dart`, `account_kind.dart`,
`workshop_application.dart`. **New:** `mock_seed.dart`,
`operator_queue_state.dart`, `workshop_state.dart`, `admin_state.dart`,
`operator_shell.dart`, `workshop_application_received_screen.dart`,
`unconfigured_api_client.dart`, `data/services/api/*` (5),
`docs/api_contract.md`, `scenario_integrity_test.dart`,
`data_source_switch_test.dart`.

**Changed** — `service_provider.dart` (staged onboarding, `isApproved` derived),
`user_profile.dart`, `app_config.dart` (`DataSourceMode`, commission, earnings
window), `service_marketplace_service.dart`/`_repository.dart` (visibility rule,
audit, metrics, earnings, onboarding, payouts), `auth_state.dart`,
`app_router.dart` (guards), `register_screen.dart`, `profile_screen.dart`
(status card), `admin_screen.dart` (rebuilt), `workshop_screen.dart` (tabbed),
`escrow_action_bar.dart`, `proof_upload_sheet.dart`, `review_service.dart`,
`providers.dart`, `bootstrap.dart`, `mock_service_data.dart`.

### Verified

- `flutter analyze lib test` — clean (one pre-existing `info` in
  `core/utils/contact.dart`, untouched).
- `flutter test` — **421 passing**, up from 396.
- Five existing tests were updated, each because a rule genuinely changed, not
  to make them pass:
  - `services_region_test` — `fromPriceFor('full')` is 27, not Sohar's 26: Sohar
    is an unapproved application now, and a "from" price has to quote something
    the tap can reach.
  - `home_offers_test` — the "board of one widens" case moved to Ad Dakhiliyah;
    North Al Batinah gained a second approved workshop.
  - `reviews_test` — three counts scoped to the booking under test, since the
    seed now contains reviews of its own completed jobs.
  - `operator_panels_test` — runs with `seeded: false`; these tests are about
    one booking they placed, and 40 others would drown the assertions.
  - `account_test` — answers step zero, and pumps on a taller surface so the
    whole form mounts.
- **One production bug found and fixed while testing:**
  `ServiceMarketplaceRepository.createRequest`/`createPartRequest` threw
  synchronously from a `Future`-returning method, so
  `createRequest(...).catchError(...)` would never have seen a rejected booking.
  Both are now `async`.

### Known-adjacent, not done

- **No maintenance/garage seed.** §2 asks for cars with two odometer readings,
  one, and none. Those live in per-car maintenance books, which are the signed-in
  user's own records — see above. Doing it needs a decision about demo-only
  seeding that the brief does not make.
- **`AK_DATA_SOURCE=api` is verified by test, not by a device run.** The
  bindings, the client and the failure mode are asserted; nobody has launched
  the app with the define set.
- **The CR document is shown to the founder as its stored reference, not
  rendered.** Pilot uploads are local device files; a viewer that silently
  failed to open one would look like a document somebody checked.
- The `UnconfiguredApiClient` means no `Api*` service has ever round-tripped
  real JSON. Their `fromJson` paths are unexercised.

---

## 2026-07-31 · Sand & Ink polish pass — spacing, hierarchy, state, icons

**Baseline:** `7468760` (working tree)
**Request:** `@"C:\Projects\Cars Project\MobileApp-Design\AK_Cars_تعليمات_تحسين_الواجهة.md"` —
"check this file and study it with my project then apply the instructions"

The brief is a visual review of 24 real screenshots. It is explicit that this is
a **polish pass, not a redesign**: the `AkColors` palette and the layer
structure stay exactly as they are. It diagnoses three faults that repeat on
every screen — a flat visual hierarchy, density with no breathing room, and no
designed empty/loading states — and traces all three to one root cause: the app
had a real colour system but **no spacing scale and no typographic ranking**, so
every screen invented its own numbers.

### What was actually wrong

Measured before touching anything: nine different `fontSize:` values were in
active use (21, 19, 15, 14.5, 13.5, 12.5, 11.5, 10.5, 9.5), several of them one
step apart *inside the same card*. Nine sizes that close is not a hierarchy —
it is nine ways of saying "normal", and the eye cannot rank them. Gaps were
equally ad hoc (14, 13, 11, 9, 7…), so a gap between two sections and a gap
between two list items were frequently the same size, which is what makes a
page read as one undifferentiated block.

### The changes, by section of the brief

**§1–§2 Foundation.** `AppSpacing` (4px scale + semantic aliases —
`cardPadding`, `sectionGap`, `itemGap`, `screenMargin`) and `AppTypographyX`
(four levels: `screenTitle` / `cardTitle` / `bodyPrimary` / `bodySecondary`,
plus `price` and `labelStrong`, which are *weight variants of `cardTitle`*, not
a fifth and sixth size). `bodySmall`'s dim colour moved into `AppTheme` so
`bodySecondary` carries it without every call site restating it. The shared
widgets (`AppCard`, `SandCard`, `SandHeader`, `SectionHeader`,
`SandSectionHeader`, `SandStatusPill`) now read from both, so a large part of
the app inherited the scale without being edited.

**§2 price rule.** On every services surface the price now outranks the service
name (`context.text.price`, w800). The name is the same on every card in a
list; the price is what the customer is comparing.

**§3 Instant state legibility.** `UrgencyCard` / `UrgencyLabel` /
`UrgencyStyle` in `core/widgets/status_indicator.dart` — a coloured leading
edge, a background tint, *and* an icon for overdue. Three signals rather than
one, so it survives a colour-blind reader and a 200ms glance alike. Applied to
maintenance `DueItem`s (the case the brief names: "overdue" and "1,500 km left"
were the same white card), both operator queues, the bookings list, and the
tracking screen's escrow card.

**§4 Escrow timeline.** `core/widgets/escrow_timeline.dart` — a reusable
four-station rail (`held → in progress → proof → released`) in `full` and
`compact` sizes, with connectors that fill progressively and a pulsing ring on
the current station. The ten `EscrowState` values map onto the four stations
via a new `EscrowStationX` extension. **A dispute is not a fifth station**: it
is not further along than "proof submitted", it is sideways from it, so it
renders as a branch below the rail in the danger colour — as do cancelled and
refunded, which never entered the rail at all.

**§5 Operator panels.** Both panels split into a pinned metrics strip
(`MetricTile` — quiet, inert, reading material) and scrollable queues below a
divider. The workshop panel now splits its queue by *who the transition table
says can act*, so "waiting on you" is a real query rather than a label. Queue
urgency comes from `QueueSla` against a new `ServiceRequest.inCurrentStateSince`
read from the escrow audit trail — a card goes red because a transition really
has not happened, never because of an invented clock. Rows the operator only
watches stay neutral: colouring a delay someone cannot act on trains them to
ignore the colour.

**§6 Empty and loading states.** `core/widgets/empty_state.dart` (`EmptyState`,
`ListSkeleton`, `MetricSkeleton`, `MetricTile`), applied to the maintenance
garage and history, bookings, both operator panels, offers, services search,
shop orders, cart and notifications. Messages follow the brief's rule —
positive and directed, not neutral: "No open jobs right now — a quiet moment,
well earned", not "No data".

**§7 One icon set.** The brief asks for Lucide throughout. Four screens mixed
the two sets outright; the rest of the app was uniformly Material *per file*
while sitting under a Lucide bottom nav, which is the same violation one level
up. All of it is now Lucide — **including the data layer**, where the service
categories, powertrains, shop products, notifications and vehicle types carried
Material `IconData`. `IconCodec` moved with them: the values are Lucide, the
**wire keys are unchanged**, so no stored record breaks.

**§8 One primary action.** `OutlinedButton`'s theme is lighter than
`FilledButton`'s now (border in `ak.border`, w600 not w700). The escrow action
bar derives one filled button (the forward move) with destructive transitions
demoted to danger-coloured text buttons — accepting and rejecting a job were
two identical buttons on an irreversible action. Same treatment on the approval
screen ("I have an issue") and the tracking screen (chat drops to outlined when
"Review completed work" is present).

### Two real bugs found on the way

1. **`EscrowTimeline` crashed on dispose.** `late final AnimationController`
   is lazy, and three of four stations are never active — so `dispose()`
   reading it *constructed* it on an already-deactivated element
   ("Looking up a deactivated widget's ancestor is unsafe"). Now built eagerly
   in `initState`. Caught by `tracking_back_test.dart` and
   `operator_panels_test.dart`.
2. **Escrow-machine notifications had no `IconCodec` key** (`request_quote`,
   `gavel`, `undo`, `hourglass`, `lock`, `star`, `build_circle`), so any that
   went through JSON came back as the fallback circle. Registered, with a new
   test asserting every key survives a decode→encode round trip — without it,
   two keys sharing an icon silently makes one un-encodable.

### Files
| File | Change |
|---|---|
| `lib/core/theme/app_spacing.dart` | **new** — 4px scale + semantic aliases |
| `lib/core/theme/app_typography.dart` | **new** — four-level `TextTheme` extension + `context.text` |
| `lib/core/widgets/status_indicator.dart` | **new** — `UrgencyLevel`, `UrgencyStyle`, `UrgencyCard`, `UrgencyLabel` |
| `lib/core/widgets/escrow_timeline.dart` | **new** — `EscrowTimeline`, `EscrowStation`, `EscrowStationX` |
| `lib/core/widgets/empty_state.dart` | **new** — `EmptyState`, `ListSkeleton`, `MetricSkeleton`, `MetricTile` |
| `lib/features/operations/queue_urgency.dart` | **new** — `QueueSla`, shared by both operator panels |
| `lib/core/theme/app_theme.dart` | `bodySmall` colour, `screenTitle` app-bar title, lighter `OutlinedButton` |
| `lib/core/widgets/widgets.dart`, `sand_widgets.dart` | token-driven padding/type |
| `lib/core/json/icon_codec.dart` | values → Lucide (keys unchanged); 7 escrow notification keys added |
| `lib/features/services/tracking_screen.dart` | `_EscrowCard` (timeline + amount + deadline) replaces the flat banner; `_DeadlineNote` folded in; theme-aware step rail |
| `lib/features/services/requests_screen.dart` | urgency cards, compact timeline, price weight, `EmptyState` |
| `lib/features/services/services_screen.dart` | price outranks name; `EmptyState`; icons |
| `lib/features/services/approval_screen.dart` | "I have an issue" demoted to a text button |
| `lib/features/operations/workshop_screen.dart` | metrics strip + "waiting on you" / "waiting on others" queues |
| `lib/features/operations/admin_screen.dart` | metrics strip + separated queues, urgency, compact timelines |
| `lib/features/operations/escrow_action_bar.dart` | one filled forward action, destructive → text button |
| `lib/features/garage/maintenance_screen.dart` | `UrgencyCard` per due item, `EmptyState`, tokens |
| `lib/features/home/home_screen.dart` | tokens on the page chrome |
| `lib/data/models/service_request.dart` | `inCurrentStateSince`, `stalledFor` |
| `lib/data/**`, `lib/features/**` (30 files) | Material → Lucide icon migration |
| `lib/features/shop/{orders,cart}_screen.dart`, `lib/features/home/notifications_screen.dart` | `EmptyState` |

### Verified
- `flutter analyze lib test` — clean apart from one pre-existing `info` in
  `lib/core/utils/contact.dart:23` that predates this work.
- `flutter test` — **396/396 pass.** Eight tests were updated, all of them
  assertions on copy this pass deliberately rewrote (§6 empty-state messages,
  "Currently held in escrow" → "Held in escrow") or `find.byIcon` finders
  pointing at now-migrated Material icons. One test was **added**
  (`models_json_test.dart`: every `IconCodec` key round-trips).
- `flutter build web --release` — succeeded (`√ Built build\web`, 56.5s).
  Note on the tree-shake output: `MaterialIcons-Regular.otf` is **still
  shipped**, shrunk 99.5% to 7,736 bytes. That is not a leftover from this
  pass — it is the Material *framework* referencing its own glyphs internally
  (dropdown arrows, date-picker chrome, dialog affordances), which no amount of
  app-level migration removes while the app is built on Material widgets. Every
  icon *this codebase* names is Lucide; `grep` for a non-Lucide `Icons.` across
  `lib/` returns nothing.
- **Not verified:** no on-device or emulator screenshot pass. Layout was
  checked only through the widget tests, which do fail on overflow (one such
  overflow *was* caught and fixed: the escrow card's title row against a long
  state name). Dark mode was not re-reviewed visually, though the pass removed
  a number of hard-coded light `AppColors` literals from the tracking and
  operator screens, which should improve it rather than regress it.

### Left alone deliberately
- The category grid's icon *choices* were mapped one-for-one to their nearest
  Lucide equivalent. A few are approximations (`rv_hookup` → `siren` for
  roadside, `local_car_wash` → `sparkles` for detailing) and are worth a
  designer's eye before launch.
- `AppColors` (the legacy static light tokens) still exists and is still used by
  several detail screens. Replacing it with `AkColors.of(context)` everywhere is
  the dark-mode migration already tracked in memory, not this pass.

---

## 2026-07-31 · The booking details page had no way out

**Baseline:** `819d58c` (working tree)
**Request:** "when enter to the order details page, there no back button."

### The bug

`/track/:id` is reached two ways, and only one of them leaves a stack behind:

- the bookings list and the founder's panel `push` it — back button appears,
  everything fine;
- finishing a booking, sending a part request, accepting a quote and approving
  a job all `go` to it.

`go` **replaces** the stack, which is deliberate and correct — "back" must not
return the user to a form they have already submitted. But `AppBar` only draws
a back button when `canPop()` is true, and `/track/:id` sits *outside* the tab
shell, so it has no bottom navigation either. The result: a customer who had
just paid for something landed on a page with no back button, no tabs, and no
way out of it at all. Android's system back gesture was the only escape, and
iOS had none.

It reproduced on the most important path in the app — the one right after
payment — which is why it was worth fixing before anything else.

### The fix

`_TrackingExit` on both of the screen's `AppBar`s (the loaded one and the
"request not found" one). It pops when there is something to pop, and
otherwise `go`es to `/bookings` — where the booking now lives, and the same
place the user would have opened it from. So the exit is explicit rather than
inherited from whether a stack happens to exist.

Deliberately fixed on the screen rather than by changing the four callers to
`push`: they use `go` for a reason, and a fix that depends on every future
caller remembering to do the same thing is not a fix.

### Files
| File | Change |
|---|---|
| `lib/features/services/tracking_screen.dart` | `_TrackingExit` as `leading` on both app bars; imports `sand_widgets.dart` |
| `test/tracking_back_test.dart` | **new** — both entry paths |

### Verified
- `flutter test` — **395 passed** (393 before, 2 new).
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements` in `lib/core/utils/contact.dart:23`) is pre-existing.
- The new test pumps against a two-route router, not the app's own: the real
  router opens on an animated splash that `pumpAndSettle` can never settle.
- **Not** run on a device.

### Known-adjacent, left alone
- `/approve/:id`, `/quote/:id` and `/review/:id` are all reached by `push`
  today (from the bookings list, the tracking screen, and notifications), so
  none of them can strand the user the same way. They would if a future caller
  used `go` — the same `_TrackingExit` pattern is what they'd need, and it is
  worth promoting to a shared widget at that point rather than now.

---

## 2026-07-29 · Completion proof now needs actual evidence

**Baseline:** `819d58c` (working tree)
**Request:** apply `MobileApp-Design/AK_Cars_تعليمات_إصلاح_الكود.md` — the
code-review handoff — and check everything still works.

### What the review actually found

The document was written against `main` and lists ten sections. Eight of them
were already implemented by the two commits since (`a854c2a`, `819d58c`), in
several places more strictly than asked: the transition table is keyed by
*event and actor* rather than a bare `from → to` set, so "only the founder may
move money" falls out of the table instead of needing the separate
`founderOnly` set the document sketches; and the 72-hour release has a
cold-start sweep the document does not ask for, because a `Timer` does not
survive the process.

Two things were genuinely outstanding, and one of them was load-bearing.

### The gap: proof without evidence

Spec §3 gives `proofSubmitted` two entry rules. Only one was enforced:

```dart
bool proofSatisfiesRules(ProofOfWork? candidate) {
  if (type != BookingType.customQuote) return true;      // ← catalogue: anything
  return (candidate ?? proof)?.includesPartBoxPhoto ?? false;
}
```

The `media.isEmpty` rule was missing entirely, so a catalogue booking could
reach "awaiting your approval" — and then auto-release 72 hours later — on the
strength of a text box reading *"All done, trust me."* That is the one thing an
escrow exists to prevent.

It was missing for a reason rather than by oversight: **nothing in the app
could create a `ProofMedia`.** `image_picker` was not a dependency, and the
workshop's proof sheet collected notes and a checkbox. Enforcing the rule
without building capture first would not have tightened the escrow, it would
have made proof submission impossible and wedged every booking at `inProgress`.
So the two halves had to land together, and the user chose to build capture
rather than record the deviation.

### The fix

`ProofUploadSheet` (`features/services/`, where §3 asks for it) composes a
proof: camera or gallery, a horizontal strip of removable thumbnails, notes,
and the part-box declaration on `customQuote` jobs only. Submit stays disabled
until the rules pass and says *which* rule is unmet — a form that lets you fill
everything in and then fails silently at the state machine is worse than one
that tells you up front. `proofSatisfiesRules` now enforces both rules for both
booking types.

Two consequences worth recording:

- **The staging simulator stops at the proof for every booking type**, not just
  `customQuote` as before. It used to submit an empty proof to keep the demo
  moving; under rule 1 the only way for it to keep moving would be to
  manufacture photographs of a car it has never seen. It stops instead, and the
  workshop panel finishes the job by hand.
- **Photos are device-local.** `image_picker` returns a file path (a `blob:`
  URL on web) and there is no upload step yet, so proof media does not survive
  a reinstall and cannot be seen from another device. Rendering it needed
  `core/media/local_image.dart` — a conditional import, because `Image.file`
  needs `dart:io` and the web build has none. This is the next real gap;
  `ARCHITECTURE.md` §7 now says so instead of claiming there is no capture.

### Files
| File | Change |
|---|---|
| `lib/features/services/proof_upload_sheet.dart` | **new** — the compose sheet, rules enforced in the UI |
| `lib/core/media/local_image.dart` + `_io` + `_web` | **new** — conditional-import shim for device-local media |
| `lib/data/models/service_request.dart` | `proofSatisfiesRules` enforces the media rule for every type |
| `lib/state/requests_state.dart` | simulator refuses `submitProof` outright; `_placeholderlessProof` deleted |
| `lib/features/operations/workshop_screen.dart` | opens the new sheet; the notes-only `_ProofSheet` deleted |
| `lib/features/services/approval_screen.dart` | proof tiles render local files, not just https |
| `android/.../AndroidManifest.xml`, `ios/Runner/Info.plist` | `CAMERA`; bilingual iOS usage strings |
| `pubspec.yaml` | `image_picker`; `image_picker_platform_interface` (dev, for the stub) |
| `test/helpers/test_harness.dart` | **`testProof`** — one shared rule-satisfying fixture |
| `test/proof_upload_test.dart` | **new** — the sheet's four rule cases |
| `test/escrow_test.dart` | media-less proof is a no-op; the simulator stops |
| `test/{operator_panels,part_install,maintenance_book,reviews}_test.dart` | fixtures now carry media |
| `ARCHITECTURE.md` | §7 and "the two rules the transition table cannot express" |

### Verified
- `flutter test` — **393 passed** (387 before, 6 new).
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements` in `lib/core/utils/contact.dart:23`) is pre-existing.
- `flutter build web` — succeeds, which is what proves the conditional import
  keeps `dart:io` out of the web bundle.
- `flutter build apk --debug` — succeeds with the plugin and the new permission.
- **Not** run on a device or emulator: the camera path is covered by a stubbed
  `ImagePickerPlatform`, so no real permission dialog, no real capture, and no
  check of how a large photo behaves. That needs a physical device.

### Deviations from the document, deliberate
- **§5 asks for four tabs; the app has five.** The extra one is *طلباتي*,
  added by `819d58c`, and it tracks the escrow bookings that are the whole
  point of phase 1. Cutting it would move the core flow's primary entry point.
  Kept on the user's decision.
- **§2 asks for `autoReleaseHours` in `app_constants.dart`.** It already exists
  as `AppConfig.approvalWindow` (72h), which is per-environment and overridable
  where a `const` would not be. Left where it is.

### Known-adjacent, left alone
- **§9's vehicle-model duplication is real.** `GalleryListing` re-declares
  `make`/`model`/`trim`/`year`/`exteriorColor` as its own fields rather than
  holding a `Car`, so a listing and a garage record can disagree about the same
  vehicle. `CarListing` is a separate flat projection for the home rail with
  its own `title`/`year`/`km`. §9 itself says to document and defer this while
  the cars marketplace is behind `AppFlags.carMarketplaceEnabled = false` —
  restructuring a hidden pillar is time spent on unreachable code. Recorded
  here so it is not rediscovered from scratch when phase 2 turns it on.
- No upload/object storage for proof media (above). Until that exists, proof
  is only as durable as the device that captured it.

---

## 2026-07-29 · Registering a car did not survive a cold start

**Baseline:** `819d58c`
**Request:** "check the car register section which now not save any car details
when register cars."

### The bug
The car form was fine. `MockGarageService` was not: it kept the saved cars in a
plain `List<Car>` field, so the garage existed for exactly as long as the
process that created it. Register a Camry, close the app, come back — empty
garage, no error, nothing to explain it.

What made it read as "Save does nothing" rather than "the app forgot":
`prefsStartChoiceMade` and the registered profile *do* persist (`MockAuthService`
writes them to SharedPreferences), so the next launch skipped the "add your
car?" question and dropped the user on a home page with no car on it.

`MockMaintenanceService` had the same shape, and it matters for the same flow:
registering a car opens its maintenance book and files the mileage typed on the
form into it. Persisting cars alone would have restored a car whose service
history and odometer reading had silently reset.

Bootstrap already warmed `garageRepositoryProvider`, and `GarageNotifier.build()`
already hydrated from it — the read path was correct all along. There was simply
never anything on the device to read.

### The fix
`PrefsCollection<T>` — one small JSON-list store on SharedPreferences, the same
mechanism `MockAuthService` already used for the profile, generalised. Both mock
services seed from it on construction and write through a single `_persist` /
`_store` funnel, so no mutation can reach memory without reaching the device.
A record an older build wrote in an unreadable shape is dropped, not thrown:
stale storage must not wedge the launch.

Reference data (makes, parts, providers) deliberately stays un-persisted — it
comes from the server every launch and would only go stale locally.

### Files
| File | Change |
|---|---|
| `lib/data/services/prefs_collection.dart` | **new** — JSON-list store on SharedPreferences, tolerant of stale rows |
| `lib/data/services/garage_service.dart` | `MockGarageService` seeds from and writes to the store |
| `lib/data/services/maintenance_service.dart` | same for the maintenance books |
| `lib/core/constants/app_constants.dart` | `prefsGarage`, `prefsMaintenance` keys |
| `lib/di/providers.dart` | both services now take `prefs`, as auth already did |
| `test/helpers/test_harness.dart` | `createDataContainer` overrides prefs too (services below it now read storage) |
| `test/garage_persistence_test.dart` | **new** — cold-start coverage |
| `ARCHITECTURE.md` | §"Session-scoped stores" corrected — it still claimed auth was in-memory |

### Verified
- `flutter test` — 393 passed (387 before, 6 new).
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements` in `lib/core/utils/contact.dart:23`) is pre-existing.
- New tests cover: every field entered on the form coming back after a restart,
  the registration mileage reaching both the car and its maintenance book, an
  edit and a deletion surviving, a fresh install starting empty, and corrupt
  storage not wedging the launch.
- **Not** run on a device or emulator — no confirmation against real
  SharedPreferences, only the in-memory mock the plugin provides to tests.

### Known-adjacent, left alone
- `MockOrderService` and `MockServiceMarketplaceService` are still in-memory, so
  order history and open service requests still vanish on restart. Same fix
  applies (`PrefsCollection`) but it is a separate report — escrow state in
  particular needs a decision about what a restored in-flight booking means.

---

## 2026-07-29 · Home page rebuilt around booking, and offers put under governance

**Baseline:** `a854c2a` (working tree)
**Request:** apply `MobileApp-Design/AK_Cars_تعليمات_الصفحة_الرئيسية.md` — the
home-page handoff — and check that the data shown is the same in every part of
the app.

### The idea the document is arguing for

The home page is not a display case, it is a starting point for a booking, and
its order should carry a sequence: **حاجة → فرصة → طمأنة**. Three sections, in
that order, and one prohibition running through all of them — *كل ما يظهر
مكتسَب بالجدارة، لا مشترى*: everything on the page is earned, nothing is bought.

The previous page had the right honesty rules but the wrong shape: offers came
first, the user's own cars second, and the car cards were informative but not
actionable — a countdown with no way to act on it from where it was read.

### What changed

**1. The running order, and section 1 (§1).** The page now opens with *حالة
سيارتي*: each registered car with the countdown closest to running out and a
button that starts the booking. Three states, as the spec lists them — overdue
renders *متأخّر — احجز الآن* in the alert colour; no record asks *متى غيّرت
[الخدمة] آخر مرة؟* and opens the record sheet, naming the service rather than
asking about "service history" in the abstract; no car at all is the single
"register your car" card. Both buttons route through a new shared
`bookMaintenanceItem`, which the My Car page now also calls — two copies of that
routing would eventually drift, and the drift would silently stop a completed
booking from writing its record.

`سياراتي` as a separate browse section is gone, per the spec's closing note; the
garage lives on the My Car tab.

**2. Offers are now a governed entity, not a banner (§3).** New `Offer` model,
distinct from the existing `Promotion`:

- `referencePrice` is validated against the price the platform *publishes* for
  that offering. A workshop cannot type a "was" price and manufacture a
  discount — the mock data carries one that tries (45 struck through on a
  service published at 32) and it is rejected.
- All six rules run on every read, in one method (`_reject`), not at fetch time:
  approved workshop, listed service, that workshop's service, real reduction,
  founder-enabled, in-window. `OfferRejection` names which rule failed.
- The card shows the four things the spec requires and has all four for real:
  the percentage (computed from the two prices, so it cannot disagree with
  them), the struck-through reference, the new price, and the deadline.
- No live offer → the section does not render at all. This is why announcements
  were split out into their own rail (`homeAnnouncementsProvider`): if a
  price-less platform card counted as an offer, the offers section could never
  legitimately be empty, and the empty-state rule would be unenforceable. An
  announcement that points at a service already discounted is dropped, so the
  page never shows two cards with two prices for one job.

`ServiceProvider.isApproved` is new and gates *promotion only* — offers and the
home boards. It is not `verified` (a badge about the business) and it does not
hide anyone from the services list.

**3. Section 3, and the empty states it needs (§§4–5).** *ورش موثوقة* with two
merit-ranked boards: **الأعلى تقييماً** on ratings, and **الأكثر طلباً** on
bookings that reached `releasedToWorkshop` in the last 30 days — completed work,
not requests, because ranking on requests rewards being asked rather than
delivering. New `WorkshopDemand` aggregate for it, fetched like the others.

The empty states are the interesting part, and the reason the two boards share
one widget:

- no workshop has enough reviews → the section does **not** show an empty "top
  rated" board and does **not** lower the threshold; the heading changes to *ورش
  معتمدة قريبة منك*, nearest first, with no rank badges, because that is a claim
  the data supports;
- nothing completed yet → the "الأكثر طلباً" tab is not offered at all.

**4. Ranking config in one place (§4).** `config/home_ranking_config.dart`:
`minReviewsForRanking`, `popularWindowDays`, `maxCardsPerSection`,
`workshopBoardSize`. Nothing is stored; every board is computed on read.

**5. One price everywhere** — the "same data in all parts of the app" half of
the request. A discount that lived only on the home card would become a lie by
the confirmation screen. The catalogue is now split in two:

- `offerings` / `offeringById` stay **raw**. Offer validation reads them, and it
  has to: a discount that could validate against a discounted price would
  validate against itself. The struck-through price comes from here.
- `pricedOffering` / `pricedOfferings` / `offeringsFor` carry the **live
  discount**, and everything else reads those — the services list, the category
  sheets, search, the "from OMR x" labels, the suggestion rail, the service page
  and the booking screen. Because the booking screen resolves the priced
  offering, the total, the escrow amount and the maintenance record inherit the
  discount without any of them knowing offers exist.

**6. Founder control (§3).** The founder panel gained an offers section: every
offer, live or not, with the exact rule keeping it off the home page, and an
on/off switch. Enabling an offer that fails another rule leaves it hidden and
says so — approval is not an override. There is deliberately no price editing
and no "feature this" control anywhere in it.

### One bug found on the way

`NumberFormat('#,###')` and `toStringAsFixed(0)` round to whole rials. That was
harmless while every published price was an integer; a service discounted to
4.5 rendered as **5** — a wrong price on screens the customer books from. Money
now formats through `#,##0.##` (`omrAmount` / `_money`) on the home cards, the
services list, the category sheets and the offer rows. Distances, odometers and
counts still use the integer formatter, which is right for them.

### Deliberate deviation from the document

**`minReviewsForRanking` is 25, not the 3 the document gives.** The spec offers
3 as an illustration ("مثال ثابت = 3") and states the reason for having a
threshold at all: a perfect score from a handful of people must not top the
board. At 3, the demo data's 4.9-from-four-reviews workshop leads the national
leaderboard — the exact outcome the rule exists to prevent. The constant is one
line in `HomeRankingConfig` if the pilot wants it looser.

**Two supporting rails were kept below the three mandated sections** rather than
removed: *مقترح لسيارتك* (per-car suggestions from the owner's own mileage) and
*الأكثر حجزاً* (category demand). The spec fixes the order of its three
sections, which is honoured and asserted by position in a test; it does not
require deleting working, honest, per-car content, and the general handoff's
rule is *أخفِ، لا تحذف*. Say the word and either can be dropped in one line.

### Files

| File | Change |
|---|---|
| `lib/config/home_ranking_config.dart` | **new** — thresholds, windows, board size |
| `lib/data/models/offer.dart` | **new** — `Offer`, `OfferRejection` + reasons |
| `lib/data/models/service_provider.dart` | `isApproved` (json/copyWith/==) |
| `lib/data/models/service_stats.dart` | **new** `WorkshopDemand` |
| `lib/data/services/service_marketplace_service.dart` | `fetchOffers`, `fetchWorkshopDemand`, `setOfferActive` |
| `lib/data/repositories/service_marketplace_repository.dart` | `_reject` (the six rules), `liveOffers`, `offerFor`, `auditOffers`, `setOfferActive`, `pricedOffering(s)`, offer-aware `offeringsFor`/`cheapestOfferingFor`/`fromPriceFor`, `mostRequestedWorkshops`, `approvedWorkshops`, approval gate on `topRatedWorkshops` |
| `lib/data/datasources/mock/mock_service_data.dart` | `isApproved` per workshop, `offers` (5 valid + 4 invalid, one per failure mode), `workshopDemand` |
| `lib/state/offers_state.dart` | **new** — audit list, revision counter, founder switch |
| `lib/state/home_state.dart` | `homeOffersProvider`, `homeAnnouncementsProvider`, `mostRequestedWorkshopsProvider`, `approvedWorkshopsProvider`, `nextServiceDueProvider` |
| `lib/features/home/home_screen.dart` | new section order + `_CarStatusSection` |
| `lib/features/home/home_widgets.dart` | `_DiscountCard`, `HomeAnnouncementsRail`, `HomeTrustedWorkshopsSection` (+ tabs, shared workshop row, three trailings), booking CTA in `_DueStrip`; `HomeTopRatedSection` replaced |
| `lib/features/garage/maintenance_screen.dart` | `bookMaintenanceItem` extracted and shared |
| `lib/features/services/service_detail_screen.dart` | priced offering + offer banner (was / now / ends) |
| `lib/features/services/service_widgets.dart` | `omrAmount`, struck-through reference on offer rows |
| `lib/features/services/services_screen.dart`, `lib/state/search_state.dart` | read `pricedOfferings` |
| `lib/features/services/booking_screen.dart` | books the priced offering |
| `lib/features/operations/admin_screen.dart` | offers governance section |
| `lib/core/i18n/strings.dart`, `lib/core/constants/api_endpoints.dart` | new strings, two endpoints |
| `test/home_offers_test.dart` | **new** — 19 tests: the six rules, each failure mode, price consistency across every surface, founder toggle, board ranking and empty states |
| `test/screens_smoke_test.dart` | section order by position, offer card contents, overdue state, no-record copy |
| `test/home_test.dart`, `test/services_region_test.dart` | updated to the discounted "from" price |

### Verified

- `flutter test` — **381 passed** (was 350; +19 new offer/board tests, +3 new
  home widget tests, the rest unchanged).
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements` in `lib/core/utils/contact.dart:23`) is pre-existing
  and unrelated.
- **Not** run on a device or emulator. No visual confirmation of the new offer
  card, the workshop tabs, or the founder panel's offers section — the widget
  tests catch layout overflow (one was found and fixed in the car card's action
  row, which needed a `Wrap`), but not appearance.

### Known-adjacent, left alone

- `Promotion` and its mock rows were kept. They are honest announcements and the
  region/powertrain filtering on them is tested; they now render in their own
  rail rather than as "offers".
- Offers are read-only in the app apart from the founder's on/off switch:
  creating one is a back-office job, as the spec says for this phase.
- `MockServiceData.offers` is mutable static state, which the founder-toggle
  tests snapshot and restore. When the real endpoint lands, that goes away.

---

## 2026-07-28 · Part + fitting requests, and verified reviews

**Baseline:** `a854c2a` (working tree)
**Request:** apply `MobileApp-Design/AK_Cars_تعليمات_تعديل_الكود2.md` — the
second handoff. It asks for two new capabilities on the existing escrow core
("اطلب قطعة + تركيب" and موثّقة reviews), re-states the flags/navigation/data
model from the first round, and forbids a payment gateway, a parts catalogue,
supplier onboarding and a fitment database.

### What the round actually changed

Most of the document was already built by the 2026-07-27 refocus: the flags,
the escrow machine, its transition table, the operator panels, proof of work,
the customer approval screen, the 72-hour auto-release, the garage, and the
whole of maintenance follow-up (§7, including the linear odometer projection
and the booking → record feedback loop). Those were re-read against the spec
and left alone. Two sections were genuinely new — §6 and §8 — plus the two
flags that gate them.

**1. "اطلب قطعة + تركيب" (§6).** A second transaction type on the *same* escrow
machine, not a second machine:

- `EscrowState` gained `requested → quoted → quoteAccepted` ahead of
  `createdPendingPayment`, plus five events and six transition rows. Only a
  `BookingType.customQuote` booking passes through them; a catalogue booking is
  untouched.
- `Quote` has `partPrice` and `laborPrice` and **no total field** — `total` is a
  getter. The itemisation is structural: a workshop cannot submit a lump sum
  through this model, which is the point of moving the transaction off the
  phone.
- `Quote.warrantyDays` is recorded and displayed as the *workshop's* warranty on
  the part, explicitly distinguished from the payment escrow everywhere it
  appears — the two have opposite lifetimes (the escrow ends at approval; the
  part warranty starts there).
- A custom-quote job cannot reach `proofSubmitted` without
  `ProofOfWork.includesPartBoxPhoto`. Enforced in the model, the notifier and
  the mock service. It is a *declaration*, not a verification — the app cannot
  inspect a photo — so the workshop ticks it and the approval screen tells the
  customer whether it was ticked.
- One quote per request. The spec's optional competing-quotes variant was
  deferred, as it allows.

**2. Verified reviews (§8).** `ReviewRepository.submitFor(request, …)` is the
only constructor of a `Review` in the app, it takes a booking rather than a
workshop, and it refuses any booking short of `releasedToWorkshop`. That single
check *is* the verification: no badge, no moderation queue, no bot detection,
and none of them missing. `(bookingId, direction)` is unique, the review is an
event rather than an escrow state (nothing is held back waiting for one), both
directions unlock on the same release, and the workshop rating is derived by
`providerRatingProvider` — **null**, not zero, for a workshop nobody has rated.
`MockReviewService` ships empty on purpose.

### What was deliberately not done

- **The bottom bar still has five tabs, not four.** §3 asks for
  `الخدمات • حجوزاتي • سيارتي • حسابي`; the shipped bar is those four plus
  `/home`, which was rebuilt and re-enabled *yesterday* at the user's request
  (see the entry below) and is pinned by `test/focus_flags_test.dart`. Removing
  it would undo that work on the strength of a section carried over unchanged
  from the first handoff. Flip `AppFlags.homeTabEnabled` to `false` if the four
  tabs are meant literally.
- No payment gateway, no automated release engine, no parts catalogue, no
  inventory, no supplier onboarding, no fitment data, no shipping, no returns,
  no automated review moderation. All forbidden by §10, none present.
- The parts store and cars marketplace remain hidden behind their flags with
  every file intact.

### Files

| File | Change |
|---|---|
| `lib/config/app_flags.dart` | **+2 flags** — `requestPartInstall`, `verifiedReviews` |
| `lib/data/models/quote.dart` | **new** — `BookingType`, `PartRequest`, `Quote`, `CreatePartRequestDraft` |
| `lib/data/models/review.dart` | **new** — `Review`, `ReviewDirection`, list helpers |
| `lib/data/models/escrow.dart` | quote-phase states/events/transitions, `isQuotePhase`, labels, step indices |
| `lib/data/models/service_request.dart` | `type`, `partRequest`, `quote`, `ServiceRequest.partInstall`, quote-aware `apply`, `proofSatisfiesRules` |
| `lib/data/models/service_offering.dart` | `ServiceOffering.partInstall` synthetic quote-only offering |
| `lib/data/models/proof_of_work.dart` | `includesPartBoxPhoto` |
| `lib/data/services/review_service.dart` | **new** — with the one-per-booking and 1–5 guards |
| `lib/data/repositories/review_repository.dart` | **new** — owns the released-booking rule |
| `lib/data/services/service_marketplace_service.dart` | `createPartRequest`, `submitQuote`, part-box guard on `submitProof` |
| `lib/data/repositories/service_marketplace_repository.dart` | same, plus provider resolution |
| `lib/data/repositories/notification_repository.dart` | part-request sent, quote received, review unlocked |
| `lib/state/reviews_state.dart` | **new** — `reviewsProvider`, pending-review queues, derived `providerRatingProvider` |
| `lib/state/requests_state.dart` | `placePartRequest`, `submitQuote`, the two new automatic hand-offs, review unlock |
| `lib/features/services/part_request_screen.dart` | **new** |
| `lib/features/services/quote_screen.dart` | **new** |
| `lib/features/services/review_screen.dart` | **new** |
| `lib/features/services/review_widgets.dart` | **new** — stars, derived-rating line, review list |
| `lib/features/operations/workshop_screen.dart` | quote sheet, part brief, part-box checkbox, "rate the customer" |
| `lib/features/operations/escrow_action_bar.dart` | `onSubmitQuote` payload hook |
| `lib/features/services/requests_screen.dart` | review prompts, quote badge/route, quote-phase subtitle |
| `lib/features/services/tracking_screen.dart` | quote card, quote-phase copy, empty-slot wording |
| `lib/features/services/approval_screen.dart` | part-box declaration + part warranty note |
| `lib/features/services/service_detail_screen.dart` | derived rating + verified-review section |
| `lib/features/services/services_screen.dart` | the part-request CTA |
| `lib/core/router/app_router.dart` | `/request-part`, `/quote/:id`, `/review/:id` |
| `lib/core/constants/api_endpoints.dart` | part-request, quote and review paths for phase 2 |
| `lib/di/providers.dart` | review service + repository bindings |
| `test/part_install_test.dart` | **new** — 11 tests |
| `test/reviews_test.dart` | **new** — 11 tests |
| `test/part_install_screens_test.dart` | **new** — 5 widget tests |
| `ARCHITECTURE.md` | §0 flag table, §9 rewritten for the quote phase, **new §12 and §13** |

### Verified

- `flutter test` — **359 passed** (was 332 before this round; the 27 new ones
  are the three files above).
- `flutter analyze lib test` — clean. The one remaining `info`
  (`use_null_aware_elements` in `lib/core/utils/contact.dart:23`) is
  pre-existing and unrelated.
- One regression was caught and fixed mid-round: the first cut of
  `proofSatisfiesRules` refused a proof-less `submitProof` on *catalogue*
  bookings too, breaking six escrow tests. The part-box rule now applies to
  custom quotes only, which is what §6 actually asks for.
- **Not** run on a device or emulator. No visual confirmation of the three new
  screens, the quote sheet, or the review prompt.

### Known-adjacent, left alone

- `MockServiceData.workshopRatings` are still fixtures, not measurements — real
  aggregate counts arrive with the API. Local reviews are folded on top of them
  by `providerRatingProvider`; a workshop with a fixture rating and no local
  reviews shows the score and no quotes, rather than invented ones.
- Reviews live only in memory for the session. Persisting them locally would be
  the wrong fix — they belong to the account, not the device — so they wait for
  the backend.
- Photo attachment on proof of work is still unavailable in this build (no
  camera/file plugin), which is why the part-box rule is a declaration. When a
  picker lands, the checkbox should become "at least one photo tagged as the
  part's box".

---

## 2026-07-28 · A new home page: the user's cars first, then the marketplace

**Baseline:** `a854c2a` (working tree)
**Request:** "Add a home main page. In this page you should hook users by what
they view on. First, a card containing the registered car with an image of the
car model, and under the image add important info from the car details. If there
is another registered car show the cards as a list. Above the cards, add a
section as a horizontal cards list for advertisements (workshop offers…). Under
the cars list add recommendations related to registered cars, changing each time
you open the app. Under that, add most ordered services and most workshops
rated. Make this page modern and with animations."

### What shipped

`AppFlags.homeTabEnabled` is `true` again (it went off in the 2026-07-27
refocus), so `/home` is the first tab and the cold-start destination.
`HomeScreen` was rewritten; the sections live in
`lib/features/home/home_widgets.dart`, one `ConsumerWidget` per section reading
one provider from the new `lib/state/home_state.dart`:

1. **Offers & announcements** — a snapping `PageView` rail with page dots, fed by
   the new `Promotion` model: workshop campaigns plus two platform cards.
2. **My cars** — a vertical list, one card per registered car: the car's picture,
   the details its owner entered as chips (mileage, plate, governorate, trim,
   powertrain badge), and its most urgent maintenance countdown. A list rather
   than a rail because the details under the picture are the point of the card.
3. **Suggested for your car** — a horizontal rail from the new
   `buildRecommendations`, reshuffled each app launch.
4. **Most booked** — the marketplace's own booking counts, over a stated window.
5. **Top-rated workshops** — real ratings, with the review count behind each.

Animations: one staggered `Entrance` down the page (the delay counter is threaded
through the section list rather than hard-coded, so a hidden section leaves no gap
in the sequence), a new `SandPressable` scale-on-tap for the large cards, an
`animate:` option on `SandProgressBar` for the single headline countdown, scaled
neighbours and an animated active dot on the offers rail.

### The data, and why it is shaped this way

Three things the page needs did not exist: promoted offers, per-category booking
counts, and workshop ratings. All three are now modelled as what they are —
**server-side aggregates fetched over the service layer** — rather than derived on
the phone:

- `Promotion` (`models/promotion.dart`), `CategoryDemand` and `WorkshopRating`
  (`models/service_stats.dart`), with the usual `fromJson`/`toJson`/`copyWith`
  and round-trip coverage in `models_json_test.dart`.
- Three service methods, three warm caches, three `ApiEndpoints` constants; the
  demo values are in `MockServiceData`.
- `buildRecommendations` (`models/recommendation.dart`) — a pure function, the
  same shape as `calculateRequestTotal`.

"Most booked" **cannot** be computed here: it is a fact about every customer's
bookings and this app can only see the signed-in user's. Deriving it from
something the client *can* reach (how many workshops sell a category, say) would
be a different fact wearing the label — the same mistake the web app's
`CATEGORY_META` keyword-guessed pricing makes. Same for ratings.

Rules that came out of building it, all in §11 of `ARCHITECTURE.md`:

- A rating needs **25 reviews** to be ranked. The demo data carries a 4.9 on four
  reviews precisely to exercise that, and two workshops with no rating at all, so
  the absent case is real rather than a defaulted zero.
- An offer card is dropped if it has expired, does not run in the user's
  governorate, points at an offering the catalogue no longer has, or sells work
  the user's car cannot use.
- Every price shown is the price of the offering the card opens.
- The rail's per-launch shuffle happens **inside a reason band**, never across
  one, so an overdue oil change cannot be demoted by a dice roll. The seed is
  drawn once per process (`sessionSeedProvider`), not inside `build` — otherwise
  the rail would reshuffle on every scroll and no test could assert anything.
- One suggestion per schedule line, cheapest of them: Major, Full and Express
  service all reset engine oil.

### Two things worth flagging

**A predicate that nearly caused a real bug.** The first cut of the
"is this work relevant to this car" filter used `MaintenanceTypeX.appliesTo`.
That predicate answers a *different* question — whether an item is tracked as its
own schedule line — and returns false for a petrol car's cabin filter, because
there it is checked inside the oil service. Used as a relevance filter it silently
removed **AC care** (one of the most booked jobs in Oman) and battery work from
every petrol owner's page. Caught by a Dhofar promotion disappearing in
`home_test.dart`. Replaced with `categoryServes`, which applies exactly two rules:
the category's own powertrain restriction, and no oil package for a car with no
engine. All three marketplace-facing sections share it.

**The EV honesty rule now covers ads too.** The old page's EV work stopped at the
seasonal banner. On the new page an electric car's home page has no engine-oil
content anywhere — not in the suggestions, not in the most-booked list (where an
oil change is the country's single most booked job), and not in the offers rail,
where a workshop's paid campaign would otherwise have carried it.

### Also changed

- `strings.dart`: the home section titles plus `days`, `months`, `reviews` and
  `bookings` — Arabic-correct counted nouns, like `workshops`/`services`.
- The old page's EV shortcut rail and seasonal promo banner are **gone**, not
  moved: the suggestion rail is driven by the same powertrain data and adds real
  prices, workshop counts and per-item reasons, so keeping both would have been
  the duplicate-section problem the web app's `/services` page had.
- `screens_smoke_test.dart`'s `pumpScreen` takes `garage:` and `height:`. The
  height matters: a `ListView` does not build an off-screen child, so a section
  below the fold cannot be found by a finder at all.

### Verified

```
flutter analyze lib test   # 1 pre-existing info (core/utils/contact.dart)
flutter test               # 332 passing (311 before; +18 home_test,
                           #   +2 models_json_test, +1 screens_smoke_test)
flutter build web          # succeeds, MaterialIcons still tree-shaken 98.2%
```

`home_test.dart` is new and covers the four sections' rules directly.
`screens_smoke_test.dart` renders the page in AR/EN, light/dark, with and without
a car — any overflow fails those. `ev_test.dart`'s home group was rewritten
against the new page. `focus_flags_test.dart` now pins five tabs.

**Not verified:** nothing was run on a device or emulator, so the animation
timings are as written rather than as felt. The offers rail's `PageView` was
exercised by the widget tests but never actually swiped by a human.

---

## 2026-07-28 · Maintenance became per car: one book per registered vehicle

**Baseline:** `a854c2a` (working tree)
**Request:** "Redesign the My Car maintenance experience so every registered car
owns its own maintenance schedule… track the full maintenance history of each
car in one place, manually enter previous maintenance information, update it
later, or let the app update it automatically when a booked service is
completed."

### What was wrong

Maintenance was app-level, not car-level, and it was seeded.
`MockMaintenanceService` started life holding `MockGarageData.maintenanceLog()`
— an oil change at 123,000 km and an alignment at 119,400 km, on an odometer
reading of 128,450. Three consequences, all of them visible on a first run:

1. A user who had just registered their first car was shown two services that
   car had never had, at a mileage that was not theirs.
2. A second car showed the first car's countdowns, because there was only one
   log for the whole app.
3. Mileage had two owners. `Car.odometerKm` and the log's `currentOdometerKm`
   were written separately, and the log's belonged to whichever car happened
   to be default at the time — `showMileageSheet(syncMaintenanceLog: isPrimary)`
   updated the log only when the car being edited was the default one, so
   updating the second car's mileage left the maintenance page showing the
   first car's number.

There was also no way to enter real history. The only manual action was "Add a
manual record", which filed a record dated *today* at *today's* odometer — the
one thing a first-time user does not want, because their last oil change was
four months and 4,000 km ago.

### What changed

**`MaintenanceLog` → `MaintenanceBook`, keyed by `carId`.** The repository holds
a `Map<carId, book>`; `MaintenanceService` is reshaped as
`/user/vehicles/{carId}/maintenance` and its nested record / item / odometer /
interval resources. Nothing is seeded — a new book is empty, with the correct
default items for its powertrain and no history it did not have.

**The garage owns the lifecycle.** `GarageNotifier.add`/`restore` open a book,
`remove` closes it, and `setOdometer` is now the single entry point for
mileage: it writes the car *and* its book. The dependency runs one way
(garage → maintenance) so the two notifiers cannot form a Riverpod cycle, and
so a garage edit cannot invalidate a maintenance write already in flight — the
first attempt derived `MaintenanceNotifier.build()` from `garageProvider` and
tripped `!_didChangeDependency` on the very next write.

**A real first-run state.** A book with no records is `isFresh`: the page shows
a setup banner instead of the "where these numbers come from" notice, every
item reads "No record yet", and the manual-entry sheet asks for what the owner
actually knows — last service date, odometer at that service, workshop, notes,
and the interval in km and/or months. Saving one record starts that item's
countdown from the truth.

**Custom items.** `CustomMaintenanceItem` belongs to one car. Its title is
stored as typed and rendered identically in both languages — the app does not
invent a translation of the owner's words. Deleting one deletes the records
filed under it.

**Bookings write records only when they are finished.** `ServiceRequest`
carries a `maintenanceItemKey` (set by `maintenanceBookingIntentProvider` when
the owner taps Book on a schedule line, otherwise mapped from the offering's
category by `MaintenanceTypeX.forCategory` and discarded if the car does not
have that item). `RequestsNotifier.fire` writes the record on
`EscrowState.releasedToWorkshop` and nowhere else: cancelled, rejected,
refunded and still-disputed bookings reset nothing. The record id is derived
from the booking id and the service upserts by id, so the approval timer and
`sweepExpiredApprovals` both arriving produces one row.

### Changed files

- `data/models/maintenance.dart` — `MaintenanceBook`, `CustomMaintenanceItem`,
  `MaintenanceItem`, `ServiceRecord.itemKey`/`notes`/`bookingId`,
  `MaintenanceTypeX.forCategory`, `DueItem.item`/`needsSetup`.
- `data/services/maintenance_service.dart`, `data/repositories/maintenance_repository.dart` — per-car, REST-shaped.
- `data/models/service_request.dart`, `data/services/service_marketplace_service.dart` — `maintenanceItemKey` on the request and the draft.
- `data/datasources/mock/mock_garage_data.dart` — demo maintenance log deleted.
- `state/maintenance_state.dart` — book map, per-car providers, `logCompletedBooking`, booking intent.
- `state/garage_state.dart`, `state/challenge_state.dart`, `state/requests_state.dart`.
- `features/garage/maintenance_screen.dart` — rewritten as a per-car dashboard.
- `features/garage/my_cars_screen.dart`, `features/garage/add_car_screen.dart`, `features/home/home_screen.dart`, `features/services/booking_screen.dart`.
- `ARCHITECTURE.md` §5 and §10.

### Verified

```
flutter analyze lib test   # 1 pre-existing info (core/utils/contact.dart)
flutter test               # 311 passing
```

New `test/maintenance_book_test.dart` (30 cases) covers book-per-car,
isolation between two cars, switching the default car, first manual record,
interval edits, custom item add/edit/delete + persistence, the completed
booking writing exactly one record on the right car and item, and every
non-completion ending writing nothing. `maintenance_projection_test.dart`,
`models_json_test.dart` (round trip incl. the legacy `type` wire name),
`providers_test.dart`, `ev_test.dart`, `garage_test.dart`, `bootstrap_test.dart`
and `screens_smoke_test.dart` were updated for the per-car model; the last two
now assert the *absence* of the seed.

**Not verified:** no release build was produced, and nothing was exercised on a
device or simulator — widget tests only.

---

## 2026-07-27 · Audited the booking → escrow → approval flow, fixed four defects

**Baseline:** working tree, on top of the refocus entry below
**Request:** "check all process of the flow and fix any issues possible."

Read the flow end to end — booking screen → `RequestsNotifier` → transition
table → workshop panel → approval screen → founder panel → tracking screen —
and fixed what was actually wrong. The state machine itself held up: no state
is reachable that the table forbids, the actor checks are enforced in both the
notifier and the service, and the notification copy never claims a transfer
that has not happened. Four defects around it:

### 1. The tracking timeline ticked steps that never happened

`EscrowState.customerStepIndex` returns 5 — the last row — for all four
endings, including `cancelled` and `refunded`. `TrackingScreen` rendered every
row below the current one as done, so a booking **cancelled before payment**
showed "Funds confirmed held ✓ · Workshop accepted ✓ · Work in progress ✓ ·
Proof of work submitted ✓" in green, and so did one **refunded because the
workshop rejected it**. None of those things happened in either case.

The screen was asking one question ("where is the customer") and using the
answer for a second one ("what actually happened"). Those are now separate:

- `EscrowState.reachedStepIndex` — how far a state *proves* a booking got, and
  `null` for the three off-path endings, which prove nothing on their own.
- `ServiceRequest.reachedStepIndex` — the furthest step actually reached, read
  from the escrow `history` the audit trail already recorded.

A row is ticked only when it is both behind the current row and one the
booking reached. Cancelled now ticks step 0 alone; a rejected job ticks through
"funds held" and stops; a dispute keeps all four, because the work really was
done and only the ending is off-path; a completed booking is unchanged.

The rule lives in the model, not the widget, per ARCHITECTURE §5.

### 2. The founder's escrow total dropped every disputed booking

`AdminScreen` folded the held total over `running`, a list that deliberately
excludes disputes so they can have their own section. But a dispute *holds
funds* — `EscrowState.holdsFunds` says so, and the dispute notification tells
the customer "the funds stay held". So the one number on the founder's panel
that says how much money is in escrow silently understated it by every open
dispute. Now folded over all requests, filtered on `holdsFunds`.

### 3. The booking screen could preselect a slot the provider cannot take

`initState` set `_slot = slots.first` without consulting `bookedSlots`. When
the first slot is taken, the chip renders as "full" and refuses to be tapped,
yet it stays selected — and `_confirm` never looked at availability, so it
would book it. Masked today because the mock's first slot happens to be free;
it would not survive real availability data. Now preselects the first
*available* slot, and confirming with no slot left says so instead.

### 4. `ref` was read after the booking screen could already be disposed

`_confirm` awaited `place(...)`, then used `ref` three more times to sync the
plate to the garage and clear the add-on selection, and only then checked
`mounted`. Backing out during that await disposes the `ConsumerState`, and
`ref.read` after disposal throws. The three notifiers are now resolved before
the await, so the post-booking work still runs and no disposed `ref` is
touched.

Also corrected a comment there that claimed `place()` raises the "funds held in
escrow" notification. It raises "request sent" — nothing is held until the
founder confirms, which is the whole point of spec §3, note 2.

### Not changed, worth knowing

- `actionableRequestsProvider` and `awaitingApprovalProvider` (`requests_state.dart`)
  are documented as driving both operator panels and the approval queue, but
  nothing reads either. `WorkshopScreen` filters `requestsProvider` by
  non-terminal instead, so it lists jobs where the workshop's own action bar
  says "nothing for you to do at this state" — arguably right (a workshop may
  want to see an incoming job before funds clear) and arguably not. Left alone:
  it is a product call, not a defect.
- `RequestsScreen.initState` sweeps lapsed approval windows, but the bookings
  tab is a `StatefulShellBranch` whose state survives tab switches, so the
  sweep runs once per app launch rather than "on every visit" as ARCHITECTURE
  §6 item 6 says. Harmless while the process lives (the timers cover it) and
  correct across restarts, which is the case that matters — but the doc
  overstates it.

**Verified:** `flutter analyze` — 1 issue, the pre-existing
`contact.dart` info, unchanged. `flutter test` — 275 passing, up from 270.
Five new tests: four in `escrow_test.dart` pinning `reachedStepIndex` for the
cancelled, rejected, disputed and completed endings, and one in
`operator_panels_test.dart` proving a disputed booking still counts toward the
founder's escrow total. **Not verified:** no release build was produced, and
the booking-screen fixes were not exercised on a device — the preselected-slot
path in particular cannot be reproduced against the current mock data, whose
first slot is free.

---

## 2026-07-27 · Focused the app on booking → escrow → approval

**Baseline:** working tree, on top of the first-launch entry below
**Request:** read `MobileApp-Design/AK_Cars_مواصفات_تعديل_التطبيق.md` and apply
it. The spec narrows the product from four pillars to one and a half — booking,
escrow, approval, plus maintenance follow-up — and specifies the escrow state
machine, the four-tab navigation, the three pilot roles, and the maintenance
projection.

### Hide, do not delete (spec §1)

New `lib/config/app_flags.dart`. `partsStoreEnabled` and
`carMarketplaceEnabled` default to `false`; `homeTabEnabled` too (see below).
A `false` removes the navigation branch, the routes, and every entry point that
would push into that pillar — the profile rows, the home shortcuts, the search
sections. It removes no code: every shop and cars screen still builds and still
has its tests. `--dart-define=AK_PARTS_STORE=true` brings the pillar back in
one run.

Compile-time constants rather than `AppConfig` fields, because the router and
the shell read them below the DI layer while building the tree, and a `const`
keeps the hidden pillars out of the release bundle's reachable code.

**The cost, stated plainly:** a compile-time flag cannot be flipped from a
test, so four assertions that covered a hidden pillar's *reachability* were
rewritten to assert its absence instead — the shop rows on the profile
(`profile_test.dart`), parts and cars in search (`screens_smoke_test.dart`,
`ev_test.dart`), the ads rail on home. The pillars' own screens keep their
coverage. If the flags flip, those assertions flip back.

### The escrow state machine (spec §3) — the core of the change

`lib/data/models/escrow.dart`. `RequestStatus` (six values, a bare `next`
getter, and screens calling `setStatus` with whatever they liked) is gone,
replaced by:

- **`EscrowState`** — the spec's ten states.
- **`EscrowActor`** — customer / workshop / founder / system.
- **`EscrowEvent`** — the named events buttons bind to.
- **`escrowTransitions`** — the spec's transition table, transcribed, and the
  single authority on what may happen next and who may do it.

That table is what makes the rest fall out. `EscrowActionBar` renders
`state.transitionsFor(actor)`, so both operator panels build their own buttons
and the workshop is *structurally* unable to be shown "resolve dispute".
`RequestsNotifier.fire(id, event, actor:)` checks the table and returns null
for anything it does not allow — a stale screen firing a stale button is an
ordinary race, not a crash. `MockServiceMarketplaceService.applyEscrowEvent`
throws `BusinessRuleException` for the same case at the service boundary, which
is where the real API will enforce it. `ServiceRequest.apply` is the only
writer of `escrow`, and it appends an `EscrowEntry` (state, actor, timestamp,
event) to `history` on every move.

Two decisions inside the machine:

1. **`proofSubmitted → awaitingApproval` fires automatically**, by the notifier
   as `EscrowActor.system`. The customer should never watch a booking sit in a
   state waiting for something invisible. The intermediate state is still
   recorded in `history` — it is hidden from the customer, not from the audit
   trail.
2. **The 72-hour window** (`AppConfig.approvalWindow`, with
   `approvalReminderLead` at 24h) releases the escrow if the customer neither
   approves nor objects, and warns them first. Spec §3 note 1: the window
   protects the workshop from a customer who disappears after collecting their
   car, and a *silent* automatic release would be indistinguishable from the
   app taking the workshop's side.

The timer only runs while the app does, so `sweepExpiredApprovals` re-settles
lapsed windows on every visit to the bookings tab. Noted as debt — a real
deployment needs this server-side.

### Honesty fixes that came with it

The old flow claimed the money was held the moment a booking was placed. It is
not: in the pilot the founder confirms the transfer by hand (spec §3, note 2),
which is exactly why `createdPendingPayment` exists as a state. So:

- `notifyRequestPlaced` no longer says "held in escrow" — it says the amount is
  awaiting confirmation.
- The tracking screen's escrow banner is state-dependent: nothing is claimed
  held before confirmation, and a cancelled or refunded booking says what
  actually happened instead of leaving "you approve → payment released"
  showing.
- The payments screen and the profile's "held" tile count `escrow.holdsFunds`
  rather than "not completed", so a booking awaiting confirmation, a
  cancellation and a refund are no longer counted as money we are sitting on.
- The founder panel states on the screen that its totals reflect what the app
  recorded, not transfers that happened.

The approval screen used to render **three hardcoded gradient rectangles** as
"proof photos" and a **hardcoded quote** as the workshop's notes, on every
booking, whether or not anything had been submitted. Both are gone. `ProofOfWork`
/ `ProofMedia` (new models) carry what the workshop actually submitted; an
empty gallery says "written notes only" in words, and a booking with no proof
says that. Drawing placeholder tiles would make an empty proof read as photos
that failed to load.

The tracking screen's Call button dialled a hardcoded `+96824000000`. It now
uses the provider's real number and is disabled when there isn't one — a call
button that reaches someone else is worse than no call button.

The maintenance screen's oil reminder advertised "من 8 ر.ع / from OMR 8", a
price no workshop had to honour. Reminders now carry no price and deep-link
into `/services?q=…` for the item, where the real prices are.

### Four tabs (spec §2)

`الخدمات · حجوزاتي · سيارتي · حسابي`. New
`lib/features/shell/shell_tabs.dart` is the single source of truth: the router
builds one branch per entry, `ShellScreen` builds one button per entry, so the
bar and the branch indices cannot drift.

**Home is the tab that went.** The spec's four do not include it, and most of
what it aggregated was the shop and the cars gallery; what remained — the
maintenance card, the live-tracking card — now has a tab of its own.
`HomeScreen` is untouched behind `AppFlags.homeTabEnabled`. Because it can come
back, `AuthState.initialRoute` and every "back to the top" navigation resolve
`AppFlags.startLocation` instead of naming a literal route, so neither can ever
point at a route the build does not register. The garage and the weekly
challenge moved to "سيارتي", which is now the only place they are reachable
from.

`/requests` became the `/bookings` branch, `/maintenance` became the `/my-car`
branch, and both screens were reworked for their new role as root tabs
(active/finished split on bookings, a garage shortcut in the header on my-car).

### Roles and the two operator panels (spec §6)

`AppRole` (customer / workshop / founder), device-local in SharedPreferences,
switched at the bottom of Settings with a note saying what it is for. Not a
permissions system — the backend will own that. `AppRole.actor` maps it onto
the `EscrowActor` the transition table speaks, and that one mapping is the
whole integration.

`WorkshopScreen` (accept/reject, start, submit proof) and `AdminScreen`
(confirm funds held, resolve disputes, watch what is in flight) are both plain
by intent — spec §6 says these exist to operate the pilot, not to impress.
Both build their buttons from `EscrowActionBar`, so neither hard-codes a
workflow.

### Maintenance projection (spec §4)

`MaintenanceLog` gained `previousOdometerKm` / `previousOdometerAt`, which give
it a usage rate (`avgKmPerDay`) and therefore a projected reading for today
(`projectedOdometerKm`). The distance countdown measures against the projection
rather than against a number entered three weeks ago.

Kept honest three ways: one reading gives no rate and no projection (there is
no fallback national average); an odometer that went backwards gives no rate
either, because a correction is not a second data point; and anything projected
is labelled — `DueItem.estimated` drives a "(تقديري)" suffix and the screen's
source notice changes wording when a projection is in play.

Items also gained distance intervals alongside their time intervals
(`MaintenanceRule.resolve`, matching the spec's `MaintenanceRule`) and now come
due on whichever runs out first, which is how a workshop quotes them.

### Not done, and why

**Media capture.** `ProofOfWork.media` is modelled, serialised and rendered end
to end, but nothing on-device can create a `ProofMedia`: that needs
`image_picker` or similar, which is a new dependency and needs your sign-off
(and iOS/Android permission plumbing). The workshop panel says so instead of
showing a button that does nothing, and points the workshop at the chat for
photos in the meantime. This is the one part of "إثبات الإنجاز" that is not
complete.

### Verified

```
flutter analyze lib test   # 1 pre-existing info (core/utils/contact.dart)
flutter test               # 270 passing (was 237 before this work)
flutter build web --release # succeeds; MaterialIcons still tree-shaken 98.2%
```

New test files: `escrow_test.dart` (transition-table invariants — no state
offers the same event twice, the happy path terminates, the wrong actor is
refused, the proof hand-off is automatic, the window lapses and sweeps),
`maintenance_projection_test.dart`, `focus_flags_test.dart` (the bar matches
the flags; the start location is always a tab that exists),
`operator_panels_test.dart`. `widget_test.dart` now boots the real router and
visits every branch — the only place the tab list and the shell's branch
indices are proved to agree.

**Not verified:** nothing was run on a device or emulator; the escrow flow was
exercised through the notifier and through widget tests, not by hand.

---

## 2026-07-27 · First-launch flow actually runs once, and wears the new mark

**Baseline:** working tree, on top of the launcher-icon entry below
**Request:** "fix the bugs in the first [screens] which should only work for the
first time after installing the app. the icon of app should update and the
flow. make the page modern with animations."

### The bugs
The intro (splash → onboarding → start-choice) replayed on **every** cold
start. Three separate faults stacked up, and each one alone was enough:

1. **The router never asked.** `app_router.dart` hard-coded
   `initialLocation: '/splash'`. Nothing anywhere read `onboardingSeen`.
2. **The flags were never written down.** `AuthNotifier` kept `onboardingSeen`
   and `startChoiceMade` in memory only, so even once the router did ask, the
   answer was `false` on every launch.
3. **The session was never restored.** `AuthNotifier.build()` returned a bare
   `AuthState`, and nothing called `AuthRepository.currentUser()` — which
   would not have helped anyway, because `MockAuthService` held the profile in
   a *field*. So a registered user came back anonymous after every restart and
   was pushed through the sign-up form again at the next gated action.

Fixed by making the two flags and the profile survive the process:
`AppConstants` gained `prefsOnboardingSeen`, `prefsStartChoiceMade` and
`prefsProfile`; `AuthNotifier` reads them in `build()` and writes them in
`markOnboardingSeen`/`markStartChoiceMade`/`register`/`signOut`;
`MockAuthService` stores the profile as JSON in SharedPreferences (it stands in
for the session store, not just the server); `AppBootstrap.createContainer`
calls the new `AuthNotifier.restore()` before the first frame. The start route
is now `AuthState.initialRoute` — kept on the state, not in the router, so it
is testable without a navigator, and read with `ref.read` because `watch`
would rebuild the router and drop the navigation stack the moment onboarding
finished mid-session.

`AddCarScreen` already recorded the choice when it saved, so the start-choice
"add my car" path was **not** broken — an earlier edit that added a second
`markStartChoiceMade()` there was reverted rather than left as dead belt-and-
braces.

### The mark, in the app
`lib/core/widgets/app_mark.dart` (`AppMark`) draws the launcher icon as a
widget — the same 1024-unit geometry as `icon/app_icon.svg`, so the installed
icon and the in-app mark cannot drift. It replaces the old "AK" text tile on
the splash. `barProgress` animates the amber light bar, which is what the
splash uses for its "lights on" beat.

### Modernised screens
- **Splash:** one `AnimationController` timeline with `Interval`s per element
  instead of scattered delays; mark settles with an overshoot then breathes;
  light bar opens from the centre; background circles drift on a slow ambient
  loop. Now theme-aware (`AkColors`) — it previously hard-coded the light Sand
  palette and stayed cream in dark mode. Honours `MediaQuery.disableAnimations`
  by jumping to the finished state.
- **Onboarding:** slides parallax (icon 40px, headline 110px, body 170px per
  page) and follow the finger mid-drag rather than only snapping; icon tile
  gains the amber accent ring; the Next/Get started label cross-fades.
- **Flow coherence:** all three screens now show the same progress language —
  dots on the splash, the start-choice step bar reused on onboarding.

### Two things found on the way
- The splash's "Have an account? **Sign in**" pointed at `/register`. There is
  no sign-in in this app — registration is the only identity path and
  `MockAuthService.register` simply overwrites — so the link promised
  something that does not exist. Replaced with the one honest shortcut:
  "Know the app already? **Skip the tour**", which jumps to the car question.
  Real sign-in / account recovery is still missing and is a product gap, not a
  bug this entry fixes.
- The splash hero photo came from `CarImage` → `cdn.imagin.studio` with
  `customer=hrjavascript-mastery`, a public tutorial account, and rendered
  **watermarked**. The splash now draws `CarArtwork` instead — the first screen
  should not wait on a CDN or show someone else's watermark. The wider problem
  (that key is the default for every car image in the app,
  `AppConfig.useRemoteVehicleImages` defaults to true) is untouched and needs
  its own decision.

### Verified
`flutter analyze` clean apart from one pre-existing info in `contact.dart`.
`flutter test` — 237 pass, up from 226. New `test/first_run_test.dart` restarts
the app the only way that proves the fix: it throws the container away and
builds a fresh one over the same SharedPreferences, covering fresh install,
onboarding done, choice made, register, sign-out, a corrupt stored profile, and
the real `AppBootstrap` path. `test/onboarding_test.dart` gained three widget
tests for the splash and the tour (note: the splash's ambient loop repeats
forever by design, so those tests pump fixed durations — `pumpAndSettle` never
returns there). Screens were then rendered from a release web build and
inspected.

**Not fixed, and not a regression:** the "Step 2 of 3" / "Step 3 of 3" text
label does not paint in the release web build — on the new onboarding header
*and* on the untouched start-choice header. The `Text` is provably in the
widget tree (asserted in a probe test) and a Latin-only string in the same slot
does not paint either, so it is neither an Arabic nor a font problem; the
sibling progress bar in the same `Column` paints fine. Unexplained. The bar
carries the meaning either way. Not checked on a device.

---

## 2026-07-27 · App launcher icon — "Sand & Ink" car mark

**Baseline:** working tree, on top of the Arabic-numbers entry below
**Request:** "generate icon for this project ... don't include AK Cars name in
the icon."

### What was made
A wordless mark, drawn from the Sand & Ink tokens in
`lib/core/theme/app_colors.dart` so the icon and the app read as one system:

- **Ink tile** (`#26241F → #16150F`) — the same ink that carries every primary
  button and the dark theme's chrome.
- **Cream car face** (`#F6F3EE`, the Sand background colour) — a front three-box
  silhouette: cabin, windshield knocked out in ink, body with fender shoulders,
  two tyres. Front-on rather than the usual side profile, because symmetry
  survives being scaled to a 20pt iOS slot.
- **Amber light bar** (`#E9A23B → #B07818`) — the one accent, and the only place
  amber appears in the app's own rules: offers and service/due state. Red was
  deliberately not used; it is reserved for roadside SOS.

The car is the whole app rather than any one tab — the gallery, the parts shop,
the workshop marketplace and the garage all hang off "your car", so the mark is
the car itself, not a wrench or a shopping bag.

Sources are SVG in `icon/`, with the 1024px PNGs rendered beside them:
- `app_icon.svg/.png` — full-bleed master (iOS, web, legacy Android).
- `app_icon_foreground.svg/.png` — Android adaptive foreground, transparent.
  Scaled up 1.22× against the master because the launcher applies its own 16%
  inset; the bounding box's half-diagonal still lands inside the 66% safe
  circle, so no mask shape clips a corner.
- `app_icon_monochrome.svg/.png` — Android 13+ themed layer. The windshield and
  the light bar are real holes (SVG `mask`), not painted shapes: the launcher
  tints by alpha, so anything merely recoloured would flatten into a blob.

### Wiring
`flutter_launcher_icons ^0.14.4` added as a dev dependency and configured in
`pubspec.yaml` (`adaptive_icon_background: "#1D1B17"`, `remove_alpha_ios: true`,
web generation on). Regenerate with `dart run flutter_launcher_icons`.
Generated/overwritten: the five Android mipmaps, `mipmap-anydpi-v26`, the
foreground + monochrome drawables, `values/colors.xml`, the full iOS
`AppIcon.appiconset`, and `web/icons/*` + `favicon.png` + `manifest.json`.

### Verified
Rendered a proof sheet from the *generated* files (not the sources) and checked
it by eye: iOS 1024, the adaptive foreground composited over the background at
the launcher's real 16% inset under both circular and squircle masks, the
monochrome layer flat-tinted, plus iOS 60/40/29/20pt and the web maskable icon.
The mark holds at 20pt and nothing clips. Not checked: an actual device install
(no emulator run this session), and the iOS icons were not re-inspected for an
alpha channel beyond trusting `remove_alpha_ios`.

---

## 2026-07-27 · Numbers in the shop-details card render right in Arabic

**Baseline:** working tree, on top of the plate entry below
**Request:** "fix the texts of the number fields in the Shop details card"
(with a screenshot of the Arabic product page).

### The situation before
Arabic paragraphs are right-to-left, and the bidi algorithm hands any
*neutral* character next to a number (`+`, `–`, `·`) to the paragraph
direction rather than to the number. In the shop-details card that produced
two wrong readings:

- the phone `+96824478120` rendered as `96824478120+` — the dial code's plus
  moved to the far side of the digits (visible in the screenshot);
- the opening hours `٨:٠٠–٢٠:٠٠` are two number runs joined by an en dash, so
  they swap: the card read as if the workshop opened at 20:00 and closed at
  8:00.

`OM1100047382` and `1198432` were correct by luck — a VATIN starts with strong
Latin letters, and a lone CR number has no neutral next to it.

### What changed
New `lib/core/utils/bidi_text.dart` → `isolateNumbers(value, rtl:)`, which
wraps each number run (leading `+` and internal `: . , / -` included) in a
Unicode isolate `U+2066 … U+2069`. That lays the run out left-to-right and
makes it a single neutral object inside the Arabic, so the text around it is
untouched.

Applied in `ProviderDetailsCard` to the hours / phone / VAT / CR rows, the
area · distance line, and the pickup-fee chip.

Two deliberate limits:
- **Arabic only.** In English the function returns the string unchanged, so
  the rendered text still equals the data and the existing English assertions
  (`find.text('OM1100047382')`) keep testing what they say they test.
- **Display only.** The copy buttons still put the raw value on the clipboard —
  pasting a phone number with invisible isolate characters into a dialler
  would be a worse bug than the one being fixed.

The existing `Directionality(textDirection: TextDirection.ltr)` approach
(`register_screen.dart`'s phone field) stays the right tool when a whole field
is Latin. This is for numbers *embedded* in Arabic that must keep their
surroundings right-to-left — wrapping the hours string in an LTR
`Directionality` would have reordered the Arabic day names.

Left as-is: the Arabic hours use Arabic-Indic digits (`٨:٠٠`) while phone/VAT/CR
use Latin. That matches the app's existing split — Arabic-Indic in prose
(`بطارية ١٢ فولت`, `الخطوة ٣ من ٣`), Latin in data — and the isolate fixes the
ordering either way, so no demo data was rewritten.

### Files
| File | Change |
|---|---|
| `lib/core/utils/bidi_text.dart` | **new** — `isolateNumbers` |
| `lib/features/services/provider_details_card.dart` | isolates numbers in the value rows, the distance line and the pickup-fee chip |
| `test/bidi_numbers_test.dart` | **new** — the isolate itself, plus the Arabic phone row and the English no-op through the real product page |

### Verified
- `flutter test` — 226 passed.
- `flutter analyze lib test` — clean apart from the pre-existing `contact.dart`
  info. (The isolate constants are written as `⁦`/`⁩` escapes; the
  literal characters trip `text_direction_code_point_in_literal`.)
- **Not** verified visually. A widget-test screenshot was attempted and is
  useless here: the test renderer draws every glyph as a box, so character
  order cannot be read off it. The evidence is the string-level assertions —
  the Arabic card renders `⁦+96824478120⁩` — not a picture. Worth one look on a
  device.

### Known-adjacent, left alone
- Only `ProviderDetailsCard` was audited. Other Arabic screens showing a phone
  or a time range (chat, orders, tracking) may have the same reordering; that
  is a wider sweep than the card asked about.
- The CR number has no copy button while the phone and VAT number do.

---

## 2026-07-27 · Omani plates can repeat a letter (AA, BB, …)

**Baseline:** working tree, on top of the image entries below
**Request:** "update the Oman number plate validation — for the middle
character, the user can select 2 letters of the same type."

### The situation before
`PlateLettersPicker` treated the letter keys as a **toggle set**: tapping a
picked letter unpicked it. A plate like `12345 AA` was therefore impossible to
enter — the second tap on `A` removed the first one. Real Omani private plates
do repeat the letter, so the picker was rejecting valid plates.

Nothing else validated the letters: `OmanPlateInput.parse`, the add-car form
and the booking form all pass the string through untouched, so the picker was
the only place to fix.

### What changed
Tapping a letter now **appends** it instead of toggling, which is what makes a
repeat possible:

- two taps on the same key give `AA`;
- a third tap slides the pair along (oldest letter drops off), which is the
  behaviour the old code already had once two were picked;
- because tapping no longer unpicks, a **backspace button** next to the live
  preview undoes the last tap;
- a key used twice shows a `×2` badge, so `AA` is not mistaken for a single
  `A` still being selected;
- the hint says the repeat is allowed, in both languages.

### Files
| File | Change |
|---|---|
| `lib/core/widgets/oman_plate_input.dart` | `_toggle` → `_pick` (append) + `_undo`; `×2` badge; backspace; hint text (ar/en) |
| `test/plate_letters_test.dart` | **new** — repeats, the `×2` badge, what gets saved, backspace, the sliding pair, reopening `HH`, `parse` round trip |

### Verified
- `flutter test` — 219 passed, including a test that picking `M` twice saves
  the string `MM`.
- `flutter analyze lib test` — clean apart from the pre-existing
  `contact.dart` info.
- **Not** run on a device — the backspace button's placement next to the
  preview was not seen at real size.

### Known-adjacent, left alone
- The letter vocabulary is the 10-entry Latin list in
  `MockCatalogData.plateLetters` (`A B D H M R S W X Y`). Real plates use Arabic
  letters with Latin equivalents; whether the picker should show both is a
  data/design question, not part of this fix.
- Nothing validates the plate *number* beyond "digits, max 5" — a plate of
  `0` is accepted.

---

## 2026-07-27 · Real logos and photos back on by default

**Baseline:** working tree, on top of the offline-artwork entry below —
**this entry corrects it.**
**Request:** "the makers icons disappeared now… roll back. also for the car
image after selecting. roll back and make it work as the web version."

### What went wrong
The entry below made the drawn artwork the *default* and put the CDN behind an
opt-in flag. That was the wrong trade: it fixed the blank-image case by
removing the real images from every build, so brand pickers showed monogram
tiles instead of Toyota/Nissan logos, and a selected car showed a drawing
instead of its studio photo. The reported bug was "no images offline", not
"stop using the CDN".

### What changed
`AppConfig.useRemoteVehicleImages` now defaults to **true**. Mobile requests
the same logo and studio-photo URLs the web app does; nothing about the online
appearance differs from web any more. `CarImage` also asks the CDN for its
default angle on the first render (`carImageUrl(make, model)` with no `angle`
override), which is the exact pose web shows — the rotated angles are only used
for later pages of the detail carousel.

The drawings from the entry below are kept, but demoted to what they should
always have been: the **fallback**, shown while an image loads and when it
fails. So the offline/no-network case still shows a car instead of a grey box,
and nothing is lost when the network is there.

`--dart-define=AK_REMOTE_CAR_IMAGES=false` forces the offline drawings for
testing that path.

### Files
| File | Change |
|---|---|
| `lib/config/app_config.dart` | `useRemoteVehicleImages` → `defaultValue: true` |
| `lib/core/widgets/car_media.dart` | doc comments corrected; variant 0 uses the CDN's default angle |
| `test/car_image_test.dart` | asserts the CDN is the default, and that a failed load still draws a car |

### Verified
- `flutter test` — 212 passed. The fallback test proves a car that fails to
  load (400 from the test HTTP client, same as offline) renders `CarArtwork`.
- `flutter analyze lib test` — clean apart from the pre-existing `contact.dart` info.
- **Not** run on a device. The thing that actually made release-build Android
  images fail — the missing `INTERNET` permission in the entry below — is still
  unverified on hardware; it is the change that matters most here, since with
  remote images back on, a release APK without that permission would show
  drawings on every screen.

---

## 2026-07-26 · Car pictures work offline (and Android release had no network)

**Baseline:** `a854c2a` (working tree, on top of the back-button entry below)
**Request:** "in the Android and iOS version, the cars images are not displayed
as in the web version… make it work offline in assets as temp files until I
decide what I will do when I want to publish."

### Two separate causes

1. **`android/app/src/main/AndroidManifest.xml` never declared
   `android.permission.INTERNET`.** Only the `debug/` and `profile/` manifests
   did (Flutter adds those for hot reload). So a debug build showed images and a
   release build had no network at all — not just images, the REST API too.
   Web was unaffected, which is why it looked like a mobile-only image bug.
2. **Every car picture was remote.** `carImageUrl()` pointed at
   `cdn.imagin.studio` with a borrowed demo customer id, and `CarMake.logoUrl`
   at a GitHub raw URL. No connection, or a dead CDN account, meant a grey icon
   everywhere — including the live preview in add-car, which is the one place a
   user expects to see the car they are registering.

### What changed
Car imagery is now drawn locally by default, so a picture never depends on the
network. `CarImage` resolves in this order:

1. a real photo bundled in `assets/cars/`, registered in
   `lib/core/media/vehicle_assets.dart`;
2. the remote CDN — **only** when the build opts in with
   `--dart-define=AK_REMOTE_CAR_IMAGES=true`;
3. `CarArtwork` — a vector side profile painted at draw time.

The artwork picks one of six body shapes (sedan / SUV / hatchback / coupe /
pickup / van) from keywords in the model name, and paints it in the car's
recorded exterior colour, falling back to a stable colour derived from the
make/model. Both are deterministic, so a car looks the same on every screen and
across rebuilds.

Chosen over downloading the CDN renders and brand logos into `assets/`: those
are third-party photography and trademarks, and committing them for a public
release is a licensing decision, not a bug fix. The folders and the lookup map
are in place so real photos can be dropped in per model later without touching
screen code — see `assets/cars/README.md`.

### Files
| File | Change |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | **the real bug** — added `INTERNET` permission for release builds |
| `lib/core/widgets/car_artwork.dart` | **new** — body-type inference, paint palette, `CustomPainter` side profile |
| `lib/core/media/vehicle_assets.dart` | **new** — bundled asset lookup + key normalisation |
| `lib/config/app_config.dart` | `AppConfig.useRemoteVehicleImages` — the `AK_REMOTE_CAR_IMAGES` opt-in, kept in `config/` per the layer rule that it is the only reader of `dart-define`s |
| `lib/core/widgets/car_media.dart` | `CarImage`/`MakeLogo` offline-first; new `color`, `variant`, `expand` params |
| `lib/features/cars/listing_detail_screen.dart` | carousel uses `CarImage(expand:)` instead of raw `Image.network` |
| `lib/features/cars/listing_card.dart`, `cars_screen.dart`, `garage/my_cars_screen.dart`, `garage/add_car_screen.dart` | pass the car's real colour through |
| `pubspec.yaml` | declares `assets/cars/` + `assets/logos/` |
| `assets/cars/README.md`, `assets/logos/README.md` | **new** — how to drop in real photos, and the licensing note |
| `test/car_image_test.dart` | **new** — offline rendering, body/colour inference, asset-key normalisation |

### Verified
- `flutter test` — 211 passed.
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements` in `lib/core/utils/contact.dart:23`) is pre-existing.
- Artwork rendered to a PNG via a throwaway `RepaintBoundary` test and inspected:
  all six body shapes read as the right kind of vehicle at card size. That
  scratch test was deleted, not committed.
- **Not** run on a device or emulator. In particular the Android release build
  with the new permission was not produced — worth a `flutter build apk --release`
  before trusting it.

### Known-adjacent, left alone
- `post_ad_screen.dart` still only stores tint colours for "added photos" — a
  user posting an ad cannot attach a real picture yet. That needs image picking
  plus storage, which is the Phase 4 upload work, not this fix.
- `carImageUrl()` still hardcodes the `hrjavascript-mastery` demo customer id
  on the imagin.studio CDN. It is now unreachable by default, but if the remote
  flag is ever turned on for a real build, that account needs to be ours.
- iOS was never blocked by a permission (ATS allows HTTPS), so on iOS this is
  purely the offline-artwork improvement.

---

## 2026-07-26 · One modern back button on every page

**Baseline:** `a854c2a` (working tree, on top of the shop-filter entry below)
**Request:** "add back button in each page and make it modern".

### The situation before
Two different back affordances, plus a third that was just the Material default:

- Screens with a custom header (`SandHeader`) already showed the Sand & Ink
  circular chevron — garage, maintenance, settings, my ads, challenge.
- Screens built on a plain `AppBar(...)` — search, cart, orders, notifications,
  payments, requests, chat, booking, tracking, approval, post ad, add car,
  register, make filter, results, services — fell back to Flutter's stock
  `Icons.arrow_back` arrow, which looks nothing like the rest of the app.
- The cars filter screen had a bare `IconButton(LucideIcons.arrowLeft)`.
- The photo-hero detail pages (listing, product) had their own private
  `_RoundButton` / `_RoundAction` with `Icons.arrow_back_rounded`.

So no page was missing a way back, but three of them looked unrelated to each
other and the most common case looked unstyled.

### What changed
`SandBackButton` is now the single back affordance and got a modern pass:
press-scale animation (0.9 over 110ms), haptic on tap, soft drop shadow, a 44px
tap target around the 38px visual, a `translucent` variant for sitting on top of
a photo, and localized semantics via `MaterialLocalizations.backButtonTooltip`.
It still mirrors LTR/RTL (chevron left / chevron right).

It reaches every `AppBar` through the theme rather than per-screen `leading:`
overrides — `ActionIconThemeData.backButtonIconBuilder` in `AppTheme`. That
means screens added later get it for free, and there is one place to change it.
`closeButtonIconBuilder` was set to the Lucide `x` for the same reason.

### Files
| File | Change |
|---|---|
| `lib/core/widgets/sand_widgets.dart` | `SandBackButton` rewritten: stateful press animation, haptic, shadow, 44px target, `translucent` variant, `.icon` decorative constructor, semantics |
| `lib/core/theme/app_theme.dart` | `actionIconTheme` — every `AppBar` back/close icon now comes from the design system |
| `lib/features/cars/cars_filter_screen.dart` | bare `IconButton` header back → `SandBackButton` |
| `lib/features/cars/listing_detail_screen.dart` | hero `_RoundButton` back → `SandBackButton(translucent: true)` |
| `lib/features/shop/product_detail_screen.dart` | hero `_RoundAction` back → `SandBackButton(translucent: true)` |
| `test/back_button_test.dart` | new — theme wiring, RTL/LTR mirroring, pop behaviour, tap-target size |

The `.icon` constructor is decorative on purpose: inside an `AppBar` the
`IconButton` Material builds already owns the gesture, tooltip and semantics, so
the chip must not add a second one.

### Verified
- `flutter analyze` — clean (the one remaining info is pre-existing, in
  `lib/core/utils/contact.dart`, untouched here).
- `flutter test` — 195 pre-existing tests pass, plus the 5 new ones. The new
  tests assert a pushed plain-`AppBar` page renders `SandBackButton` and *not*
  `Icons.arrow_back`, that the chevron flips with locale, and that tapping pops.
- **Not** run on the device or a browser — the visual polish (shadow, press
  scale) has not been eyeballed on real hardware.

---

## 2026-07-26 · Shop filter: search keyboard covered the make/model picker

**Baseline:** `a854c2a` (working tree, on top of the EV entry below)
**Request:** read a debug run's logcat together, then "if there any issue fix it".

### What the log showed
A device run on an SM-S918B with the shop filter sheet open. No crash, no
`E/flutter`, no exception. Two things stood out:

- Dozens of `TextInputPlugin.showTextInput` / `hideTextInput` pairs, each
  building and tearing down an `InputTransport` channel — the search keyboard
  opening and closing repeatedly inside the filter's picker sheets.
- `E/AccessibilityBridge: transform has not been initialized for id = 952`, on a
  zero-rect / null-transform node parented to the `RangeSlider` row (node 935 in
  the dumped semantics tree). Framework-side `RangeSlider` semantics, not ours.
  Left alone.

The keyboard traffic itself is normal Flutter behaviour, but chasing it surfaced
a real defect in the sheet it was coming from.

### Fixed
`_PickerSheet` (make / model / year popup inside the shop filter) is anchored to
the bottom edge and capped at 70% of the **full** screen height, with no
`viewInsets` handling. Opening the search keyboard therefore covered the grid or
list it was filtering: type a make, and the matching logos are behind the
keyboard. The parent `ShopFilterSheet` already handled this correctly — only the
nested picker did not.

Now the picker pads its bottom by the keyboard inset and measures its 70% cap
against the screen *minus* the keyboard, so the sheet lifts clear and the
results stay visible while typing.

### Files
| File | Change |
|---|---|
| `lib/features/shop/shop_filter_sheet.dart` | `_PickerSheet.build` — keyboard inset padding + height cap measured against the remaining screen |

### Verified
- `flutter analyze lib/features/shop/shop_filter_sheet.dart` — no issues.
- **Not** re-run on the device. The fix is geometry, so it needs a visual check:
  open the shop filter → الشركة المصنعة → tap search, and confirm the logo grid
  sits above the keyboard.

### Found but NOT fixed — the year pickers do not filter anything
"السنة من / Year from" and "السنة إلى / Year to" in the shop filter are dead
controls. `_selectedCar` builds a `Car` from make/model/year, but matching runs
through `Product.fitsCar`, which only compares make, model and powertrain — it
never reads `car.year`. `Product` carries no year data at all, so there is
nothing to match against. Corroborating tell: `_toYear` is never restored in
`initState`, so it silently blanks every time the sheet reopens, and it is not
passed to `_selectedCar` even in principle.

Both fixes are product decisions rather than defect repairs, so they are left for
the owner to choose:
- drop the two year fields from the shop filter (they promise filtering the
  catalogue cannot do), or
- add a supported year range to `Product` and extend `fitsCar` to honour it.

Note this is the shop filter only — the add-car flow's year picker is real and
unaffected.

---

## 2026-07-26 · EV owners are first-class: powertrain, EV services, parts, challenge

**Baseline:** `a854c2a` (on top of the register-wilayat entry below)
**Request:** "make electric car owners feel like they belong in the product, not
like EV support is an afterthought" — practical, user-facing changes across
garage, home, services, maintenance, shop, challenge and the cars marketplace.

### What was there
The app knew nothing about how a car is driven. Everything downstream therefore
assumed a combustion engine:

- The garage stored make/model/year/plate/odometer and no powertrain, so an EV
  was indistinguishable from a Camry.
- `MaintenanceRepositoryImpl.dueItems` returned every `MaintenanceType` for
  every car — an EV owner got an **engine-oil countdown**. The home card asked
  for oil and tyres *by name* (`due.firstWhere(type == oil)`), which would have
  **thrown** the moment the list stopped containing oil.
- The service marketplace had eleven categories, none EV-specific: no EV health
  check, no high-voltage battery diagnostic, nothing about charging.
- The shop sold no charging hardware, no EV-rated tyre and no EV 12V battery.
- The weekly challenge was tyre pressures for everyone, and the maintenance
  record it wrote was hardcoded to "Tyre pressure check (challenge)".
- The Tesla ad's range, battery warranty and included charger were prose inside
  its `description`, so nothing could show or filter on them.

### The model now
**One optional field decides everything: `Car.powertrain`.**

| Rule | Where it lives |
|---|---|
| Which maintenance items a car has | `MaintenanceTypeX.appliesTo` / `forPowertrain`, applied by `MaintenanceRepositoryImpl.dueItems(powertrain:)` |
| Which services a car can book | `ServiceCategory.powertrains` + `appliesTo`, ordered by `ServiceMarketplaceRepository.categoriesFor` |
| Which workshops may sell EV work | `ServiceCategory.requires` + `ServiceProvider.capabilities` (`evService`, `evChargerInstall`) |
| Which parts fit | `Product.powertrains` + `fitsPowertrain`, honoured by `Product.fitsCar` and `ShopFilter.matches` |
| Which weekly challenge is offered | `ChallengeTrack` in `challenge_service.dart`, one board per track |
| Most-urgent-first ordering | `DueItemListX.byUrgency` / `mostUrgent` (was a private method inside two widgets) |

Petrol/diesel behaviour is unchanged, and so is a car whose owner never
recorded a powertrain — `null` keeps the combustion set. Make, model and year
are still the only required fields.

### What an EV owner sees
- **Garage** — an "Electric" badge on the car photo and a spec chip; a
  five-chip powertrain row in add/edit (one tap, skippable).
- **Maintenance** — no oil line. Tyres, battery/thermal coolant (reworded for
  an EV), cabin filter, brake fluid, 12V battery, EV battery health. A hybrid
  keeps its oil change *and* gains battery health.
- **Home** — the seasonal banner becomes battery/tyres/12V priced from the real
  `ev-check` offerings, plus a "Your electric car" shortcut rail (EV check,
  charging, tyres, parts, roadside) that states how many workshops in the
  user's own governorate are actually EV-certified.
- **Services** — five new categories (`ev-check`, `ev-battery`, `ev-charging`,
  `ev-charger`, `ev-sos`) on their own rail: top of the page for an owner whose
  car plugs in, bottom and labelled for everyone else. The unsearched shortlist
  holds only what the saved car can be booked in for; a typed query still
  returns everything.
- **Shop** — six EV products with full spec sheets (Type 2 cable, portable
  charger, Type 1↔2 adapter, EV-rated tyre, EV 12V battery, EV cabin filter), a
  new "Charging & cables" category, an "EV parts" chip, and a product page that
  says "Not for your Toyota Camry" instead of implying a fit.
- **Challenge** — an EV track (plan charging, inspect the cable, set pressures
  for range) with the same points, streak and badges, and a record title that
  says what was actually done.
- **Cars marketplace** — `rangeKm`, `batteryWarrantyUntilYear` and
  `chargerIncluded` on `GalleryListing`, shown as rows only when the seller
  stated them. The existing Electric fuel filter is untouched.

### Honesty rules held
- No battery state of health anywhere. The EV battery item shows "no record",
  and the maintenance screen says outright: *the app cannot read your car —
  battery condition appears after an inspection at an EV-certified workshop*.
- No fabricated EV coverage. Not every workshop is EV-certified (a test asserts
  the certified set is a strict subset), but every served governorate has at
  least one for each EV category, so the region filter never widens silently.
- `Product.universalFit` now means *fits any car* — a charging cable with
  `fits: {'any'}` no longer claims "Fits all cars".

### Files
| File | Change |
|---|---|
| `lib/data/models/powertrain.dart` | **new** — `Powertrain` + labels, icons, `hasEngine`/`plugsIn`/`isFullyElectric`, `specFuel`, tolerant `fromKey` |
| `lib/data/models/car.dart` | `powertrain`, `isElectric`, `plugsIn` (+ JSON, copyWith, equality) |
| `lib/data/models/maintenance.dart` | 4 new `MaintenanceType`s, `appliesTo`/`forPowertrain`, per-item `defaultMonths`, EV coolant wording, `DueItem.powertrain`, `DueItemListX` |
| `lib/data/repositories/maintenance_repository.dart` | `dueItems(powertrain:)` |
| `lib/data/models/service_category.dart` | `powertrains`, `requires`, `evOnly`, `appliesTo` |
| `lib/data/models/service_provider.dart` | `ProviderCapability`, `capabilities`, `can`, `evCertified` |
| `lib/data/repositories/service_marketplace_repository.dart` | `evCategories`, `categoriesFor`, `providersWith`; `otherCategories` excludes EV |
| `lib/data/models/product.dart` | `powertrains`, `fitsPowertrain`, EV-aware `fitsCar`/`matchesQuery`, stricter `universalFit` |
| `lib/data/models/shop_filter.dart` | `powertrain` facet (+ query parameter) |
| `lib/data/models/challenge.dart` | `WeeklyChallenge.recordTitle` |
| `lib/data/models/gallery_listing.dart` | `rangeKm`, `batteryWarrantyUntilYear`, `chargerIncluded`, `plugsIn` |
| `lib/data/services/challenge_service.dart` | `ChallengeTrack`, powertrain-aware fetch/complete, step-owning board lookup |
| `lib/data/repositories/challenge_repository.dart` | one warm cache per track, `boardFor` |
| `lib/state/maintenance_state.dart` | `primaryPowertrainProvider`, `isElectricCarProvider`, due items scoped to the car |
| `lib/state/challenge_state.dart` | board follows the default car; record title from the challenge |
| `lib/data/datasources/mock/*` | provider capabilities, 5 EV categories + copy + catalogue rows, 6 EV products + "charging" category, EV challenge board, Tesla EV facts |
| `lib/core/json/icon_codec.dart` | 6 EV icon keys (tree-shaking stays intact) |
| `lib/features/garage/*` | powertrain chips in the form, badge + chip on the cards, EV battery guidance and powertrain line on maintenance |
| `lib/features/home/home_screen.dart` | EV banner, `_EvShortcuts`, maintenance card no longer names oil |
| `lib/features/services/*` | EV rail (`_TileRail`), capability note in the category sheet, powertrain on the car chip, powertrain-scoped shortlist, `?q=` initial query |
| `lib/features/shop/*` | "EV parts" chip, powertrain fitment on the product page |
| `lib/features/search/search_screen.dart` | suggestions follow the saved car |
| `lib/core/router/app_router.dart` | `/services?q=` |
| `test/ev_test.dart` | **new** — 39 tests: garage identity, EV vs ICE vs hybrid vs unstated maintenance, EV service coverage and capability, search, shop fitment, challenge tracks, home, EV listings, AR/EN |
| `test/models_json_test.dart` | round-trips for every new field |
| `test/translation_coverage_test.dart` | powertrain row + EV product page, both languages |
| `test/screens_smoke_test.dart` | "battery" search now matches 5 services / 2 parts (asserted through "Show all") |
| `test/garage_test.dart` | taller surface — the form is a lazy ListView and now has one more field |

### Verified
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements` in `lib/core/utils/contact.dart:23`) is
  pre-existing and unrelated.
- `flutter test` — **195 passed** (153 before this work, all still passing).
- **Not** run on a device or emulator — no visual confirmation of the EV badge,
  the home shortcut rail, or the services EV rail.

### Known-adjacent, left alone
- **Add-ons are still per provider, not per category.** Booking an EV charging
  check offers "tyre rotation" and "engine flush" from the workshop's generic
  add-on list. Pre-existing shape (`addOnsByProvider`); making add-ons
  category-aware is its own change.
- **Post-ad does not collect the three EV listing fields.** A seller posting an
  EV in-app leaves `rangeKm`/`batteryWarrantyUntilYear`/`chargerIncluded` null,
  which renders correctly (rows omitted) but means only seeded ads carry them.
- **No EV facet in the cars filter** beyond the existing `fuels` set — range and
  battery-warranty filters would need the fields on every EV ad first.
- **`cabinFilter`/`brakeFluid`/`battery12v` are EV-only for now.** A petrol car
  has them too, but they are covered inside its oil service; listing them
  separately for everyone is a product decision, not a data one.
- The maintenance oil card still hardcodes "from OMR 8" (pre-existing) while
  every other price on that screen is derived.

---

## 2026-07-26 · Register: wilayat is a picker now, like everywhere else

**Baseline:** `a854c2a` (on top of the phone-field entry below)
**Request:** "in the register page. the Welayat feild should be same other
Welayat feild as dropdown list"

### What was there
Register had no wilayat field at all. It had **Governorate** (a picker) and
then a free-text **Address** whose hint was "الولاية، المنطقة / Wilayat, area" —
so the wilayat was typed prose, spelled however the user felt, while
`add_car_screen` and `post_ad_screen` both make it a picker cascading off the
governorate.

- **New Wilayat `_PickerRow`** between Governorate and Address, listing
  `LocationCatalog.wilayatsOf(region)` — the same canonical English keys, with
  Arabic display names, that the car screens store.
- **Cascades**: picking a different governorate clears the wilayat, so nobody
  ends up filed in Seeb under Dhofar.
- **Disabled until a governorate exists**, showing "Choose a governorate first"
  rather than opening an empty sheet — `_PickerRow` gained `enabled` (dimmed,
  no tap) and `optional` (the same "optional" chip `_FieldRow` already had).
- Address keeps its own row, re-hinted "المنطقة، الشارع / Area, street", since
  the wilayat is no longer its job.
- Optional, not required: the registration gate is unchanged. Governorate is
  still the only location the app insists on.

### Model + display
- `UserProfile` gained `wilayat` (canonical English key, defaults to `''`, so
  every existing construction site and any profile already on file still
  compiles and decodes).
- The profile identity card now reads "Seeb, Muscat · Verified account",
  narrowest first, each part only when present.
- `_pickRegion`/`_pickWilayat` share one `_pickLocation` sheet, so the wilayat
  list looks and behaves exactly like the governorate list above it.

### Files
| File | Change |
|---|---|
| `lib/data/models/user_profile.dart` | `wilayat` field through the constructor, JSON, `copyWith`, `==`/`hashCode` |
| `lib/features/auth/register_screen.dart` | wilayat state + cascade reset, `_pickWilayat`, shared `_pickLocation`, `enabled`/`optional` on `_PickerRow`, address re-hinted |
| `lib/features/profile/profile_screen.dart` | identity line shows "Wilayat, Governorate" |
| `test/account_test.dart` | 2 new tests (list is the governorate's own wilayats and saves; changing governorate clears it) + `pickWilayat` helper |
| `test/models_json_test.dart` | `UserProfile` round-trip now carries a wilayat |

### Verified
- `flutter test` — 153 passed.
- `flutter analyze lib test` — clean apart from the pre-existing
  `use_null_aware_elements` info in `lib/core/utils/contact.dart:23`.
- **Not** run on a device or emulator.

### Known-adjacent, left alone
- Nothing consumes `UserProfile.wilayat` yet beyond display — service requests
  and orders still take their address from the free-text `address` line. Wiring
  the wilayat into delivery/dispatch is a separate decision.
- `add_car_screen`/`post_ad_screen` keep their own searchable popup for the same
  list; the two implementations were not merged.

---

## 2026-07-26 · Register: the phone row read backwards in Arabic

**Baseline:** `a854c2a`
**Request:** "in the register page, the phone number field need to update and
edit" — with a screenshot of the field under Arabic showing `98765432 968+`.

### The bug in the screenshot
The row painted `+968 ` as a plain `Text` before the `TextField` inside a `Row`.
Under Arabic the whole app is RTL, so the `Row` laid its children right-to-left
and the dial code landed *after* the digits — the number read `98765432 968+`,
with the caret at the far left. Nothing was wrong with the stored value; the
field just rendered a phone number as if it were Arabic prose.

- `_FieldRow` gained `forceLtr`, which wraps the value row in a
  `Directionality(ltr)` and sets `textDirection`/`textAlign`/`hintTextDirection`
  on the field. The **label** stays RTL — only the dial code + digits flip, which
  is how a phone number is written in both languages.
- A hairline divider now sits between `+968` and the digits so the dial code
  reads as a fixed prefix rather than part of the number.

### While in there — the field accepted things it then rejected
It was `digitsOnly` with no length cap and no paste handling, so pasting from
Contacts (`+968 9988 7766`, `00968…`, `968-99887766`) left `96899887766` in the
box and failed validation with "An 8-digit Oman number" — for a number that
*was* the user's 8-digit number.

- **New `_OmanMobileFormatter`** strips a leading `00968`/`968` and any leading
  zeros, caps at 8 digits, and groups them as `9200 1234` (matching the hint the
  field already showed). The caret is repositioned by counting digits, so editing
  mid-number no longer jumps to the end.
- **Landlines are refused** — `2x` numbers cannot receive the SMS the very next
  step sends. The message names the rule: "An Oman mobile number starting with 7
  or 9".
- Storage/format is `+968 9200 1234` (grouped) via `_fullPhone`, matching the
  mock profile and what the profile hub displays. Every comparison still goes
  through `_local()`, which strips non-digits, so old ungrouped values on file
  compare equal and do not trigger a re-verification.

### Files
| File | Change |
|---|---|
| `lib/features/auth/register_screen.dart` | `forceLtr`/`formatters` on `_FieldRow`, `_OmanMobileFormatter`, mobile-prefix validation, `_grouped()` display/storage |
| `test/account_test.dart` | 3 new tests (landline refused, paste normalisation, LTR under Arabic); existing phone expectations regrouped to `+968 9988 7766` |

### Verified
- `flutter test` — 151 passed.
- `flutter analyze lib test` — clean apart from the pre-existing
  `use_null_aware_elements` info in `lib/core/utils/contact.dart:23`.
- **Not** run on a device or emulator — the RTL fix is asserted in a widget test
  (field `textDirection` + nearest `Directionality`), not seen on screen.

### Known-adjacent, left alone
- Other phone entry points (`Contact.call` targets, mock provider numbers) are
  display/dial only — no other screen has a phone *input*, so the formatter was
  kept private to this file rather than promoted to `core/`.

---

## 2026-07-25 · Home page: the search pill now searches; three fabrications out

**Baseline:** `228e1d2` (uncommitted working tree, on top of the entries below)
**Request:** "check the main page and fix bugs and improve it. check the filter
and the search feature and fix issues"

### The headline bug: the search box was decorative
The home pill rendered a magnifier, the hint "ابحث عن خدمة، قطعة، أو سيارة… /
Search services, parts, cars…", and a filled circle with a sliders icon on the
end. Tapping anywhere on it ran `context.go('/services')`. Nothing was
searched, and the sliders button opened no filter — it was a picture of a
search box.

- **New `/search` screen** (`features/search/search_screen.dart`) doing what
  the hint says: one query across services, parts and car ads, grouped by
  section with counts, capped at four rows each and expandable in place (a
  "see all" that handed the query to another screen would drop it — none of
  the three list screens accept an incoming query). Results link straight to
  `/service/:id`, `/shop/product/:id`, `/cars/listing/:id`.
- **Empty state suggests real chips** — service categories, part categories
  and makes read off the catalogues, not a hand-written "popular searches"
  list nobody measured.
- The sliders circle became an arrow, because it now describes what happens.

### The search itself was matching too little
- **New `core/utils/search_match.dart`**: tokens are **ANDed**, not compared
  as one substring. "camry 2017" used to find nothing on the cars screen —
  the ad's title reads "2017 Toyota Camry SE", so the words are in the other
  order and `displayTitle.contains(q)` failed. Each token also gets a
  punctuation-stripped comparison, which is how "90915 yzze1" finds part
  number `90915-YZZE1`.
- `Product.matchesQuery` moved onto it; **new `GalleryListing.matchesQuery`**
  (make, model, trim, year, body type, region, localized region, seller) and
  **`ServiceOffering.matchesQuery`** (name, description, workshop, place).
- **Arabic search of a place now works.** Listing regions are stored as
  English keys ("Bawshar, Muscat"), and the cars screen matched that raw key,
  so an Arabic user searching "مسقط" got nothing. The localized name is now
  passed in by the caller — the models stay free of the location catalogue.

### Three fabrications on the main page
- **"Book · OMR 9"** on the summer AC banner. The cheapest AC service any
  workshop in the catalogue actually sells is OMR 13. The price now comes
  from `fromPriceFor('ac')`, sits in the descriptive line as "from OMR 13",
  and disappears entirely if no workshop sells the category. The button is
  just "Book now" — a pill has no room to ellipsize a CTA gracefully.
- **"Camry 2017"** as the maintenance card's car when nothing is saved — a
  car the user does not own, on a card whose entire purpose is that its
  numbers come from their own odometer. With no car the card now asks for
  one and routes to `/add-car`.
- **"الأكثر بحثاً / Most searched"** over what was simply the first four rows
  of the feed. Nothing in the app records searches. The rail now sorts by
  `postedMinutesAgo` and is titled "أحدث الإعلانات / Latest ads"; the string
  getter was renamed `mostSearched` → `latestAds`.

### The filter was fine
Audited `CarsFilterScreen` and `CarsFilter` end-to-end since the request named
it: the accordion's live counts come from `_draft.apply(feed, specs)` against
the unfiltered feed (not the already-filtered one, which would double-count),
Clear-all only touches the draft until Apply, and back pops `null` so a
cancelled visit leaves the applied filter alone. No changes were needed. One
adjacent nit left alone deliberately: the filter's "Show N results" ignores an
active search box, so the number can differ from the grid behind it — they are
separate concepts and merging them would surprise more than it fixes.

`InkPill` now wraps its label in `Flexible` with an ellipsis, after the longer
promo label overflowed it by 53px under the test font.

### Found and not fixed
Every car ad's Call/WhatsApp dials the same hardcoded `96892000000` — the same
bug already fixed for workshops. Six call sites across `cars_screen`,
`listing_card` and `listing_detail_screen`, plus a model and demo-data change.
Left out of this pass to keep it coherent; raised as a separate task.

**Verified:** `flutter analyze` — clean (same pre-existing
`use_null_aware_elements` hint in `core/utils/contact.dart`). `flutter test` —
148 passing, with four new search cases: "camry 2017" finds the Camry (the
token-order bug), "denso" and "battery" span parts and services, "مسقط" in the
Arabic build matches by localized place, and a nonsense query renders the
no-results state. The home smoke test's `الأكثر بحثاً` assertion was pinning
the mislabel and moved to `أحدث الإعلانات`, with the reason recorded above it.
Not verified: no device or emulator run this session.

---

## 2026-07-25 · Offers became a swipeable slider instead of one banner

**Baseline:** `228e1d2` (uncommitted working tree, on top of the entry below)
**Request:** "edit and update the offers section which it as slider and user
can see more than one advertising"

### What changed
- `bestOfferProvider` (one product) became **`offersProvider`** — every part
  with a live discount, deepest first. Still fully derived: an empty list
  means the section disappears entirely rather than falling back to evergreen
  ad copy.
- New `_OffersCarousel`: a `PageView` at `viewportFraction: 0.9`, so the next
  offer peeks in at the edge and reads as swipeable without an affordance,
  plus a dot indicator. With the current catalogue that is three real offers —
  LED kit −21%, cabin filter −20%, battery −13%.
- **Auto-advance every 6s**, implemented as a `Timer` that is *rescheduled
  after each page change* rather than a periodic one. A periodic timer would
  keep firing while the customer is mid-swipe and yank the page out from under
  them; rescheduling means touching the slider restarts the countdown. It is
  cancelled in `dispose`, which also keeps widget tests free of a pending
  timer.
- Each card now leads with the **cash saving** ("SAVE OMR 2.50") next to the
  percentage — the number a buyer actually compares — and carries a "View
  part ›" affordance; the "All offers" action moved up to a proper section
  header, where it sets `onOfferOnly` and shows only when there is more than
  one offer to see.

**Verified:** `flutter analyze` — clean (same pre-existing hint in
`core/utils/contact.dart`). `flutter test` — 144 passing. The banner test grew
into a slider test: it asserts the first page is the real −21% LED kit, that
"Up to 15% off" appears nowhere, and that dragging the `PageView` reaches the
−20% cabin filter. Not verified: no device or emulator run, so the auto-
advance was not watched in real time — only its scheduling and cleanup are
covered.

---

## 2026-07-25 · Shop page: real offers, a search that finds part numbers, sort

**Baseline:** `228e1d2` (uncommitted working tree, on top of the two entries
below)
**Request:** "improve the shop page and make it modern."

### The two things that were wrong, not just dated
- **The promo banner was fiction.** "خصم حتى 15% على البطاريات / Up to 15% off
  batteries · free fitting at partner workshops" was hardcoded. The battery in
  the catalogue is 28 down from 32 — 12.5%, not 15 — and nothing anywhere
  records free fitting. Same class of bug as the fake "Open" badge fixed on
  the service page and the invented provider ratings removed on 2026-07-13.
- **"الأكثر مبيعاً / Best sellers" sorted by `rating`.** Nothing in the
  catalogue records sales, and the rail was hardcoded to `itemCount: 3`, which
  would throw the moment a filter or a smaller catalogue left fewer than three
  products in it.

### What changed
- **The banner is now derived** (`bestOfferProvider`): the single biggest live
  discount in the catalogue, quoting that part's real percentage, name and
  before/after price, tapping through to it, with "All offers" setting the new
  `onOfferOnly` filter. If nothing is on offer the banner does not render at
  all. It also moved from the fixed `AppColors.sunsetGradient` (white text on
  amber, unreadable-adjacent in dark) to the `promoBg*/promoTitle/promoSub`
  tokens, which the theme already defines for both modes.
- **Rail renamed to "الأعلى تقييماً / Top rated"** — what it actually sorts by
  — and its count is `clamp(0, 5)` instead of a literal 3.
- **Search matches what is written on the part.** New `Product.matchesQuery`
  covers name (both languages), brand, and part number with punctuation
  stripped from both sides, so "90915 yzze1" finds `90915-YZZE1` and "denso"
  finds the Denso filter. It lives on the model, next to `fitsCar`, so the
  local search and a future `GET /products?q=` cannot drift.
- **Quick filters and sort.** `ShopFilter` gained `inStockOnly`, `onOfferOnly`
  and a `ShopSort` (recommended / price ↑ / price ↓ / top rated), all wired
  into `matches`, `activeCount` (sort excluded — it reorders, it does not
  filter), `toQueryParameters` and the filter sheet. Ordering is
  `ShopFilter.ordered`, which copies before sorting so the repository's warm
  cache can never be reordered underneath it.
- **Modernized layout**: `CustomScrollView` with a floating app bar, a
  **pinned search header** that stays reachable down the grid, and a real
  `SliverGrid` instead of a `shrinkWrap: true` `GridView` nested in a
  `ListView`. The grid uses `SliverGridDelegateWithMaxCrossAxisExtent` so a
  tablet gets more columns rather than two stretched cards.
- **Richer product cards**: brand line, delivery estimate, out-of-stock state
  (dimmed art, "Out of stock" tag, add button disabled and greyed) — all from
  fields the product page work added. Badges are `PositionedDirectional`, so
  they sit on the correct side in Arabic.
- **Empty state earns its keep**: different copy for "no search results" vs
  "filters too narrow", plus a Clear-filters button; the results header gained
  the same action, and uses `s.resultsCount` (Arabic-correct counted noun)
  instead of interpolating a bare number.

### Test that had to change
`screens_smoke_test` asserted `الأكثر مبيعاً`. That string was the mislabel,
so the assertion moved to `الأعلى تقييماً` with the reason recorded above it.
Three tests were added: the banner quotes the real -21% LED kit and no longer
contains "Up to 15% off"; searching "90915 yzze1" and "denso" both find the
oil filter and nothing else.

**Verified:** `flutter analyze` — clean (same pre-existing
`use_null_aware_elements` hint in `core/utils/contact.dart`). `flutter test` —
144 passing. One overflow was caught and fixed during the run (the banner's
discount-badge row, 11px in Arabic); the label is now `Flexible` with an
ellipsis. Not verified: no device or emulator run this session.

---

## 2026-07-25 · Service details rebuilt on the same pattern as the product page

**Baseline:** `228e1d2` (uncommitted working tree, on top of the product-page
entry below)
**Request:** "do same thing for the service details page"

### What was there
One `ListView` inside a provider card: name, a three-tile stat row, one
paragraph, the add-on wraps, and a book button. Three specific problems:

- **A fabricated "Open" badge.** `StatusBadge.good('مفتوح', 'Open')` was
  hardcoded on every offering — every workshop read as open at every hour of
  every day, including the ones whose demo hours say Friday closed. Nothing in
  the data ever said "open".
- **It was written against the legacy `AppColors` statics** (`AppColors.field`,
  `ink2`, `ink3`, `brand`), so the page did not follow the dark "Ink" theme —
  the stat tiles and body copy stayed light-theme colours in dark mode.
- **The workshop was a name and a distance.** No hours, no phone, no
  registration details, no way to contact it, and nothing about what the price
  actually covers or what happens when the job grows past the quote.

### What changed
- **Rewritten `service_detail_screen.dart`** as a `CustomScrollView` with a
  category-icon hero and a sticky book bar. Order: name/workshop/description →
  price card → duration / workmanship / payment facts → your car → **what's
  included** → **how it works** → add-ons → **workshop details** → same
  service at other workshops → other services here.
- **The "Open" badge is gone**, replaced by the workshop's real opening hours
  inside the details card. The page shows no rating and no review count for
  the same reason the provider-comparison cards stopped showing them on
  2026-07-13: the data does not contain any.
- **Theme-aware throughout** — every colour now resolves from
  `AkColors.of(context)`, so the page follows light/dark like the rest of the
  rebuilt screens.
- **New shared `features/services/provider_details_card.dart`.** The workshop
  record — verified mark, area/governorate/distance, hours, phone, **Oman VAT
  number**, commercial registration, VAT-invoice note, Call/WhatsApp, optional
  footer action — is now one widget used by *both* the service page and the
  parts product page, which grew its own copy yesterday. A buyer asks the same
  questions of a workshop whether they are buying a part or a service, and the
  VATIN in particular must not be formatted in two places. The product page's
  private `_sellerCard`/`_sellerRow` were deleted in favour of it; on the
  service side it also renders the fulfillment chips (visit / pickup with its
  fee / roadside) from the provider record.
- **`ServiceOffering` gained `includes` (the checklist of what the price
  covers) and `warrantyMonths`**, plus a `quoteOnly` convenience. Both are
  filled per *category* in `MockServiceData._copy`, not per workshop — same
  reasoning as the 2026-07-22 entry: two garages selling "Express service" are
  selling the same job, and a per-workshop checklist would invent a difference
  the real API will not return. `warrantyMonths` is null where a workmanship
  warranty is meaningless (roadside callout, annual contract, diagnostics).
- **Quote-only offerings get their own price card** — an amber panel that says
  the price comes after inspection and that no work starts without approval —
  instead of a stat tile reading "Quote / After inspection". Priced offerings
  show the 5% VAT split, matching the product page.
- **"How it works"** is four steps built from the app's real flow (book →
  fixed price or inspect-and-quote → track → pay after completion, funds held
  until the customer confirms), branching on `quoteOnly`.

### Two overflow guards worth keeping
The price row overflowed by 31px under the test font. Both price cards now
wrap the trailing element (`Fixed price` label, `Save OMR x` pill) in
`Flexible` with an ellipsis, so under a large text scale the label yields and
the price — the one thing that must never be clipped — always renders whole.

### Test that had to change
`translation_coverage_test` asserted `مفتوح` / `Open` on this screen. That
assertion was pinning the fabricated badge, so it was replaced with the
what's-included heading; the reason is recorded in a comment above the case so
the next reader does not "restore" the badge.

**Verified:** `flutter analyze` — clean (same pre-existing
`use_null_aware_elements` hint in `core/utils/contact.dart`). `flutter test` —
142 passing, including two new smoke tests asserting the service page prints
`OM1100047382` for the VAT-registered workshop and "Not VAT registered" for
the one without a VATIN. Not verified: no device or emulator run; the Arabic
and English pumps at 402×874 would have failed on an overflow, but nothing was
inspected visually.

---

## 2026-07-25 · Product details became a real page, with shop identity + VAT

**Baseline:** `228e1d2` (uncommitted working tree)
**Request:** "check the page of the product details. it needs to update and
improve. show the shop details and contacts also. see in the internet how the
product details of cars part shop should be and generate a modern page for my
project. also update the shops demo data to add the Oman VAT code and display
it with the shop details."

### What was there
There was no product *page* — `_ProductSheet`, a half-height modal inside
`shop_screen.dart`. It showed the name, rating, a fits-list, one paragraph of
boilerplate and a seller strip whose Call/WhatsApp buttons dialled two
hardcoded constants (`+96824000000` / `96892000000`) identical for every
seller in the catalogue. No part number, no brand, no specs, no stock, no
delivery, no warranty, no shop registration details.

### What a parts PDP actually needs
Checked current auto-parts commerce guidance (BigCommerce's 2026 selling-auto-
parts guide, scandiweb/VWO PDP practice) before designing. The recurring point
is that fitment is the section that decides the sale — roughly a third of
automotive e-commerce returns trace to fitment data that was not specific
enough — followed by part identity (brand + manufacturer part number the buyer
can cross-check against the part in their hand), then specs, then seller trust
and delivery. The page is ordered in that decision order rather than by visual
weight.

### What changed
- **New `features/shop/product_detail_screen.dart`**, routed at
  `/shop/product/:id`; `ShopScreen._openProduct` pushes it instead of opening
  the sheet. Sections: gallery app-bar (save/share, photo counter, discount
  pill) → brand + genuine/aftermarket badge + copyable part number → price
  card with the VAT split → fitment card → stock/delivery/fitting →
  description → spec table (collapsed past four rows) → warranty/returns/
  escrow → **shop details** → similar parts rail → sticky qty + add-to-cart.
- **Fitment card has three honest states**, not one: universal part, "select
  your car" when no car is saved, fits / may-not-fit when one is. It links
  straight into `ShopFilterSheet` to change the car.
- **Shop details card** shows the seller's real record — verified mark,
  localized area/governorate + distance, opening hours, phone, **Oman VAT
  number**, commercial registration — with copy-to-clipboard on the phone and
  VAT number, Call/WhatsApp wired to *that seller's* numbers (the WhatsApp
  message quotes the part name and part number), and "All parts from this
  shop" which sets `providerId` on the shop filter and pops back.
- **Models extended.** `Product`: `brand`, `partNumber`, `genuine`,
  `warrantyMonths`, `stock`, `deliveryDays`, `returnDays`,
  `fittingAvailable`, `specs` (new `ProductSpec`), plus `inStock` / `saving` /
  `discountPercent` / `universalFit`. `ServiceProvider`: `phone`, `whatsapp`,
  `vatNumber`, `crNumber`, `hours`, plus `vatRegistered`. All round-trip
  through `toJson`/`fromJson` and are covered by the existing
  `models_json_test` loops over the demo data.
- **Demo data filled in** for all six products and all eleven workshops.
- `AppConstants.vatRate = 0.05` (Oman standard rate); the price card shows the
  tax backed *out* of the price, because Oman shelf prices are quoted
  VAT-inclusive.
- `_Rating` / `_PriceLine` moved out of `shop_screen.dart` into
  `features/shop/product_widgets.dart` as `ProductRating` /
  `ProductPriceLine` / `DiscountBadge`, so the grid card and the page cannot
  render the same price two ways. New `savedPartsProvider` keeps saved parts
  out of `favoritesProvider`, which holds car-ad ids.

### The VAT decision worth remembering
An Oman VATIN is `OM` + 10 digits, issued by the Oman Tax Authority, and only
businesses over the registration threshold have one. So `vatNumber` is
**nullable**, and four of the eleven demo workshops (the unverified ones)
deliberately have none: the card then reads "Not VAT registered" and drops the
"issues a VAT invoice with every order" line, instead of printing a blank
field or implying a number exists. Both branches are pinned by tests.

**Verified:** `flutter analyze` — clean (the one remaining info is the
pre-existing `use_null_aware_elements` hint in `core/utils/contact.dart`,
untouched here). `flutter test` — 140 passing, including two new smoke tests
covering both VAT states and a new bilingual coverage case for the page. Not
verified: no run on a device or emulator this session; the phone-sized
(402×874) widget pumps would have failed on an overflow, but nothing was
inspected visually.

---

## 2026-07-22 · Region filter widened itself because the demo data had holes

**Baseline:** `5744a25` (uncommitted working tree)
**Request:** "the workshops demo data must be reviewed and update to match the
services page filter idea. still when user choose an area the filter view
workshops of other areas." — with a screenshot of the Arabic build: chip reads
"مسقط · 3 ورش", the Tyres sheet below it reads "ورشتان في مسقط وما حولها" and
lists Sohar and Salalah.

### Diagnosis
The filter was not broken — the data was. `_openCategory` opens a category
sheet widened when the selected governorate has *zero* offers in it, because a
filter with nothing behind it has nothing left to honour. Muscat had three
workshops but **no workshop selling tyres or diagnostics at all**, so every
Muscat user tapping either tile was silently shown other governorates. The old
data grew one offering at a time (`o1`…`o25`) with nobody checking coverage,
and four of the eleven categories had exactly one or two sellers nationwide.

Related: `MockCatalogData.serviceRegions` omitted `South Al Batinah` even
though `p7` (Barka) operates there — flagged as known-adjacent in the previous
entry, fixed here. Settings and the shop filter read that list, so Barka was a
workshop the user could never filter to.

### What changed
- **Demo data rebuilt around a coverage rule:** every governorate carries at
  least two workshops that between them sell *all eleven* categories. 11
  providers across 5 governorates (Muscat 3; North Al Batinah, South Al
  Batinah, Ad Dakhiliyah, Dhofar 2 each), 72 offerings.
- Offerings are now expanded from a `_catalogue` matrix (provider → category →
  price/duration) crossed with per-category `_copy`, instead of 25 hand-written
  entries. The matrix is the reviewable artefact — a hole is visible by
  reading down a governorate's block. Ids became `o-{provider}-{category}`.
- Wording is shared per category rather than varied per workshop: a demo file
  inventing a distinct sales pitch per workshop is fabricating detail the real
  API will not return.
- Every provider now has add-ons (was p1–p3 only), so the booking extras step
  is never empty in a way that reads as a loading bug.

### Two bugs the denser data exposed
- **`_AddOnRow` overflowed** (`service_detail_screen.dart`) — a fixed `Row` of
  `Expanded` cards cannot hold more than two add-ons; three overflowed by
  23–43px. Replaced with a `LayoutBuilder` + `Wrap` that picks a column count
  from the available width. The count of extras is the API's to decide.
- **"Look beyond" stopped adding anything.** The shortlist capped the
  *combined* list at 6, so a governorate with 6+ local offers swallowed every
  result from beyond it — the button changed the header and nothing else. Each
  group is now capped on its own.

### Files
| File | Change |
|---|---|
| `lib/data/datasources/mock/mock_service_data.dart` | rewritten — 11 providers grouped by governorate, `_catalogue` coverage matrix, `_copy` per-category wording, generated `offerings`, add-ons for every provider |
| `lib/data/datasources/mock/mock_catalog_data.dart` | `serviceRegions` gains `South Al Batinah`, with a note on why it must track the providers |
| `lib/features/services/services_screen.dart` | cap `local` and `nearby` separately so widening always adds rows |
| `lib/features/services/service_detail_screen.dart` | `_AddOnRow` → `LayoutBuilder` + `Wrap`, card extracted to `_card` |
| `test/services_region_test.dart` | **new** coverage guard (every governorate sells every category, ≥2 workshops) and catalogue/provider region agreement; `settleEntrances` helper; region-scoped price/count assertions updated |
| `test/translation_coverage_test.dart` | fixture id `o1` → `o-p1-express` |

### Verified
- `flutter test` — 136 passed.
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements` in `lib/core/utils/contact.dart:23`) is
  pre-existing and unrelated.
- **Not** run on a device or emulator — the Tyres-in-Muscat sheet from the
  screenshot was not visually re-checked; the coverage test asserts the data
  behind it (`providerCountFor('tyres', region: 'Muscat')` is now 2, was 0).

### Known-adjacent, left alone
- `regionProvider` can still be set to an unserved governorate: `add_car` and
  `register` write whichever governorate the user typed, from the full list of
  11, not from `serviceRegions`. The services page handles it honestly ("No
  workshops in Musandam yet — here are the closest"), but a user who registers
  in Musandam lands on a permanently widened services page. Constraining the
  write, or prompting for a nearest served governorate, is a follow-up.
- Distances are still measured from a notional Muscat user and do not move
  when the region filter does — Salalah reads "45 km" whether you are in
  Muscat or in Salalah. Real distances need the user's location.

---

## 2026-07-22 · Services page: numbers on screen disagreed with each other

**Baseline:** `5744a25` (uncommitted working tree)
**Request:** "fix and edit and update the services page data and view. test and
fix issues." — with two screenshots of the Arabic build.

### What the screenshots showed
1. **The chip said 14, the picker said 3.** The chip counted *offers* in Muscat
   (14) under a "ورشة/workshops" label; the picker counted *workshops* (3).
   Both were on screen at once, contradicting each other.
2. **Broken Arabic plurals.** "3 ورشة" and "2 ورش" — Arabic inflects a counted
   noun by the number in front of it (singular for 1, a dual form for 2, broken
   plural for 3–10, singular again from 11). Counts were interpolated inline,
   so every one of them was ungrammatical for some value.
3. **Package-card numbers were nationwide** while the chip above them was
   region-scoped, so "3 ورش" sat above a list filtered to Muscat.
4. **Category prices were fabricated.** `ServiceCategory.fromPrice` was a
   hardcoded literal: `full` claimed "from 30" when the cheapest real offering
   is 28 (Nizwa), and `diag`/`tyres` advertised a price to Muscat users when no
   Muscat workshop offers them at all.
5. **`ServiceCategory.providerCount` was invented data** — `express: 6` when
   three offerings exist. Nothing read it (the UI already used the derived
   count), so it sat in the model contradicting reality.
6. The picker sheet's last row sat flush against the bottom nav bar.

### Fixes
- **One definition of "workshop" everywhere**: distinct providers. Chip,
  picker, category sheet, and the widen button all count that. Offer counts are
  never labelled as workshops.
- **`S.count()` + `S.workshops/services/resultsCount`** in `core/i18n/strings.dart`
  handle Arabic inflection (`ورشة واحدة` / `ورشتان` / `3 ورش` / `14 ورشة`) and
  English plurals. Counts no longer get interpolated inline.
- **Real, region-scoped category stats**: `providerCountFor(id, {region})` and
  the new `fromPriceFor(id, {region})` derive from the offerings. A category
  with no local workshop shows "خارج المحافظة / outside your area" instead of
  a price that cannot be booked.
- **Deleted `providerCount` and `fromPrice`** from `ServiceCategory`, its JSON,
  and the mock data — fabricated numbers with no source of truth.
- Sheet bottom padding 16 → 28; `s.km` used instead of re-inlining the unit.

### Files
| File | Change |
|---|---|
| `lib/core/i18n/strings.dart` | `count()` + `workshops()` / `services()` / `resultsCount()` |
| `lib/data/models/service_category.dart` | removed `providerCount`, `fromPrice` (ctor, JSON, copyWith, ==, hashCode) |
| `lib/data/datasources/mock/mock_service_data.dart` | dropped the 20 fabricated count/price lines |
| `lib/data/repositories/service_marketplace_repository.dart` | `region` param on `offeringsFor`/`providerCountFor`; new `fromPriceFor` |
| `lib/features/services/service_widgets.dart` | region-scoped package card, workshop-based counts, `WidenSearchButton.workshops` |
| `lib/features/services/services_screen.dart` | chip counts workshops, result line uses `resultsCount`, sheet padding |
| `test/services_region_test.dart` | +3 tests: chip/picker agreement, region-scoped card counts and prices, Arabic inflection |

### Verified
- `flutter test` — 134 passed (was 131; three added).
- `flutter analyze lib test` — clean apart from the pre-existing
  `use_null_aware_elements` info in `lib/core/utils/contact.dart:23`.
- `flutter build web` — compiles.
- **Not visually confirmed.** A release bundle was built and served at
  `127.0.0.1:5599`, but the browser pane could not composite frames, and
  Flutter web paints to canvas so there is no DOM text to assert against. The
  string-level checks are the widget tests, which render the real tree.

### Checked, not a bug
- The "⋯"-looking icon in the screenshot's fourth row is `Icons.local_car_wash`
  clipped by the viewport edge, not a missing glyph. `IconCodec` is a static
  registry precisely so `--tree-shake-icons` cannot strip API-named icons.

---

## 2026-07-22 · Services page: region filter did not filter

**Baseline:** `5744a25` (uncommitted working tree)
**Request:** "check the services page needs to improvements and there are some
bugs. when user choose an area from the filter the work shops sometimes view
works hops from areas not selected in the filter" → then: "improve the idea of
filtering because a little confused me. make it friendly."

### The bug
The region chip only **sorted** results — it never filtered. `_results()` pushed
in-region offerings to the front, then the page took the first 6 and titled them
"Popular near you". Any governorate with fewer than 6 offerings had the
remainder silently filled in from Muscat, Sohar, Nizwa, etc., presented as local.

Three related defects found in the same pass:
- The category comparison sheet (`_openCategory`) ignored the region entirely.
- The region picker listed all 11 Oman governorates, including ones with zero
  providers, so a filter could be selected that could never match.
- Search matched place names only against the canonical English key — "صحار" or
  the area name "Qurum" found nothing.

### The model now
**The chip filters; nothing else appears unless the user asks.**

- Chip shows the count up front (`Muscat · 9 workshops`), so a short list reads
  as complete rather than broken.
- Picker sheet states the rule ("workshops in this governorate only") and shows
  a workshop count per governorate, built from `providerRegions` — derived from
  real providers, so it cannot offer an empty one.
- One list, one meaning. Widening is an explicit "Look beyond {region}" button;
  it flips the header/chip to "& around", offers "Show only {region}" to undo,
  and resets whenever the governorate changes.
- The single automatic widening is a governorate with zero workshops, where
  there is no filter left to honour — and it announces itself first.
- "Near you" replaced with real distance in km, since results can now come from
  further out.

### Files
| File | Change |
|---|---|
| `lib/features/services/services_screen.dart` | filter/widen state (`_widenedFrom`), chip counts, region picker sheet, `_Notice`/`_RegionOption`, distance on cards |
| `lib/features/services/service_widgets.dart` | `splitByRegion` (in-region cheapest-first, beyond it closest-first), region-aware category sheet, shared `WidenSearchButton`, `outsideRegion` row marker |
| `lib/data/repositories/service_marketplace_repository.dart` | added `providerRegions` |
| `test/services_region_test.dart` | **new** — strict filtering, opt-in widening + undo, empty-governorate explanation, sort order |
| `test/translation_coverage_test.dart` | services-screen header assertion updated ("Popular near you" → "Popular in Muscat") |

### Verified
- `flutter test` — 131 passed.
- `flutter analyze lib test` — clean; the one remaining info (`use_null_aware_elements`
  in `lib/core/utils/contact.dart:23`) is pre-existing and unrelated.
- **Not** run on a device or emulator — no visual confirmation of the new chip,
  picker sheet, or widen flow.

### Known-adjacent, left alone
- `ServicePackageCard` shows a nationwide workshop count, not a per-region one.
  It matches the sheet's total across both groups, so it is consistent — but if
  the cards should count only the selected governorate, that is a follow-up.
- The static `MockCatalogData.serviceRegions` list omits `South Al Batinah`
  even though provider `p7` (Barka) operates there. The services page no longer
  reads it, but the shop filter and the `regionProvider` default still do.
