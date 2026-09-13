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

## 2026-09-13 · API log triage: two EF warnings fixed, the SQL error was environmental

**Baseline:** `00e1d90` (this repo). **The code changed is in the API repo**
(`AKCarsMobileAPI`), logged here because this is where the running edit log lives.

Request, verbatim: "check the logs and fix the bugs:" followed by an
`AKCars.Api` development-run log.

### What the log actually contained

1. **`SqlException 18461` — "Server is in single user mode"**, hitting a request
   query and then both background services at 13:57. **Not a code bug and
   nothing was changed for it.** SQL Server (`.\SQLEXPRESS`) had been started
   with `-m`, so only one administrator could connect. Checked live during this
   session: `SERVERPROPERTY('IsSingleUser') = 0`, `UserAccess = MULTI_USER`,
   `Status = ONLINE` — it had already cleared.

   Worth recording because the stack trace *looks* like a crashed background
   service: it names `AutoReleaseHostedService.ExecuteAsync` line 33 and
   `ApprovalReminderHostedService.ExecuteAsync` line 30. Both were read and
   both are correct — the `try/catch` is inside the `do { } while
   (await timer.WaitForNextTickAsync(...))` loop, so a failed tick is logged and
   the next one runs five minutes later. The frames appear only because the
   exception carries its original stack. The escrow auto-release and the 24h
   approval reminder were never at risk of dying with the database.

2. **`MultipleCollectionIncludeWarning` ×3 on every cold start** — real, fixed.
   `ServiceRequest` carries three collections (`History`, `AddOns`, and the
   owned `ProofMedia`) and `MaintenanceBook` two (`Records`, `CustomItems`), so
   every list query over them returned the cartesian product of those
   collections in a single result set. The row count multiplies with a
   booking's history, not with the number of bookings, so it gets worse as the
   pilot accumulates real data.

   Fixed by `UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery)` on
   the SqlServer builder in `AKCars.Infrastructure/DependencyInjection.cs`.

   **First attempt was wrong and was reverted:** `.AsSplitQuery()` was added to
   the eight affected queries in `AKCars.Application`, which does not compile —
   `AsSplitQuery` is in EF's *Relational* package and `AKCars.Application`
   references only `Microsoft.EntityFrameworkCore`, on purpose: the application
   layer is not supposed to know its provider. The revert was done by reversing
   each edit rather than `git checkout`, because that repo has a lot of
   unrelated uncommitted work. (A stray BOM introduced by the edit script was
   stripped from all nine files; `git diff` was used to confirm only the
   intended change remains.)

3. **`'First'/'FirstOrDefault' without 'OrderBy' and filter operators`** —
   real, fixed. `GetVehicleCatalogQueryHandler` read the `CatalogSettings`
   singleton with a bare `FirstOrDefaultAsync`. One seeded row exists today, so
   nothing is currently wrong, but the query asks SQL Server for "any row" — if
   a second ever appeared, the catalogue's earliest selectable year would flip
   between page loads. Now `OrderBy(c => c.Id).FirstOrDefaultAsync(...)`.

### Found and deliberately not fixed

The app warms **every** provider on cold start:
`ServiceMarketplaceRepository._warmProvider` runs for each entry in
`_providers.value`, fetching add-ons and tomorrow's slots — two requests per
provider. That is the 20-request burst visible at 13:23:12 and 13:56:52 with
ten providers, and it grows linearly with the number of workshops on the
platform.

Not fixed here because it is not a one-line change: `addOnsFor()` and
`availabilityFor()` are **synchronous** cache reads used directly by
`booking_screen.dart`, `quote_screen.dart` and `service_detail_screen.dart`, so
making the fetch lazy means giving those three screens real loading states.
That is a scoped piece of work, not a side effect of reading a log — raised for
the user's decision.

### Verified

`dotnet build src/AKCars.Infrastructure` — 0 warnings, 0 errors.
`dotnet test tests/AKCars.Tests` — **984 passed, 0 failed**. The full solution
build cannot link while the API is running (the .exe holds the DLLs), so the
tests were built to a scratch `BaseOutputPath` rather than stopping the user's
server.

**Not verified:** the split-query behaviour itself. The test suite runs on the
EF in-memory provider, which ignores a SqlServer-specific option, so the proof
that the warnings are gone is the next real cold start against SQL Server.

---

## 2026-09-13 · First-run screens rebuilt around what the app actually does

**Baseline:** `00e1d90`.

Request, verbatim: "check the pages which works first time when install the app
. that pages need to improve  and recreate. also the idea of telling users what
we provide and what we have. improve the user expereance also."

The first-run flow is three screens: `/splash` → `/onboarding` → `/start-choice`
(`AuthState.initialRoute`), each seen once per install.

### What was actually wrong

1. **The tour sold a pillar this build does not ship.** Slide 2 of 2 was the
   parts store — "Shop parts for your car … with filters for category,
   provider, price, and region" — while `AppFlags.partsStoreEnabled` has been
   `false` since the phase-1 refocus, which compiles the Shop tab, its routes
   and every entry point into it out of the build. Half the tour described a
   feature the user could not then find.
2. **The tour never mentioned escrow.** The thing that makes this app different
   from phoning a workshop — the money is held and released only on the
   customer's approval — appeared nowhere in the intro, so the one remaining
   truthful slide undersold the product.
3. **The welcome screen said nothing.** "Everything your car needs… in one
   place" is true of every automotive app ever shipped.
4. **No sign-in on the way in.** Login existed only in the profile tab, so a
   user reinstalling or switching phones had to sit through an intro for a
   product they already use, and answer a car question about a car they had
   already registered, before getting their bookings back.
5. **The skipper learned nothing.** Both exits from step 3 ("Skip", "Not now")
   drop straight into the app, and the tour is skippable from two screens
   earlier, so it was possible to reach the shell having been told nothing.

### The change

- **New `lib/features/onboarding/intro_content.dart`** — the single source of
  what the app claims it does, built from the same `AppFlags` that decide what
  is reachable. `introSlides()`, `capabilityHighlights()`, `introChips()`. The
  parts and marketplace slides live there behind their flags, so flipping a
  flag restores the tab and its slide together; neither can drift again.
- **Tour rebuilt** (`onboarding_screen.dart`): four slides on the real phase-1
  product — verified workshops → money held until you approve → itemised
  part+labour quote → live tracking and service history. Each carries three
  proof chips, which is what a user skimming in four seconds actually reads.
  Dots are now tappable (they were a 7px target with no hit padding), and each
  slide scrolls rather than overflowing at large text scales.
- **Welcome screen** (`splash_screen.dart`): concrete tagline, a three-chip
  capability strip above the fold, and an "Already have an account? Sign in"
  link that pushes `/login` (`AuthNotifier.login` already records both
  first-run flags, so a returning user answers nothing). Layout now
  LayoutBuilder + minHeight + IntrinsicHeight so the Spacer-based hero still
  centres on a normal phone but scrolls on a short one.
- **Step 3** (`start_choice_screen.dart`): a "What AK Cars does for you" recap
  card from `capabilityHighlights()` — the last place the app can say what it
  is for before the user is expected to go and find out.

Two things were fixed in the product rather than worked around in a test: the
recap's reminder line duplicated the "Add my car now" card's benefit line word
for word on the same screen (reworded), and the longest Arabic proof chip
overflowed a 320pt screen by 2.5px (the chip label is now `Flexible`).

### Not done

`AppFlags.partsStoreEnabled` / `carMarketplaceEnabled` were left off. The copy
now follows them instead of contradicting them; whether phase 2 turns on is the
user's call, not a side effect of fixing the intro.

### Verified

`dart analyze lib/features/onboarding/` — no issues. `flutter test` — 602
passing (597 before, 5 new). New tests: the tour never names a flag-hidden
pillar; the tour states the escrow promise; the welcome screen fits 360×640 and
320×568 in both languages; every tour slide fits 320×568 in Arabic. The
overflow tests were written after hitting both overflows for real, not
speculatively. Not run on a device or emulator — no screenshots taken.

---

## 2026-09-13 · Auth gate's primary option was unreadable in dark theme

**Baseline:** `00e1d90`.

Request, verbatim: "when user change to dark theam and click on login this
happen. colors are mismatched. fix them" (with a screenshot of the dark-theme
auth gate dialog).

### What was actually wrong

`_GateOption` in `lib/features/auth/auth_gate_screen.dart` painted the primary
("لديّ حساب" / "I have an account") card with `ak.ink` and hardcoded every
foreground on it to `Colors.white`. Those two tokens only agree in the light
theme: `ink` is near-black in Sand, but in Ink (dark) it inverts to cream
`#F2EFE8` — so the card came out light cream with white title, white subtitle,
white chevron and a white-on-white icon tile. Effectively invisible text.

The card's shadow had the same bug: `ak.ink.withValues(alpha: 0.18)` is a pale
glow in dark theme, not a shadow.

### The fix

- Background now reads `ak.primary` and all foregrounds read `ak.onPrimary`.
  That pair is defined to invert together (light: ink bg / cream fg; dark: cream
  bg / ink fg), which is exactly the contract this card needs.
- Icon-tile wash switched from `Colors.white @ 16%` to `ak.onPrimary @ 12%`.
- Card shadow switched to `Colors.black @ 18%`.
- The dialog title got an explicit `color: ak.ink` instead of inheriting an
  implicit theme text color.

The only remaining `Colors.white` in the file is the car icon on the header's
`AppColors.brandGradient`, which is a dark ink gradient in both themes — correct
as-is.

### Verified

`dart analyze lib/features/auth/auth_gate_screen.dart` — no issues. Not
re-screenshotted in a running app; the change is a token swap with no layout or
logic effect.

---

## 2026-09-04 · A per-caller catalogue response was marked publicly cacheable

**Baseline:** `00e1d90` here (no app-side change); `AKCarsMobileAPI` at `74b1305`,
changed in its own repo.

Request, verbatim: "review the code for api and flutter project for any possible
bugs and issues then fix them. After finish write small explanation about what
you did."

### What was actually wrong

`GET /api/v1/service-marketplace/offerings` set
`Cache-Control: public, max-age=300`, but its body is **not** the same for every
caller. `GetOfferingsQuery` branches on `ICurrentUser` twice:

- a founder additionally receives the offerings of workshops that are *not*
  approved yet (everyone else is filtered to `Stage == Approved`);
- `CatalogueMappers.ToPublicDto` keeps the nested provider's CR document scan,
  VAT number, CR number and the owner's personal phone for a founder or for the
  workshop's own owner, and strips them for everybody else.

`public` tells *any* shared cache — a CDN, a corporate proxy — that one stored
copy may be handed to every later caller. So a founder's response could be
served to the next anonymous visitor for five minutes, handing out workshop
identity documents, owner phone numbers and unapproved workshops to strangers.

This was latent rather than observed: no shared cache sits in front of the API
today. It is a header promising something untrue, and the promise is only wrong
once something starts believing it.

### The fix

**Files:** `src/AKCars.Api/Endpoints/MarketplaceEndpoints.cs` (API repo).

A second helper beside `Cacheable`, used only by `/offerings`:

    private, max-age=300
    Vary: Authorization

`private` keeps the response in the one caller's own HTTP cache. `Vary:
Authorization` keeps it correct even there — the app sends a bearer token and a
guest sends none, so signing in or out no longer re-serves the previous
identity's snapshot.

`/promotions` and `/offers` were left `public` deliberately, and that is now
asserted rather than assumed: their handlers take no `ICurrentUser` at all, so
they really are the same for everyone.

### What was checked and found *correct* (no change made)

Recorded so the same ground is not re-covered later:

- `ToPublicDto`'s founder/owner gating of CR document, VAT/CR and owner phone.
- The new `MediaValidation`/`MediaRules` allowlist, its size pre-check, and every
  call site's `.When(... is not null)` guard on optional photos.
- `ApplyEscrowEventCommandValidator`'s `RuleForEach(x => x.Proof!.Media)`. The
  `Proof!` looked like an NRE waiting for any event sent without proof; it is
  not — FluentValidation evaluates the rule-level `.When` before touching the
  collection. Pinned by a test rather than left to be re-suspected.
- Both new migrations add only nullable columns — no repeat of the
  `defaultValue: false` backfill that once switched every offering inactive.
- Notification dismissal (`DismissedAt`) filters consistently across all four
  handlers; founder-only authorisation on every new offer/promotion/badge slice.
- Flutter: every `double.parse`/`int.parse` on a text field is gated behind a
  `tryParse`-based `_ready`/`_canSave` guard, so no editor can crash on input.

### Known-adjacent, not fixed (needs a product decision, not a bug fix)

`ServiceProvider.Photo` is half-wired: the API has the column, the migration and
the validation, and both `UpdateMyWorkshopCommand` and
`AdminUpdateProviderCommand` set `provider.Photo = null` whenever the request
carries no photo. No Flutter client ever *sends* or *reads* a provider photo —
the Dart `ServiceProvider` model has no photo field at all — so nothing is lost
today. The moment a photo-upload UI is added, every unrelated profile edit
(name, hours, pickup fee) will silently delete the photo, because the client
does not round-trip it the way the offering editor does. Offerings are fine:
that editor preloads the existing photo and resends it.

Also unaddressed: `GetOfferingsQuery` does `.Include(o => o.Provider)`, which
materialises each provider's full `varbinary(max)` `PhotoData` and `CrDocument`
once per offering, even for callers whose response strips them. A projection
would fix it; that is a larger change than this pass.

### Verified

- `dotnet build` — 0 errors, 0 warnings.
- `dotnet test` — 984 passed, 0 failed (980 before, plus 4 added here).
- New `CatalogueCachingIntegrationTests` asserts `/offerings` is `private` +
  `Vary: Authorization` and that `/promotions` and `/offers` stay `public`.
  Confirmed non-vacuous: reverting the one-line fix makes it fail with "GET
  /offerings varies by caller and must be `private`", and it passes again once
  restored.
- New `EscrowProofValidationTests` covers an escrow event with no proof.
- Flutter side: `flutter analyze` clean, `flutter test` 595 passed. **No Dart
  file was changed** — the app sends no `Cache-Control` request headers and
  reads the catalogue through its own warm caches, so this fix needs nothing
  from the client.

---

## 2026-09-02 · The inbox's delete was broken two ways, from one cause

**Baseline:** `00e1d90` here; `AKCarsMobileAPI` changed in its own repo. Fixes
the 2026-09-01 (4) entry below.

Request, verbatim: "Last time I asked you to update the notification page but I
think there some bugs. Check the notifications idea in both sides: api and
flutter. Review, test, fix issues. And make sure is working properly."

### What was actually wrong

Both defects were on the **Flutter** side, and both came from the same decision:
the notifier wrote optimistically and the list matched its rows by index.

1. **A refused delete crashed the list.** `Dismissible.onDismissed` fired, the
   notifier removed the row, the call failed, the rollback put the same
   `ValueKey` back — into a tree that had already recorded that key as
   dismissed. Flutter asserts on exactly this: *"A dismissed Dismissible widget
   is still part of the tree."*
2. **And the card did not come back.** After the assertion the row was simply
   gone until the next fetch — the reader was left believing something was
   deleted that the server had refused to delete. The previous entry's own doc
   comment claimed the rollback prevented this. It did not, and nothing tested
   it.
3. **Rows were matched by index.** `ListView.itemBuilder` returned an unkeyed
   `Entrance`, so deleting a card handed its element — including the live
   `_DismissibleState` — to whichever notification moved up into that slot. That
   is the mechanism behind (1), and it also replayed every entrance animation
   below a deletion.

### The fix

* **Writes are no longer optimistic.** `_write` (apply-then-roll-back) became
  `_apply`: await, then adopt the inbox the server returns. These routes answer
  with the remaining visible inbox precisely so the screen cannot drift from it,
  and there is now nothing to roll back.
* **The swipe is held open across the round trip** — `confirmDismiss` instead of
  `onDismissed`. It returns `true` only if the server agreed; `false` springs
  the card back, which is both the honest answer and better feedback than a
  card vanishing and reappearing.
* **Every row is keyed by notification id.**

Trade-off worth naming: deleting from the overflow menu now waits for the round
trip before the card goes, where before it went instantly and sometimes lied.
The swipe covers its own latency with the drag; the menu does not.

### What was checked and found correct

* **The API side has no equivalent bug.** All four queries that read
  `db.Notifications` filter `DismissedAt == null` — `GetNotifications`,
  `MarkAllRead`, and both handlers in `InboxActions`. `NotificationSender` only
  inserts. There is no path that resurfaces a dismissed row.
* **Every route is mapped and authorised.** With the API running, all six
  answered `401` rather than `404`/`405`, including the two riskiest: the
  empty-pattern `DELETE /notifications` and the pre-existing
  `DELETE /notifications/devices/{token}`, which the new `{id:guid}` route
  could have shadowed and does not.
* **The wire contract matches.** `Program.cs` sets camelCase; `NotificationDto`
  emits `{id, title:{ar,en}, body:{ar,en}, icon, time, read, route}`, which is
  exactly what `AppNotification.fromJson` and `L.fromJson` read. `Guid`
  serialises to a string for `requireString('id')`, `DateTime` to ISO-8601 for
  `dateTimeOr('time')`.
* **The migration caveat from the last entry is resolved.** The API was no
  longer holding a lock on its build output, so the hand-written migration was
  replaced with a properly scaffolded `20260902172823_AddNotificationDismissedAt`
  (now with its `.Designer.cs`). Before swapping it, a throwaway scaffold came
  out **empty** against a real build — proving the hand-written file and the
  snapshot had been correct all along.
* `Entrance` leaves an uncancelled `Future.delayed` per row. It is guarded by
  `mounted`, so it cannot crash — it only means a widget test must pump past the
  delay. Left alone: it is shared code, pre-existing, and outside this request.

### Verified

* `flutter analyze` clean; `flutter test` **595 passing** (was 589).
* New `test/notifications_screen_test.dart` — six widget tests pinning the two
  bugs: a swipe that succeeds, **a swipe the server refuses (the card must come
  back, and nothing may assert)**, tap-marks-read, deleting the last card
  reaching the empty state, a push landing on top while the list is open, and
  **deleting after a push removing the right card** — the one that fails if rows
  go back to index matching.
* `dotnet test` **980 passing**, run this time with a normal build (no
  `-p:BuildProjectReferences=false` needed).

### The gap

Still **not exercised with a signed-in session end to end**. Reaching one would
mean creating an account or entering a password, which I do not do. Everything
either side of the token is covered — routes and auth over real HTTP, handler
behaviour against a real `DbContext`, the UI against the service double — but
the single round trip through a live JWT is not.

**Files:** `lib/state/notifications_state.dart`,
`lib/features/home/notifications_screen.dart`,
`test/notifications_screen_test.dart` (new),
`AKCarsMobileAPI/src/AKCars.Infrastructure/Persistence/Migrations/20260902172823_AddNotificationDismissedAt.cs`
(replaces the hand-written `20260901161747_…`), and that migration's
`.Designer.cs` + `AkCarsDbContextModelSnapshot.cs`.

---

## 2026-09-01 (4) · The notification inbox gets actions, and a memory

**Baseline:** `00e1d90` here; `AKCarsMobileAPI` changed in its own repo.

Request, verbatim: "in the notifications page, users can remove the notification
cards only as hide and let them available in the database. so user can cacele or
delete one notification and also can cancel or delete all notifications. also
users can mark as red"

### The shape of it

`Notification` gains **`DismissedAt: DateTime?`** — null while it is on the
owner's list. Every read (`GetNotifications`, `MarkAllRead`) filters it out, and
three new commands write it:

* `DELETE /notifications/{id}` — dismiss one.
* `DELETE /notifications` — dismiss the lot.
* `POST /notifications/{id}/read` — mark one read.

The verb is DELETE because that is what the caller means; what the server does
is stamp a timestamp and keep the row. Whether a customer was told their money
moved is a question support answers months later, and an inbox is the first
thing anybody clears out — so the button says delete, the reader stops seeing
it, and the record survives. All three answer with the **remaining visible
inbox** rather than 204, the shape `MarkAllRead` already used, so the screen
rebuilds from the server's answer instead of guessing.

Two details worth keeping: a dismissal is idempotent (a retry does not rewrite
*when* it happened), and somebody else's notification is a **404, not a 403** —
403 would confirm the id exists.

### The read state, which had to change to make the request possible

`NotificationsScreen` marked **everything** read from `initState`. That made the
unread count a number that could only ever be zero by the time anyone looked at
it, and left "mark as read" with nothing to do. So reading is now something the
reader does: tapping a card marks that one, its overflow menu marks it without
opening it, and an app-bar action marks the lot. Unread is carried by a tinted
surface, an inverted icon tile and a dot — not by font weight alone, which only
reads as a state when both weights are on screen together.

**This is a behaviour change the request implied rather than asked for**, and it
is the one thing here worth a second opinion: the badge on the home bell now
stays lit until the reader acts, where before it cleared itself.

### The rest

Swipe-to-dismiss in both directions with a red captioned background, plus a
per-card menu — the menu exists because a reader who never discovers the gesture
would otherwise have no way to these actions at all. "Delete all" confirms
first; a single dismissal does not, because a swipe is already deliberate and
what it removes is a message *about* something, not the something.

`NotificationsNotifier` writes optimistically and **rolls back on failure**,
which is the half that makes optimism honest — a dismissal the server refused
has to come back, or the reader believes something is gone that will reappear on
the next fetch. The screen surfaces that failure in a snackbar rather than
letting the list silently snap back.

`ApiClient` gains `deleteList` (DELETE routes answering with a collection);
`OfflineApiClient` refuses it like the rest.

### A fake that was lying

`MockNotificationService.push` minted ids from
`DateTime.now().microsecondsSinceEpoch`. That has **millisecond** resolution on
Windows, so a loop pushing three notifications gave all three the same id — and
dismissing one then hid every one of them. Replaced with a counter. Worth
noting because it was only visible once something keyed off ids; every test
before this one compared whole objects.

### Verified

* **App:** `flutter analyze` clean, `flutter test` **589 passing**, including 8
  new in `test/notifications_inbox_test.dart`. The load-bearing ones count rows:
  after dismissing one of three the list holds two and the store still holds
  three; after dismissing all the list is empty and the store still holds four.
  Plus: a dismissed row does not return on refetch, marking all read skips
  dismissed rows, and a failed dismissal restores the list.
* **API:** `dotnet test` **980 passing**, including 8 new in
  `InboxActionCommandTests.cs` — the row survives, the query stops returning it,
  a second dismissal keeps the first timestamp, a stranger's id is a 404, "all"
  stops at the caller's own rows, and an anonymous caller gets 401.
* A temporary widget check (deleted) rendered the screen in **ar/en ×
  light/dark**, then drove the real controls: the card menu's Delete removed the
  card while the store kept all four rows, "Mark as read" disappeared from the
  menu once used, and "Delete all" showed its confirmation before emptying the
  list.

### Two caveats

* **The migration is hand-written.** `dotnet ef migrations add` has to load a
  freshly built startup assembly, and the API was running from Visual Studio,
  holding a lock on `AKCars.Apiin`; with `--no-build` the scaffolder diffs
  against the stale assembly and emitted an empty migration twice. The column is
  one nullable `datetime2` with no default and no backfill (NULL = visible,
  which is what every existing row already is), the model snapshot was updated
  alongside it, and regenerating it properly with the API stopped is safe and
  would produce the same two statements.
* `dotnet test` again needed `-p:BuildProjectReferences=false` for the same
  lock. The Application project was built clean separately, and these tests call
  handlers directly rather than endpoints. **Nothing was walked in a browser.**

**Files (app):** `lib/features/home/notifications_screen.dart`,
`lib/state/notifications_state.dart`,
`lib/data/repositories/notification_repository.dart`,
`lib/data/services/notification_service.dart`,
`lib/data/services/api/api_notification_service.dart`,
`lib/core/constants/api_endpoints.dart`, `lib/core/network/api_client.dart`,
`lib/core/network/dio_api_client.dart`,
`test/fakes/mock_notification_service.dart`,
`test/fakes/offline_api_client.dart`,
`test/notifications_inbox_test.dart` (new).

**Files (API):** `src/AKCars.Domain/Entities/Notification.cs`,
`src/AKCars.Application/Notifications/InboxActions/InboxActionCommands.cs`
(new), `src/AKCars.Application/Notifications/GetNotifications/GetNotificationsQuery.cs`,
`src/AKCars.Application/Notifications/MarkAllRead/MarkAllReadCommand.cs`,
`src/AKCars.Api/Endpoints/NotificationEndpoints.cs`,
`src/AKCars.Infrastructure/Persistence/Migrations/20260901161747_AddNotificationDismissedAt.cs`
(new), `.../AkCarsDbContextModelSnapshot.cs`,
`tests/AKCars.Tests/MyWorkshop/InboxActionCommandTests.cs` (new).

---

## 2026-09-01 (3) · Service types become the founder's to manage

**Baseline:** `00e1d90` here; `AKCarsMobileAPI` changed in its own repo.

Request, verbatim: "admin can control to add, edit, update, delete services
types in the contents page in the admin page"

### The constraint this deliberately lifts

The badge was the **only** writable field on a `ServiceCategory`, said so in
four places, and the reason was real rather than decorative:

* `MaintenanceTypeX.forCategory(slug)` resets a maintenance line from the slug —
  `express`/`full`/`major` reset engine oil, plus `tyres`, `battery`, `ac`,
  `ev-battery`/`ev-check`.
* `booking_screen.dart` reads `offering.categorySlug == 'sos'` to make a booking
  an emergency: no time slots, roadside by default.

So the catalogue is not inert wording — parts of it are behaviour. That is a
reason to make the editor *say so*, not a reason to keep the founder locked out
of their own catalogue, so the whole record is now editable and the editor names
the consequence before the save.

### The API (`AKCarsMobileAPI`)

`WriteServiceCategoryCommands.cs` — create, update, delete, on the `founder`
group, beside `POST/PUT/DELETE /service-marketplace/categories`.
`UpdateCategoryBadgeCommand` stays as the narrow one-field path, because the
badge is what a founder changes most often and the only field carrying no
behaviour.

Three guards carry the weight:

1. **A key stays unique** (`409 slug_taken`). Two rows answering to `sos` makes
   "which one is the emergency" undefined.
2. **A rename rewrites every offering's `CategorySlug` in the same
   transaction.** Offerings carry a denormalised copy so the booking screen can
   read `sos` without a join; leaving it behind is how a renamed emergency
   category stops being an emergency for everything already sold under it.
3. **A type with offerings cannot be deleted** (`409 category_in_use`, with the
   count). Refused rather than cascaded: deleting a workshop's priced work as a
   side effect of tidying a catalogue is not an admin screen's decision.

### The app

`ServiceCategoryDraft` (the editable half of a category) → service → repository
→ `CategoryBadgeAdmin.create/update/delete/offeringCount`. The repository
patches its warm caches on each write, including rewriting cached
`categorySlug`s after a rename so this session's booking screen does not keep
reading the old key.

`category_editor_sheet.dart` is the editor: four numbered steps (name+icon,
key, how it shows and to whom, price note), a 14-icon visual picker, powertrain
chips, the capability requirement, and a Save that names what is still missing.
Its centrepiece is the key step — changing away from a behavioural slug shows a
**red** notice naming what will stop working ("the current key `major` resets
the engine-oil reminder"); adopting one shows an amber notice naming what it
switches on. The list flags behavioural keys with an amber chip so they are
visible before anything is opened.

Delete confirms in two shapes: a plain refusal naming the count when services
are still filed under the type, and an ordinary destructive confirm when not.

### A crash this closes on the way past

`services_screen.dart` resolved a category with
`categories.firstWhere((c) => c.id == o.categoryId)` in two places — once per
search hit and once per card. Unguarded, that throws `StateError` for an
offering whose category is gone, which deleting a type can now cause. Both are
`firstWhereOrNull` and degrade instead (the search falls back to an empty name,
which cannot match a non-empty query; the card falls back to a wrench glyph).

### Verified

* **App:** `flutter analyze` clean, `flutter test` **581 passing**, including 6
  new tests in `test/admin_service_types_test.dart` covering create, the
  duplicate-key refusal, the badge surviving an edit, the rename cascade onto
  offerings, the delete-in-use refusal, and the delete that is allowed.
* **API:** `dotnet test` **972 passing**, including 22 new ones in
  `WriteServiceCategoryCommandTests.cs` — founder-only on create and delete,
  key lower-casing, uniqueness on both create and rename, the badge surviving a
  PUT, the offering cascade, the in-use refusal leaving both rows intact, the
  404, and the slug-pattern table (rejects `UPPER`, `Has Spaces`, `-leading`,
  `double--hyphen`).
* A temporary render check (deleted) rendered the Content tab and the type
  editor at 402×874 in **ar/en × light/dark**, scrolled both to the bottom, and
  asserted the behavioural-key warning appears live while typing. Two golden
  captures were inspected by eye, then deleted.
* **Two caveats.** `dotnet test` had to run with
  `-p:BuildProjectReferences=false`: the API is running from Visual Studio and
  holds `AKCars.Api`'s build output, so a normal build cannot copy into it. The
  Application project — where all three handlers live — was built clean
  separately, and the new tests exercise handlers directly, not endpoints. And
  the founder panel is behind a real founder JWT, so none of this was walked in
  a browser; the render check stands in for that.

**Files (app):** `lib/data/models/service_category.dart`,
`lib/data/services/service_marketplace_service.dart`,
`lib/data/services/api/api_service_marketplace_service.dart`,
`lib/data/repositories/service_marketplace_repository.dart`,
`lib/core/constants/api_endpoints.dart`, `lib/state/admin_content_state.dart`,
`lib/features/operations/category_editor_sheet.dart` (new),
`lib/features/operations/admin_category_badges.dart`,
`lib/features/services/services_screen.dart`,
`test/fakes/mock_service_marketplace_service.dart`,
`test/admin_service_types_test.dart` (new),
`test/admin_category_badges_test.dart`.

**Files (API):**
`src/AKCars.Application/Marketplace/WriteServiceCategory/WriteServiceCategoryCommands.cs`
(new), `src/AKCars.Api/Endpoints/MarketplaceEndpoints.cs`,
`tests/AKCars.Tests/MyWorkshop/WriteServiceCategoryCommandTests.cs` (new).

---

## 2026-09-01 (2) · The Content tab explains itself

**Baseline:** `00e1d90`, on top of the same day's tab-UI entry below.

Request, verbatim: "the contents page in the admin page and it's details are
not clear to how use them or dealing with them. Improve this page and make it
friendly."

### What was actually wrong

The tab held two sections — service badges and Home announcements — with no
statement of what either changes, so the page was two stacked lists with no
stated relationship. Underneath that were four things that made it genuinely
hard to operate, and two that were bugs:

* **Nothing said where the writing lands.** Both sections described an effect
  in a subtitle; neither showed one. For announcements there was no preview
  anywhere, so a founder wrote a title, a body, a badge and an icon blind and
  found out how it looked by leaving the panel and opening Home.
* **The icon dropdown listed raw wire keys** — `notification`, `fact_check`,
  `lock_clock`, `inventory`. Those are `IconCodec`'s storage keys; they name the
  asset, not the announcement.
* **The region chips and the row's region chip printed canonical English keys**
  (`Muscat`) instead of going through `LocationCatalog.localized` the way every
  other screen in the app does.
* **A badge filled in one language only was accepted silently.** `L('عرض', '')`
  paints an *empty yellow pill* for every English reader. The category badge
  dialog has guarded against exactly this since it was written; the
  announcement editor never did.
* **Save was disabled with no explanation.** Four fields are required and
  nothing said which was missing.
* **The three destination fields interact by precedence** (a chosen service
  beats a search beats the plain Services tab) and nothing said so, so a search
  typed under an already-chosen service was silently ignored.
* Rows were editable only through an 18px pencil in the corner, which reads as
  a list you look at rather than one you edit.

### What changed

**A preview that is the real card.** `_AnnouncementCard`'s painting is extracted
into `PromotionCardFace` (`core/widgets/`), and Home and the editor now render
the *same widget* — Home feeding it a `Promotion`, the editor feeding it the
half-typed form. It is given the rail's own height, so text that will ellipsise
on a phone ellipsises in the preview. A preview drawn separately from the thing
it previews drifts within a release and the founder learns about it from a
customer; this one cannot.

**The tab says what it is.** A short intro names the two sections and where each
one appears, and states once — in amber, up front — that a discount must not be
announced from this tab, because neither a badge nor an announcement is checked
against the catalogue price. That warning used to be a footnote under one of the
two sections.

**The editor is three numbered steps** instead of twelve controls at one level:
what the card says, where tapping it goes, and who sees it until when. The icon
dropdown is a grid of the eight icons with human labels. A live line under the
destination fields states, in a sentence, where a tap would actually land — and
says outright when a typed search is being overridden. The blocked Save now
names the first missing thing.

**Two real bugs fixed:** the badge is enforced both-languages-or-neither, with
the reason shown inline; regions are localised in the editor chips and in each
row's meta chip.

**Both lists are filterable** (`All / Live / Expired`, `All / With a badge /
Without`) using the panel's existing `AdminFilterRow`, so the counts in the
summary strips became something to act on. **Whole rows are tappable** on both
lists, and an unbadged category now says "Tap to add a badge" rather than
reporting "No badge"; its corner action switches between a `+` and a pencil.

### Verified

* `flutter analyze` clean; `flutter test` **575 passing**.
* A temporary render check (deleted with the pass) rendered the whole tab and
  the editor sheet at 402×874 in **ar/en × light/dark** and scrolled both to the
  bottom. It caught one real overflow — the new "Tap to add a badge" row, whose
  `mainAxisSize.min` let the label overflow instead of ellipsising once a long
  category name squeezed the column. Fixed with `Flexible`.
* Two one-off golden captures were rendered and inspected, then deleted:
  structure, spacing and the preview pane confirmed by eye. (Glyphs render as
  tofu under `flutter_tester`, which has no Arabic font — layout only.)
* `test/admin_category_badges_test.dart` updated to the deliberate behaviour
  change: the corner tooltip is now `Add a badge` on an unbadged row and
  `Edit badge` on a badged one, so the test asserts the split rather than
  counting one tooltip across the whole list.
* **Not** verified in a browser: `/admin` requires a real founder JWT
  (`AuthState.isFounder`), which this session had no account for. The render
  check above stands in for that walkthrough.

**Files:** `lib/core/widgets/promotion_card_face.dart` (new),
`lib/core/widgets/widgets.dart`, `lib/features/home/home_widgets.dart`,
`lib/features/operations/admin_content_screen.dart`,
`lib/features/operations/admin_category_badges.dart`,
`test/admin_category_badges_test.dart`.

---

## 2026-09-01 · The five customer tabs, on one type scale and one header

**Baseline:** `00e1d90`. The working tree already carried unrelated uncommitted
work when this started, so `git diff 00e1d90` is wider than this entry; the
files this entry covers are listed at the bottom.

Request, verbatim: "I think the home page, services page, bookings page, my car
page, and my account page needs update the ui and make them look modern. try to
polish the ui to the best you can to make the user experience so modern and
efficiency. review them then make the update."

### What the review found

The Sand & Ink system itself is sound. What had drifted was every screen's
compliance with it, and the drift was concentrated in three places.

**1. The type scale existed and nobody used it.** `AppTypography` documents four
levels — 12.5 / 14 / 16 / 20 — and says in its own doc comment that nine sizes
one step apart "is not a hierarchy; it is nine ways of saying normal". Across
the five tabs there were **104 hand-written `fontSize:` values** spanning 8.5,
9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 15, 16, 17, 19, 20, 21.
Everything below ~11px is also simply too small to read on a phone: the home
page's quick-action tiles labelled their buttons at **9.5px**, so "حجز صيانة"
and "مساعدة طريق" were guessed at from their icons rather than read.

**2. Five tabs, four different headers.** Home had a greeting row, Services and
Bookings had Material `AppBar`s, My Car had a `SandHeader`, Account had a bare
`Text(fontSize: 19)`. Switching tabs moved the title, changed the top margin,
and changed whether the title stayed put while scrolling.

**3. No pull-to-refresh anywhere on the customer side.** Every screen in the
workshop dashboard has a `RefreshIndicator`; not one of the five customer tabs
did. On a phone, the gesture *is* the refresh affordance, and its absence left
stale data with no way to ask for fresh data short of killing the app.

### What changed

**Shared** — `sand_widgets.dart` gains `SandTabHeader` (title + optional
subtitle + one trailing action; scrolls rather than pinning, because on a tab
root the bottom bar already says which tab this is) and `SandRefresh` (the
app's `RefreshIndicator`, one tint and one displacement).
`SessionRefresh.refreshVisibleData()` is the whole warm-cache + announce +
per-account-list refresh without the generation guard `refreshEverything` needs
— there is no identity changing underneath a pull, so there is no race to lose.

**Type scale** — every `fontSize:` on the five tabs snapped to the nearest of
the four levels (104 call sites), and the tabular-figure sizes moved one step
with them. The fixed-height carousels grew to match (offers 158→186,
announcements 150→178, recommendations 152→180), and two `Row`s that could not
survive the larger labels were fixed properly rather than by shrinking the text
back: the recommendation card's workshop count is now `Flexible` + ellipsis
inside a 190px card, and the two ranking-board tabs are `Flexible` pills.

**Home** — pull-to-refresh; quick-action labels at `bodySecondary`/w700 instead
of 9.5px; challenge strip and search pill on the spacing scale.

**Services** — the search field is now **pinned** (`SliverPersistentHeader`), so
refining a search after reading three results no longer means scrolling back up
to find the box. Its background fades out over its last 14px rather than ending
in a hard edge, which was slicing the first line of whatever scrolled under it
in half. **The 450ms fake skeleton is gone**: `ServiceMarketplaceRepository`
gained `isCatalogueWarm`, so the screen now shows a skeleton while the catalogue
is genuinely cold, an honest "couldn't load services / retry" when a fetch came
back and left it cold, and results otherwise. It also re-asks for the catalogue
once on mount if bootstrap's best-effort warm-up had failed — previously that
failure surfaced as a permanently empty "nothing matched".

**Bookings** — a filter bar (الكل / بانتظارك / جارية / منتهية) with live counts,
each chip hidden while its slice is empty except "All". "بانتظارك" is the point
of it: `quoted`, `awaitingApproval` and `disputed` are the only states blocked
on the customer, and they are also lifted to the top of the active list. The
header subtitle counts them.

**My Car** — `SandTabHeader` in place of `SandHeader`, pull-to-refresh on both
the book and the empty-garage state (the empty state became a `ListView`, since
the one screen a user with a failed sync lands on must be the one they can pull
to retry from).

**Account** — `SandTabHeader` with a subtitle, screen margin onto the scale
(20→16, matching the other four), stat tiles on `SandPressable` so they dip
under the finger, roomier menu rows.

### Verified

* `flutter analyze` — clean.
* `flutter test` — **599 passing**, up from 575 (the 24 new ones below).
* `test/tmp_tab_layout_check_test.dart` — a temporary check that renders all
  five tabs at 402×874 in **ar/en × light/dark** and scrolls each to the bottom.
  A type-scale change fails silently otherwise: nothing throws at build time, a
  yellow-and-black overflow bar just appears somewhere below the fold. It found
  the two `Row`s named above. Deleted after the pass.
* `test/ev_test.dart`'s synthetic viewport raised 2600→3200. Not an assertion
  change — it is the off-screen height at which the whole page mounts in one
  frame, and the page legitimately got taller. A taller viewport makes that
  file's `findsNothing` checks stricter, not looser.
* In the browser against the live API (`dotnet run` on `:7291`, Flutter web on
  `:5959`, 375×812): all five tabs walked, plus a scroll through Services
  confirming the search field parks at the top with content passing under it.

**Files:** `lib/core/widgets/sand_widgets.dart`, `lib/state/session_refresh.dart`,
`lib/data/repositories/service_marketplace_repository.dart`,
`lib/features/home/home_screen.dart`, `lib/features/home/home_widgets.dart`,
`lib/features/services/services_screen.dart`,
`lib/features/services/requests_screen.dart`,
`lib/features/garage/maintenance_screen.dart`,
`lib/features/profile/profile_screen.dart`, `test/ev_test.dart`.

---

## 2026-08-29 (3) · The yellow "شارة" on a service card had no owner

**Baseline:** `00e1d90` here; `AKCarsMobileAPI` changed in its own repo.
Request, verbatim: "the yellow sign called \"شارة\", there is now clear way to
control by it in the admin dashboard eathier in the advertisments section or in
the content section. check there and fix it."

### What it actually was

Two different things in this app render a yellow badge, and only one of them was
editable:

* `Promotion.badge` — on the announcements rail. Already editable, in the
  Content tab's promotion editor.
* **`ServiceCategory.badge`** — the pill in the corner of the big service cards
  (`service_widgets.dart`, `ak.amber`, positioned `top: -10, end: 12`). This is
  the one in the screenshot: "زيت مجاني" on صيانة شاملة.

The second had no write path anywhere. Not in the app, not in the repository,
not in the API: `GET /service-marketplace/categories` was the *only* category
endpoint, and `ServiceMarketplaceService` exposed only `fetchCategories()`. The
badge was seed data — visible to every customer on the home page, changeable by
nobody, including the founder.

### The fix, end to end

**API** (`AKCarsMobileAPI`): `UpdateCategoryBadgeCommand` +
`PUT /service-marketplace/categories/{id}/badge`, on the `founder` group.

The badge is deliberately the *only* writable field on a category. Slug, name,
icon and the powertrain restrictions are catalogue structure the app branches on
— the slug drives `MaintenanceTypeX.forCategory`'s schedule reset and the `sos`
emergency booking path — so an admin screen that could retype them would break
bookings rather than change wording. The badge carries no behaviour at all;
nothing reads it but the card that draws it. Hence a PUT on a sub-resource
rather than a PATCH on the category: the route says how narrow the write is.

Validation: max 24 characters (the ribbon is a small pill on a 148px card and
longer text is clipped, not wrapped), and **both languages or neither** — half a
badge renders as an empty yellow box for readers of the other language, which
looks like a bug rather than a missing translation. Null or whitespace in both
clears it, which is the supported way to take a ribbon down.

**One consequence that had to be handled.** `GET /categories` was `Cacheable`
for five minutes, on the stated reasoning that "static catalogue data
(categories, offerings, promotions) doesn't flip on a single admin click". That
stopped being true the moment the badge became editable — the founder would save
a ribbon, pull to refresh, and be served the old one back, indistinguishable
from the save failing. The cache header is gone from that route and the comment
next to `/providers` (which already had this exact problem) now says why.

**Client:** `ApiEndpoints.serviceCategoryBadge`, `updateCategoryBadge` on the
marketplace service (API + mock), `setCategoryBadge` on the repository (patches
the warm cache in place — unlike the offers feed, `/categories` returns every
category whether or not it has a badge, so the edited row is always already
cached), plus `categoriesRevisionProvider` / `adminCategoriesProvider` /
`categoryBadgeAdminProvider` mirroring the offers pattern.

`ServiceCategory.copyWith` gained a `clearBadge` flag. `badge: null` in a
copyWith cannot mean "clear" — it is indistinguishable from "leave alone" — and
clearing is a real operation now.

**UI:** a "شارات الخدمات / Service badges" section at the top of the Content tab
(`admin_category_badges.dart`), in the same card language as the rest of the
panel: summary card with with-badge/without counts, one row per category, and a
dialog with Arabic/English fields, a live preview, and Remove.

Two deliberate details:

1. **The preview is the real ribbon**, not the text in a neutral chip — same
   colour, radius, font size and letter-spacing as `service_widgets.dart` draws
   it. The founder is choosing wording for a small yellow pill, and a preview in
   a different shape hides the one thing that actually goes wrong: it not
   fitting.
2. **The card says what a badge is not.** "A badge is wording only — it promises
   no price and no discount. For a real discount use the Offers tab, the one
   that is validated against the published price." An offer that lies is a
   mispriced booking the platform has to honour; a badge that lies is only wrong
   wording. That asymmetry is exactly why a badge must never be used to announce
   a discount, and the one place to say so is where someone is typing one.

Placed on the Content tab rather than Offers for the same reason: both the badge
and an announcement are copy the founder writes on top of data they did not
write. An offer is a claim about money and is validated as one.

### Not changed

No migration: `ServiceCategory.Badge` already existed as a column and was
already returned by `GET /categories`. What was missing was only the write.

### Verified

- `dotnet build` — clean. `dotnet test` — 950 passing (941 before, 9 new,
  covering the founder guard, set/clear/whitespace-clear, not-found, the
  one-language rejection and the length cap).
- `flutter analyze` — no issues. `flutter test` — 575 passing (570 before, 5
  new, covering the list, the write-through, the both-languages rule and
  removal).
- **Not verified in the running app.** `https://localhost:7291` is still
  refusing connections, so the founder panel has not been exercised against the
  live API. In particular the new endpoint has been tested at the handler level
  and through the client's mock, but never over HTTP.

---

## 2026-08-29 (2) · The other four founder tabs, in the Offers tab's language

**Baseline:** `00e1d90`, continuing the entry below. Request, verbatim: "do same
ui idea for the rest of sections."

### The idea, made shared instead of copied

The Offers rebuild invented a card language and kept it private to one file.
Applying it to the other tabs by copy would have produced five stat strips that
drift apart on the first edit, so it moved to
`admin_panel_widgets.dart` first: `AdminSummaryCard` (icon, title, stat strip,
fact chips, footnote, one primary action), `AdminStat`, `AdminMetaChip` +
`AdminChipTone`, `AdminGroupHeader`, `AdminFilterRow`, `AdminCardAction`,
`AdminInsetDivider`. The Offers tab was then rewritten onto them, so it is now a
consumer of the language rather than its owner.

Every tab now answers the same shape of question in the same shape: *what is the
state of this pile, and which row needs me.*

### Per tab

**Today** — summary card leads with money held, in-flight count, open disputes
(red only when non-zero), with completed-this-month as a chip. Each queue got an
`AdminGroupHeader` whose icon tile turns amber when the queue is non-empty, so a
day with work in it looks different from a quiet one before you read a word. The
booking card is now zoned: header, divider, timeline + waited label, divider,
action bar. The customer's dispute note moved out of loose italics into an amber
quote block, and the auto-release deadline became a chip that turns amber once
the window has closed.

**Workshops** — pending/approved/suspended as the three figures. The onboarding
pipeline, previously a row of bespoke `_StageChip`s, is now the summary card's
chip row (empty stages dimmed, still shown — a pipeline that hides its empty
columns changes shape as you work through it). The roster row became a full card:
icon tile tinted by approval state, status badge, region and stage as chips, the
rejection reason in a quote block, and Suspend/Manage on an action bar. The
application-review card is deliberately untouched — it is a form, not a list row.

**Money** — held / released / refunded as three rial figures, plus an "owed to
workshops" chip that is green at zero and amber otherwise. Owed rows became cards
with "Mark as paid" as a real button and a shortcut into the workshop. The
transfer ledger stays deliberately quieter than everything above it: it is
history, and it carries no controls at all.

**Log** — entries / today / records-touched, and the subject filter moved from a
wrapping chip pile to the same `AdminFilterRow` the Offers tab uses, now with
counts. Each row gets an icon per subject type so a filtered log still reads as a
list of different things. The action key is still printed verbatim, and the card
still has no control that writes anything — the footnote says so.

**Content (announcements)** — live/expired counts, "New announcement" as the
card's action, and promotion rows restyled to the shared card: icon tile in the
primary colour while live and grey once expired, live/expired badge, end date and
regions as chips, edit/delete as icon actions.

### Structure

`admin_screen.dart` went from 1724 lines to 108 — it is now only the shell and
its six tab registrations. The tabs live in `admin_today_tab.dart`,
`admin_workshops_tab.dart`, `admin_money_tab.dart`, `admin_offers_tab.dart` and
`admin_audit_tab.dart`. `PhoneField`/`showCrDocumentDialog` moved with the
workshops tab and `admin_workshop_detail_screen.dart`'s import was repointed.

### Two bugs this surfaced

1. **`AdminMetaChip` overflowed by 80px on a long label.** `MainAxisSize.min`
   sizes the row to its children, so a label longer than the space the parent
   `Wrap` had left overflowed instead of ellipsising. Every chip holds
   translator-written text and the Arabic of a short English label is regularly
   half as long again — the text is `Flexible` now. Caught by
   `operator_panels_test.dart`, which renders the Today tab.
2. **A precision change broke two existing assertions.** Rendering
   completed-this-month as a full `RialAmount` put a second `0.00` on the Today
   tab; the old code used `toStringAsFixed(0)` in the label. Both tests
   (`the founder panel offers only the founder's transitions`, `a disputed
   booking still counts toward the escrow total`) assert on money text globally.
   The figure is back to whole rials — a month's takings are a scale, not
   something anyone reconciles to the fils — so the tests pass unchanged rather
   than being loosened.

### Verified

- `flutter analyze` — no issues.
- `flutter test` — 570 passing, same as before this change.
- Rendered all five tabs to PNG in `en` and `ar` at 402×1600. No `RenderFlex`
  overflow in any of the ten, and RTL mirrors correctly throughout (icon tiles,
  status badges, action bars and stat strips all swap sides). Those preview files
  were temporary and are deleted.
- **Not verified in the running app**, same as the entry below:
  `https://localhost:7291` is refusing connections, so the founder panel cannot
  be reached against a real API or a real founder session.

---

## 2026-08-29 · The Offers tab could not show the offer you had just made

**Baseline:** `00e1d90`. Request, verbatim: "update the offers section in the
admin page. allow admin to add, edit, update, and delete offer. make the ui
modern and update the offer card ui. make this section modern and nice look."

### What was actually wrong, beyond the missing buttons

The founder panel had **two** places that dealt with offers: the Offers tab
(an approve/stop switch and nothing else) and a second offers list on the
Content tab (which *did* have create/edit/delete). The screenshot in the
request is the first one — the one with no way to add anything.

Underneath that, the Offers tab was reading the wrong list. `offersAuditProvider`
resolves to `ServiceMarketplaceRepository.auditOffers()`, which reasons over the
warm cache filled from `GET /service-marketplace/offers` — and that endpoint,
by its own documented contract, *"returns only founder-approved, in-window
offers"*. So the tab's promise ("every offer the platform holds, live or not,
with the exact rule keeping it off the home page") was not true against the real
API. It was only true in tests, because the mock returned every fixture row from
that endpoint. Bolting a "New offer" button onto that screen would have produced
the worst possible bug: create an offer, watch it not appear, create it again.

A second, related bug found on the way: `setOfferActive` patched the cached row
in place (`for (final offer in _offers.value) if (offer.id == updated.id) ...`).
An offer being switched **on** is by definition absent from that cache, so the
map left it out and the customer-facing home rail stayed empty until the next
warm-up — even though the founder had just enabled it.

### What changed

**One surface for offers, and it reads the founder's list.**
`lib/features/operations/admin_offers_tab.dart` (new) replaces `_OffersTab`/
`_OffersSection`/`_OfferRow` inside `admin_screen.dart`, and the Content tab's
duplicate offers list is gone — that tab is announcements only now. The new tab
reads `adminOfferAuditProvider` (new, in `admin_content_state.dart`), which
pairs `adminOffersProvider` (`GET /offers/all` — every offer, any stage) with
the repository's own validation.

**The validation stayed put.** `ServiceMarketplaceRepository.rejectionFor(offer)`
(new on the interface) just exposes the existing private `_reject` — the same
rules the home page runs, not a second opinion. The reference price is still
never typed by hand: the editor copies it from the selected service's published
catalogue price, so the original reason the tab had no edit button ("an approval
screen that could quietly adjust either would hollow out the validation") is now
enforced in the editor rather than by having no editor.

**`setOfferActive` re-fetches** instead of patching in place, matching what
`createOffer`/`updateOffer`/`deleteOffer` already did.

**`AdminOffersNotifier.setActive`** added, so the founder's switch writes
through to the list the screen is rendering. `OffersAdmin.setActive` only bumped
the revision counter — fine for the rails that re-read the cache, useless for a
list holding its own state.

### The card, and why it is shaped this way

- **The percentage leads**, as a tile, in the primary colour when the offer is
  live and grey when it is not. It is the one thing readable while scrolling,
  and it is also the home page's only ranking signal (spec §2), so it carries
  the same weight here that it carries there.
- **Discounted price large, reference price struck through** beside it, then the
  saving, the window, and the time left as fact-chips — all read off the `Offer`
  itself. The "ends soon" chip turns amber at ≤3 days and grey once past.
- **The blocking reason is on the row**, and now distinguishes two cases that
  used to look identical: merely awaiting the founder's switch (neutral, one tap
  away) versus blocked by a rule the switch cannot clear (amber, plus "fix the
  cause first"). That distinction already existed in the code as `blockedByOther`
  but only changed a sentence, not the card's tone.
- **Actions inline**: a switch for enable/stop, plus edit and delete.
- **The list is ordered decision-first** — blocked, then live, then expired,
  each by soonest deadline. A founder opens this tab to unblock something; a
  live offer needs nothing from them.
- **A summary card on top** carries live/blocked/expired counts and the only
  "New offer" button, because a bare count of offers says nothing: an offer that
  exists and an offer that is showing are different facts.

The editor sheet (`offer_editor_sheet.dart`, moved out of
`admin_content_screen.dart`) is grouped into four questions — what, how much,
how long, where — and now shows the arithmetic back: published price struck
through beside what the customer saves and the resulting percentage, live as
you type. It also clamps the end date forward when a start date is pushed past
it, instead of silently disabling Save.

### Files

New: `admin_offers_tab.dart`, `offer_editor_sheet.dart`, `admin_form_widgets.dart`
(the shared date field, loading and error blocks, and one `formatAdminDate` so
the panel has a single date format), `test/admin_offers_tab_test.dart`.
Changed: `admin_screen.dart` (−207 lines, tab now delegates), `admin_content_screen.dart`
(−548 lines, announcements only), `service_marketplace_repository.dart`,
`admin_content_state.dart`.

### Verified

- `flutter analyze` — no issues.
- `flutter test` — 570 passing (566 before, 4 new).
- The new tests use a mock whose `fetchOffers()` filters like the **real** API
  does, which is the point: the old screen passes its own tests against the
  permissive mock and fails against the deployed one. They cover the create/
  edit/enable/delete affordances, that a stopped offer still appears with its
  reason, that delete removes the row, and that the switch writes through.
- Rendered the tab to PNG in both `en` and `ar` at 402×1500 to check layout —
  no overflow, RTL mirrors correctly (badge/status/switch/actions all swap
  sides). Those preview files were temporary and are deleted.
- **Not verified in the running app.** The Flutter web build starts, but
  `https://localhost:7291` is refusing connections, so the app stops at "The app
  could not start" and the founder panel cannot be reached. Nothing here has
  been exercised against the real API or a real founder session.

---

## 2026-08-26 (3) · Security review of the API — a phone number bought you a stranger's home address

**Baseline:** `00e1d90` here; `AKCarsMobileAPI` reviewed and changed in its own
repo. Request, verbatim: "/ecc:security-review — for api and fix any issue of
this skill feedbacks."

The skill's checklist is written for TypeScript/Next.js/Supabase; the API is
ASP.NET Core 8 with EF Core, so each item was mapped onto the real stack
(parameterised queries → EF's `IQueryable`; RLS → per-handler ownership
checks; httpOnly cookies → bearer tokens in the client's secure storage).

### What was already right

Worth recording, because it is most of the checklist: **no raw SQL anywhere**
(`FromSqlRaw`/`ExecuteSqlRaw` return nothing); JWT validation is complete
(issuer, audience, lifetime, signing key, 30s skew); refresh tokens are 64
crypto-random bytes stored only as a SHA-256 hash with a family id; the OTP is
crypto-random, hashed, 5-minute, and capped at five attempts; every endpoint
group carries `RequireAuthorization()` and the founder-only ones re-check
`ICurrentUser.IsFounder` **inside the handler**, not just at the route; every
user-scoped query filters on `currentUser.UserId`; the chat hub is
`[Authorize]`; CORS is wide open in `IsDevelopment()` only; Swagger is
dev-only; and the committed `Jwt:SigningKey` is empty, with the only literal
key clearly labelled dev-only in `appsettings.Development.json`.

### HIGH — `POST /auth/login` handed the account to anyone who asked

`RequestOtpCommandHandler` returned the matched `UserProfileDto` — id, name,
phone, **e-mail, region, wilayat and street address** — from an endpoint that
is `AllowAnonymous` by necessity. The stated reason, in the handler's own
comment, was "so the code screen can greet the user by name". The code screen
never did: `login_screen.dart`'s only use of the response was `if (account ==
null)`. An Oman mobile is eight digits beginning 7 or 9, so this was a
guessable key to a stranger's home address, five lookups per minute per IP.

Fixed on both sides: the handler now returns the non-generic `Result`, the
endpoint answers `200 { "sent": true }`, and the client's
`AuthService.findAccount` became `requestOtp` returning `bool`. The 200-vs-404
split is kept deliberately — it is what lets the login screen offer
registration instead of pretending a code went out — and is now the only thing
an unauthenticated caller learns. `docs/api_contract.md` updated.

### HIGH — every 500 carried its exception message to the client

`GlobalExceptionHandler` set `Detail = exception.Message` on all paths,
including the `_ =>` 500 case. A `SqlException` names the server, database and
often the failing column. Now: a fixed sentence plus the existing `traceId`
for correlation; the full exception was already being logged. Deliberate
failures (validation, `Result<T>` errors) still carry their own detail.

### MEDIUM — nine unvalidated base64 uploads

Every photo, CR scan and proof attachment went straight into
`Convert.FromBase64String` and then into the database: no type check at all, no
per-item size check, and a `FormatException` on malformed input — which
surfaced as a 500 (carrying its message, per the finding above) rather than the
400 a bad request deserves.

Added `MediaValidation` + `MediaRules` (`AKCars.Application/Common/`) and wired
them into all nine: an **allowlist** of media types — exactly what the client's
own picker can produce, per `media_codec.dart`, and deliberately *not*
`application/octet-stream`, which is the client's "I could not identify this"
fallback — plus a 4 MB per-item cap matching the client's `maxAttachmentBytes`,
checked from the encoded length before allocating. `ApplyEscrowEvent` takes a
*list*, so it uses `RuleForEach`: Kestrel's 8 MB cap bounded the batch, nothing
bounded an item inside it. `Decode` stays guarded so a handler reached without
its validator still fails as a rejected request.

### MEDIUM — rate limiting covered two endpoints out of ~140

`IpRateLimiting.GeneralRules` listed only `/auth/login` and
`/auth/login/verify`. Added `/auth/register` (10/h) and `/auth/refresh`
(20/min), plus `*` fallbacks at 300/min and 5000/h so a new endpoint is
covered the day it is written rather than the day someone remembers it.

### LOW — no transport or framing headers

Added `UseHsts()` outside Development (on localhost it would pin the
developer's browser for every other localhost project, with a 30-day max-age
they cannot easily undo) and a small middleware setting
`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` and
`Referrer-Policy: no-referrer`.

### Reported, deliberately NOT changed

- **`AllowedHosts: "*"`** disables host-header filtering. The right value is
  the production hostname, which this session has no way to know — guessing it
  would break their deployment. Needs the real host set before launch.
- **User enumeration on `/auth/login`.** The 404-vs-200 split tells an
  attacker whether a number is registered. It is load-bearing product
  behaviour (the login screen offers registration on 404), so it stays — but
  it is a knowing trade, not an oversight, and it is now the *only* thing that
  leaks.
- **`LoggingOtpSender` writes OTP codes to the log.** It already carries a
  "swap for a real provider (and never log the code) before production"
  comment and no SMS gateway exists yet; replacing it is a feature, not a fix.
- **The OTP is four digits, SHA-256 without a salt.** 10,000 possibilities is
  small, but the guess rate is bounded by five attempts per challenge and the
  per-IP limits, and the hash only matters to someone who already has the
  database. Worth revisiting alongside a real SMS provider.

### Verified

- API: `dotnet build -c Release` clean (0 warnings), `dotnet test` **941/941
  pass**.
- Client: `flutter analyze` clean, `flutter test` **566/566 pass**.
- **Not** verified: nothing was exercised against a running server. In
  particular the new media allowlist has not been tested with a real photo
  from a real device — if a picker reports a type outside the allowlist, that
  upload now gets a 400 where it previously succeeded. That is the intended
  behaviour, but it is the change most worth watching first.
- The API was **running from Visual Studio** throughout (which is why the
  Debug build was file-locked and Release was used); it must be restarted for
  any of this to take effect.
- No regression test was added for the `/auth/login` fix. The guarantee is now
  in the type — `Result` has no payload to leak — but an integration test
  asserting the response body contains no profile fields would be a cheap
  belt-and-braces addition.

---

## 2026-08-26 (2) · Three `403`s after every ordinary sign-in — the founder claim was there all along, just never read

**Baseline:** `00e1d90`, on top of the uncommitted working tree from the
entries below. Reported verbatim: "after login I sow some errors in the
console: … `/service-marketplace/audit` 403 (Forbidden) …
`/service-marketplace/payouts` 403 … `/service-marketplace/operator/requests`
403 … check what are those errors and fix them".

### What they were

All three endpoints are founder-only, and all three were being asked for by
**every** account that signed in. None of them was a malfunction — each `403`
was already caught and treated as the ordinary answer
(`ServiceMarketplaceRepositoryImpl._optionalForFounder` for two,
`SessionRefresh._bestEffort` for the third), which is why nothing broke. They
were three guaranteed-to-fail round trips and three red console lines per
sign-in, on every customer's and every workshop's device.

### Why they were being asked

Two comments in the code said the same thing, and both were wrong:

> "there is no claim on the profile that says whether this session is a
> founder's — the `403` *is* the check"

True of the **profile** (`UserProfileDto` mirrors the `Users` table and has no
role column) and false of the **token**. `TokenService.GenerateAccessToken`
puts the role in the JWT, and `jwtHasFounderRole` has decoded it since the
`/admin` route guard needed it — `AuthState.isFounder` is built on it. The
check existed; these three call sites just never used it.

### The fix

- `SessionRefresh` gained `_isFounder()`, which decodes the role claim off the
  **stored token** rather than reading `AuthState.isFounder`. That matters:
  bootstrap calls `loadSessionLists` *before* `AuthNotifier.restore()`
  re-attaches the profile, so auth state is empty there for everyone — the
  same reason `AppBootstrap._signedIn` already reads the token store. The
  token is in place in both paths (a cold start reads last session's;
  `login()`/`register()` save it before returning).
- `refreshEverything` now passes `includeFounderLedger: await _isFounder()`
  instead of a hardcoded `true`.
- `loadSessionLists` fires the operator-queue refresh only when that claim is
  present.
- `AppBootstrap.warmUp` keys `includeFounderLedger` on a new `_isFounder`
  rather than on `signedIn`, which had the same effect on every cold start.

Both `_optionalForFounder` and `_bestEffort` are **left in place**. The claim
describes the token; only the server decides, and if the two ever disagree the
`403` must still land softly.

### Checked before gating: does anyone else need this data?

Yes — this was the thing worth getting wrong. `payouts` feeds
`outstandingFor`, which sounds like a workshop's "what am I owed". It is not:
`payoutsProvider`, `auditLogProvider` and `outstandingByProviderProvider` are
read **only** by `admin_screen.dart`, the founder panel, which does its own
`warmUp(includeFounderLedger: true)` and `operatorQueueProvider.refresh()` on
entry. The workshop dashboard's earnings come from `WorkshopRepository`
(`/my-workshop/*`) and never touch the ledger. So no non-founder screen loses
data.

### Four tests failed, and they were right to

The fake world seeds every test container with a session (`MemoryTokenStore`
holding the non-JWT string `'test-access'`), and the mock services do not
enforce roles — so founder-only data used to arrive for everybody. Gating on a
real claim took it away:

- `scenario_integrity_test` × 2 read the whole seeded marketplace through
  `operatorQueueProvider`.
- `session_refresh_test`'s founder-ledger test asserts sign-in *does* fetch
  payouts.

Fixed by adding `founderSessionOverride()` to `test/fakes/fakes.dart` — a real
three-part JWT whose payload is exactly the founder role claim — and passing it
in those three tests. **Deliberately not made the default token**: seven test
files sign in, and `activeRoleProvider` returns `AppRole.founder` the moment
`isFounder` is true, so a founder-by-default container would have quietly
changed what `profile_test`, `account_test` and
`account_business_panel_test` were testing.

The fourth, `workshop_dashboard_test`'s StatisticsScreen, was **not** a data
problem: dumping the widget tree showed the expected empty states appear after
`pumpAndSettle` but not after that helper's single fixed `pump(500ms)` — the
two figure providers each re-run once `workshopSummaryProvider` resolves, which
is more async hops than one pump covers. The test now settles. The helper
itself was left alone, since three other tests (and the dashboard goldens)
depend on its fixed pump.

### Verified

- `flutter analyze` — no issues.
- `flutter test` — all 566 pass.
- The four failures were **confirmed to be caused by this change**, not
  pre-existing: `git stash`ing only `session_refresh.dart` and `bootstrap.dart`
  made all three files pass, and popping it brought them back.
- **Not** verified against the live API: the console should now show no `403`
  for these three after an ordinary sign-in, and a founder's panels should
  still populate, but neither was watched in a running app.

---

## 2026-08-26 (1) · Login redesigned: an ink header, a sliding channel switch, and one box per code digit

**Baseline:** `00e1d90`, on top of the uncommitted working tree from the
entries below. Request, verbatim: "the login design needs to be improve. make
it modern in different way."

### The bug the screenshot showed first

The brand tile rendered as a **full-width black bar**, not the 56px rounded
square it asked for. `Container(width: 56, height: 56)` was a direct child of
a `ListView`, and a `ListView` hands its children a *tight* cross-axis
constraint — so the width was ignored and the tile stretched edge to edge. It
had presumably looked right wherever it was written and never been checked in
place.

### What changed

**One flat sheet of sand → an ink header over a form.** The screen is now a
`brandGradient` panel with a 32px rounded bottom, carrying the back button,
the (correctly sized) 48px key badge, the title and the subtitle — badge
*beside* the title rather than stacked above it, which halves the header's
height. A soft off-canvas white disc at 5% keeps it from reading as a plain
black rectangle. The back button is a white-on-ink chip rather than
`SandBackButton`: that widget's chip is `ak.surface`, which is dark in the Ink
theme, and the header is the same dark gradient in *both* themes.

**Two channel cards → one sliding segmented control.** `AuthChannelCard`
(icon + title + subtitle, twice, side by side) is replaced by
`AuthChannelSwitch` — one track, a thumb that slides on `easeOutCubic`, and
the delivery detail demoted to a single line underneath that changes with the
selection. About a third of the height. The thumb uses
`AlignmentDirectional`, so under RTL it starts on the same side the flipped
segment row does.

**One wide code field → four boxes.** `AuthOtpBlock`'s single field faked its
gaps with `letterSpacing: 10`, which showed no progress — how many digits were
wanted, and how many had landed, could only be worked out by counting
characters. `AuthOtpBoxes` draws one box per digit, lights the next one to
fill, and reddens all four on error. There is still exactly **one** real
`TextField`: an invisible one (`Opacity(0)`, which still hit-tests) stretched
across the row, so paste, autofill and the OS one-time-code suggestion keep
working and the boxes are only a rendering of its value.

**The two steps are now actually two steps.** The identifier field used to
stay on screen after sending, locked `readOnly` with no way to unlock it — a
mistyped digit meant leaving the screen and coming back. It is now replaced by
a "Code sent to +968 …" summary with a **Change** button that returns to step
one. The channel switch and the account-kind notice are gone from step two:
there is one thing to do there. The steps cross-fade through an
`AnimatedSwitcher`.

**The dead space is gone.** The form sits in `Expanded > Center >
SingleChildScrollView`, so a short form is vertically centred between header
and button instead of pinned under the header with a wall of empty sand below
it. The footer's hard `border(top:)` divider is gone — it was drawing a box
around that emptiness.

### Overflow caught in review

The first cut of the resend line was `Row[Text("Didn't get it?"),
TextButton(countdown)]`, which overflowed by 4.3px in English and would have
been far worse in Arabic (the Arabic countdown is about half again as long).
It is now a single centred element: a countdown `Text` while the timer runs, a
`TextButton.icon` once it expires.

### Scope

`AuthChannelCard` and `AuthOtpBlock` were **login-only** — `grep` found no
other call sites, and `register_screen.dart` uses only `AuthNoticeCard`,
`AuthSectionLabel`, `AuthFieldRow`, `AuthPhone`, `AuthChannel` and
`OmanMobileFormatter`, none of which changed. So they were replaced rather
than left behind as dead code. **No logic changed**: validation, `findAccount`
/ `login` calls, the rate-limit and OTP error copy from the 2026-08-25 entry,
and the resend countdown are all byte-identical.

### Verified

- `flutter analyze` — no issues.
- `flutter test` — all 566 tests pass, including
  `login_error_messages_test.dart`, whose four cases still drive the screen
  through both steps (its anchors held: the phone field is still the first
  `TextField`, the code field still the last).
- A **temporary** layout test pumped the screen at 402×874 in both `ar` and
  `en`, through step 1 → send → partial code → Change, asserting
  `takeException()` was null at each stop. That is what caught the resend-row
  overflow. Deleted after it went green; it is not in the suite.
- **Not** verified on a device or emulator: the gradient, the thumb slide, the
  box-lighting animation and the step cross-fade were never seen rendering —
  only asserted not to overflow.

---

## 2026-08-25 (3) · The login/register choice is a dialog now, not a page of its own

**Baseline:** `00e1d90`, on top of the uncommitted working tree from the
entries below. Request, verbatim: "I want to update the idea of login page
display. now its a new page open to view two options: register new account or
login. I want this idea display as dialog popup box in modern way instead of
open new page."

### What changed

`AuthGateScreen` was a full route at `/auth`: a `Scaffold` with a back button,
a brand mark, and the two option cards. Every gated action — adding a car,
checking out, posting an ad — pushed it, so answering "which kind of account
is this?" looked like leaving the task behind.

It is now `showAuthGate(BuildContext)`, a `showGeneralDialog` over whatever
screen asked. The two option cards, their copy, and their press animation are
unchanged; what is new is the presentation:

- Blurred backdrop (`BackdropFilter`, sigma ramped 0→6 with the animation) so
  the screen underneath stays visible and the interruption reads as temporary.
- Fade plus a 0.94→1.0 scale on `easeOutCubic`, 240ms — the card settles
  forward rather than growing into place.
- An X in the top corner (labelled for screen readers) replaces the back
  button; the barrier is dismissible, so tapping outside or pressing back
  cancels and leaves the user exactly where the gated action was.
- Capped at 420px wide and centered, with `viewInsets` padding for the short
  screens where the keyboard would otherwise overlap it.

The dialog **returns a choice** (`_GateChoice.login` / `.register`) rather than
navigating from inside itself — `showAuthGate` awaits the pop, then pushes
`/login` or `/register` through a `GoRouter` captured before the await. Popping
and pushing from the same callback would have raced the exit animation, and the
captured router avoids using a `BuildContext` whose widget may be unmounted by
then.

### Call sites

- `ensureRegistered` (`lib/core/router/app_router.dart`) now calls
  `unawaited(showAuthGate(context))` instead of `context.push('/auth')`. That
  covers the eight gated actions in `cars_screen`, `my_ads_screen`,
  `home_screen`, `service_detail_screen`, `product_detail_screen`, and
  `shop_screen` — none of those files needed a change.
- `profile_screen.dart` had three direct pushes to `/auth` (the register
  prompt card, the "Complete your details" menu row, and the identity card).
  All three now open the dialog; the registered-user branches still push
  `/register` as before.
- The `GoRoute` for `/auth` was **removed**. Nothing else referenced it:
  `AuthState.initialRoute` can only return `/splash`, `/start-choice`, or
  `AppFlags.startLocation`, and a grep across `lib/` and `test/` found no
  other push, redirect, or deep link naming it. Leaving a dead route
  registered would have left two divergent ways to ask the same question.

### Verified

- `flutter analyze` — no issues.
- `flutter test` — all 566 tests pass.
- **Not** verified on a device: the blur, the entrance stagger, and the
  RTL chevron direction inside the dialog were not looked at on a running
  emulator, only reasoned about from the unchanged card code.
---

## 2026-08-25 (2) · Whole-project Flutter review, and the 13 fixes it produced — starting with a release build that would have trusted any TLS certificate

**Baseline:** `00e1d90`, on top of the uncommitted working tree from the entry
below. Request, verbatim: "review the whole flutter project", then "apply all
fix suggested."

A `/ecc:flutter-review` pass over all 240 files in `lib/`. Most of what it
looked for was already right — every `.when(` has an `error:` branch, all 40
files that create controllers dispose them, there are 86 `mounted` guards, and
exactly two untranslated user-facing strings, both brand names. The findings
below are what was left.

### 1. CRITICAL — a release build would accept any TLS certificate if `AK_ENV` was missing or misspelled

`DioApiClient` sets `badCertificateCallback = (_, _, _) => true` for
`AppEnvironment.development`, to trust the ASP.NET Kestrel dev certificate.
That is fine on its own. The problem was that everything guarding it failed
open: `AK_ENV`'s dart-define defaults to `'development'`, and
`AppEnvironment.fromKey` returned `development` for *any* unrecognised value.
`kReleaseMode` appeared nowhere in the codebase.

So a release build shipped without the define, or with `AK_ENV=prod`, would
have disabled certificate validation on every request — bearer token, refresh
token, CR/VAT numbers and customer phone numbers readable and modifiable by
anyone on the network path, with nothing visible in the app to indicate it.

Two changes, either of which closes it alone:
- `dio_api_client.dart` — the guard is now `!kIsWeb && !kReleaseMode &&
  config.environment.isDevelopment`. A compile-time constant, so it does not
  depend on anyone getting a build command right.
- `app_environment.dart` — `fromKey` now falls back to `production`, not
  `development`. Every environment-gated concession in this app *loosens*
  something, so the unknown case has to land on the strict end. A plain
  `flutter run` is unaffected: the define's default is the literal string
  `'development'`, which matches a real enum value and never reaches the
  fallback.

### 2. HIGH — the push subscription was never cancelled

`NotificationsNotifier._subscribeToPush` called `.listen(...)` and dropped the
`StreamSubscription`. `clear()`'s own doc comment had *identified* the
consequence ("would rebuild the notifier and open a second push subscription
without closing the first") and worked around the trigger instead of the
cause. It is now held and cancelled via `ref.onDispose`, the same way
`RequestsNotifier` handles its timers. `adopt` also gained the `_disposed`
guard the class already had but was not using there. The two doc comments that
described the leak as unavoidable were corrected.

### 3. HIGH — `ChatHub` stream controllers were never closed or removed

`_threadControllers` gained an entry per thread via `putIfAbsent` and lost one
never — no `close()`, no `remove()`, no `dispose()` anywhere in the file. The
map grew for the life of the process and survived sign-out (`chatHubProvider`
is not rebuilt by `SessionRefresh`), leaving one account's thread ids keyed in
a hub the next account on the same device was posting frames into.

Added `ChatHub.release(threadId)`, which closes and forgets a controller only
when `hasListener` is false — so a second open view of the same thread keeps it
alive — called from `ApiChatService`'s existing `onCancel`; and
`ChatHub.dispose()`, wired to `chatHubProvider`'s `onDispose`.

### 4. HIGH — three unbounded lists were built eagerly

`ListView(children: [...])` and `Column(children: [...])` instantiate every
child, on screen or not. Converted:
- `inventory_screen.dart` → `ListView.builder`. Worst of the three: a live
  search field sat on top of it, so a workshop with 500 SKUs paid the full
  build cost per keystroke. The field is now debounced 250 ms as well.
- `orders_screen.dart`, `customers_screen.dart` → `CustomScrollView` with a
  `SliverToBoxAdapter` header and `SliverList.builder` rows. Padding was split
  top/bottom across the two slivers so the layout is unchanged.

### 5. MEDIUM — `_invalidateSummary` re-introduced the eager-build bug from the 2026-08-15 entry

`provider_dashboard_state.dart` called a bare
`ref.invalidate(workshopSummaryProvider)`, which is exactly what
`SessionRefresh._ifBuilt`'s doc comment spends twenty lines explaining is
unsafe. Not hypothetical: `MyWorkshopProfileNotifier.save` is also reached from
"بياناتي" in `register_screen.dart`, where the dashboard has never been opened
and that provider does not exist. Guarded with `ref.exists`. The `save` method
four lines below was already guarding `workshopScheduleConfigProvider`
correctly. `ref.invalidate(workshopScheduleProvider)` was left bare — it is a
`.family`, and a bare-family invalidate only touches existing instances.

### 6. MEDIUM — screen readers could not reach the app's own tappables

One `Semantics` widget existed in 240 files, against 96 `GestureDetector`s.
`InkPill` and `SandPressable`, the two shared pressables, published no role and
no tap action, so TalkBack and VoiceOver read them as static text.
- Both now wrap in `Semantics(button: true, ...)`. `InkPill` passes its own
  `label` and excludes the child's duplicate text node; `SandPressable` takes
  an optional `semanticLabel` and otherwise lets the wrapped card's text serve
  as the name.
- `InkPill` also gained 7px of vertical tap padding, the same trick
  `SandBackButton` already used, so the target clears 44px without changing the
  painted pill (~31px before).
- All 18 icon-only `IconButton`s that had no `tooltip:` got one, bilingual via
  `s.t(...)`. Two files (`cart_screen.dart`, `review_widgets.dart`) needed an
  `S.of(context)` first. The cart stepper's label changes with its icon at
  qty 1, and the five star buttons are now distinguishable from each other.

### 7. MEDIUM — the rest

- `push_service.dart` — `onTokenRefresh.listen` fired an unawaited, unguarded
  `_client.post`, in the one class whose stated contract is that push failures
  are logged and swallowed. Routed through `registerCurrentDevice()`, which has
  the try/catch.
- `requests_state.dart` — `_scheduleAutoRelease`'s reminder timer resumed past
  an `await` and used `ref` without re-checking `_disposed`. `ref.onDispose`
  cancels timers that have not fired; it cannot cancel one already suspended at
  the await. Second check added.
- `token_store.dart` — was using default `FlutterSecureStorage()`. Now
  `AndroidOptions(encryptedSharedPreferences: true)` and
  `IOSOptions(accessibility: first_unlock_this_device)`. The `_this_device`
  half keeps the refresh token out of iCloud/iTunes backups, which is the exact
  threat that file's own doc comment names.
- 20 `MediaQuery.of(context)` call sites narrowed to `sizeOf` / `viewInsetsOf` /
  `paddingOf`. The over-broad form subscribes to every MediaQuery change, so
  bottom sheets reading `.size.height` rebuilt on every keyboard-animation
  frame. The one remaining `MediaQuery.of` is `working_hours_field.dart`'s
  `copyWith`, which needs the whole object.
- `contact.dart` — the one outstanding analyzer info
  (`use_null_aware_elements`).

**Verified:** `flutter analyze` → "No issues found!" across the project (it was
1 info before this work).

**NOT verified — read this before trusting the entry:** `flutter test` was
**not** run after these changes. The command was blocked by the session's
permission classifier and the suite has not been executed since. The last known
state is 566/566 passing *before* any edit. The highest-risk item is the
`InkPill` tap padding in §6, which changes layout and could move
`test/goldens/dashboard_home_*.png` — `dashboard_home_screen.dart` does not
reference `InkPill` directly, so it may well pass, but that is reasoning, not a
test run. Run `flutter test` before committing.

**A mistake made and mostly undone, recorded because the diff shows traces of
it:** `dart format lib/` was run to tidy the new code. Dart 3.12's "tall style"
formatter restyled ~150 files that had nothing to do with this work, turning a
38-file change into a 193-file one. All 197 tracked files outside the
already-dirty working set were restored with `git checkout HEAD --`, bringing
`lib/` back to 67 changed files (37 pre-existing + 30 from this entry).
`dart format` was deliberately **not** re-run afterwards; the new code is
hand-formatted to match its surroundings instead. The 37 files that were already
dirty did pass through the formatter once — but their uncommitted diffs were
already in tall style before this session (visible in `session_refresh.dart`'s
pre-existing hunks), so it was most likely a no-op there. Worth a skim of
`git diff` on those 37 before committing.

**Left alone:**
- 17 files still exceed the 800-line ceiling in `CLAUDE.md` §5
  (`admin_screen.dart` at 1930 is the worst). Splitting them is a real
  refactor, not a review fix, and §13.4 says confirm scope first.
- `_sharedApiBaseUrl` is still `https://localhost:7291/api/v1` for *every*
  environment, so a production build points at localhost. That is the
  2026-08-09 instruction in `app_config.dart` ("do not change until told to"),
  left as-is deliberately — but it will have to change before any real release,
  and it is now the only thing standing between §1's fix and a shippable build.

---

## 2026-08-25 · The workshop record reads first and edits on purpose — in both places, with shared validation

**Baseline:** entry (6). Request, verbatim, against a screenshot of "بياناتي"
showing an **empty** workshop section on an account that had registered one:
"now, add validations in this page to let user of workshop rol see what he
registerd and give him the chois to edit and update there workshop info. also
in the workshop profile in the workshop dashboard same thing."

**This reverses part of entry (6) §3 and entry (4) §4, deliberately and at the
owner's request.** Those made the filed record view-only. It is now
*read-first, editable on purpose*: the owner sees exactly what is on file and
can change it in one tap. The reasoning that produced the lock still holds for
one field only — the CR certificate — and that is the only thing still not
editable by its owner.

---

### 1 · The bug in the screenshot: the section was empty

The workshop half of "My details" seeds its controllers in `initState` from
`profile.workshop`. After a fresh sign-in that is **null** — `GET /me` answers
with the account, not with the application it filed months ago — so an owner
who had registered, been approved, and was live in the marketplace opened "My
details" to a blank registration form. No name, no area, no certificate, and
nothing saying the platform still had the record.

Seeding now falls back to the marketplace roster entry (`providerOwnedBy`),
which is the record the founder approved: name (ar/en), CR number, VAT number,
area, fulfillments and the certificate itself.

### 2 · Read first, then edit — the same shape in both screens

Neither screen opens as a wall of live inputs over a verified business record.

**"My details"** shows the filed record read-only under a header that names it
("Your filed record") with **Edit workshop details**. Tapping it turns the
section into ordinary validated fields; **Discard changes** puts every one of
them — including the chips and the area picker — back to what is on file.

**The dashboard's workshop profile** does the same at screen scale: the
reading view from entry (6), an Edit action in the app bar and a full-width
button at the foot, then the editor with Save changes / Cancel. Hours in that
editor are the [entry (6)] `WorkingHoursField` picker, so the owner and the
founder now edit hours the same way.

A rejected application still opens **in edit mode**: correcting it is the only
reason its owner came.

### 3 · Saving means two different things, and the screen says which

The trap here is `resubmitWorkshopApplication` → `submitWorkshopApplication`,
which **files an application for review**. Entry (4) hit this: an approved
owner correcting their phone number was put back into the founder's pipeline.

So the save path forks on the stage, and the notice says so before anything is
typed:

- **Approved** → `PUT /my-workshop`. The live `ServiceProvider` *is* the
  record; the change reaches customers on save and no review re-opens.
  ("Your workshop is approved — what you save here reaches customers
  directly.")
- **Anything else** → re-file the application, as before. ("Saving re-submits
  your application for the founder to review.")

Both paths then refresh the marketplace roster, because it is a separate cache
— without it the status dialog on "My account" and the services list would
keep showing the old name until the next cold start. That refresh is never
allowed to fail the save it follows: the record is already written by then, and
reporting "couldn't save" because an optional fetch timed out would be a lie.

### 4 · The validations

New `lib/core/utils/workshop_validation.dart` — `WorkshopRules`, one set of
rules for all three screens that touch this record. Rules written per screen
drift, and the owner finds out which screen was lying only after a rejected
review.

| Field | Rule |
|---|---|
| CR name (Arabic) | required |
| CR number | 6–10 digits; required at registration, optional on an existing record |
| VAT number | **optional**, shape-checked when given (`OM1100059183` or the bare digits) |
| Phone | 8 Oman digits, `2`/`7`/`9` — a workshop line may be a landline |
| WhatsApp | 8 digits, mobile only — there is no WhatsApp on a landline |
| Area / region | required |
| Fulfillments | at least one, or the listing cannot be booked at all |
| Pickup fee | a non-negative number, or empty |

Nothing here contacts a registry. A CR number is shape-checked, never
verified — the founder reads the certificate, and a client-side check
pretending otherwise would be false assurance.

### 5 · Two fixes that fell out of the above

- **`_buildApplication` could throw.** It read `_crDocs.first`, safe only
  while validation demanded a certificate for every workshop save. An approved
  workshop legitimately has none in this form (the document lives on its
  record), so it now returns null and the caller keeps the filed application
  untouched.
- **Saving an address change no longer re-dates the application.** Only an
  actual edit pass sets a new `submittedAt`.

### Files

| File | Change |
|---|---|
| `lib/core/utils/workshop_validation.dart` | **new** — `WorkshopRules`, the shared field rules |
| `lib/features/auth/register_screen.dart` | roster fallback seeding; `_workshopEditing` + `_WorkshopRecordNotice` (read/edit/discard); validation via `WorkshopRules` + fulfillments; stage-forked save (`_saveApprovedWorkshopRecord`); `_buildApplication` nullable; `_workshopErrorKeys` |
| `lib/features/workshop_dashboard/workshop_profile_screen.dart` | view + editor, validation, hours picker, roster refresh after save |
| `lib/state/provider_dashboard_state.dart` | `save`'s doc comment: it has callers again, and why they use it instead of re-filing |
| `test/workshop_validation_test.dart` | **new** — 16 tests over the shared rules, both languages |
| `test/workshop_dashboard_test.dart` | view/edit/cancel and the malformed CR/VAT/phone refusal; the entry (6) view-only tests replaced |
| `test/account_business_panel_test.dart` | read-then-edit-then-discard; a profile with no application still shows what it registered |

### Verified

- `flutter test` — **566 passed** (547 before, +19).
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements`, `lib/core/utils/contact.dart:23`) is pre-existing.
- **Not** run on a device or emulator. In particular the approved-workshop save
  path (`PUT /my-workshop` from "My details") is covered by the shared rules
  and the mock service, not by a real API round trip.

### Known-adjacent, left alone

- **The CR certificate is still owner-read-only.** There is no owner-side
  endpoint to replace it — `updateCrDocument` is on `adminActionsProvider` —
  so both screens say "contact support" instead of offering a control that
  cannot work. An owner-side "request a document change" flow would need a
  founder-side inbox.
- **"My details" edits a subset.** Phone, WhatsApp, hours, capabilities and
  the pickup fee are passed back through unchanged from the current record
  when an approved workshop saves there: a screen that does not show a field
  has no business rewriting it. Those live on the dashboard's workshop
  profile.
- **Area and region are free text in the dashboard editor**, while "My details"
  picks them from `LocationCatalog`. A typo there produces a governorate the
  services filter cannot match. Worth giving that editor the same picker.
- **No optimistic-concurrency check.** If a founder and an owner edit the same
  workshop at the same time, the later `PUT` wins silently.

---

## 2026-08-24 (6) · Status dialog rebuilt, working hours picked instead of typed, and the owner's workshop profile made read-only

**Baseline:** entry (5). Request, verbatim, against two screenshots (the
workshop-status dialog, and the founder's workshop editor): "needs to improve
and update to be modern. also when login as founder, and open any workshop
profile to edit, the date time of works hours need to change as real picker not
as text. also, when workshop owner open's his profile to edit, do not allow to
edit the workshop information's. only display them. the only who can edit is
the founder user in the founder dashboard."

---

### 1 · The workshop-status dialog

Entry (4) created it as a plain title/body/actions `AlertDialog`: a small icon
tile, a badge, two paragraphs, a list of facts, and two text buttons in a
corner. It read as a system alert, not as the workshop's own card.

Rebuilt as a sheet — still an `AlertDialog`, so the barrier, the dismiss
behaviour and the platform padding stay standard, but the whole shape now
lives in `content` with zero title/content padding:

- **Tinted header band** in the stage's own colour (green approved / red
  suspended / amber under review), carrying the icon on a surface tile, the
  workshop name, `area · region`, and the stage badge.
- **A four-step rail** — `applied → documentsSubmitted → verified → approved`,
  the stages the backend actually has, with "Step 3 of 4 · Verified" under it.
  An applicant asking "where is this" now gets a position rather than a
  paragraph. Suspended has no rail on purpose: it is not a step on the path,
  it is the path ending, and the founder's reason above already says so.
- **The record in its own grouped card** — divider-separated rows on the dim
  surface instead of loose lines. Working hours were added to it: they are on
  the record and the owner has no other read-only view of them.
- **A full-width primary action** (Dashboard / Edit and re-submit) with Close
  under it, instead of two small words in the corner.

### 2 · Working hours are picked, not typed

`WorkingHoursField` (new, `lib/core/widgets/working_hours_field.dart`) replaces
the founder editor's two free-text boxes — `ساعات العمل (عربي)` and `Hours
(English)` — with day chips, two `showTimePicker` tiles (forced 24-hour), and a
preview of the exact sentence that will be stored in each language.

The API still stores `hours` as a free-text `{ar, en}` pair, so the widget's
`WorkingHours` value type carries the structure and renders back to that string
on save: `Sat–Thu 08:00–18:00 · Fri closed`. Contiguous days collapse into a
range, two loose days read as a pair, and a full week has nothing to call
closed.

**Reading existing values back is the hard half**, and it is where the first
implementation was wrong. `WorkingHours.parse` normalises Arabic-Indic digits,
the four dashes, the alef and ta-marbuta spellings and case, then groups day
names into phrases and decides open-vs-closed by *adjacency* to the word
"closed"/"مغلق". The first version split on `·` instead, which got the real
database value — `السبت–الخميس ٧:٣٠–١٩:٠٠ الجمعة مغلق`, with no separator at
all before `الجمعة` — exactly backwards: the whole line contained "مغلق", so
every day was marked closed and the parse returned null. Caught by the test
written from that screenshot.

Text that still cannot be read (`By appointment`, `حسب الطلب`) parses to null,
and the field then **shows the stored text verbatim** with a "Set them with the
picker" button, and the screen saves it back unchanged unless the founder takes
it over. Quietly replacing hours the founder was never shown would be worse
than the free-text box this replaced.

### 3 · The owner's workshop profile is view-only

`workshop_profile_screen.dart` was a full editor — every field of the approved
record, plus Save. It is now a read-only view: grouped fact cards for identity,
contact + hours, registration + fees, and non-interactive pills for
fulfillments and capabilities.

Why: this record is what the founder approved and what customers search, call
and book against. An owner who could rewrite their own name, governorate,
phone or commercial numbers after approval would leave an approval standing
over details nobody checked — the same reasoning that locked the filed
application in "My details" in entry (4). Editing now lives in exactly one
place, `admin_workshop_detail_screen.dart`.

**The completeness meter stays**, with reworded copy. The owner still needs to
know which fields the platform is missing — that is what they have to ask
support for — so locking the fields does not mean hiding the gaps.

**A notice says who to ask**, and names what the owner *does* still control
from the dashboard: offerings, add-ons, inventory, team, and the schedule's
slots/capacity/closed days. A locked screen with no explanation reads as a
broken screen.

**Entry (4)'s lock notice in "My details" was corrected** in the same pass: it
told owners that "opening hours, phone and services are managed from the
workshop dashboard", which stopped being true the moment the dashboard's
profile went read-only. It now points at support for hours and phone, and at
the dashboard for offerings/inventory/team/schedule.

### Files

| File | Change |
|---|---|
| `lib/core/widgets/working_hours_field.dart` | **new** — `WorkingHours` (format/parse/round-trip) and `WorkingHoursField` (day chips, time pickers, both-language preview, unparsed-text fallback) |
| `lib/features/operations/admin_workshop_detail_screen.dart` | founder editor: two hours `TextField`s → `WorkingHoursField`; unreadable stored text passed back unchanged on save |
| `lib/features/workshop_dashboard/workshop_profile_screen.dart` | rewritten as a read-only view: fact cards, view-only notice, completeness meter reworded; no `PUT` |
| `lib/features/profile/profile_screen.dart` | `_WorkshopStatusDialog` rebuilt (header band, `_StageRail`, grouped record card, `_DialogAction`); `_DialogFact` gained a `last` flag |
| `lib/features/auth/register_screen.dart` | locked-application notice corrected — it no longer promises the dashboard can edit hours/phone |
| `lib/state/provider_dashboard_state.dart` | `MyWorkshopProfileNotifier.save` documented as caller-less, and why it was kept |
| `test/workshop_dashboard_test.dart` | +12 tests: owner profile is uneditable, `WorkingHours` format/parse cases, `WorkingHoursField` interaction |
| `test/account_business_panel_test.dart` | +1 assertion: the dialog shows the review step rail |

### Verified

- `flutter test` — **547 passed** (534 before, +13).
- `flutter analyze lib test` — clean; the one remaining info
  (`use_null_aware_elements`, `lib/core/utils/contact.dart:23`) is pre-existing.
- **Not** run on a device or emulator — no visual confirmation of the rebuilt
  dialog, the time pickers, or the read-only profile.

### Known-adjacent, left alone

- **`PUT /my-workshop` is now unreachable from the app.** The notifier,
  repository, service and API client for it all still exist. Left in place
  deliberately (see the comment on `MyWorkshopProfileNotifier.save`) rather
  than ripped out across four layers on the strength of one UI decision.
- **There is still no in-app "ask support to change my record" route.** Both
  view-only notices say "contact support", which in practice is the WhatsApp /
  phone sheet on My account. Same gap entry (4) recorded; a real request flow
  would need a founder-side inbox.
- **One workshop, one set of hours.** The picker models a single opening and
  closing time across all open days. A workshop with different Thursday hours,
  or a lunch break, still cannot express that — `hours` would have to stop
  being a string on the server before the client could offer it.
- **The schedule screen's config sheet still owns slots/capacity/closed days**
  and passes `hours` through untouched, so the two cannot disagree on the
  string. Its closed days and the profile's open days are, however, two
  separate records that a founder and an owner could set inconsistently.

---

## 2026-08-24 (5) · Every provider/offering read 500'd: the Photo mapping shipped without its migration

**Baseline:** entry (4). Reported as a runtime log: `SqlException … Invalid column
name 'PhotoCaption' / 'PhotoData' / 'PhotoFileName' / 'PhotoId' /
'PhotoMimeType'`, turning `GET /service-marketplace/providers` and
`/offerings` into 500s and taking the app's whole catalogue with them.

### What happened

Entry (3)/(4) added `ServiceProvider.Photo` and its `OwnsOne` mapping, but the
migration was never generated — `dotnet ef` could not build while the API was
running, and the one attempt produced an empty migration off stale assemblies
(and, worse, removed the wrong one — see below). EF therefore queried five
columns per table that SQL Server did not have.

The error named the columns **twice** on the offerings query, which was the
useful detail: `ServiceOfferings.Photo*` was missing too. So the offering-photo
work from a previous session had never reached this database either.

### The fix

One migration covering both, since neither had ever been applied:
`20260824190700_AddServiceProviderAndOfferingPhoto` — ten nullable columns,
five per table (`PhotoId uniqueidentifier`, `PhotoData varbinary(max)`,
`PhotoMimeType nvarchar(100)`, `PhotoFileName nvarchar(255)`,
`PhotoCaption nvarchar(500)`), applied to `AKCarsMobileDb`.

### Resolves the warning left in entry (3)

That entry flagged that the accidentally-deleted `20260818194205_AddServiceOfferingPhoto`
might leave `__EFMigrationsHistory` referencing a migration no longer in source,
needing a hand cleanup. **It does not.** `dotnet ef migrations list` shows no
such row: the migration was never applied anywhere, which is exactly why the
offering columns were missing at runtime. Nothing to clean up, and the new
migration restores those columns as a side effect. The only lasting trace is
that the offering-photo columns now arrive under a differently-named migration.

### Verified

- `dotnet ef database update` → Done; `sys.columns` confirms all ten columns on
  both tables.
- API started and both previously-500ing endpoints re-checked over real HTTP:
  `/providers` **200** (10 records, each carrying `photo: null` — the field is
  live and correctly empty), `/offerings` **200**. Zero `[ERR]` lines in the
  server log after startup.
- `dotnet test` — **941 passed**.
- The API was started by this session for that check and **stopped again**
  afterwards, so the Visual Studio debug session owns the ports again — it
  needs restarting from VS.

### Still open

The Flutter half of the storefront photo is unstarted: `ServiceProvider.photo`
on the Dart model, the service/repository plumbing, `ServicePhotoField` on the
dashboard's workshop-profile screen, and rendering on the marketplace provider
cards. The column and the API contract are ready for it.

---

## 2026-08-24 (4) · My-account cleanup: status as a dialog, About as a dialog, and a filed workshop record made read-only

**Baseline:** `00e1d90`, on top of entry (3). Request, verbatim: "the settings
button at the top left is no longer needed. in the account section in my
account page, make the workshop status as popup box dialog shows the workshop
short cut info with status as dialog popup box. in the settings page, the about
about button, update it to be as dialog pop up box shows app info with the
version. in my info page. workshop owners they can't change there workshop
info. it should view only registered data as disable for editing."

---

### 1 · Settings cog removed from the My-account header

It was a second door to the screen the "Language & appearance" row in the
Account section already opens. `_CircleButton` existed only to host it and went
with it.

### 2 · Workshop status → a dialog

The row still shows the verdict as a badge (green approved / red suspended /
amber everything else). Tapping it now opens `_WorkshopStatusDialog`: workshop
name, area · region, the stage badge, the owner-facing sentence, and the record
behind it — phone, WhatsApp, CR number, verification. An approved workshop gets
a **Dashboard** action; a rejected one gets **Edit and re-submit** carrying the
founder's own unedited reason.

Read-only by design: everything in it is either the founder's decision or the
registered record, and neither belongs behind an edit control in a status
popup.

The old behaviour — tapping the row silently restored a dismissed status card —
is now an explicit "Show the status card again" button inside the dialog, shown
only while the card is actually hidden.

Name falls back to the filed application's `businessNameAr` when the workshop
has no roster entry yet: an application under review genuinely has none, and an
em-dash there would read as lost data rather than "not live".

### 3 · Settings "About the app" → a dialog

It was a dead row: it printed a version and did nothing when tapped. Now it
opens a dialog with what the app is, the market, the currency and the version.

**It also fixed a real inconsistency.** Two hardcoded version strings had
drifted apart on the same build — Settings said `v2.0`, the profile screen said
`v1.0.0`, and `pubspec.yaml` said `1.0.0+1`. Both now read
`AppConstants.appVersion` (`1.0.0`, matching pubspec). A version the app cannot
state consistently is worse than one it does not show, since it is the first
thing a support conversation asks for.

### 4 · A filed workshop record is view-only in "My details"

Business name (ar/en), CR number, VAT number, the certificate, the area picker
and the fulfilment chips are all locked once an application has been filed. The
certificate renders as read-only `AttachmentThumb`s instead of the `MediaStrip`
uploader — the founder approved *that* document, and silently swapping it would
leave an approval standing over a file nobody checked. A notice at the top of
the section says so and points at the two places that *are* editable: support
for the CR record, the workshop dashboard for hours/phone/services.

**Two deliberate exceptions**, both flagged rather than assumed:

- **A rejected application stays editable.** Correcting it is the entire point,
  and the status card already tells the owner to "edit and re-submit". The lock
  is `stage != suspended`, not "is a workshop".
- **A first-time registration is not locked** — there is nothing filed yet to
  protect.

**A bug found while doing this.** `_submit` called
`resubmitWorkshopApplication` on *every* save by a workshop account, and that
call goes through `submitWorkshopApplication`, which re-files the application.
An approved workshop owner who corrected their own phone number would have been
put back into the founder's review pipeline with nothing to review. Resubmission
is now gated on the same `!_workshopLocked` condition, so it only fires when the
owner could actually change the application.

### Files

| File | Change |
|---|---|
| `lib/core/constants/app_constants.dart` | `appVersion`, the single source for both places that show it |
| `lib/features/profile/profile_screen.dart` | header cog + `_CircleButton` removed; `_WorkshopStatusRow` opens `_WorkshopStatusDialog`; `_stageBadge`/`_DialogFact` helpers |
| `lib/features/settings/settings_screen.dart` | About row wired to `_showAboutDialog`; `_AboutFact` helper; version from the constant |
| `lib/features/auth/register_screen.dart` | `_workshopLocked`; read-only fields, picker, chips and certificate; lock notice; resubmission gated |
| `test/account_business_panel_test.dart` | 5 new tests; the dismiss/restore test corrected (see below) |

### Verified

- `flutter test` — **534 passed** (529 before, +5).
- `flutter analyze` — clean; the one remaining info
  (`use_null_aware_elements`, `lib/core/utils/contact.dart:23`) is pre-existing.
- **A test from entry (3) was passing for the wrong reason and is now fixed.**
  "the row brings the card back" asserted on the status sentence alone — which
  the new dialog also prints, so it would have passed whether or not the card
  came back. It now asserts an `AlertDialog` appeared, taps the dialog's own
  restore control, and checks the dismissal actually cleared.
- **Not** run on a device or emulator — no visual confirmation of either
  dialog or of the locked form.

### Known-adjacent, left alone

- The locked notice points at "contact support" for CR-record changes, but
  there is no in-app route that files such a request — support is the WhatsApp
  / phone sheet on My account. Good enough for the pilot; a real "request a
  change to my CR record" flow would need a founder-side inbox.
- `AuthFieldRow.readOnly` locks input but does not restyle the field. A locked
  field looks the same as an editable one until you tap it; the section notice
  is what carries the message. Greying them would read better.

---

## 2026-08-24 (3) · Workshop dashboard review: the profile screen never loaded, the schedule config never came back, and "open my dashboard" was buried in Settings

**Baseline:** `00e1d90` (HEAD). Request, verbatim: "the workshop dashboard needs
to be review. test and check each section of the dashboard, some of them needs
to update and fix bugs and some needs improve. check the profile page, its not
working and fix it. make this dashboard modern and familiar and friendly for
users. review from the internet what this type of dashboards need to be modern
and then decide and apply the changes then check what you changed. […] the card
of explaining the approving message, add x button […] to allow the user to hide
this card and not view it again. add soothing that describe for the workshop
owner if his account approved or not in the my account page. the option of
opening dashboard for founder users or for workshop owner should be in the my
account page and it should be in modern way."

---

### Bug 1 — the workshop profile screen could never load (the reported one)

`GET /service-marketplace/my-workshop` does not answer with a `ServiceProvider`.
It answers with an envelope:

```jsonc
{ "provider": { … }, "isComplete": false, "missingFields": ["whatsapp", …] }
```

`ApiWorkshopService.getMyWorkshop()` parsed that whole object as a bare
`ServiceProvider`. There is no top-level `id` on it, so `requireString('id')`
threw on every single call and `WorkshopProfileScreen` rendered nothing but its
error state — "تعذّر تحميل الملف الشخصي" — for every workshop, forever. The
dashboard home worked because `/my-workshop/summary` *is* flat, which is why
this looked like one broken screen rather than a broken account.

Modelled the envelope as `MyWorkshopProfile` instead of unwrapping it inline,
because two of its three fields were being thrown away and both are worth
having:

- `missingFields` is the server's own completeness answer, from the same
  handler the founder's review reads. The screen used to re-derive it from the
  provider it had on hand — the same six checks, written twice, free to drift.
  It now renders the server's list and **names** each missing field as a chip;
  a bare "70%" tells nobody which three fields to go and fill in.
- `schedule` — see Bug 2.

`PUT /my-workshop` still answers with the bare provider, so `MyWorkshopProfile`
parses both shapes, and `MyWorkshopProfile.of()` re-derives the completeness
report after a save (six checks mirroring `GetMyWorkshopQueryHandler`, in its
order) so the meter reflects the edit instead of the last `GET`.

### Bug 2 — a saved schedule never came back

`WorkshopScheduleConfigNotifier.build()` returned
`WorkshopSchedule(hours: (await loadMyWorkshop()).hours)` — hours only. Slot
template, capacity per slot and closed days all fell back to their defaults, so
the working-hours sheet reopened blank after every save, and a workshop that
had set "closed Fridays, 3 bays, 08:00/10:00/12:00" saw an empty box and one
bay next time it looked.

The cause is on the API side: those three fields are written by
`PUT /my-workshop/schedule` and **no route ever read them back**. Added them to
`MyWorkshopDto` (`GET /my-workshop`), which is where the rest of the profile
already lives, rather than inventing a fourth schedule route.

Also: saving the config did not invalidate `workshopScheduleProvider`, so the
day grid behind the sheet kept showing slots generated from the settings that
had just been replaced. It does now.

### Bug 3 — smaller ones, found while going through each section

| Screen | Was | Now |
|---|---|---|
| Add-ons | editor dialog was a fixed `Column` — four fields plus a keyboard overflowed on a short phone | wrapped in `SingleChildScrollView` |
| Add-ons | a rejected save was swallowed by a bare `finally`: spinner stopped, dialog open, nothing said | snackbar on failure, same as every other editor |
| Add-ons | a rejected delete threw straight out of the callback | caught, snackbar |
| Schedule | day arrows were fixed `chevronRight`/`chevronLeft` — correct in Arabic, pointing backwards in English | direction-aware, plus a tappable date opening a real `showDatePicker` and a "Today" shortcut |
| Schedule | closed-day chips were hardcoded English `Monday…Sunday`, Monday-first | localised labels (wire value stays English — `UpdateScheduleCommand` parses it back to a `DayOfWeek`), ordered Saturday-first for the Omani week |
| Statistics | no pull-to-refresh; the only way to re-read the figures was to leave and come back | `RefreshIndicator` |
| Dashboard home | quick action labelled "الملف الشخصي / Profile" | "ملف الورشة / Workshop profile" — the account has a *different* screen called Profile, and two things with one name is how someone edits their own phone number meaning the shop's |

### Dashboard home — rebuilt as a priority ladder

Research first, as asked. The consistent findings across current dashboard-UX
writing: a reader should understand the most important thing within about five
seconds; visual hierarchy has to rank the metrics rather than present them as
equals; show only decision-critical figures up front and put the rest behind a
drill-down. Sources are listed at the end of this entry.

The old screen was a 2×2 grid of four identical `OperatorFigure` tiles, where
"3 jobs are waiting on you" and "your average rating" had the same size, the
same weight and the same colour. Nothing on it said what to do first, and no
tile was tappable, so every number was a dead end.

Now, top to bottom:

1. **Identity strip** — workshop name, area · region, live/stage badge. Costs
   no request: `/my-workshop/summary` already carried `provider` and it was
   being discarded.
2. **Alerts** — unchanged; already the right thing, already the top.
3. **Needs your action** — one number, largest type on the screen, amber card,
   straight through to the job list. At zero it becomes a plain "Nothing is
   waiting on you" with a green check rather than a grey `0` in a grid: an
   empty queue is good news and should look like it. Overdue count rides along
   underneath in danger colour when there is one.
4. **Today** — booked today / in progress / awaiting customer.
5. **Money** — held in escrow *and* payout due (the second was already in the
   payload and never shown). The standing off-app-transfer caveat moved inside
   this card, next to the figures it qualifies, instead of floating on its own
   further down where it read as a page-level disclaimer.
6. **Workshop health** — low stock, rating, customers, active team.
7. **Quick actions** — nine tiles, reordered the way a workshop's day runs
   (jobs → schedule → what you sell → what you stock → who does the work →
   numbers → settings).

Every figure is now a tap target into the list that produced it.

### My account — status, dismissal, and the way into a panel

- **X button on the status card.** Dismissal is keyed on the *stage*, not a
  boolean. Hiding "your workshop is approved" must not also hide a later "your
  workshop was stopped" — different sentence, different decision. When the
  stage changes the key no longer matches and the card returns on its own.
  Persisted in `SharedPreferences`, so it stays hidden across launches.
- **A permanent "Workshop status" row** in the Account section, with the real
  stage as a badge (green approved / red suspended / amber everything else).
  This is what makes the card safe to dismiss: the explanation can be put away,
  the fact cannot. Tapping the row while the card is hidden brings it back, so
  dismissing is never a one-way door.
- **"My business" moved from Settings to My account**, as a card rather than a
  settings row: workshop dashboard for an approved owner, founder panel for a
  founder, both for an account that is both. Nothing at all for an unapproved
  applicant — `_guardOperatorPanels` would bounce them straight back, and a
  button that cannot work is worse than no button.
- The section was **removed** from Settings rather than duplicated. Two doors
  to one room drift apart the first time one is edited.
- Consequently `_guardOperatorPanels` and the founder panel's back button now
  land on `/profile` instead of `/settings` — the screen that actually explains
  why the panel was refused.

### Files

| File | Change |
|---|---|
| `lib/data/models/my_workshop_profile.dart` | **new** — the `GET /my-workshop` envelope, plus `.of()` to rebuild it after a `PUT` |
| `lib/data/services/workshop_service.dart`, `.../api/api_workshop_service.dart` | `getMyWorkshop()` returns the envelope |
| `lib/data/repositories/workshop_repository.dart` | caches the envelope; `updateMyWorkshop` re-wraps the PUT's bare provider |
| `lib/state/provider_dashboard_state.dart` | profile provider holds `MyWorkshopProfile`; schedule config reads the real config; config save invalidates the day view |
| `lib/features/workshop_dashboard/dashboard_home_screen.dart` | rebuilt (see above) |
| `lib/features/workshop_dashboard/workshop_profile_screen.dart` | server-sourced completeness, missing fields named |
| `lib/features/workshop_dashboard/schedule_screen.dart` | `_DayPicker`, localised weekdays |
| `lib/features/workshop_dashboard/add_ons_screen.dart` | scrollable dialog, save/delete error handling |
| `lib/features/workshop_dashboard/statistics_screen.dart` | pull-to-refresh |
| `lib/features/profile/profile_screen.dart` | dismissible status card, `_WorkshopStatusRow`, `_BusinessPanelSection`, `_PanelCard` |
| `lib/features/settings/settings_screen.dart` | "My business" section removed |
| `lib/state/settings_state.dart`, `lib/core/constants/app_constants.dart` | `workshopNoticeDismissalProvider` + its prefs key |
| `lib/core/router/app_router.dart`, `lib/features/operations/admin_screen.dart` | operator-panel refusals and the founder back button land on `/profile` |
| `docs/api_contract.md` | `GET /my-workshop` envelope documented, including the `PUT` asymmetry |
| **API** `.../MyWorkshop/Common/MyWorkshopDtos.cs`, `.../GetMyWorkshop/GetMyWorkshopQuery.cs` | `MyWorkshopDto` carries `Schedule` |
| `test/account_business_panel_test.dart` | **new** — replaces `settings_business_section_test.dart` (deleted); 7 tests |
| `test/workshop_dashboard_test.dart` | envelope parsing, completeness re-derivation, schedule round-trip; smoke tests updated to the new layout |
| `tests/AKCars.Tests/Integration/MyWorkshopEndpointsIntegrationTests.cs` | 2 new tests pinning the envelope shape and the schedule round-trip over real HTTP |
| `test/goldens/dashboard_home_*.png` | regenerated for the new layout |

### Verified

- `flutter test` — **529 passed** (522 before; +7 net after replacing the
  settings suite with a larger account one).
- `flutter analyze` — clean. The one remaining info
  (`use_null_aware_elements`, `lib/core/utils/contact.dart:23`) is pre-existing
  and untouched.
- API: `dotnet test` — **941 passed** (939 before). Built into a scratch output
  directory because a running `AKCars.Api` process held `src/AKCars.Api/bin`
  locked; the source change itself compiles clean (`dotnet build` on
  `AKCars.Application` succeeded).
- Golden images regenerated and **visually inspected** — the ladder renders in
  the intended order with no overflow. One real overflow was caught this way
  (`_Figure` at `childAspectRatio: 1.9`, "Low stock items" wrapping to two
  lines over a hint line) and fixed to `1.6`.
- **Not** run against a live device, emulator or the real API. No manual
  sign-in as a workshop owner was performed, so the fixed profile screen has
  been proven against the fake service and the API's own integration tests, not
  against a real end-to-end round trip.

### Known-adjacent, left alone

- A stage change made by the founder does not reach the owner's already-open
  screen on its own — `providerOwnedBy` reads a warm cache and only re-reads on
  a `WarmCacheNotice.announce()` (session refresh). Correct in production
  (different devices), and the test drives the announce explicitly rather than
  pretending it is live.
- `test/failures/` holds golden-diff artifacts from the intermediate failing
  runs. Untracked and stale now that the goldens are regenerated; left in place
  rather than deleted, since it predates this session.
- The dashboard still shows no trend on any home-screen figure (only the
  Statistics screen has a chart). A sparkline on "Money" would be the next
  honest improvement, but it needs a bucketed series in
  `/my-workshop/summary` that the payload does not carry yet.

### Sources consulted

- [Dashboard UI Design Principles & Best Practices Guide 2026 — DesignStudio](https://www.designstudiouiux.com/blog/dashboard-ui-design-guide/)
- [Dashboard Design Principles: The Definitive Guide (2026) — UXPin](https://www.uxpin.com/studio/blog/dashboard-design-principles/)
- [Dashboard UI: 4 Best Practices for Mobile Clarity — Spaceberry](https://spaceberry.studio/blog/dashboard-ui-four-best-practices-for-mobile-clarity)
- [Dashboard Design Guide (2026): UX Best Practices & Examples — Aufait UX](https://www.aufaitux.com/blog/dashboard-design-examples-inspiration-best-practices/)

---

## 2026-08-24 (2) · The settings screen's back button did nothing whenever settings was reached by a route that replaces the stack

**Baseline:** `00e1d90` (HEAD). Request, verbatim: "back button in the
settings page not working. fix it"

`SettingsScreen` rendered `SandHeader(s.settings)` with no `onBack`, so
`SandBackButton` fell through to its default `Navigator.of(context).maybePop()`
(`lib/core/widgets/sand_widgets.dart:171`). That is correct only when something
is actually on the stack — and three real paths land on `/settings` via
`context.go()`, which *replaces* the stack rather than pushing onto it:

- the founder panel's own back button (`admin_screen.dart:58`,
  `context.canPop() ? context.pop() : context.go('/settings')`),
- the workshop dashboard's back button (`dashboard_home_screen.dart:47`, same
  idiom),
- `_guardOperatorPanels` redirecting a non-founder, an unidentified user, or an
  unapproved workshop owner to `/settings` (`app_router.dart:381-389`).

In all three `/settings` is the only page there is, `maybePop()` returns false,
and the button is inert. Reaching settings the ordinary way — the profile tab's
`context.push('/settings')` (`profile_screen.dart:65`, `:208`) — always worked,
which is why this survived: the dead path is the operator one, hit while
working in the founder panel.

Fixed with the idiom this codebase had already settled on for exactly this
problem everywhere else. `_TrackingExit` (`tracking_screen.dart:651`) carries it
with a comment describing the identical bug — "a customer who had just paid for
something landed on a page with no back button, no bottom navigation, and no way
out of it at all" — as do the founder panel and workshop dashboard. Settings was
the screen that got missed.

| File | Change |
|---|---|
| `lib/features/settings/settings_screen.dart` | `SandHeader` now passes `onBack: () => context.canPop() ? context.pop() : context.go('/profile')`. `/profile` is the fallback because it is a shell-tab root and the only screen that opens settings. |

**Verified:** `flutter analyze lib/features/settings/settings_screen.dart` →
"No issues found!"; `flutter test test/settings_business_section_test.dart
test/screens_smoke_test.dart` → 37/37 pass (both build `SettingsScreen`
directly, without a `GoRouter` in the tree — safe because `onBack` is a closure
that only calls `context.canPop()` when actually tapped, and neither test taps
it). **Not** verified: the fix was not exercised in a running app — the two
`go()`-entered paths (founder panel → back → settings → back, and the
unapproved-workshop redirect) were traced through the router by reading, not by
tapping through a device.

**Left alone:** the Android system back gesture on a single-page `/settings`
stack is still whatever `GoRouter` does by default — this change only fixes the
on-screen chevron. Worth a `PopScope` if it turns out to matter, but it is a
different mechanism and was not part of the report.

---

## 2026-08-24 (1) · Approving a workshop appeared to do nothing, because `GET /providers` was served from a 5-minute browser cache

**Baseline:** `00e1d90` (HEAD). Request, verbatim: "there is an issue when
admin click on approve button to verify the workshop: [server log excerpt] check
this logs and fix the issue"

The pasted log showed only a successful `AppendAuditCommand` (HTTP 201) — the
audit write succeeding, not the failure. Querying `AKCarsMobileDb` directly
showed what actually went wrong:

```
provider.approved  documentsSubmitted → approved   23:57:03
provider.approved  documentsSubmitted → approved   23:58:21   (same provider)
```

The same workshop approved twice, 78 seconds apart, both computing
`documentsSubmitted` as the prior state — so after a successful approve the
app's roster still believed the workshop was pending.

**Root cause:** `GET /service-marketplace/providers` — the endpoint the founder
panel re-fetches through `warmUp`/pull-to-refresh — set
`Cache-Control: public, max-age=300`. On a Flutter **web** build the browser's
own HTTP cache honours that header regardless of the `Authorization` header, so
any re-fetch within five minutes of a prior request to that URL can return the
**pre-approval** snapshot even though the `PATCH` had already committed. The
founder sees the workshop still pending, taps Approve again, and the cycle
repeats. It also meant a real customer could fail to see a newly-approved
workshop for up to five minutes — directly contradicting the app's own success
message, "the workshop is now visible to customers and takes bookings".

| File | Change |
|---|---|
| `AKCarsMobileAPI/src/AKCars.Api/Endpoints/MarketplaceEndpoints.cs` | Dropped `Cacheable(http)` from `GET /providers` only. Categories/offerings/promotions keep the 5-minute cache — they don't flip on a single admin click. |
| `lib/features/operations/admin_screen.dart` | `_ApplicationCard` became a `ConsumerStatefulWidget` with a `_submitting` guard, so a second tap can't fire a second `setStage` before the first response lands — which is what let the stale "before" state reach the audit trail twice. |

**Verified:** backend compiles (`dotnet build`, no `error CS`); `flutter
analyze` clean across the project apart from one pre-existing unrelated
`use_null_aware_elements` info in `lib/core/utils/contact.dart`. **Not**
verified: the running API was not restarted — Visual Studio held
`AKCars.Application.dll` / `AKCars.Infrastructure.dll` locked under the
debugger, so the backend fix had not taken effect at the time of writing. The
end-to-end approve flow was not re-tested against a live server.

**Left alone:** the connection string carries `MultipleActiveResultSets=true`,
which is what produces the "Savepoints are disabled because MARS is enabled"
warning in the log. Nothing in the codebase needs MARS (no raw ADO.NET, no
concurrent readers on one connection), but changing a connection string is the
user's call, so it was flagged rather than edited.

---

## 2026-08-18 · README rewritten as a real project README; the old design-handoff content moved to DESIGN_HANDOFF.md

**Baseline:** `62ad8e0` (HEAD). Request: rewrite `README.md` and
`AKCarsMobileAPI/README.md` with modern, useful project info and a
hand-written project-structure map, for both repos.

`README.md` had been repurposed on 2026-07-20 to hold the "Sand & Ink"
visual design handoff (design tokens, per-screen mockup references, in
Arabic) — useful, but not what a README is for, and it referenced local
working files (`AK Cars — GTD Mockups.dc.html`, `ios-frame.jsx`,
`image-slot.js`) that are gitignored and don't exist in a fresh clone.

Moved that content verbatim to the new `DESIGN_HANDOFF.md` (tracked; doesn't
match any `.gitignore` pattern) and wrote a standard README in its place:
overview, feature list, tech stack, `flutter run` + `--dart-define` config
table, a hand-drawn `lib/`/`test/` structure tree cross-checked against the
actual directory listing, and a short architecture summary linking to
`ARCHITECTURE.md`. `AKCarsMobileAPI/README.md` (previously just a title) got
the same treatment — architecture (Clean Architecture, CQRS/MediatR vertical
slices), tech stack, `dotnet run` / `AKCARS_USE_INMEMORY_DB` /
`AKCARS_SEED_DEMO_DATA` getting-started steps, an endpoint-group table, and a
structure tree, built by reading `Program.cs`, the four `.csproj` files, and
`src/`/`tests/` on disk rather than guessed.

No code changed. Docs only, both repos.

**Verified:** read both project trees, `Program.cs`, `pubspec.yaml`, and all
four backend `.csproj` files to keep the structure trees and tech-stack
tables accurate; confirmed `DESIGN_HANDOFF.md` isn't caught by any
`.gitignore` rule before relying on it as the new home for that content.

---

## 2026-08-17 (2) · The services section had no offerings because of a bad migration default on the API, and a sign-out that failed its own logout call skipped every clear

**Baseline:** `7cf6a5f` (HEAD). Request, verbatim: "the services section not
loading any data from the api. it show no data... add seed data... the
logout when user click on should clear current user data from all sections.
like notifications, cars... but now not deleting." Two unrelated bugs, one on
each side of the stack.

### Bug 1 — every `ServiceOffering` row was `IsActive = 0`, so `GET /service-marketplace/offerings` always returned `[]`

Not a data-source problem: `AKCarsMobileAPI` (`C:\Projects\Cars
Project\AKCarsMobilApp\AKCarsMobileAPI`, see [[backend-api-path]]) was up,
`/providers`, `/categories`, `/promotions` and `/offers` all returned real
seeded rows (43 offerings' worth of providers, categories and discounts —
`DemoMarketplaceSeed.cs`, opt-in via `AKCARS_SEED_DEMO_DATA=true`), but
`/offerings` itself came back `[]`, confirmed with `sqlcmd`:
`SELECT COUNT(*), SUM(CASE WHEN IsActive=1 THEN 1 ELSE 0 END) FROM
ServiceOfferings` → `43, 0`.

**Root cause:** migration `20260812134135_AddServiceOfferingIsActive.cs`
added the column with `defaultValue: false`. SQL Server used that default to
backfill every *pre-existing* row — all 43 of them — to `IsActive = 0`, even
though `ServiceOffering.cs`'s own C# default is `= true` and nothing had ever
deliberately unpublished any of them.
`GetOfferingsQuery`/`GetOfferingQueryHandler` (`AKCars.Application/
Marketplace/GetOfferings/GetOfferingsQuery.cs`) filter on `.Where(o =>
o.IsActive)`, so the whole catalogue silently disappeared from every
customer-facing read while `providers`/`categories`/`offers`/`promotions`
(unaffected tables) stayed visible — which is exactly the "categories show,
nothing inside them does" shape the user described.

**Fix, in `AKCarsMobileAPI`** (separate, non-git repo — nothing to commit
there, recorded here since this session's fix lives on the app's actual data
source):
- New migration `20260816202114_FixServiceOfferingIsActiveBackfill.cs`
  (`src/AKCars.Infrastructure/Persistence/Migrations/`) — a data-only `Up()`:
  `UPDATE [ServiceOfferings] SET [IsActive] = 1 WHERE [IsActive] = 0`. `Down()`
  is deliberately a no-op — there is no record of which rows were genuinely
  `false` before this ran versus backfilled-false, so it cannot be reversed
  correctly, only re-run forward.
- Generated with `dotnet ef migrations add ... --no-build` (the API was
  running under a live Visual Studio debug session, which locks
  `AKCars.Api`'s build output — a plain `dotnet build`/`dotnet ef migrations
  add` fails on `MSB3027: file locked`; `--no-build` reuses the already-built
  assembly instead of recompiling, which is safe here since nothing in the
  model changed).
- `dotnet ef database update --no-build` reported `Done` but **did not
  actually apply it** — confirmed via `SELECT MigrationId FROM
  __EFMigrationsHistory`, the new migration was absent. `--no-build` reuses
  the *previously compiled* assembly to enumerate migrations, and that
  assembly predates the new migration file's own compilation, so it never
  saw it. Applied the fix directly instead: `sqlcmd -S .\SQLEXPRESS -d
  AKCarsMobileDb -E -Q "UPDATE [ServiceOfferings] SET [IsActive] = 1 WHERE
  [IsActive] = 0;"` — idempotent, so the migration will still apply cleanly
  (as a no-op) the next time someone runs `dotnet ef database update` from a
  real build.

**Verified:** `sqlcmd` re-query showed `43, 43`;
`GET https://localhost:7291/api/v1/service-marketplace/offerings` went from
`[]` to the full 43-row catalogue, each with the discounted price where an
offer applies (spot-checked Al Noor Workshop's "صيانة شاملة" at 45→36, matching
the seeded `Offer` row). Not re-verified inside the Flutter app itself beyond
that — see the notes under bug 2 for why (the same session used the app to
investigate bug 2 and this offering fix was visible on the home page's offers
rail while doing so, but no dedicated screenshot pass was made of the
Services tab specifically after the fix).

### Bug 2 — `AuthNotifier.signOut()` skipped `SessionRefresh.clearAfterSignOut()` entirely whenever the server logout call failed

Read `session_refresh.dart`, `notifications_state.dart`,
`garage_repository.dart`, `session_routed_services.dart`, `token_store.dart`
and `api_auth_service.dart` end to end first — the sign-out clearing
mechanism (clear `requests`/`orders`/`notifications`/`reviews`/
`operatorQueue`, invalidate `garage`/`maintenance`/`challenge`/`myAds`/`chat`
and the workshop-dashboard providers) was already correct on paper and
already covered by four passing tests in `session_refresh_test.dart` from
the 2026-08-15 fixes. Two things were missing from that coverage:
notifications and the garage, neither of which had a test.

Added both as new tests. The notifications one passed immediately — that
half of the mechanism is fine. The garage one failed at first for an
unrelated reason (the test's own `AuthService` double didn't round-trip a
token through login the way `ApiAuthService` really does, so `hasSession()`
was already wrong before sign-out was even reached) — fixed the double, and
the real bug then reproduced cleanly.

**Root cause:** `AuthNotifier.signOut()` (`lib/state/auth_state.dart`) called
`await ref.read(authRepositoryProvider).signOut()` with no `try`/`catch`.
`ApiAuthService.signOut()` clears the token in its own `finally` regardless
of whether `POST /auth/logout` succeeded, but the exception itself — an
ordinary `401` from `RequireAuthorization()` when the access token had
already expired before the user tapped "sign out" — still propagates out.
Since the very next line is `unawaited(sessionRefreshProvider
.clearAfterSignOut(...))`, an uncaught throw on the line above meant that
line never ran: the token was gone, `AuthState.profile` was already `null`
(set synchronously at the top of the method, before any of this), but
`requestsProvider`/`ordersProvider`/`notificationsProvider`/`reviewsProvider`
/`operatorQueueProvider` were never told to clear and `garageProvider`/
`maintenanceProvider`/etc. were never invalidated — every one of those
screens kept showing the departed account's data indefinitely. This matches
the report exactly: the profile screen would have correctly shown "Guest"
(state flips synchronously) while garage/notifications/bookings stayed
stale.

**Fix:** wrapped that one call in `try`/`catch`, logging via `developer.log`
(same rule `SessionRefresh._bestEffort` already follows — never fail
silently) and falling through to `clearAfterSignOut` regardless.

### Files
| File | Change |
|---|---|
| `lib/state/auth_state.dart` | `AuthNotifier.signOut()`: wrapped `authRepositoryProvider.signOut()` in `try`/`catch` so a failed server round trip can no longer skip `clearAfterSignOut()` |
| `test/session_refresh_test.dart` | new tests: notifications clear on sign-out; a signed-in account's garage is not shown to the guest left on the device afterward (via a real `SessionGarageService`, not the harness's usual direct-to-`LocalGarageStore` override — see the new `_AuthServiceThatClearsTokensOnSignOut` double for why that needed its own token round-trip); a sign-out whose server call throws still clears the app (`_AuthServiceThatFailsToSignOut`) |

### Verified
- `flutter analyze lib/state/auth_state.dart test/session_refresh_test.dart`
  — clean.
- `flutter test test/session_refresh_test.dart` — all 12 tests pass,
  including the 3 new ones. Confirmed the garage test actually exercises the
  bug by watching it fail first against an incomplete test double (token
  never restored on login), then pass once the double correctly mirrored
  `ApiAuthService`'s login/signOut token lifecycle.
- `flutter test` (whole suite) — 522 passed, 0 failed.
- **Not** reproduced against the live app end to end — attempted via the
  `ak_cars_web` Chrome preview, but the OTP login step requires reading a
  server-logged one-time code this session had no way to retrieve without
  either the Visual Studio debug console (not accessible from here) or
  brute-forcing the code against its stored SHA-256 hash, which was
  correctly refused as an auth-bypass pattern regardless of whose database it
  is. The fix is verified against the mechanism (a Riverpod test that
  reproduces the exact failure and confirms the fix resolves it) and against
  the real `ApiAuthService`/`SessionGarageService` source, not against an
  actual expired-token round trip through the live API.

---

## 2026-08-17 · Booking a workshop/pickup slot sent a localized display string as `slot` instead of the raw key the server contract expects, against availability fetched for the wrong day; three screens also printed a customer's full GUID booking id instead of its short reference

**Baseline:** `7cf6a5f` (HEAD), with the in-flight mock→API migration on
`lib/features/services/*` and `lib/data/services/api/api_service_marketplace_service.dart`
already uncommitted in the working tree. Request: "the service section has
real bugs and issues. it's not working as expected" — read cold, no repro
steps given, so this was found by comparing the customer-facing service
screens against `docs/api_contract.md`, not from a reported symptom.

**Bug 1 — `BookingScreen._confirm()` sent `_slotLabel(s)` (a translated
"Tue 5 Aug · 9:00 AM"-style string) as `CreateServiceRequestDraft.slot`.**
`docs/api_contract.md`'s own example for `POST /service-marketplace/requests`
is `"slot": "10:30"` — the raw `"HH:mm"` key `GET .../slots` returns, the same
convention `QuoteScreen._accept()` already follows for
`applyEscrowEvent(..., slot: _slot)`. A workshop/pickup booking would submit
a value the server has no way to parse as the slot it was chosen for; a
roadside/ASAP booking (`_needsSlot == false`) sent a full sentence
("ASAP · provider heads to you") into the same field. `_slotLabel` is still
used for the on-screen "When" summary row — only the submitted payload
changed, to the raw `_slot` (empty string for the no-slot fulfillments,
matching the `slot: ''` convention `ServiceRequest.partInstall` already uses
for "not scheduled yet").

**Bug 2 — the slots shown/booked against were fetched for *today*, under a
UI that unconditionally labels them "Tomorrow".** `ApiServiceMarketplaceService.
fetchAvailability` resolves a null `date` to `DateTime.now()` (today);
`ServiceMarketplaceRepositoryImpl._warmProvider` called it with no date at
all. `BookingScreen` has no date picker — every slot chip and the "Tomorrow ·
{date}" heading above them assume the grid is for tomorrow, and `_slotLabel`
hardcodes `DateTime.now().add(Duration(days: 1))` for the date half of the
string it builds. So a chip shown as "full" could really be free tomorrow (or
vice versa), independent of bug 1. Fixed by warming availability for
`DateTime.now().add(Duration(days: 1))` instead of leaving `date` null — the
UI's fixed "Tomorrow" copy is the one place that already commits to a single
day, so the data now matches it.

**Bug 3 — three screens printed the customer's raw GUID request id.**
`shortRef()` (`lib/core/utils/guid.dart`) exists specifically because a full
id "pushed the booking's status pill off the edge of the screen" (its own doc
comment) — used correctly in `TrackingScreen`, `ChatScreen`, `NotificationRepository`,
and even `ReviewScreen`'s own subject line one screen up. Three call sites
missed it: `RequestsScreen._RequestCard` (the "#<id> · <name>" line on every
card in the main bookings list — the single most-visible instance),
`QuoteScreen`'s app bar title, and `ReviewScreen`'s "<offering> · #<id>"
subtitle. All three now go through `shortRef(request.id)`.

### Files
| File | Change |
|---|---|
| `lib/features/services/booking_screen.dart` | `_confirm()`: `slot: _slotLabel(s)` → `slot: _needsSlot ? _slot : ''` |
| `lib/data/repositories/service_marketplace_repository.dart` | `_warmProvider`: `fetchAvailability(providerId)` → `fetchAvailability(providerId, date: DateTime.now().add(const Duration(days: 1)))`, with the reasoning inline |
| `lib/data/models/service_request.dart` | `CreateServiceRequestDraft.slot`'s doc comment corrected — it was still describing the pre-fix "human-readable label" behavior |
| `lib/features/services/requests_screen.dart` | `_RequestCard`: `'#${request.id}'` → `'#${shortRef(request.id)}'` |
| `lib/features/services/quote_screen.dart` | app bar title: raw `request.id` → `shortRef(request.id)`; added the `guid.dart` import |
| `lib/features/services/review_screen.dart` | subtitle: raw `request.id` → `shortRef(request.id)` |

### Verified
- `flutter analyze` on every changed file plus the rest of
  `lib/features/services` — clean.
- `flutter test test/services_region_test.dart test/contact_gating_test.dart
  test/escrow_test.dart test/maintenance_book_test.dart
  test/operator_panels_test.dart test/part_install_screens_test.dart
  test/reviews_test.dart test/scenario_integrity_test.dart
  test/session_refresh_test.dart test/tracking_back_test.dart
  test/translation_coverage_test.dart` — all 135 passed; the fake service's
  `fetchAvailability` ignores `date` entirely, so bug 2's fix is a no-op
  against the test double and was checked by reading, not by a test that
  would fail without it.
- **Not** exercised against the real backend (no live API in this
  environment) — bug 1 and bug 2 are verified against `docs/api_contract.md`
  and the codebase's own established conventions (`QuoteScreen`, `shortRef`'s
  other call sites), not against an actual server round-trip. No automated
  test asserts the raw `slot` value `CreateServiceRequestDraft.toJson()`
  produces; worth adding if this area gets touched again.

---

## 2026-08-15 · The workshop-dashboard fix two entries below was itself firing nine spurious `/my-workshop/*` requests — for every account, on every sign-in and sign-out — and very likely the actual cause of "the services page has no data"

**Baseline:** the "Signing out was resetting the selected region" entry
immediately below. Request: the user pasted a live browser console from a
debug web run — nine `GET .../service-marketplace/my-workshop*` calls
answering `403 (Forbidden)`, one stack frame reading `session_refresh.dart:211`
— alongside "the services page not containing any data."

**Root cause: `Ref.invalidate()` on a never-built provider is not a no-op in
a debug build, and the fix two entries below relied on it being one.** That
entry added `_ref.invalidate(...)` for all 13 `provider_dashboard_state.dart`
providers to `_announce()`, reasoning that invalidating an unbuilt provider
does nothing. True in `--release` (`assert`s are stripped), false everywhere
else: `ProviderElementBase.invalidate` (`riverpod` 2.6.1,
`element.dart:287`) runs `assert(_debugAssertCanDependOn(provider), '')`
*before* invalidating, and that assertion's own body — a debug-only
circular-dependency check — calls `_container.readProviderElement(listenable)`
on the target, with the comment "Initializing the provider, to make sure its
dependencies are setup." For a plain `Provider`, "initializing" is a cheap
synchronous read (which is all the five pre-existing invalidations in this
method ever were — `garageProvider` et al., all `Notifier`s deriving from an
already-warmed cache). For an `AsyncNotifierProvider` that has never been
built, "initializing" means actually running its `build()` — a real
`await ref.read(workshopRepositoryProvider).loadOfferings()` (or `.getMy
Workshop()`, `.getInventory()`, …), i.e. a genuine network request — purely
so the assertion has something to inspect before discarding the result. Nine
of the thirteen providers added two entries below are plain (non-`.family`)
`AsyncNotifierProvider`s, and every one of them fired its request on *every*
sign-in and sign-out, for *every* account — a guest, a customer, a founder —
regardless of whether that account has ever owned a workshop, because
`_announce()` runs unconditionally. The other four (`workshopCustomerDetail
Provider`, `workshopScheduleProvider`, `workshopDashboardEarningsProvider`,
`workshopDashboardMetricsProvider`) are `.family` providers invalidated as
bare families (no argument) — confirmed safe by reading
`ProviderContainer.invalidate`: a bare-`Family` target loops over *already-
existing* `_stateReaders` rather than creating one, so those four were never
at risk.

Whether this alone explains "the services page has no data" was not directly
provable, but the mechanism fits: nine extra failing requests fired
concurrently with the real warm-up calls (`_refillWarmCaches`'s own
`Future.wait`) on every sign-in/out is exactly the kind of thing that
crowds out or delays the requests a screen is actually waiting on, especially
against a browser's per-origin connection cap — and removing the cause
removes both symptoms at once rather than chasing the services page
separately.

**Fix:** `Ref.exists(provider)` performs the same "does an element already
exist" check `_debugAssertCanDependOn` needs — via
`ProviderContainer._getOrNull`, confirmed by reading its source — without
the `assert` and without ever creating one. New `SessionRefresh._ifBuilt`
wraps the nine single-provider invalidations in `if (_ref.exists(provider))`;
the four family ones are untouched, since they were already safe. A
provider that really was built (a workshop owner's dashboard was actually
opened this session) is still invalidated exactly as before — this only
skips the ones nobody ever asked for in the first place.

### Files
| File | Change |
|---|---|
| `lib/state/session_refresh.dart` | `_announce()`: 9 single-provider `_ref.invalidate` calls → `_ifBuilt(...)`; new `_ifBuilt` helper (`Ref.exists` guard) with the full mechanism documented inline; the 4 family invalidations left as-is with a comment explaining why |
| `test/fakes/mock_workshop_service.dart` | `MockWorkshopService.callCount` — overrides the shared `respond()` mixin method once, so it counts every call to the fake regardless of which method, without instrumenting each individually |
| `test/session_refresh_test.dart` | new test: a plain customer who never opens the workshop dashboard causes zero `/my-workshop/*` calls across a full sign-in→sign-out cycle. Verified this test fails against the pre-fix code (temporarily bypassed the `exists()` guard: got exactly 9, matching the 9 affected providers) before confirming it passes restored |

### Verified
- `flutter analyze lib test` — clean apart from the pre-existing
  `use_null_aware_elements` info in `lib/core/utils/contact.dart:23`.
- `flutter test` — 519 passed (518 from the entry below + 1 new).
- Temporarily replaced `_ifBuilt`'s body with a bare `_ref.invalidate(provider)`
  (bypassing the `exists()` guard), re-ran the new test alone, confirmed it
  fails with `callCount` at exactly 9 — reproducing the reported symptom
  under the same test harness that will catch it if it regresses — then
  restored the guard and confirmed the full suite passes again.
- **Not** re-run against the live backend the user's console log came
  from — the fix is verified against the mechanism (Riverpod's own debug-
  assert source, read directly) and against a test that reproduces the exact
  request count from that log, but the actual browser session was not
  re-checked.

---

## 2026-08-15 · Signing out was resetting the selected region — a device preference, not account data — because `regionProvider` `watch`ed a repository just to seed its default

**Baseline:** the "Signing out still left the workshop dashboard showing the
departed owner's data" entry immediately below. Request, verbatim: "the
services page and other other default data cleared with the current user
data when logout. clear only user info and his cars data and booked
services and related data only."

**Not a data-clearing bug — a `StateProvider` losing its `.state`.**
`regionProvider` (`lib/state/settings_state.dart`) is a `StateProvider<String>`
the Services page, Home, the Garage's add-car form and Register all filter
by. Its create closure did `ref.watch(catalogRepositoryProvider)
.serviceRegions` to pick a default ("the first governorate") — but `watch`
inside a `StateProvider`'s closure does not just seed the initial value once,
it makes the *whole provider* rebuild — discarding any `.state =` write made
since — every time the watched dependency's element notifies its listeners.
`SessionRefresh._announce()` calls `WarmCacheNotice.announce()` on **both**
sign-in and sign-out (the public catalogues are re-warmed either way, per the
2026-08-13 entry two below), and `WarmCacheNotice` works by calling
`ref.notifyListeners()` directly on `catalogRepositoryProvider`'s own
registered ref — so every sign-out silently snapped whatever region the user
had picked back to `regions.first`. The Services page (and everything else
region-filtered) then genuinely showed a different, often emptier list —
which is exactly what "the services page and other default data cleared"
describes, even though not one byte of the actual catalogue had been
touched.

Checked every other provider that `ref.watch`es one of `SessionRefresh`'s
seven `WarmCacheNotice`-registered repositories
(`catalog`/`shop`/`cars`/`serviceMarketplace`/`garage`/`maintenance`/
`challenge`Repository`Provider`): `regionProvider` is the only one that is
both (a) a `StateProvider`/`Notifier`-style provider holding externally
mutable `.state` and (b) `watch`ing rather than `read`ing in its initializer.
Every other consumer (`platformListingsProvider`, `productsProvider`,
`rosterProvider`, `homePromotionsProvider`, …) is a plain derived `Provider`
with no state of its own to lose — recomputing them on every announce is the
whole point. `favoritesProvider`/`savedPartsProvider`/
`selectedMaintenanceCarIdProvider` are `StateProvider`s too but seed from a
constant (`{}`, `null`), not a watched repository, so they were never at
risk.

**Fix:** `ref.watch` → `ref.read` in `regionProvider`'s initializer. It still
picks a sensible default the first time anything reads it (the catalogue is
already warmed by then, at bootstrap or at the first screen that touches
this provider); it just never again does so out from under a value the user
or a previous default-pick already set. No other change needed — the
region's own writers (`settings_screen.dart`'s region sheet,
`services_screen.dart`'s picker) already write via `.notifier.state =`
directly and are unaffected.

### Files
| File | Change |
|---|---|
| `lib/state/settings_state.dart` | `regionProvider`: `ref.watch(catalogRepositoryProvider)` → `ref.read(...)`, with the reasoning recorded in a doc comment so it is not "corrected" back by a future edit that does not know why |
| `test/session_refresh_test.dart` | new group "signing out must not reset device preferences that are not account data" — sets a non-default region, signs an account in then out, asserts it survived both. Verified this test fails against the pre-fix `watch` (region snapped from the chosen 'Dhofar' back to 'Muscat') before confirming it passes against the fix |

### Verified
- `flutter analyze lib test` — clean apart from the pre-existing
  `use_null_aware_elements` info in `lib/core/utils/contact.dart:23`.
- `flutter test` — 518 passed (517 from the entry below + 1 new).
- Manually reverted the fix, re-ran the new test alone, confirmed it fails
  with the exact symptom reported (`Muscat` where `Dhofar` was expected),
  then restored the fix and confirmed it passes again — the test is proven
  to catch the regression, not just to pass by construction.
- **Not** run on a device or emulator — same limitation as every entry
  above this one.

---

## 2026-08-15 · Signing out still left the workshop dashboard showing the departed owner's data — two real state leaks found and fixed

**Baseline:** `7cf6a5f` (working tree already carried the 2026-08-12/13 role
and dashboard work, uncommitted). Request: "logout ends session but not
deleting the current user data. the account types and their dashboards
ideas not working as I expected." — a review of the sign-out and
owner/workshop-dashboard work already in the tree, against exactly that
complaint.

**Confirmed first: the backend and the client's own auth/session state are
both correct.** `LogoutCommandHandler` (`AKCarsMobileAPI`) properly revokes
the caller's whole refresh-token family and deletes their device
registrations; `AuthState.profile` is cleared synchronously on
`AuthNotifier.signOut()`; `SessionRefresh.clearAfterSignOut` already dropped
`requestsProvider`/`ordersProvider`/`notificationsProvider`/`reviewsProvider`
and invalidated `garageProvider`/`maintenanceProvider`/`challengeProvider`/
`myAdsProvider`/`chatProvider`. None of that was the bug.

**Bug 1 — the workshop dashboard's `AsyncNotifierProvider`s were never
invalidated by anything, ever.** `lib/state/provider_dashboard_state.dart`
(`workshopSummaryProvider`, `myWorkshopProfileProvider`,
`workshopOfferingsProvider`, `workshopAddOnsProvider`,
`workshopInventoryProvider`, `workshopStaffProvider`,
`workshopRequestsProvider`, `workshopCustomersProvider`,
`workshopCustomerDetailProvider`, `workshopScheduleProvider`,
`workshopScheduleConfigProvider`, `workshopDashboardEarningsProvider`,
`workshopDashboardMetricsProvider`) all read through `workshopRepositoryProvider`
with `ref.read`, not `ref.watch` — so `WarmCacheNotice.announce()` (which
works by calling `notifyListeners()` on each *registered repository's own
ref*, reaching only its `watch`ers) never touched them, and
`SessionRefresh` never listed them at all. A non-`autoDispose`
`AsyncNotifierProvider` keeps its resolved `AsyncData` forever once built,
so once one workshop owner opened `/workshop/dashboard`, every one of these
screens (summary KPIs, offerings, add-ons, inventory, staff, orders,
customers, schedule, earnings, the workshop's own profile) went on showing
that owner's data — through a sign-out, and through a *different* workshop
owner signing in on the same device — until something unrelated happened to
invalidate them. Fixed by adding all thirteen to
`SessionRefresh._announce()`, which now runs on both `refreshEverything`
(sign-in) and `clearAfterSignOut` (sign-out), the same as the five
account-scratch providers already there.

**Bug 2 — `OperatorQueueNotifier._marketplace` is a plain field, and a field
is not what `clearAfterSignOut`'s existing reasoning accounted for.** The
method's own doc comment claimed `operatorQueueProvider` "needs no entry
here: it derives from `requestsProvider` via `ref.watch`, so clearing that
clears it too" — true that `build()` reruns, false that rerunning resets
`_marketplace`: that field holds every account's bookings as last fetched by
`refresh()` (most recently at sign-in), and `_merged(mine)` folds it into
`state` regardless of what `mine` is. So the founder/operator queue kept
showing every booking on the platform from the last signed-in session,
through a sign-out, until the *next* sign-in's own `loadSessionLists()`
happened to call `refresh()` again — a narrow but real window, and the
comment describing why it was safe was simply wrong once checked against the
field it was describing. Added `OperatorQueueNotifier.clear()` (resets
`_marketplace` to `const []`, same shape as `_replace`) and call it from
`clearAfterSignOut`.

**Bug 3 — stale UI copy, not a state bug but the same complaint's territory.**
`ProfileScreen`'s `_WorkshopApplicationCard` told every approved workshop
owner: *"If the panel does not open, switch your role to 'Workshop' in
Settings."* That device-local role switcher was removed in the 2026-08-12
"Removed the demo role switcher" entry — Settings has had no such control
since. An owner for whom `/workshop/dashboard` failed to open for any other
reason would have followed instructions for a feature that no longer exists.
Deleted the paragraph; the `/workshop` → `/workshop/dashboard` redirect
either works (real ownership + approval, checked by `_guardOperatorPanels`
on every navigation) or it doesn't, and there is nothing left for the user
to toggle either way. Also corrected three doc comments
(`provider_dashboard_state.dart` ×2, `dashboard_home_screen.dart`) still
describing the deleted `workshop_state.dart`/`isStandingInForDemoProvider`
mechanism.

### Files
| File | Change |
|---|---|
| `lib/state/session_refresh.dart` | `_announce()` invalidates all 13 `provider_dashboard_state.dart` providers; `clearAfterSignOut` calls `operatorQueueProvider.notifier.clear()`; doc comments corrected |
| `lib/state/operator_queue_state.dart` | new `OperatorQueueNotifier.clear()` |
| `lib/features/profile/profile_screen.dart` | removed the stale "switch role in Settings" paragraph from `_WorkshopApplicationCard` |
| `lib/state/provider_dashboard_state.dart` | two doc comments no longer describe the deleted role-switcher/`workshop_state.dart` mechanism |
| `lib/features/workshop_dashboard/dashboard_home_screen.dart` | doc comment now names the real guard (`_guardOperatorPanels`) instead of the deleted `isStandingInForDemoProvider` |
| `test/fakes/mock_workshop_service.dart` | `MockWorkshopService.provider` setter, so a test can simulate a second owner's workshop without a second fake |
| `test/session_refresh_test.dart` | two new tests in "signing out clears the whole app": the workshop dashboard reflects a different workshop after sign-out (proved via the fake answering a different `ServiceProvider.id`, not a call count — `ref.invalidate` on a never-yet-built provider triggers an immediate debug-mode build via `_debugAssertCanDependOn`, which made a naive call-count assertion flaky), and the operator queue drops marketplace-wide bookings on sign-out |

### Verified
- `flutter analyze lib test` — clean apart from the pre-existing
  `use_null_aware_elements` info in `lib/core/utils/contact.dart:23`.
- `flutter test` — 517 passed (515 pre-existing + 2 new).
- Backend: read-only review of `LogoutCommandHandler`, `TokenService`, and
  `CurrentUser.IsFounder` — all three already correct, not touched.
- **Not** run on a device or emulator — same limitation as every entry
  above this one.

### Known-adjacent, left alone
- The founder/admin panel's own providers (`rosterProvider`,
  `payoutsProvider`, `auditLogProvider`, `onboardingPipelineProvider`) were
  checked and are fine: they read `serviceMarketplaceRepositoryProvider`
  with `ref.watch`, so `WarmCacheNotice.announce()` does reach them — the
  same mechanism that does not reach `provider_dashboard_state.dart`'s
  providers, because those use `ref.read`. Not a second version of bug 1.

---

## 2026-08-13 · Added a real, log-in-able demo founder account (backend: `AKCarsMobileAPI`)

**Baseline:** the "Signing out now refreshes app data" entry immediately
below. Request: manual testing needed a workshop owner login (already
seeded, but its `ServiceProvider.OwnerUserId` link had never actually been
inserted — filled in directly against the local SQLEXPRESS dev DB, no code
change needed there), then a way to actually approve a workshop, which needs
a founder login — and none existed anywhere in this backend.

`DemoMarketplaceSeed.cs` gained `DemoFounderId`/`FounderPhone`
(`+968 9200 0000`) and a `FounderUser` singleton (`IsFounder = true`, `Kind =
Customer` — founder is orthogonal to account kind, same as in production).
`DemoDataSeeder.cs` inserts it under its own per-id check, same pattern as
the existing workshop-owner/technician logins, so a database that already has
real users still gets this one login on the next `AKCARS_SEED_DEMO_DATA=true`
run. Same OTP flow as every other demo login (`LoggingOtpSender` logs the
code to the server console in dev — no real SMS gateway wired up yet).

Also inserted directly into the current local dev DB (SQLEXPRESS,
`AKCarsMobileDb`) so it's usable immediately without restarting the already-
running backend process: the founder user row, computed with the exact same
`DeterministicGuid.From("DemoUser:founder")` the new code produces, so a
future seeder run recognises it as already present rather than inserting a
duplicate.

**Verified:** `POST /auth/login` against the live local backend found the
account and returned `kind: "customer"` as expected (founder status is
JWT-only, not visible on the profile — see the 2026-08-12 role-derivation
entry). Did not run `dotnet build`/`dotnet test` — every attempt to build
the `AKCars.Infrastructure` project to a scratch output path hit an MSBuild
duplicate-`AssemblyInfo` error unrelated to this change (the live `dotnet
run` process already holds the project's normal build output open); verified
by close inspection against `User.cs`'s actual properties and the existing,
already-compiling `WorkshopUsers`/`DemoDataSeeder` code this mirrors instead.
Worth a real `dotnet build` next time the backend process is stopped anyway.

---

## 2026-08-13 · Signing out now refreshes app data, and a real Riverpod race that hid a booking after a fast sign-out→sign-in was found and fixed along the way

**Baseline:** the "Removed the demo role switcher" entry immediately below.
Request: "when user log out refresh app data" — signing in already re-read the
whole app (`SessionRefresh.refreshEverything`, see the 2026-08-11-era work);
signing out just cleared `AuthState` and left every warm cache and every
per-account list holding the departed account's data. The garage tab kept
showing that account's cars, "My orders"/"My bookings" kept their contents,
and a founder's payout ledger stayed cached for whoever used the app next on
the same device.

**`SessionRefresh.clearAfterSignOut`** — the mirror image of
`refreshEverything`: refills every warm cache (public catalogues included,
same reasoning as sign-in — they may be stale by the time someone signs out)
but with `includeFounderLedger: false`, so a founder's payouts/audit-log
cache is dropped rather than refetched; announces the refill so
`garageProvider`/`maintenanceProvider`/`challengeProvider`/`myAdsProvider`/
`chatProvider` re-derive (garage/maintenance correctly fall back to this
device's own local guest store, since the token is already cleared by the
time this runs); and clears the per-account lists (`requestsProvider`,
`ordersProvider`, `notificationsProvider`, `reviewsProvider`) since there is
nobody left to reload them for. `AuthNotifier.signOut` awaits the token clear
first, then fires this off unawaited — same fire-and-forget shape as
sign-in's own refresh, so "sign out" never blocks on a network round trip.

**The bug this surfaced, not one anticipated:** `flutter test` immediately
failed an *existing, untouched* test (`session_refresh_test.dart`'s "the
account's own bookings and orders arrive") once `clearAfterSignOut` invalidated
`requestsProvider`/`ordersProvider` via `ref.invalidate`. Traced with a
throwaway debug build to `RequestsNotifier.load()` finding `_disposed == true`
on a notifier instance obtained *fresh* from `ref.read(requestsProvider.notifier)`
moments earlier in a completely separate, later `SessionRefresh` call — i.e.
`ref.invalidate()` on a `NotifierProvider`, read via `.notifier` from a plain
`Provider`'s `Ref` (never from a widget's `watch`), can leave the provider
disposed rather than rebuilt by the time the next unrelated call goes looking
for it. Fixed by not invalidating these four providers at all: each notifier
(`RequestsNotifier`, `OrdersNotifier`, `NotificationsNotifier`,
`ReviewsNotifier`) gained a `clear()` method that just writes
`state = const []` directly — the same plain `state =` mutation every other
method on these classes already uses, with no disposal/rebuild cycle to race.
`NotificationsNotifier.load()`'s own doc comment had already flagged half of
why invalidating it specifically is wrong (a second push subscription opened
without closing the first) — this was the second, independent reason.

**A second, real race, caught by the same failing test once the first fix
landed:** signing out and immediately signing back in — the pattern
`session_refresh_test.dart`'s own `_createAccountThenSignOut` helper uses —
runs two fire-and-forget `SessionRefresh` calls back to back. Nothing stopped
the sign-out's tail (clearing `requestsProvider`) from finishing *after* the
following sign-in's tail (loading it), which would have silently dropped the
new session's freshly-loaded bookings. Fixed with `AuthNotifier.generation`,
an `int` bumped by `register`/`login`/`signOut` and threaded into
`refreshEverything`/`clearAfterSignOut`; each checks, right after its one slow
step (the network refill), whether a newer generation has since started, and
if so stops before touching any provider — so only the most recently started
call is ever allowed to apply its effects, regardless of which one finishes
first.

**Verified:** `flutter analyze` (clean, one pre-existing unrelated info-level
lint), `flutter test` (515 passed). Added two tests to
`session_refresh_test.dart`'s new "signing out clears the whole app" group:
bookings/orders are dropped on sign-out, and the founder-ledger fetch is not
repeated (a call-count field, `MockServiceMarketplaceService
.fetchPayoutsCallCount`, added to the fake to observe it). Not run: a live
device pass (same limitation as every entry above this one).

---

## 2026-08-12 · Removed the demo role switcher — roles are real account facts now, and workshops get a statistics screen with charts

**Baseline:** the "Workshop Dashboard follow-up" entry immediately below.
Request: "I dont want a demo view or using mode. make it real... when user
login as a workshop role then the workshop dashboard will [enable] in the
settings menu if the workshop is approved. also the owner dashboard will
display only if the user role is owner... use charts for statistics."

**The demo mechanism, gone.** `lib/state/role_state.dart`'s `RoleNotifier`
used to be a `Notifier<AppRole>` backed by a SharedPreferences key — a
device-local switch, changeable from Settings, that let any signed-in account
preview the workshop or founder panel regardless of what it actually owned or
was. `activeRoleProvider` is now a plain derived `Provider<AppRole>` with no
`setRole` at all:

- `AppRole.founder` ⟸ a new `AuthState.isFounder` flag, decoded off the
  stored JWT's own role claim by a new `lib/core/utils/jwt_claims.dart`. The
  backend (`TokenService.GenerateAccessToken`) has minted a real
  `ClaimTypes.Role: "founder"` claim all along; nothing on the client ever
  read it before. `jwt_claims.dart`'s doc comment records the one non-obvious
  fact this needed: the claim's actual JSON key in the token is the long
  `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` URI, not the
  short `"role"` string — confirmed empirically by minting a token with the
  real `TokenService` in a throwaway console probe and decoding its payload,
  since `JwtPayload.AddClaims` writes `Claim.Type` verbatim and the
  short-name remapping only exists on the inbound/validation side.
  `AuthState.isFounder` is decoded once per `restore()`/`login()`/`register()`
  — same caching shape as `AuthState.profile` — so router guards read it
  synchronously.
- `AppRole.workshop` ⟸ `providerOwnedBy(userId)?.isApproved == true` — real
  ownership (keyed on `ServiceProvider.ownerUserId`, so a staff member linked
  to the roster but not the owner does not get this), already-existing data,
  just no longer bypassable by a role switch. This is also the direct answer
  to "owner dashboard only if the user role is owner": since the role itself
  is now defined as ownership, there is no separate check to add.
- `activeRoleProvider` watches the founder panel's own `adminRevisionProvider`
  (bumped after every founder write) and registers with `WarmCacheNotice`, so
  an approval made from the founder's panel is picked up on the account's
  next read rather than freezing at whatever it first resolved to — this was
  a real bug caught by a test (see below), not a hypothetical one.

**`/workshop` retired as a second panel — it redirects.** The old read-only
`lib/features/operations/workshop_screen.dart` and its
`lib/state/workshop_state.dart` (`activeWorkshopProvider`,
`isStandingInForDemoProvider` — the "first approved workshop" stand-in that
made the demo view possible) are deleted. `GoRoute(path: '/workshop',
redirect: (_, __) => '/workshop/dashboard')` sends every old deep link into
the real dashboard, gated by the same real ownership+approval check
`_guardOperatorPanels` already applied there — simplified now that there is
no demo tolerance branch to carve an exception around. This was not just a
cleanup: the old panel's Jobs tab read `operatorQueueProvider`
(`GET /operator/requests`), which is founder-only on the real backend, so it
could never have worked for a genuine (non-founder) workshop owner in the
first place — it only ever worked against the demo stand-in or the test
fakes, which don't enforce that boundary. `AppRole` itself
(`data/models/app_role.dart`) lost `key`/`fromKey`/`hasPanel`/`panelRoute`/
`label`/`description` — all switcher-only members with no other caller once
the switcher was gone.

**Settings' "How you're using this" section → "My business".** The
`_RoleSwitcher` widget (three tappable rows, one per role, a checkmark on
whichever was picked) is replaced by `_businessSection`: a "Workshop
dashboard" row, shown only when the account's `kind == AccountKind.workshop`
— tappable straight into `/workshop/dashboard` once approved, or showing the
real `ProviderOnboardingStage.label` (e.g. "Documents submitted") and routing
to `/profile` instead while it's not; and a "Founder panel" row, shown only
when `AuthState.isFounder`. Neither row exists for a plain customer — no
section renders at all, matching the old "customer has no panel" invariant
but now because there is genuinely nothing to show, not because a switch
defaults to hidden.

**Statistics, with real charts.** `workshopDashboardEarningsProvider`/
`workshopDashboardMetricsProvider` (`provider_dashboard_state.dart`) existed
since the original dashboard build but had no screen reading them anywhere —
a named gap nobody had come back to. New
`lib/features/workshop_dashboard/statistics_screen.dart`: a 7/30/90-day
window selector, an `fl_chart` (new dependency) bar chart of net earnings
bucketed from `WorkshopEarnings.lines` by day (capped at 14 bars regardless
of window length — a 90-day view groups into roughly weekly buckets rather
than rendering ninety illegible slivers), and the acceptance/completion/
dispute rate cards the old panel's Performance tab used to show, now backed
by the server-computed metrics endpoint. Added as a quick-action tile on the
dashboard home screen; regenerated the dashboard home's 3 golden baselines
since the KPI/quick-action grid gained a row.

**A real bug the tests caught mid-implementation:** the first version of
`activeRoleProvider` only watched `authProvider` and
`serviceMarketplaceRepositoryProvider` — since the repository's *identity*
never changes when a founder approves a workshop (only its internal roster
does), Riverpod never recomputed the provider, and a freshly-approved
workshop kept reading back as `AppRole.customer` until something unrelated
invalidated it. Caught by `scenario_integrity_test.dart`'s rewritten scenario
8 failing with exactly that stale value; fixed by watching
`adminRevisionProvider`, the same mechanism `rosterProvider`/
`pendingApplicationsProvider` already use for the identical reason.

**Verified:** `flutter analyze` (clean, one pre-existing unrelated info-level
lint), `flutter test` (513 passed). Rewrote `test/scenario_integrity_test.dart`
scenario 8, `test/focus_flags_test.dart`'s "roles" group and
`test/operator_panels_test.dart`'s workshop-panel test (now pumps the real
`OrdersScreen` with a booking seeded into the workshop fake, rather than the
deleted `WorkshopScreen`) to assert the derived roles instead of a switch;
added `test/settings_business_section_test.dart` (4 tests: customer sees no
section, pending applicant sees a status row, approved owner sees a real
link, founder JWT shows the founder row) and a `StatisticsScreen` smoke test
in `test/workshop_dashboard_test.dart`. Not run: a live device pass (same
limitation as every entry above this one — this is a Flutter mobile app, not
a web dev server).

---

## 2026-08-12 · Workshop Dashboard follow-up — closed the four named gaps from the previous entry

**Baseline:** the "Workshop (Provider) Dashboard" entry immediately below.
That entry shipped with four gaps named rather than silently stubbed; this
entry closes all four.

**1. Quote submission wired into the new orders screen.** Extracted the
private `_QuoteSheet`/`_QuoteSheetState` out of
`lib/features/operations/workshop_screen.dart` into a public
`lib/features/operations/quote_sheet.dart` (`QuoteSheet` widget, verbatim
logic, no behaviour change) so both the old panel's Jobs tab and the new
`lib/features/workshop_dashboard/orders_screen.dart` show the same sheet.
`orders_screen.dart`'s escrow-transition handler now branches on
`EscrowEvent.submitQuote` the same way it already branched on
`submitProof`: opens `QuoteSheet`, then calls
`ServiceMarketplaceRepository.submitQuote` directly (not through
`EscrowActionBar`, for the same founder-only-endpoint reason the rest of that
screen already avoids it). `OperatorShell` gained an optional `actions` param
so the dashboard's app bar can carry the same icon-button chrome the old
panel used.

**2. Founder audit-log entries for inventory/staff/customer writes.**
`WorkshopRepositoryImpl` now takes a second constructor dependency
(`ServiceMarketplaceService`, for its existing `appendAudit` — no new
service, reusing the same audit log the escrow/payout flows already write
to) and a private `_audit()` helper mirroring
`ServiceMarketplaceRepositoryImpl._audit()`'s shape: called once after each
successful mutation, best-effort (an `AppException` from the audit call
itself is swallowed rather than failing the write it's describing).
Wired after `createInventoryItem`/`updateInventoryItem`/
`deleteInventoryItem`/`recordInventoryMovement`/`createStaff`/`updateStaff`/
`deactivateStaff`/`addCustomerNote`. `AuditSubjectType` gained `inventory`,
`staff`, `customer` (with `label(S s)` cases) since none of those existed as
audit subjects before — `payout`/`booking`/etc. were the only prior
subjects. `di/providers.dart`'s `workshopRepositoryProvider` updated to pass
the new dependency.

**3. HTTP-level integration tests for `/my-workshop/*`.** New
`Microsoft.AspNetCore.Mvc.Testing` 8.0.10 dependency in
`AKCars.Tests.csproj` — no `WebApplicationFactory` existed anywhere in that
repo before this. `tests/AKCars.Tests/Integration/MyWorkshopApiFactory.cs`
boots the real `Program` against an InMemory EF database (one per test, via
`IAsyncLifetime`, not a shared `IClassFixture` — a shared fixture would leak
state between the ownership-boundary tests this suite exists to catch) and
mints real JWTs through `ITokenService` for a seeded owner or staff account.
Two bugs found and fixed while building the harness, both now documented
inline: `Program.cs`'s unconditional `UseHttpsRedirection()` combined with
`SocketsHttpHandler` stripping `Authorization` across a scheme-changing
redirect (fixed by pointing `ClientOptions.BaseAddress` at `https://`), and a
signing-key mismatch between `AddJwtBearer`'s eager config read and
`ITokenService`'s lazy `IOptions<JwtSettings>` read when a
`ConfigureAppConfiguration` override was in play (fixed by dropping the
override and using `UseEnvironment("Development")` so both paths read the
same file-backed key). 6 new tests in
`MyWorkshopEndpointsIntegrationTests.cs` covering a real create+read round
trip, cross-workshop isolation, the non-approved-workshop 422, the
technician-403 and manager-201 authorization cases, and an unauthenticated
401 — all passing.

**4. Pixel golden tests for the dashboard home screen.** No golden-file infra
existed anywhere in this repo before this. `AppTheme` gained a test-only
static flag, `debugDisableGoogleFonts` (default `false`, never read in
production — same pattern as Flutter's own `debugDisableShadows`-style
flags): when set, both `GoogleFonts.*` call sites in `_build()`/`numeric()`
are skipped in favour of the base Material text theme. This exists because
`google_fonts` fetches its `.ttf` files over the network on first use, which
made a golden test's pixels depend on network reachability — and this
sandboxed environment could not reach `fonts.gstatic.com` at all, so runtime
fetching failed outright; the alternative (`allowRuntimeFetching = false`)
just traded that failure for a different one, since it requires the font to
already be a bundled local asset, which this app has never needed before
now. New `test/dashboard_home_golden_test.dart` sets the flag in
`setUpAll`/clears it in `tearDownAll`, pumps `DashboardHomeScreen` at a fixed
402×1400@3x viewport in three configurations (Arabic/light, English/light,
Arabic/dark), and asserts against 3 new baseline PNGs under `test/goldens/`
generated on this machine with `flutter test --update-goldens`. As documented
in the test file's own header: these intentionally do not exercise the real
app fonts, so they catch layout/colour drift, not a font-rendering
regression — if the goldens ever need regenerating on a different
machine/CI image, `--update-goldens` is the way, same as any Flutter golden
suite.

**Verified:** Flutter — `flutter analyze` (clean, one pre-existing unrelated
info-level lint in `lib/core/utils/contact.dart`), `flutter test` (509
passed, including the 3 new golden tests, the audit-trail test added to
`workshop_dashboard_test.dart`'s "Founder audit trail" group, and no
regressions in the pre-existing 505). Backend — `dotnet build`, `dotnet test`
(the 6 new integration tests plus the existing 933 unit/handler tests, all
passing). Not run: a live device pass (same limitation as the previous
entry — this is a Flutter mobile app, not a web dev server).

---

## 2026-08-12 · Workshop (Provider) Dashboard — real CRUD for a workshop's offerings, add-ons, inventory, staff, customers and schedule

**Baseline:** `7cf6a5f`. Request: `docs/prompts/provider_dashboard_prompt.md`
— build a modern operational home for a workshop owner (reachable from
Settings) backed by real endpoints, replacing the fact that
`lib/features/operations/workshop_screen.dart` only ever *displayed* derived
data and a provider could not create, edit or delete anything.

Two corrections to the prompt's own assumptions, confirmed by direct audit
before any code was written: (1) its backend path
(`C:\Projects\Cars Project\AKCarsMobileAPI`) does not exist — the real API is
`C:\Projects\Cars Project\AKCarsMobilApp\AKCarsMobileAPI` (Clean Architecture,
CQRS/MediatR, minimal APIs, confirmed accurate once pointed at the right
path); (2) the demo pilot's client-side "role switcher" fallback
(`activeWorkshopProvider` standing in with the first approved workshop when
the signed-in account owns none) cannot extend to real, per-owner endpoints —
`/my-workshop/*` resolves ownership from the JWT server-side with no roster
to fall back into, so an account standing in for a workshop it does not own
gets `403 workshop_not_owned` on the first call. The new dashboard is
therefore **additive**, not a replacement for `/workshop`: reachable at
`/workshop/dashboard`, gated on real ownership
(`!isStandingInForDemoProvider`), linked from an app-bar button on the old
panel once that gate passes. The old panel is untouched and still serves the
pilot/demo role-switch case.

### Backend (`AKCarsMobileAPI`)

New entities `InventoryItem`, `InventoryMovement` (append-only stock ledger —
`InventoryItem.QuantityOnHand` is a projection over it, never written
directly), `WorkshopStaff`, `WorkshopCustomerNote`, plus
`ServiceRequest.AssignedStaffId` and `ServiceOffering.IsActive` (the public
catalogue read now filters on it). Three migrations
(`AddWorkshopDashboard`, `AddServiceOfferingIsActive`,
`AddWorkshopScheduleConfig`). 24 endpoints under
`/api/v1/service-marketplace/my-workshop/*` (profile, summary, offerings,
add-ons, inventory + movements, staff + assign, requests, customers + notes,
schedule, earnings, metrics) in `MyWorkshopEndpoints.cs`, every handler
resolving the caller's workshop from `ICurrentUser.ProviderId` — never a
route parameter — via a new shared `WorkshopAccess` gate
(owned → approved → owner-or-manager). New `WorkshopFinanceCalculator`
computes held/released/commission figures server-side for the first time
(previously entirely client-computed). 8 new `ErrorCodes`. Seed data extended
with a real, log-in-able demo workshop owner (`DemoMarketplaceSeed.
WorkshopOwnerPhone`) plus a technician account, staff roster and inventory —
none of the seeded providers had an owner account before this. 933 backend
tests pass (26 new: `WorkshopAccess`, `CreateOffering`,
`RecordInventoryMovement`, `DeleteOffering`, `AssignRequest`), covering the
three authorisation cases the spec named: another workshop's id, a
non-approved workshop, and a technician attempting an owner/manager-only
write.

### Flutter app

New models (`inventory_item`, `inventory_movement`, `workshop_staff`,
`workshop_customer`, `workshop_summary`, `workshop_schedule`) plus
`fromJson`/`toJson` added to the previously wire-less `WorkshopEarnings`/
`EarningsLine` now that earnings are server-computed; `ServiceOffering` and
`ServiceRequest` gained `isActive`/`assignedStaffId`. New `WorkshopService`/
`ApiWorkshopService`/`WorkshopRepository` (kept separate from
`ServiceMarketplaceService`, which already sits at ~24 members — this adds
~30 more). New `lib/state/provider_dashboard_state.dart` —
`AsyncNotifier`-based (deliberately, unlike `operator_queue_state.dart`'s
plain `Notifier` + manual `refresh()`: this screen starts with nothing loaded
and needs real loading states). New `lib/features/workshop_dashboard/` — home
(KPI cards, alerts, quick actions), offerings, add-ons, inventory (+ stock
movement sheet), orders (filterable queue, fires escrow transitions directly
through `ServiceMarketplaceRepository` rather than
`EscrowActionBar`/`operatorQueueProvider`, because that pair's list source is
founder-only on the real backend and would silently no-op for a real
workshop owner), staff, customers (+ detail with notes and gated contact),
schedule, profile (+ completeness meter). Added the Settings role-switcher
section that `role_state.dart`/`app_router.dart` both referenced but that did
not actually exist in `settings_screen.dart`.

**Known gaps, named rather than hidden:** quote submission for a
part-install request is not wired into the new orders screen (still on the
`/workshop` panel's Jobs tab); founder audit-log entries are not written for
inventory/staff/customer mutations (would require coupling
`WorkshopRepository` to `ServiceMarketplaceService` purely to call
`appendAudit`); no HTTP-level integration tests for the new backend routes
(unit tests drive the handlers directly against an InMemory EF context — no
`WebApplicationFactory` exists yet anywhere in that repo to build on); no
pixel golden tests (no golden-file infra exists anywhere in this repo either
— the "RTL/LTR golden" test is a build/content smoke test in both
directions, not a pixel comparison).

**Verified:** backend — `dotnet build`, `dotnet test` (933 passed), `dotnet
ef database update` applied against the local dev database. Flutter —
`flutter analyze` (clean project-wide), `dart format`, `flutter test` (505
passed, including 6 new: dashboard smoke in Arabic/English, offering
create/edit/publish/delete, inventory movement math including the
insufficient-stock rejection, staff deactivation). Not run: a live device/
simulator pass against the real API (`preview_tools` are web-browser-based
and do not apply to this Flutter mobile app).

---

## 2026-08-11 · Booking slot time showed as raw "09:00" text instead of a formatted clock time

**Baseline:** `7cf6a5f`. Request: "edit any date and time as date and time
format not as text — see the [Slot] in the services request table" —
`request.slot` itself (`lib/data/models/service_request.dart`) is a free-text
label composed once at booking time, and its *date* portion already went
through `DateFormat('EEE d MMM', …)` — but the *time* portion was the raw
`"HH:mm"` string straight from `GET .../slots` (backend's fixed slot list:
`09:00`, `10:30`, `12:00`, …), concatenated as plain text with no locale
formatting. That produced labels like `"Fri 15 Aug · 09:00"` — half formatted,
half literal — and the same raw `"09:00"`/`"10:30"` strings were also shown
verbatim on the slot-picker chips in `booking_screen.dart`.

### Fix

Added `_formatSlotTime(raw, isAr)` in `lib/features/services/booking_screen.dart`
— parses the `"HH:mm"` key and renders it with `DateFormat('h:mm a', isAr ?
'ar' : 'en')` (e.g. `"9:00 AM"`), falling back to the raw string if it isn't in
the expected shape. Wired into `_slotLabel()` (the string sent to the backend
as `ServiceRequest.Slot` and shown on `requests_screen.dart` /
`tracking_screen.dart` / `escrow_action_bar.dart`, all of which just echo that
already-composed string) and into the `_SlotChip` picker labels. The raw
`"HH:mm"` value is still what's compared for selection/availability and stored
as `_slot` — only the *displayed* text changed. Also renamed the chip-loop's
loop variable from `s` (shadowing the outer `S.of(context)` instance) to
`slot`, which is what made reaching `s.isAr` inside the loop possible.

**Verified:** `dart analyze` on both changed files — no issues. Not run
in the simulator/device — this is a display-string change with no new state
or network calls, and the existing `DateFormat(pattern, 'ar')` call one line
above (already in the codebase, unchanged by this edit) uses the same
locale-string pattern this one follows, so it carries no new risk beyond what
already shipped.

---

## 2026-08-11 · Chat's REST fallback was polling every 5s for up to 5 minutes per message

**Baseline:** `7cf6a5f`. Request: server logs showed `GetThreadMessagesQuery`
firing every 5 seconds right after a chat message was sent — flagged as a
server-cost concern.

### The mechanism

`ApiChatService.awaitProviderReply` (`lib/data/services/api/api_chat_service.dart`)
already treats SignalR as the fast path and REST polling as a fallback that's
only supposed to run "while the hub is disconnected" — that part was already
correct. What wasn't accounted for: once the hub failed to connect for a given
message (any transient network hiccup, cold start, etc.), the old
`Timer.periodic(Duration(seconds: 5), …)` kept firing at a flat 5s cadence for
the entire `_replyTimeout` (5 minutes) with no attempt to reconnect the hub in
between — worst case 60 REST calls to `GET
/chat/threads/{id}/messages` for a single sent message if the provider was
slow to reply.

### Fix

Replaced the flat-interval `Timer.periodic` with a self-rescheduling `Timer`
that (a) retries `_hub.join(threadId)` on every tick before falling back to
REST, so a transient drop can heal mid-wait instead of polling for the rest of
the 5-minute window, and (b) doubles the poll interval each time REST is
actually used (5s → 10s → 20s → capped at 30s), resetting to 5s the moment the
hub reconnects. Worst case over 5 minutes drops from 60 requests to roughly
12-13 with the hub down the whole time, while a reply in the first few seconds
still gets picked up at the original 5s latency.

**Verified:** `dart analyze lib/data/services/api/api_chat_service.dart` —
no issues. Not verified against a live disconnected-hub scenario (would need a
device/environment where the SignalR hub genuinely fails to connect to
reproduce the original log pattern) — the diagnosis is why the client was
capable of running the REST endpoint 5x more than intended, not a claim about
why the hub was disconnected in the first place; that would need infra-level
investigation (proxy/websocket support, TLS, auth) if it recurs.

---

## 2026-08-11 · Reserving a service failed with a 500, twice over

**Baseline:** `7cf6a5f`. Request: "I was trying to reserve a service and the
app crushed" with a Flutter console dump ending in `POST
/service-marketplace/requests 500` and `ApiException(500): An error occurred
while saving the entity changes.`

### The real bug: booking any add-on a second time crashed the save

`CreateServiceRequestCommandHandler`
(`AKCarsMobileAPI/src/AKCars.Application/Marketplace/CreateServiceRequest/CreateServiceRequestCommand.cs`)
built each `RequestAddOn` row with `Id = addOn.Id` — the **catalogue** add-on's
own id, reused as the primary key of the new snapshot row.
`RequestAddOnConfiguration` keys `RequestAddOns` on `Id` alone (not composite
with `RequestId`), so the first booking of a given add-on inserted fine, and
every booking of that same add-on by anyone, ever, after that hit a primary-key
collision on `SaveChangesAsync` — exactly the "error occurred while saving the
entity changes" the user hit. Since the DB has carried real data since
2026-08-10 (`[[no-demo-seeder-decision]]`), most add-ons had already been
booked at least once, so this was not an edge case — it reproduced on most
bookings that included an add-on. Fixed by generating a fresh `Guid.NewGuid()`
for `RequestAddOn.Id` instead; nothing reads it expecting it to equal the
catalogue add-on's id (`ServiceRequestMapper.ToDto` only echoes it back as a
snapshot id).

### A second, real but separate bug in the same flow

`BookingScreen._confirm` (`lib/features/services/booking_screen.dart`) built a
placeholder `Car(id: 'adhoc', …)` when the signed-in customer had no primary
car, a leftover from when this screen wrote a fake local `ServiceRequest`
instead of calling the API (see `819d58c`, `228e1d2`). `carId` is a required
`Guid` foreign key on the server
(`CreateServiceRequestCommand`/`CreateServiceRequestBody`), so `"adhoc"` cannot
bind as a `Guid` at all — this path fails before reaching the handler above,
not with the same 500, but it is a real dead end with no way forward for the
customer. `PartRequestScreen._send` already handles the equivalent case
correctly: stop and send the customer to `/add-car`. `BookingScreen._confirm`
now does the same instead of fabricating an id, and the actual
`requests.place(...)` call is wrapped in try/catch — previously an API error of
any kind (this 500 included) left `_confirming` stuck `true` forever with no
feedback, matching the "crashed" report even though nothing in Flutter itself
threw uncaught. Same recovery pattern as `AddCarScreen._watchWrite`: reset the
button, heavy-impact haptic, a translated snackbar.

### File-by-file

| File | Change |
|---|---|
| `AKCarsMobileAPI/src/AKCars.Application/Marketplace/CreateServiceRequest/CreateServiceRequestCommand.cs` | `RequestAddOn.Id` is now `Guid.NewGuid()`, not the catalogue add-on's id |
| `lib/features/services/booking_screen.dart` | `_confirm` now requires a real primary car (redirects to `/add-car` if none) and wraps `requests.place(...)` in try/catch with a reset + snackbar on failure |

### Verified

- `dotnet build src/AKCars.Application/AKCars.Application.csproj` — 0 warnings,
  0 errors.
- `flutter analyze lib/features/services/booking_screen.dart` and
  `flutter analyze lib` — clean (one pre-existing unrelated info in
  `core/utils/contact.dart`).
- `flutter test test/translation_coverage_test.dart` — 26 passed, including
  both booking-screen cases (the new strings have Arabic/English pairs).
- **Not run:** the full `flutter test` suite, and no live end-to-end booking
  against a running `AKCarsMobileAPI` instance (no dev server/DB available in
  this session) — the add-on-collision fix in particular should be exercised
  against a real database before this is called closed, since nothing in
  `AKCars.Tests` currently covers `CreateServiceRequestCommandHandler` at all.

---

## 2026-08-11 · Signing in refreshes the whole app, not four repositories

**Baseline:** the entry below, same working tree. Request: "when user login the
whole app data should be refreshed".

### What signing in used to do

`AuthNotifier._warmAuthenticatedData` re-warmed exactly four repositories — the
garage, the maintenance books, the challenge board and the service marketplace.
That list was not chosen as "what a new session needs"; it was "what
`AppBootstrap` had to skip because nobody was signed in yet". Two consequences:

- **Everything bootstrap *had* warmed kept the guest's copy.** The catalogues,
  the parts shop and the cars feed were fetched before sign-in and never fetched
  again, however long the app had been open.
- **The lists that belong to an account were never fetched at all.**
  `OrderRepository.fetchOrders` and `ServiceMarketplaceRepository.fetchRequests`
  had no caller anywhere in `lib/` — "طلباتي" and "حجوزاتي" showed only what had
  been placed since the app was last opened, and after a cold start, nothing.

### The part that was not obvious

Re-warming alone fixes nothing visible. A `WarmCache` is a field on a
long-lived repository, and Riverpod compares provider values by identity — so
refilling one is silent to every `ref.watch(…RepositoryProvider)` above it, in
~20 providers under `lib/state/` and ~15 widgets that read the marketplace
directly. That is why the old four-repository warm-up appeared to work in the
places it covered: those screens are rebuilt for other reasons on the way out of
the auth flow.

Invalidating the repository providers would announce the change and *also* throw
the caches away, blanking every synchronously-read screen until the network
answered. `Ref.notifyListeners` is Riverpod's own answer for this shape — it
tells a provider's dependents to read again without rebuilding the provider — so
each cache-holding repository now registers its `ref` with `WarmCacheNotice`
(`lib/di/providers.dart`) and one `announce()` reaches all of them. Nothing has
to remember to watch a revision counter, including code written later.

A first attempt did use a counter (`dataRevisionProvider`, watched by each
reader). It worked, needed ~35 one-line edits, and would have been silently
wrong the first time somebody added a provider without it. Backed out.

### What is new

- **`lib/state/session_refresh.dart`** — `SessionRefresh`, the single place that
  says what a session refresh is: refill all seven warm caches (the public
  catalogues included), announce, then load bookings, orders, inbox, reviews and
  the operator queue. Every step best-effort and logged; `401`/`403` as plain
  lines, everything else with its stack. The session is committed before this
  runs, so nothing here can strand a user on the auth screen.
- **`RequestsNotifier.load` / `OrdersNotifier.load`** — the missing readers.
  Deliberately *not* started from `build()`: both lists are mutated
  optimistically while the user works, and a fetch begun on an earlier frame
  landing on top of that would undo a transition they just watched happen.
- **`NotificationsNotifier._loadFromServer` → `load`** — public, because
  sign-in needs to call it. Invalidating that provider instead would open a
  second push subscription without closing the first.
- **`AppBootstrap`** now calls `loadSessionLists(includeSelfLoading: false)` for
  a cold start with a stored token, which is what fixes the empty bookings and
  orders on relaunch. The flag leaves out the inbox and the reviews, which load
  themselves from their own `build()`. `_optionalForFounder` moved into
  `SessionRefresh._bestEffort` and is gone from `bootstrap.dart`.

Ads posted and chat threads opened are cleared rather than reloaded — on this
phone they may belong to whoever was signed in before. The **cart is
deliberately left alone**: a guest who fills a basket and signs in to check out
must not lose it.

### Verified

`flutter analyze` clean (one pre-existing `use_null_aware_elements` info in
`lib/core/utils/contact.dart`, untouched). `flutter test` — 488 passing,
including three new ones in `test/session_refresh_test.dart`: a workshop
suspended behind the app's back is visible after sign-in, an account's existing
booking and order arrive, and a refresh whose network fails leaves the session
intact with the old feed still on screen. The first was confirmed to fail
without the `announce()` line, so it is a real regression test rather than a
tautology.

**Not verified:** nothing was run against the live API — the fakes were the only
server. Worth watching on a real sign-in: `_refillWarmCaches` now issues every
catalogue request a second time, and `ServiceMarketplaceRepositoryImpl.warmUp`
fans out one `addOns` + one `availability` call per provider on top of that.

---

## 2026-08-11 · A clean launch that looked like a wall of crashes

**Baseline:** the entry above, same working tree. Request: a `flutter run -d
chrome` log, "check this logs if there any issues then fix them".

### There were no failures in it

Every request succeeded. The only non-2xx was `403` on `/payouts`, `/audit`
and `/operator/requests` — founder-only, warmed once after sign-in, caught by
`_optionalForFounder`. `Firebase.initializeApp() failed` is the documented
no-native-config path. Nothing was broken.

**The issue was that none of that was visible.** An ordinary launch printed
roughly forty 25-line stack traces, and a real failure would have been
indistinguishable from the wallpaper. That is a defect in its own right — a
log nobody can read is a log nobody checks.

### Two sources

**Dio's web adapter warns, per request, that the call will trigger a CORS
preflight** — with `StackTrace.current` attached. It is right about the
mechanism and useless as a signal here: this client sends `application/json`
and an `Authorization` header on nearly every call, so *every* request is a
non-simple one. The preflights are fine — the API answers `OPTIONS` with
`204` and the requests succeed.

Silenced on web via `BrowserHttpClientAdapter.enableCORSWarning`, reached
through a conditional import (`browser_cors_warning.dart` /
`_web.dart`) so the native build never sees `package:dio/browser.dart`.

**`AppBootstrap._optional` / `_optionalForFounder` attached `error` and
`stackTrace` to their `developer.log` calls** — for conditions their own doc
comments call "the ordinary answer, not a failure". `developer.log` renders
that as a full exception dump. Now a plain line each; the two genuine failure
logs in `auth_state.dart` keep their stacks, because those are real.

### Not fixed, and not ours

`dwds/src/injected/client.js` raises `TypeError: Instance of '_JsonMap': type
'_JsonMap' is not a subtype of type 'List<Object?>'`. That is Flutter's own
debug tooling (the webdev injected client), it exists only under `flutter run`
on web, and its own message asks that it be filed against `dart-lang/webdev`.
No app code is involved.

### Files

- **New:** `lib/core/network/browser_cors_warning.dart`,
  `lib/core/network/browser_cors_warning_web.dart`.
- `lib/core/network/dio_api_client.dart` — conditional import + one call.
- `lib/app/bootstrap.dart` — four `developer.log` calls lose `error`/`stack`.

### Verified

- `flutter analyze` clean; `flutter test` — **485 passed, 0 failed**.
- **Ran on web against the live API, both states.** Guest cold start: 31
  requests, all `200`, and the console holds **nothing** from Dio,
  `AppBootstrap` or `PushService`. Signed in: `/user/profile`,
  `/user/vehicles`, `/user/vehicles/maintenance` and both `/challenges/board`
  all `200`, founder-only `403`, every `OPTIONS` `204` — and again no console
  output from any of the three.
- The conditional import genuinely compiles on web: the run above *is* the web
  build, and the warnings it was written to suppress are gone from it.
- **Not checked:** a native (Android/iOS) build. The stub is a one-line no-op
  and `flutter analyze` covers that path, but no device was available to run
  it on.

---

## 2026-08-11 · "Could not log in — try again" was the wrong advice four times out of five

**Baseline:** the entry below, same working tree. Request: a console log full of
`POST /auth/login/verify 401`, "why do these errors happen?", then "yes" to
making the messages specific.

### The 401s were not a bug

`/auth/login/verify` answers `401 otp_invalid_or_expired` for four cases: no
challenge, expired (>5 min), five attempts used up, or **the wrong code**. The
database said which one it was — the challenge created at 16:29 had
`Attempts = 3`, then a fresh one at 16:32 was `Consumed = 1`. Three wrong codes,
then a correct one. Working exactly as designed.

Almost certainly `7391` was typed: the mock backend's fixed code, deleted
yesterday. The real code is random per request and only appears in the API's
console (`LoggingOtpSender`).

The `/payouts` and `/audit` `403`s in the same log are the founder-only
endpoints, warmed once after sign-in and swallowed by `_optionalForFounder`.
Expected; a guest no longer fires them at all since yesterday's gate.

### What *was* wrong: the screen said the same thing to everyone

Both handlers on `login_screen.dart` were bare `on AppException` with one
sentence each. So "wrong code", "expired", "five attempts used", "rate
limited" and "you are offline" all read **"Could not log in — try again"** —
advice that is actively wrong for three of them. `POST /auth/login` is capped
at five per minute per IP, so "try again" there is the one thing guaranteed to
fail.

Worse, the information to do better was already on the wire and being thrown
away: `_translate` parsed the envelope's `code` and then dropped it for a
`401`, and `429` fell through to the `ApiException` catch-all.

### The fix

- `UnauthorizedException` gained `code`, and `_translate` now passes the
  envelope's through. Every existing `on UnauthorizedException` catcher is
  unaffected — they ignore it and still mean "no session".
- `RateLimitedException` for `429`, its own type rather than a magic status,
  because it is the one failure whose correct advice is "wait, then retry the
  identical thing". Nothing caught `ApiException` before, so nothing changed
  shape underneath it.
- `_verifyMessage` / `_sendMessage` on the login screen, both bilingual:
  wrong-or-expired code → *"That code is wrong or has expired — request a new
  one"*; rate limited → *"wait a minute"*; unreachable → *"check your
  connection"*; anything else keeps the old generic line.

**Deliberately not distinguished:** wrong vs. expired vs. attempts-exhausted.
The server collapses all three into one code so the message cannot be used to
learn whether a code was ever right, and the client respects that — the copy
names what the user can *do*, not which of the three happened.

### Files

- `lib/core/error/app_exception.dart` — `UnauthorizedException.code`,
  `RateLimitedException`.
- `lib/core/network/dio_api_client.dart` — carry the code on `401`, map `429`.
- `lib/features/auth/login_screen.dart` — `_verifyMessage`, `_sendMessage`.
- **New:** `test/login_error_messages_test.dart` (4),
  `test/api_error_translation_test.dart` (4).

### Verified

- `flutter analyze` clean (the `core/utils/contact.dart` info predates this).
- `flutter test` — **485 passed, 0 failed** (477 before, 8 new).
- **The transport tests fail on the old code** — reverting the two `_translate`
  lines fails "a 401 carries the envelope code" and "a plain-text 429 is a rate
  limit", which are the two that matter.
- The transport tests drive a **real socket**, not a stubbed adapter, because
  the shapes are the real API's and they differ: problem+json for the `401`,
  **plain text** from the rate limiter for the `429`. Both were captured from
  the live server first (`curl` against `localhost:7291`) and reproduced
  verbatim in the test.
- **Not checked:** the UI was not driven by hand — Flutter web renders to a
  canvas and its accessibility tree could not be enabled here. The widget tests
  do pump the real `LoginScreen` and assert the rendered text, so the copy
  itself is covered; what is untested is a human tapping through it.

---

## 2026-08-10 · Registration succeeded and then every request answered 401

**Baseline:** the entry below, same working tree. Request: a browser console
log full of `401`s and one uncaught `DartError`, then "check the register
account scenario and test all cycle and fix the bugs and errors".

**One root cause under almost all of it, and it was in storage, not in auth.**

### The bug

`TokenStore.save()` wrote its three fields with `Future.wait` — three
concurrent `flutter_secure_storage` writes.

On web that plugin AES-GCM-encrypts every value under a **single key it creates
lazily**: `if (localStorage.containsKey(k)) import else generate-and-store`.
That read-then-write is not atomic. Three writes starting together against a
store with no key yet all see "no key", all generate a **different** key, and
each overwrites the last. Two of the three values end up encrypted under a key
that is no longer there, and every later read of them rejects with WebCrypto's
`OperationError`.

The symptom was not "storage is broken". `DioApiClient`'s request interceptor
reads the token through `tryReadAccessToken()`, which — correctly, for its own
reasons — turns a read failure into `null`. So the app sent **no
`Authorization` header at all** and could not tell that apart from being signed
out:

- `POST /auth/register` → `201`, tokens stored, user registered.
- `POST /user/vehicles` (guest-data adoption) → `401`.
- `GET /user/vehicles`, `/user/vehicles/maintenance`, `/challenges/board` → `401`.
- `PUT /user/profile` → `401`.
- `TokenStore.hasSession()` threw, so `mayHaveSession()` guessed `true`, so the
  next cold start fired the auth-gated warm-ups too — more `401`s.
- One `401` triggered `_doRefresh()`, whose `POST /auth/refresh` also failed,
  and its `on DioException` calls `tryClear()` — **silently deleting a session
  that was perfectly valid.**

Device platforms never had this: the keystore has no shared key to race over.
It only ever showed on web.

### The fix

`save()` and `clear()` write **one value at a time**. The first call creates
the key, the rest import it. Nothing else changed — the tokens, the endpoints
and the interceptor were all fine.

An existing corrupt store heals itself at the next successful register or
login, because by then the key exists and all three writes import it.

### Two more, found while testing the cycle

**`ReviewsNotifier.load()` threw uncaught for every guest.** `build()` ran it
from a bare `Future.microtask(load)` with nothing catching it, and `GET
/reviews` is `[Authorize]`d — so the moment a guest opened any screen reading
that provider (a workshop's details page), the `UnauthorizedException` escaped
into the zone. That is the `Uncaught (in promise) DartError` at the top of the
reported log. Now guarded on the session and swallowing `UnauthorizedException`,
the same shape `NotificationsNotifier._loadFromServer` already used.

**Both of those notifiers could read a disposed container.** Each starts an
unawaited load from `build()` and touches `ref` after an `await`; a container
disposed mid-load (sign-out, hot restart) made them throw a bare `StateError`
into the zone. Both now carry the `_disposed` flag `AuthNotifier` grew earlier
today, set from `ref.onDispose`.

**The founder's ledger was warmed for everyone.**
`ServiceMarketplaceRepositoryImpl.warmUp()` fetched `/payouts` and `/audit` on
every launch. They are founder-only — `403` for a signed-in customer, `401` for
a guest — and `_optionalForFounder` correctly swallowed both, so this was noise
rather than breakage: two red lines in every visitor's console, on every cold
start, forever. `warmUp` now takes `includeFounderLedger`, and bootstrap passes
`signedIn`. A signed-in non-founder still asks and still gets its `403` — the
client has no founder claim to check — but a guest provably cannot be one.

**Not a bug:** `[PushService] Firebase.initializeApp() failed` is expected and
already handled. There is no native Firebase config in this repo; push is
additive and its absence must never block sign-in, which is exactly what that
log line shows working.

### Files

- `lib/data/services/token_store.dart` — sequential `save`/`clear`.
- `lib/state/reviews_state.dart` — session guard, `UnauthorizedException`
  swallow, disposal guard.
- `lib/state/notifications_state.dart` — disposal guard.
- `lib/data/repositories/service_marketplace_repository.dart`,
  `lib/app/bootstrap.dart`, `lib/state/auth_state.dart` —
  `warmUp({includeFounderLedger})`.
- **New:** `test/token_store_write_race_test.dart`,
  `test/web/token_store_browser_test.dart`.

### Verified

- `flutter analyze` clean (the one remaining `info` in
  `core/utils/contact.dart` predates this work).
- `flutter test` — **477 passed, 0 failed.**
- **The regression test fails on the old code**, which is the only thing that
  makes it worth having: reverting `save()` to `Future.wait` gives
  `maxConcurrentWrites: 3` and an `OperationError` on read-back.
- **Reproduced and fixed in the real browser, against the live API.** Writing
  the token store the racy way (three keys) reproduces the reported log exactly
  — `/user/profile`, `/challenges/board`, `/user/vehicles` all `401`, a
  `/auth/refresh` attempt, then the tokens deleted. Writing the same tokens the
  way the fixed `save()` writes them (one shared key) gives:
  `GET /user/profile` **200**, `/user/vehicles` **200**,
  `/user/vehicles/maintenance` **200**, both `/challenges/board` **200**,
  founder-only **403**, no refresh, no clearing.
- **Guest cold start is now silent**: 31 requests, all `200`, no `401`, no
  `403`, no uncaught exception. Before: `/payouts`, `/audit`, `/reviews`,
  `/user/vehicles`, `/user/vehicles/maintenance` and both `/challenges/board`
  all `401`, plus the uncaught `UnauthorizedException`.
- **Not checked:** `test/web/token_store_browser_test.dart` — the real
  `TokenStore` against the real `flutter_secure_storage_web` — is written and
  committed but **has not been run to completion**: `flutter test --platform
  chrome` did not finish compiling in this environment. Run it with
  `flutter test test/web --platform chrome`. Its coverage is otherwise
  reproduced by the pure-Dart race test plus the live browser A/B above.
- **Also not checked:** the UI path into registration. Flutter web renders to a
  canvas and the accessibility tree could not be enabled here, so the register
  *form* was not driven by hand; the account was created through the same
  `POST /auth/register` the form calls, and the session behaviour after it was
  exercised in full.

---

## 2026-08-10 · The demo data left the app; the API is the only data source

**Baseline:** `7cf6a5f`, working tree already dirty with the API/currency work.
Request: "remove the whole demo data from the frontend
`lib/data/datasources/mock` · force app to use the api only · test the app when
you make sure is fully connected with the api", against
`C:\Projects\Cars Project\AKCarsMobilApp\AKCarsMobileAPI` on
`Server=.\SQLEXPRESS;Database=AKCarsMobileDb`, running at
`https://localhost:7291/api/v1`.

### What was there

The app shipped **two complete data layers**. Every service had an `Api*`
implementation and a `Mock*` one reading a 185 KB seeded world under
`lib/data/datasources/mock/`, and `di/providers.dart` chose between them on
`AppConfig.dataSource` (`DataSourceMode { mock, api }`, overridable with
`--dart-define=AK_DATA_SOURCE`). Every environment already shipped
`useMockData: false`, so the demo half was dead weight in the binary — but it
was reachable weight, and several screens still branched on which half was live.

### What was done

**The demo world left `lib/` entirely.** The nine seed files moved to
`test/fakes/data/` (as a git rename, so history follows), and the ten demo
`Mock*Service` classes were cut out of the interface files they shared and
rewritten as test doubles in `test/fakes/`. `lib/data/datasources/` is gone.

**`DataSourceMode`, `useMockData`, `mockLatency` and `AppConfig.forTests` are
gone**, along with `UnconfiguredApiClient` — with one arm there is nothing to
guard against a misconfigured second arm. `apiClientProvider` is always a
`DioApiClient`; every service binding is its `Api*` implementation, no
condition.

**Two classes named `Mock*` were not mocks and stayed**, renamed:
`MockGarageService` → `LocalGarageStore`, `MockMaintenanceService` →
`LocalMaintenanceStore`. They are SharedPreferences-backed device stores, and
they are half of the *live* API path — `SessionGarageService` writes a guest's
cars to the device because registering one is step 3 of 3 of first launch while
`/user/vehicles` is `[Authorize]`d. Deleting them with the rest of the "mocks"
would have broken first launch.

**Client-side pretending was removed, not relocated:**

- `RequestsNotifier._simulateLifecycle` / `OrdersNotifier._simulateStoreLifecycle`
  — timers that walked a booking or order along its happy path — and the
  "Demo build — the state advances on its own · Skip ahead" row on the tracking
  screen, with `AppConfig.simulateProviderLifecycle` that gated them.
- The registration OTP. `RegisterScreen` demanded a 4-digit code and compared
  it to `_stagingCode = '7391'` compiled into the app. `POST /auth/register`
  and `PUT /user/profile` have no OTP step, so that gate could only ever be
  satisfied by a code the real server never issued. The whole verification
  block, the channel picker and the constant are gone; the submit button says
  "Continue". **Login still verifies a real, server-issued code** —
  `/auth/login/verify` exists and is rate-limited — only its `isMock`
  shortcut around `_stagingCode` was removed.
- `ChallengeNotifier._writeMaintenanceRecord`. The server writes that record in
  the same transaction as the award (`CompleteChallengeCommand.
  FeedMaintenanceRecordAsync`); the client's copy was harmless only while the
  mock backend wrote none, and a duplicate entry against the real one.

### The trap: the suite hung, and the mock path had been hiding why

Removing the mock branch made 26 of 39 test files hang for their full
ten-minute deadline. The cause was not the change — it was something the change
stopped concealing. `AppBootstrap._signedIn` used to short-circuit to `true` on
the mock source and never touch `TokenStore`. Now every warm-up asks it, and
`flutter_secure_storage` under `flutter_tester` does not throw — **it never
completes**. Every widget test sat on an unresolvable future before its first
`pump()`.

`test/fakes/memory_token_store.dart` fixes it, and two more floors were added
under the harness for the same class of problem: `OfflineApiClient` refuses
every request loudly (a service the harness forgets to double now fails at the
call site instead of opening a socket), and `SilentPushService` keeps
`NotificationsNotifier.build` away from Firebase.

`AuthNotifier` also grew a `_disposed` guard: `_adoptGuestDataThenWarm` is
fire-and-forget and now always has adopters to run, so it could read `ref` after
the container went away and throw a bare `StateError` into the zone.

### Found on the way, and fixed — unrelated to this work

`RialGlyph` renders the rial sign as an `Image.asset` inside a baseline-aligned
`WidgetSpan`. `RenderImage` does not implement `computeDryBaseline`, so **any**
ancestor that dry-lays-out its children asserted rather than laid out — and
`UrgencyCard` wraps its content in an `IntrinsicHeight` for the leading edge
bar. Every escrow card and status pill that printed a price threw in debug: the
tracking screen, both operator panels, the quote screen, the services region
cards, the home offer rail. Reproduced in isolation with no providers, no
services and no data source involved, so it predates this change and came in
with the currency work.

Fixed by aligning that one inner span `middle` instead of `baseline`. The glyph
is drawn at 0.72em (cap height, per the guideline) and centred on the text
midline, within a fraction of a pixel of where it was; the *outer* span still
baseline-aligns the whole sign+numeral cluster with the sentence around it, and
that one is a `RenderParagraph`, which computes a dry baseline perfectly well.
**Flagged rather than assumed:** if the sub-pixel shift matters, the other fix
is to stop `UrgencyCard` using `IntrinsicHeight`.

Six test assertions still expected the old literal `'OMR 45.00'` string that
the currency work replaced with a glyph; they now match on the numeral with
`findRichText: true`.

### Files

- **Moved:** `lib/data/datasources/mock/*` (9 files) → `test/fakes/data/`.
- **New:** `test/fakes/fakes.dart` (the `fakeServiceOverrides` seam), ten
  `test/fakes/mock_*_service.dart`, `fake_service_base.dart`,
  `memory_token_store.dart`, `offline_api_client.dart`.
- **Deleted:** `lib/core/network/unconfigured_api_client.dart`,
  `lib/data/services/mock_service_base.dart`, `lib/data/datasources/`.
- **lib:** `config/app_config.dart`, `di/providers.dart`, `app/bootstrap.dart`,
  the ten `data/services/*_service.dart` interface files,
  `data/repositories/notification_repository.dart`, `state/auth_state.dart`,
  `state/challenge_state.dart`, `state/notifications_state.dart`,
  `state/orders_state.dart`, `state/requests_state.dart`,
  `features/auth/login_screen.dart`, `features/auth/register_screen.dart`,
  `features/services/tracking_screen.dart`, `core/widgets/rial_symbol.dart`.
- **Docs:** `ARCHITECTURE.md` §1/§3/§4, `docs/api_contract.md` scope section.
  The Arabic phase-2 instruction files were left alone — they are a record of
  what was planned, not a description of what is.

### Verified

- `flutter analyze` — clean. The one remaining `info`
  (`core/utils/contact.dart:23`, `use_null_aware_elements`) predates this work.
- `flutter test` — **474 passed, 0 failed**, 42s. It was 432/42 with hangs when
  the work started.
- **The app, running against the live API.** `flutter run -d web-server`, loaded
  in a browser: 33 requests to `https://localhost:7291/api/v1`, **all 200**
  except `GET /service-marketplace/payouts` and `/audit`, which are founder-only
  and correctly `401` for an anonymous session. Zero requests to anything else.
  `GET /service-marketplace/providers` returned the eight approved workshops
  from `AKCarsMobileDb` (Al Noor, Gulf Auto Care, Qurum Auto Experts, Nizwa Car
  Care, Rustaq Motor Works, Saham Auto Centre, Salalah Motors Hub, Barka Quick
  Fix), and the app then fetched add-ons and slots for each of those eight ids —
  so it parsed and used them, not just received them.
- **Not checked:** no Android or iOS device was available (no emulator
  configured, and the project has no `windows/` target), so the run above was
  the web target. The signed-in half of the app — anything behind
  `/auth/login/verify` — was not exercised end to end; only its `401` behaviour
  as a guest was.

---

## 2026-08-09 · The whole service marketplace was behind auth; only one route needed it

**Baseline:** the entry below, same working tree. Request: the user's own
diagnosis — "the getting data from other endpoints asks authentication for each
request, but no need that for all endpoints" — then study it and fix.

**They were right, and this is the actual root of the very first symptom in this
log's session: "no data displayed on the screens".** Earlier that was put down to
an empty database. The database *is* empty, but it was not the only reason a
guest saw nothing — even fully seeded, the Services tab, the home offers rail
and every provider page would still have rendered empty, because the API refused
to serve them without a session.

### The problem
`MarketplaceEndpoints` put `RequireAuthorization()` on the whole
`/service-marketplace` group. Twelve routes; **eleven are public catalogue
data** — categories, providers, offerings, promotions, offers, category and
workshop demand, ratings, add-ons, slots. Only `PATCH /offers/{id}`, the
founder's approval switch, is a write.

That contradicts the rule the app states outright — "browsing is open, but
transactions (booking, checkout, publishing an ad) require a completed
registration" — and it contradicts the rest of this same API, where `/cars`,
`/cars/{id}`, `/products` and the whole catalogue are already `AllowAnonymous`.
`GET /service-marketplace/providers/{id}/reviews` had the same problem: the
ratings that decide whether to book were invisible until after registering.

Two things made it safe to open, and both were checked rather than assumed:
`CurrentUser` is null-safe on every member, so an anonymous caller yields
`IsFounder == false` — which is exactly what `GetProvidersQuery` needs to narrow
the roster to approved workshops. And `GetProviderReviewsQuery` takes no
`ICurrentUser` at all.

### The fix, and the trap in it
Two `MapGroup`s on the same prefix — one `AllowAnonymous`, one
`RequireAuthorization` — rather than one group with a per-route override.

That is not stylistic. ASP.NET's authorization middleware short-circuits when it
finds **any** `IAllowAnonymous` in an endpoint's metadata, so
`group.AllowAnonymous()` plus `.RequireAuthorization()` on one route inside it
leaves that route **open**: the override silently loses, and the founder's
approval switch would have shipped unauthenticated. Separate groups cannot
express the mistake. It is also the shape `CarsMarketplaceEndpoints` already
uses for its `cars` / `cars/my-ads` split.

The client had the mirror image of the same gate. `AppBootstrap.warmUp` skipped
the marketplace for guests, so opening the API alone would have changed nothing.
Moved out of the `if (signedIn)` block — and `_optionalForFounder` had to grow
an `UnauthorizedException` arm, because `/payouts` and `/audit` are the only
calls in that warm-up still needing a session and they answer a guest `401`, not
`403`. Catching only `403` would have failed the whole `Future.wait` and left
the guest with the empty categories this change exists to fill.

### Files
| File | Change |
|---|---|
| `AKCarsMobileAPI/…/Endpoints/MarketplaceEndpoints.cs` | group split: public browse + founder-only `PATCH /offers/{id}` |
| `AKCarsMobileAPI/…/Endpoints/ReviewEndpoints.cs` | `providers/{id}/reviews` → `AllowAnonymous` |
| `lib/app/bootstrap.dart` | marketplace warm-up moved out of the signed-in block |
| `lib/data/repositories/service_marketplace_repository.dart` | `_optionalForFounder` also swallows `UnauthorizedException` |

### Verified
- **Both directions, against a running server, with no token.** The API was
  built to a temp output and started as a *second* instance on `:7399` rather
  than restarting the user's own — which holds a lock on `bin/` and may have a
  debugger attached.
- 14 browse routes now answer **200** anonymously: all ten marketplace reads,
  provider reviews, plus `/cars`, `/products`, `/locations`, `/cars/catalog` as
  controls.
- **19 protected routes still answer 401** anonymously — including
  `PATCH /service-marketplace/offers/{id}`, the one sharing the opened prefix,
  which is the direct check that the two-group split beat the `IAllowAnonymous`
  trap. Also `/requests`, `/operator/requests`, `/part-requests`,
  `/applications`, `/providers/{id}/stage`, `/payouts`, `/audit`, `GET /reviews`
  (the caller's own, unlike the provider's), `/user/*`, `/cart`, `/orders`,
  `/notifications`, `/chat/*`, `/challenges/board`, `/cars/my-ads`.
- `dotnet build`: 0 warnings, 0 errors. `flutter analyze` on `lib/`: clean
  apart from the pre-existing `core/utils/contact.dart` info.
- Client tests: `bootstrap`, `home`, `home_offers`, `guest_garage`,
  `token_store_unreadable`, `warm_up_error_handling`, `data_source_switch`,
  `onboarding`, `account` — **78 passed, 0 failed**.
- **One pre-existing failure, measured not assumed:** `services_region_test` →
  "Package cards count and price the selected region only" fails identically
  with the bootstrap hunk applied and reverted by hand. Unrelated to this
  change.
- **Full suite, finally measured: 398 passed / 61 failed** (9m27s, API running).
  The comparable figure recorded three entries below was **77 failures with the
  server up** — so the session's changes take the suite down by ~16 failures and
  add none. It took this long to get a number because the first full run had
  been moved to the background after its timeout instead of being killed, and
  kept competing with every later run; once it and its successor were stopped,
  the suite completed normally. No verification claimed earlier depended on it —
  every other figure came from targeted runs read directly.
- **Not verified in the browser.** The user's API instance still runs the old
  binary — this needs their server restarted and the Flutter app hot-restarted
  before a guest's Services tab will actually fill.

---

## 2026-08-09 · An unreadable token store was reported as an unreachable server

**Baseline:** the entry below, same working tree. Request: a debugger message —
`Error calculating Dart variables for 1 sync frames` — paused in
`flutter_secure_storage_web`'s WebCrypto `decrypt`.

### The debugger message itself is not a bug
"Error calculating Dart variables for N sync frames" comes from the Dart
debugger, not the app. It is the IDE failing to *render* locals for a frame,
which it routinely does under DDC when the frame holds JS-interop values —
`ByteBuffer`, a `CryptoKey`, the `promiseToFuture` machinery in that very
snippet. Nothing is thrown and nothing is broken by it. No fix, because there
is nothing there to fix.

### What is a bug is the code it was paused in
That `decrypt` call is how `flutter_secure_storage` reads a value on web, and
it can genuinely fail: WebCrypto raises `OperationError` when the key in
storage no longer matches the ciphertext — a rotated key, a half-cleared
origin, storage written by another build. On device the same read fails on a
keystore behind the lock screen or a keychain refusing on a restored backup.

`TokenStore` already knew this. `mayHaveSession()` was written for exactly
these cases and documents them. **Only that one method was hardened**, and
three call sites on the request path read the store unguarded:

| Call site | What a throw did |
|---|---|
| `DioApiClient` request interceptor | Dio turns an exception out of `onRequest` into a `DioException` with no response → `_translate` sees `DioExceptionType.unknown` → **`NetworkException: Could not reach <host>`**. The network blamed for a storage fault, on *every* request. |
| `DioApiClient._doRefresh` | The read sits outside the `try`, so it escaped `_refreshAndSave` and surfaced from inside `_send`'s `on DioException` block — replacing the original `401`, and leaking a raw platform error to callers, which this class explicitly promises never to do. |
| `ChatHub`'s `accessTokenFactory` | Threw out of the SignalR handshake instead of failing as an ordinary unauthorized connection, which the class already swallows. |

The first is the one that matters. It converts a recoverable, correctly
diagnosable condition into a wrong diagnosis, and it does it on the hot path.

### The fix
`TokenStore` grows the non-throwing forms the request path needs —
`tryReadAccessToken()`, `tryReadRefreshToken()`, `tryClear()` — and the three
call sites use them. An unreadable token now means the same as no token: the
request goes out unauthenticated and the server's `401` is the answer, which
the app already handles.

The plain `readAccessToken()` / `readRefreshToken()` / `clear()` stay
unguarded. Callers that genuinely want to know still get told; only the request
path opts out.

`_doRefresh` also gained a general `catch` for a refresh response it cannot
read or a store that will not take the new pair. It deliberately does **not**
clear the tokens there, unlike the `DioException` branch: a rejected refresh
proves the stored token is bad, whereas a transient storage fault proves
nothing, and discarding a good session over it would sign the user out for no
reason.

### Files
| File | Change |
|---|---|
| `lib/data/services/token_store.dart` | new `tryReadAccessToken`, `tryReadRefreshToken`, `tryClear` |
| `lib/core/network/dio_api_client.dart` | interceptor and `_doRefresh` use them; `_doRefresh` gains a non-clearing general `catch` |
| `lib/core/network/chat_hub.dart` | `accessTokenFactory` uses `tryReadAccessToken` |
| `test/token_store_unreadable_test.dart` | **new** — 4 tests |

### Verified
- `flutter analyze` on `lib/`: clean apart from the pre-existing
  `core/utils/contact.dart` info.
- New tests cover the store failing every operation: the `try…` reads answer
  `null`, the plain reads still throw (the guard is opt-in, not a blanket
  swallow), `tryClear` completes, and `mayHaveSession()` still answers `true`.
  That last one is asserted precisely because it is the **opposite** guess to
  `tryRead…` and the two must not be "tidied" into agreement: it only decides
  whether a request is worth making, where guessing "signed out" would drop a
  real session from its own warm-up.
- `token_store_unreadable`, `warm_up_error_handling`, `guest_garage`,
  `data_source_switch`, `bootstrap`, `garage`, `onboarding`, `account`,
  `profile`: **70 passed, 0 failed**.
- **Not changed, and flagged rather than fixed:** `ApiAuthService.signOut()`
  also calls `_tokens.clear()` unguarded, in a `finally`. It is the same shape,
  but the existing comment there is a security argument — "a logout that leaves
  a token behind … is the worst kind of bug on a shared phone" — and silently
  swallowing a failed clear on a shared device is worse than surfacing it.
  Changing that is a security-relevant decision, so per CLAUDE.md §13.6 it is
  raised here rather than made quietly.

---

## 2026-08-09 · "That account already exists" reached the console, not the user

**Baseline:** the entry below, same working tree. Request: an uncaught
`ApiException(409): An account with that phone or email already exists.` from
`POST /auth/register`.

### The problem
The `409` was right — that phone *was* already registered. Two things were
wrong with what the app did about it.

**`_submit()` had no `try`/`catch`.** `AuthNotifier.register` rolls its
optimistic state back and rethrows, so the screen was the only thing left to
handle it, and it did not. The result: `_saving` stayed `true` so the button
span for ever, the screen said nothing, and the reason went to a console the
user will never open. Every failure mode of that form behaved this way — a
`409`, an offline phone, a `500` — not just this one.

**The transport could not tell it apart from a crash.** `_translate` mapped
`400`/`422`-with-a-code to `BusinessRuleException` but left `409` in the
`ApiException` catch-all, so "that phone is already registered" arrived at the
call site indistinguishable from a `500`. Even a screen that *did* catch could
only have shown "something went wrong".

### The fix
`409` with a code now maps to `BusinessRuleException`, alongside `400`/`422`. A
conflict carrying a stable documented code is a business rule, not a malformed
request — the server refused on a condition the client can name and act on.

`_submit()` catches, clears `_saving`, and reports. The one case worth branching
on is `account_already_exists`: "try again" is the wrong advice, because the
same phone will be refused every time, so the snackbar carries a **Sign in**
action instead of leaving the user to find it. It is also the likeliest failure
here — `/auth` offers registration to anyone not signed in, including someone
who simply signed out of an account they still have.

The server's own `detail` is deliberately not shown: it is English-only and this
screen is Arabic by default. A localized line for the case we recognise beats a
server string the user may not read.

### Files
| File | Change |
|---|---|
| `lib/core/network/dio_api_client.dart` | `_translate`: `400 \|\| 409 \|\| 422 when code != null` → `BusinessRuleException` |
| `lib/features/auth/register_screen.dart` | `_submit` wrapped in `try`/`catch`; new `_reportSubmitFailure` with the `account_already_exists` branch |
| `docs/api_contract.md` | `409` added to the status→exception table with the reasoning; `account_already_exists` added to the business-rule code table |

### Verified
- **The wire format was checked, not assumed** — the whole mapping depends on
  the body carrying `code` as a ProblemDetails extension member, so a duplicate
  registration was re-sent to the live API:
  `{"title":"account_already_exists","status":409,"detail":"An account with
  that phone or email already exists.","code":"account_already_exists",…}`.
  `code` is present, so the new arm fires and the screen's
  `error.code == 'account_already_exists'` matches.
- `flutter analyze` on `lib/`: clean apart from the pre-existing
  `core/utils/contact.dart` info.
- `account`, `profile`, `onboarding`, `warm_up_error_handling`, `guest_garage`,
  `data_source_switch`: all pass.
- **`_translate` itself is not unit-tested, and that is a real gap rather than
  an oversight I am glossing over.** `DioApiClient` builds its own `Dio` with no
  adapter seam, and the suite is required to pass with no server listening, so
  there is nowhere to inject a canned `409`. The sibling `400`/`422` arm has
  never been tested either. Adding a seam (an injectable `HttpClientAdapter`)
  would make this whole error table testable and is worth doing on its own.
- **One pre-existing failure, diagnosed rather than waved away:**
  `contact_gating_test` → "tracking offers the thread until the funds are held"
  fails with `The RenderImage class does not implement "computeDryBaseline"` in
  `IntrinsicHeight` at `core/widgets/status_indicator.dart:121`. That file is
  **unmodified since the last commit** and none of this change's files are in
  that render path. It is an image widget (the new `RialSymbol`, from the
  currency work already in the tree) inside a committed `IntrinsicHeight` —
  a Flutter layout limitation. Not fixed here: it is a separate bug that was
  not reported, and the fix touches layout. Cheap when wanted — give the image
  an explicit size, or drop the `IntrinsicHeight`.

---

## 2026-08-09 · The error handler was the error: `warmUp()` lied about its type

**Baseline:** the entry below, same working tree. Request: an uncaught
`Invalid argument(s) (onError): The error handler of Future.catchError must
return a value of the future's type`, traced through `warm_cache.dart:25` and
`api_challenge_service.dart:18`.

### The problem
`AuthNotifier._warmAuthenticatedData` treats a post-sign-in warm-up as
best-effort and discarded failures with `warmUp().catchError((_) {})`. When the
challenge warm-up actually failed, **the discard itself threw** — and the error
it threw replaced the one it was meant to swallow, so the real cause never
appeared anywhere.

Five `warmUp()` implementations declared `Future<void>` over a body that
returns something else:

```dart
Future<void> warmUp() => Future.wait([...]);   // really Future<List<…>>
Future<void> warmUp() => _cars.load(...);      // really Future<List<Car>>
```

This compiles, because `void` accepts anything — but widening at the
*declaration* does not change the *object*. The future's runtime type argument
stays `List<…>`, and `catchError`'s contract is that the handler returns a value
of that type. A handler returning nothing is then an argument error. It is
invisible until the future rejects, which is exactly when you least want a
second, unrelated failure.

`cars`, `catalog`, `challenge`, `shop`, `garage` and `maintenance` all had it.
`service_marketplace` did not — it was already `async`.

### The fix
Both halves, because either alone leaves the trap armed.

- The six `warmUp()`s are now `async`, so they return a genuine `Future<void>`.
- `_warmAuthenticatedData` uses `try`/`catch` instead of `.catchError`, and
  **logs** rather than discarding — a warm-up that fails silently is a screen
  that renders empty with nothing to explain it. That was the second half of why
  this was hard to see. `_watchWrite` (added in the entry below) moved to
  `try`/`catch` too; its futures were genuine `Future<void>`, but the form is
  what made this bug possible and it should not survive anywhere.

The underlying challenge-warm-up failure is a separate question — it was never
diagnosable while the handler was overwriting it, and it is now logged instead
of swallowed.

### Files
| File | Change |
|---|---|
| `lib/data/repositories/{cars,catalog,challenge,shop}_repository.dart` | `warmUp()` → `async` body; comment on why the arrow form is a trap |
| `lib/data/repositories/{garage,maintenance}_repository.dart` | same, one-liners |
| `lib/state/auth_state.dart` | `_warmAuthenticatedData` is `async` with `try`/`catch` + `developer.log` |
| `lib/features/garage/add_car_screen.dart` | `_watchWrite` → `try`/`catch` |
| `test/warm_up_error_handling_test.dart` | **new** — 3 tests |

### Verified
- **The new test reproduces the original error before the fix, verbatim.**
  Reverted `garage_repository.warmUp()` to the arrow form by hand and re-ran:
  `Invalid argument(s) (onError): The error handler of Future.catchError must
  return a value of the future's type`. Restored → passes. That round trip is
  the evidence; without it the test only proves the current code works.
- Note `isA<Future<void>>()` **cannot** catch this — `void` is a top type, so
  every future satisfies it. The test handles a real error instead, and also
  asserts the original `StateError` reaches a `try`/`catch` caller rather than
  being replaced.
- `flutter analyze` on `lib/`: clean apart from the pre-existing
  `core/utils/contact.dart` info.
- `warm_up_error_handling`, `guest_garage`, `data_source_switch`, `bootstrap`,
  `garage`, `onboarding`: **45 passed, 0 failed**.
- `garage_persistence` + `first_run`: still exactly 14, unchanged — the same
  pre-existing `NetworkException` set measured in the entry below.

---

## 2026-08-09 · Registering a car on first launch answered 401 and lost the car

**Baseline:** `7cf6a5f` (working tree already dirty with the API-data-source
work, including the entry below). Request: a console trace showing
`POST /user/vehicles` → `401` and an uncaught `UnauthorizedException`, then
"check and fix".

### The problem
Tapping Save on the add-car form fired `POST /user/vehicles` and
`PATCH /user/vehicles/{id}`, both answered `401`, and the rejection escaped as
an uncaught async error.

The `401` was correct. The *request* was the bug. `/user/vehicles` is
`[Authorize]`d — reasonably, a vehicle belongs to a user — but the app
deliberately lets a **guest** register a car: `StartChoiceScreen` is step 3 of 3
of first launch ("Rule 3 — start with a registered car, or skip"), and
`AuthState` documents the gate as "browsing is open, but transactions
(booking, checkout, publishing an ad) require a completed registration". A
garage entry is none of those, `/add-car` carries no guard, and `ensureRegistered`
is not on that path. So the API migration bound a deliberately guest-accessible
feature to an authenticated endpoint.

Three consequences, worst last:

1. Every guest write answered `401`.
2. The UI claimed otherwise. `_save()` fires `add()` without `await` (deliberate
   — the screen pops on the same frame), so the failure could only surface as a
   console trace while the success snackbar said "added to your garage".
3. **The car was gone by the next launch.** `warmUp` skipped the garage for a
   guest, so nothing read it back even if it had been stored — precisely the
   failure `MockGarageService`'s own docstring warns about.

Maintenance had it too: `GarageNotifier.add` opens a book, and
`/user/vehicles/{id}/maintenance*` is behind the same `RequireAuthorization()`.

### The fix
A guest's garage lives on the device and is handed to the server at sign-in.

`SessionGarageService` / `SessionMaintenanceService` wrap the local and REST
services and pick per call: no session → device, session → API. The local half
is the same prefs-backed store the mock data source uses, deliberately — it *is*
"the device standing in for the server", and sharing the store means a car
survives switching `AK_DATA_SOURCE` instead of appearing to vanish.

The session check is strict, unlike `TokenStore.mayHaveSession()`: that one
guesses "maybe" because its callers only risk a wasted request, whereas this one
decides where a *write lands*. An unreadable keystore routes to the device — a
local write is adopted at the next sign-in; a remote write for a session that
turns out not to exist is a `401` and the user's car on the floor.

`adoptGuestData()` uploads the device's cars and books when a session starts and
drops the local copy **only after** the upload lands, so a partial failure
retries rather than loses. `AddVehicleCommand` is idempotent and honours the
client-chosen id, so re-running is harmless and each maintenance book stays
attached to its car. Ordered garage-then-maintenance: a book is filed against a
car that has to exist server-side first.

Bootstrap now warms the garage and maintenance for **everyone**, not only for a
session — they are session-routed below the repository, so a guest reads the
device. Leaving them gated was what made the just-registered car unreadable.

`add_car_screen` no longer drops a failed write on the floor: `_watchWrite`
replaces the success snackbar with a failure one. It does **not** roll the
optimistic state back — that matches the app's existing style, and yanking a row
out from under someone who has already navigated away would be its own surprise.

### Files
| File | Change |
|---|---|
| `lib/data/services/session_routed_services.dart` | **new** — `GuestDataAdopter`, `SessionGarageService`, `SessionMaintenanceService` |
| `lib/di/providers.dart` | garage/maintenance wrap local+REST on the API source; new `guestDataAdoptersProvider` |
| `lib/state/auth_state.dart` | `_adoptGuestDataThenWarm()` — hand the device's data over *before* warming from the server, or the warm-up pulls an empty garage over it |
| `lib/app/bootstrap.dart` | garage + maintenance warm-ups moved out of the `if (signedIn)` block |
| `lib/features/garage/add_car_screen.dart` | `_watchWrite` reports a failed save instead of leaving an uncaught rejection |
| `test/guest_garage_test.dart` | **new** — 6 tests: guest→device, session→API, unreadable store→device, adoption keeps ids, failed adoption keeps the local copy, empty adoption is a no-op |
| `test/data_source_switch_test.dart` | garage/maintenance now assert `Session*` rather than `startsWith('Api')`, with the reason; stale `development == mock` assertion corrected (see below) |

### Verified
- **`flutter analyze` on `lib/`: clean** apart from the one pre-existing info in
  `core/utils/contact.dart`.
- The five directly-affected files — `guest_garage`, `data_source_switch`,
  `bootstrap`, `garage`, `onboarding` — **42 passed, 0 failed**.
- **No regression, measured rather than assumed.** `garage_persistence` +
  `first_run` fail 14 tests both with the bootstrap hunk applied and with it
  reverted by hand — identical, so they are pre-existing. All 14 are
  `NetworkException: Could not reach https://localhost:7291/api/v1`, thrown by
  the catalog/shop/cars warm-ups that have always run unconditionally, against
  a config every environment of which now points at the API. Same family as the
  56 documented in the entry below.
- **A stale assertion the previous entry's work left behind, not caused by this
  change:** `data_source_switch_test` asserted
  `forEnvironment(development).dataSource == mock`, which stopped being true
  when `app_config.dart` flipped every environment to `useMockData: false`
  ("set by the user 2026-08-09 — do not change until told to"). Corrected to
  `api`, plus a new assertion that `AppConfig.forTests()` is still `mock` —
  that is what the suite actually runs on. A first stash-based baseline made
  this look like *my* regression; it reverted the whole dirty tree, not just
  this change. Re-checked against the real cause before editing.
- **Not** re-run in Chrome: the running `flutter run` is the user's own and
  needs a manual hot restart, and the browser pane would not composite frames
  for a screenshot. The 401 path is proven by unit test, not by observation.

---

## 2026-08-09 · A guest's cold start fired a dozen requests that could only 401

**Baseline:** `7cf6a5f` (working tree already dirty with the API-data-source
work). Request: diagnose a console log full of errors on start-up, then "fix
all issues" and verify in Chrome.

### The problem
Two unrelated things were in that log.

**The fatal one was server-side, not app-side.** Six endpoints answered `500
Invalid object name 'PartCategories'` — the `AKCarsMobileDb` schema had never
been created. `Program.cs` deliberately never auto-migrates SQL Server, so the
migration simply had to be run and never had been. It could not be run, either:
LocalDB is unrepairable on this machine (all 27 keys under
`HKCU\…\SQL Server\UserInstances` are missing their `DataDirectory` value, so
`sqllocaldb create` fails outright). Fixed in the **API** repo by repointing
`DefaultConnection` at `.\SQLEXPRESS` — a full SQL Server 2022 already running
and already hosting `MotorzDb` — rather than doing registry surgery on an
instance that also holds two other projects' databases. All 11 migrations then
applied: 47 tables, `PartCategories` present, 33 `CarMakes` seeded.

**The noisy one was app-side and is what this entry is really about.** The
remaining ~17 red lines were auth-gated warm-ups fired on a cold start with no
session. They were never fatal — `_optional`/`_optionalForFounder` have always
swallowed them — but every one of them could *only* answer `401` without a
token, so a guest's launch spent a dozen guaranteed-failed round trips and
buried any real error in a wall of red on the way.

### The fix
Skip the calls instead of swallowing their failures. `warmUp` now resolves
whether a session is even plausible before building the parallel batch, and
omits the auth-gated warm-ups when it is not. Same treatment for the two
auth-gated requests that sit outside `warmUp`: `fetchCurrentUser` and the
notification inbox.

The gate is **not** just "is there a token": mock mode has no token either, and
gating on that alone would have left the demo world half-built. It short-
circuits to "attempt" whenever the data source is not the API.

`_optional` stays. A *stored* token is not a *valid* one — an expired session
still answers `401`, and that still must not be fatal.

### The regression this introduced, and the second fix
Consulting the token store meant touching `flutter_secure_storage`, which has
no VM implementation and **is not mocked anywhere in the suite** — so under
`flutter test` it threw `MissingPluginException` and took `warmUp` down with
it. Caught by a before/after run: baseline 10 failures, 11 with the change.

`TokenStore.mayHaveSession()` now answers `true` when the store cannot be read
(no platform channel, a locked keystore, a keychain refusing on a restored
backup). The failure mode has to be "ask the server anyway" — guessing `false`
on an unreadable store would silently sign a real session out of its own
warm-up, while guessing `true` costs at worst the one request that was being
made before any of this existed. Back to 10 failures after.

### Files
| File | Change |
|---|---|
| `lib/app/bootstrap.dart` | `warmUp` is now `async` and gates the auth-gated warm-ups behind new `_signedIn`; doc comment rewritten to explain the three cases |
| `lib/data/services/token_store.dart` | added `mayHaveSession()` — `hasSession()` that degrades to `true` when the store is unreadable |
| `lib/data/services/api/api_auth_service.dart` | `fetchCurrentUser` returns `null` without a request when there is no session |
| `lib/state/notifications_state.dart` | `_loadFromServer` returns early when there is no session |
| `AKCarsMobileAPI/src/AKCars.Api/appsettings.json` | `DefaultConnection`: `(localdb)\MSSQLLocalDB` → `.\SQLEXPRESS` (other repo) |

### Verified
- **Guest cold start against the live API: 7 requests, all `200`, zero `401`.**
  Was 24 requests (7×`200`, 17×`401`). App boots to title "AK Cars"; browser
  console clean apart from a DWDS tooling bug in `dwds/src/injected/client.js`
  (`_JsonMap is not a subtype of List<Object?>` — a known webdev issue, not
  app code).
- API server log across a full boot: 0×`500`, 0×`Invalid object name`.
- `flutter analyze` on all four changed files — clean.
- Full `flutter test`, **with no server listening**: 460 tests, **384 passed /
  76 failed** across 13 files. 56 `NetworkException: Could not reach
  https://localhost:7291/api/v1`, 14 `TimeoutException`, and **zero
  `MissingPluginException`** — that last count is the load-bearing one, because
  it is what confirms the `mayHaveSession()` fallback holds across the whole
  suite rather than only in the files that were re-run by hand.
- **No regression, measured twice by reverting the change and re-running rather
  than assumed:** the four bootstrap-related files give 10 failures before and
  10 after; the three largest failing files (`maintenance_book`, `reviews`,
  `part_install`) give 50 before and 50 after. Each pair was run in one
  environment, so the deltas hold even though the absolute totals move with the
  API's state.
- Running the API changes the result, but only slightly: 77 failures with the
  server up against 76 with it down. `data_source_switch_test`'s network-error
  case does assert the host is *unreachable*, so a test run is only strictly
  trustworthy with the API stopped — but the API being up was **not** the
  explanation for the bulk of these failures, and an earlier note in this entry
  that implied otherwise was wrong.
- **Not** run on Android/iOS, and no screenshot: the browser pane never
  composited a frame (`document.visibilityState === "hidden"`), so rendering was
  verified structurally (glass pane mounted, title set) and by network
  behaviour, not visually.

### Known-adjacent, left alone
- **76 pre-existing failures across 13 files, overwhelmingly one root cause** —
  `maintenance_book` (30), `reviews` (10), `part_install` (10), `first_run` (8),
  `garage_persistence` (6), `operator_panels` (4), `tracking_back` (2) and six
  files with one each. 70 of the 76 die on `NetworkException`/`TimeoutException`
  from booting against the real API instead of the mock harness; the remaining
  ~6 are plain assertion failures worth looking at separately once the harness
  noise is gone. This is fallout from every environment moving to
  `useMockData: false` on 2026-08-09: `AppConfig.forTests()` exists precisely
  so the suite stays offline-safe, and these tests do not go through it.
  `data_source_switch_test`'s "explicit `AK_DATA_SOURCE` define wins" is the
  same root cause seen from the other side — it still expects `mock` to be the
  default. **This is the single highest-value follow-up in this file:** it is
  one harness fix, and it is currently hiding real regressions behind noise.
- `PartCategories` is created but **empty** — no `HasData` seed, unlike
  `CarMakes`/`Governorates`. `/products/categories` returns `{}`. Nothing 500s,
  but the shop's category UI has nothing to show.
- LocalDB is still broken and now unused by this project. `MotorzDb` and
  `ROMAPI_DEV` on that instance remain unreachable.

---

## 2026-08-05 · Workshop phone numbers were public before any booking existed

**Baseline:** `238a93d`. Request: implement
`MobileApp-Design/AK_Cars_تعليمات_منع_التسرب.md` — two layers against platform
leakage (disintermediation), then run it on a device and fix what turns up.

### The problem
Every workshop's phone and WhatsApp number were printed on the service detail
page, to anyone, before a booking existed. The whole transaction could be
agreed on WhatsApp — no escrow, no proof of work, no service record, and no
commission, which is the only revenue the pilot has. Both sides have an
incentive to do it, so it happens without anyone acting in bad faith.

The instruction file is explicit that the answer is **not** to block contact:
staying inside the app has to be *better* than leaving, and hard walls read as
a platform that distrusts its users.

### Section 1 — where contact was actually reachable (the audit)
Searched `lib/` for `tel:` / `wa.me` / `url_launcher` / any "call"/"WhatsApp"
affordance. Six sites, of which **three** are on the service path:

| # | Site | Verdict |
|---|---|---|
| 1 | `provider_details_card.dart` — the copyable **Phone** row | leaked; now gated |
| 2 | `provider_details_card.dart` — **Call** + **WhatsApp** buttons | leaked; now gated |
| 3 | `tracking_screen.dart:257` — **Call** button on a live booking | leaked while the booking was still pre-payment; now gated |
| 4 | `shop/product_detail_screen.dart` — seller card + "Ask the shop" | parts store, `AppFlags.partsStoreEnabled = false`; **out of scope**, see below |
| 5 | `cars/*` (listing card, listing detail, cars screen) | car marketplace, hidden behind `AppFlags`; explicitly untouched per the instruction file |
| 6 | `profile_screen.dart:312/329` | AK Cars' own support line, not a provider; untouched |

### Section 2 — the gate
- **New** `lib/core/utils/provider_contact.dart` —
  `canContactProviderDirectly(EscrowState?)`, the single authority. `null`
  (no booking yet) is false; `fundsHeld` → `releasedToWorkshop` are true;
  `disputed` is **deliberately true** — a customer with a problem needs the
  workshop more than anyone, and cutting them off there is where trust breaks.
  Exhaustive `switch`, so a new escrow state forces the decision here rather
  than silently defaulting.
- **New** `lib/features/services/platform_trust_widgets.dart` —
  `ContactLockedCard`, what stands in the number's place: says *why* (nothing
  agreed outside the app is covered) and opens the in-app thread.
- `ProviderDetailsCard` takes `escrow` + `onMessageProvider`; no screen
  re-derives the rule. The provider's contact fields are untouched in the
  model — only their display is governed.
- The service detail page unlocks contact when the viewer already has a
  *live booking with that same workshop* — someone whose car is on the ramp is
  not a browsing stranger. It asks the same helper for that answer.
- **New route** `/chat/provider/:providerId` + `providerThreadId()` — the
  pre-booking enquiry thread. Contact being gated is only fair if asking a
  question still works, and `ChatScreen` was per-request only, so a customer
  who had not booked had no channel at all. Same screen, keyed by workshop,
  titled "Enquiry before booking".

### Section 3 — the value reminder
`BookingValueCard` on the booking screen, between the total and the confirm
button: money held until you approve · photo proof · logged to your service
history · your review is verified. Four things the app actually does. Quiet dim
surface, no filled colour, so it never competes with the confirm button. Framed
"Why book through the app?" — never "don't deal outside it", which would put an
idea in the reader's head that was not there.

### Four bugs found while testing this
1. **The tracking screen's app bar overflowed.** Surfaced by the new test the
   moment a booking reached `fundsHeld`: `AppBar` hands its `actions` unbounded
   width, so `UrgencyLabel`'s own ellipsis never engaged and the longer state
   names ("Funds held — waiting for the workshop") ran off the edge. Bounded to
   50% of the screen; the title ellipsizes. Confirmed fixed on the device.
2. **Request ids were printed raw into customer-facing text** — the tracking
   title, the chat subtitle, the review screen, the bookings list and six
   notifications. Harmless today (`MockServiceMarketplaceService` numbers
   requests `3001`, `3002`, …) but the id is whatever the source hands over,
   and the `Api*` layer will hand over the GUIDs everything else moved to on
   2026-08-03 — at which point every one of those strings becomes
   "Request #3f2a7c1e-8b4d-4e9a-a5f0-2c6d1b7e4a93". Added `shortRef()`
   (`lib/core/utils/guid.dart`): last six hex digits, upper-cased, and a no-op
   on a short id, so it changes nothing today and cannot break tomorrow. The
   full id stays the id in routes, storage and the API.
   *This is prevention, not a live defect — recorded honestly as such.*
3. **The Oman VAT number rendered backwards in Arabic** — `OM1100047382`
   displayed as `1100047382OM` on the workshop card (seen on the device).
   `isolateNumbers` isolated only the digit run, leaving `OM` as a run of its
   own that the RTL paragraph then placed on the far side of it. The regex now
   binds a Latin prefix that *touches* the digits into the same isolate;
   `OMR 36.00` keeps its currency word outside, where it belongs. The existing
   `bidi_numbers_test` case pinned the wrong behaviour under the name "isolates
   each number separately" — it was corrected and split in two.
4. **The new enquiry thread answered as if a job were under way** — the first
   canned reply is "your car is with us — work is going well", which is fine on
   a booking's thread and nonsense to someone who has not booked. Split
   `MockChatData.enquiryReplies` out, selected by `isProviderThread()`; the
   thread-key helpers moved to `data/models/chat_message.dart` so the data
   layer can tell the two kinds of thread apart. Confirmed on the device: the
   enquiry now opens with "Welcome! Go ahead — what does your car need?".

### Files
| File | Change |
|---|---|
| `lib/core/utils/provider_contact.dart` | **new** — the one gate |
| `lib/features/services/platform_trust_widgets.dart` | **new** — `ContactLockedCard`, `BookingValueCard` |
| `lib/features/services/provider_details_card.dart` | phone row + buttons behind the gate; `escrow`/`onMessageProvider`/`gateContact` |
| `lib/features/services/service_detail_screen.dart` | passes the live booking's state; enquiry-thread action |
| `lib/features/services/tracking_screen.dart` | Call gated; locked card + full-width Chat below it; app-bar overflow + short ref |
| `lib/features/services/booking_screen.dart` | `BookingValueCard` above the confirm button |
| `lib/features/services/chat_screen.dart` | optional `providerId` — the pre-booking thread; short ref |
| `lib/core/router/app_router.dart` | `/chat/provider/:providerId` |
| `lib/core/utils/guid.dart` | `shortRef()` |
| `lib/core/utils/bidi_text.dart` | Latin prefix bound to its digits (VAT bug) |
| `lib/data/models/chat_message.dart` | `providerThreadPrefix` / `providerThreadId` / `isProviderThread` |
| `lib/data/datasources/mock/mock_chat_data.dart`, `lib/data/services/chat_service.dart` | enquiry-thread replies |
| `lib/features/services/{requests,review}_screen.dart`, `lib/data/repositories/notification_repository.dart` | short ref in customer-facing text |
| `lib/features/shop/product_detail_screen.dart` | explicit `gateContact: false` + why |
| `test/contact_gating_test.dart` | **new** — 8 tests |
| `test/bidi_numbers_test.dart` | VAT case corrected + currency-word case added |

### Verified
- `flutter analyze lib test` — clean (the one remaining info,
  `use_null_aware_elements` in `contact.dart:23`, is pre-existing).
- `flutter test` — 460 passed (450 before; 8 new + 2 from the split bidi case).
- **On the device** — Galaxy S23 (`R5CWA25GD7N`), Arabic, debug build,
  walked by hand over adb: services → صيانة شاملة → ورشة النور. The workshop
  card shows hours, VAT and CR and **no phone row, no Call, no WhatsApp**; the
  explainer card and "راسل الورشة" sit in their place. The enquiry thread opens
  titled "ورشة النور / استفسار قبل الحجز" and a sent message gets an
  enquiry-appropriate reply. The booking screen shows the value card as a quiet
  block above the confirm button. Confirming the booking lands on tracking,
  where the staging lifecycle takes it to `fundsHeld` and **Call appears** —
  the unlock side of the gate, on real hardware, with no app-bar overflow.
- **Not** verified on the device: the *locked* state of the tracking screen
  (the build's `simulateProviderLifecycle` advances past it too quickly to
  catch by hand) — that path is covered by
  `test/contact_gating_test.dart`. Nothing was checked in English or in dark
  mode on hardware; both are covered only by widget tests.

### Deliberately not done
- **The parts store keeps its contact buttons.** The instruction file scopes
  this to the services/booking path, and a catalogue purchase has no booking,
  no escrow state and no thread to fall back to — gating it would leave a
  hidden phase-2 flow with no way to ask a question at all. It is marked at the
  call site. Worth knowing that it *is* a hole if the store ever ships: the
  same workshops sell parts, so their numbers would be reachable from there.
- No leakage *detection*, no automatic penalties, no suspensions — the
  instruction file forbids all three, and they are the wrong instrument anyway.

---

## 2026-08-04 · Login flow — the app previously had registration only

**Baseline:** `1e17d34`. User request: the app had one screen
(`register_screen.dart`) that doubled as both sign-up and "my details", and
no way back into an account once signed out — a returning user had to
register again. Added a proper login flow and a welcome gate that lets a
guest choose between the two instead of always landing on the registration
form.

### What changed

- **`AuthService`/`AuthRepository`/`AuthNotifier`** gained `findAccount(
  identifier)` (looks an account up by phone or email, null if none) and
  `login(identifier, code)` (verifies the OTP and starts the session).
  `MockAuthService` had to stop treating "sign out" as "delete the account" —
  it previously called `prefs.remove(prefsProfile)` on sign-out, which meant
  there was nothing left to log back into. Sign-out now only flips a new
  `prefsSessionActive` flag off; the account record survives, the same way a
  real backend keeps it in its database (`lib/data/services/auth_service.dart`,
  `lib/core/constants/app_constants.dart`).
- **`ApiAuthService`** grew matching `POST /auth/login` (send code) /
  `POST /auth/login/verify` (verify + start session) calls; documented in
  `docs/api_contract.md`. Still unimplemented behind `UnconfiguredApiClient`,
  same as the rest of the `Api*` layer — this is the REST contract, not a
  working backend call.
- **`lib/features/auth/login_screen.dart`** (new) — phone-or-email field →
  OTP (reusing the same staging code `7391` the register screen shows) →
  session starts with the profile exactly as it was registered, `kind` and
  all, so what the rest of the app shows a workshop vs. a customer account
  is unchanged by this work.
- **`lib/features/auth/auth_gate_screen.dart`** (new) — "I have an account"
  / "New here" choice screen. Every entry point that used to jump straight
  to `/register` for a guest (`ensureRegistered` in `app_router.dart`, the
  profile hub's identity card, "Complete your details" row, and the amber
  registration prompt) now opens this instead; an *already-registered*
  account editing its own details still goes straight to `/register` as
  before — the gate is only for guests.
- **`lib/features/auth/auth_form_widgets.dart`** (new) — extracted
  `register_screen.dart`'s field/notice/OTP widgets (`_FieldRow`,
  `_NoticeCard`, `_FieldShell`, `_SectionLabel`, `_OtpBlock`) into shared
  `Auth*` widgets so login, register, and the gate render as one visual
  family instead of three independently-styled forms. `register_screen.dart`
  now imports these instead of defining its own copies, and gained an
  "Already have an account? Log in" link at the top (new-registration mode
  only — hidden while editing an existing profile).

**Left alone:** the OTP itself is still a client-side staging comparison
(`_stagingCode`), same weakness `register_screen.dart` already had — `login`
threads a `code` parameter through to the service layer so a real backend has
somewhere to verify it, but neither mock implementation actually checks it
server-side. Not this pass's scope to fix.

**Verified:** `flutter analyze` (0 issues), `flutter test` (450/450 passing,
including the pre-existing register-screen and profile-screen suites, which
would have caught a routing regression).

### 2026-08-04 follow-up — on-device test on a real Android phone (adb)

The Chrome-based visual check above never actually ran (screenshots
wouldn't composite). Ran the app for real via `flutter run -d <deviceId>`
on a connected Samsung S918B and drove it end-to-end with `adb shell input`
+ `adb exec-out screencap`, in Arabic/RTL, since that's the device's
configured language: signed out → gate screen → registered a fresh account
("Test User", Muscat, phone OTP) → signed out → logged back in with the
same phone number → OTP `7391` → landed back on the profile with the same
name, region, and verified badge intact. The account-persistence rework
above ([`prefsSessionActive`] surviving sign-out) is what made this loop
possible at all — confirmed working, not just compiling.

Found and fixed two real issues surfaced by that run:

- **Phone number reordered under RTL on the profile identity card** —
  "+968 9200 1234" rendered as "1234 9200 968+". `profile_screen.dart`'s `_IdentityCard`
  rendered `profile.phone` as plain RTL-context text with no direction
  override, same class of bug the register form already guards against on
  its own phone field (`forceLtr`) — this one card was missed. Wrapped it in
  `Directionality(textDirection: TextDirection.ltr, ...)`, matching that
  existing fix.
- **`AuthGateScreen` centered its content in the remaining vertical space**,
  which on a tall phone (3088px) left a wall of empty space above the back
  button before anything else appeared — read as a broken/half-loaded
  screen on first look. Changed from `Center` to anchoring the column a
  fixed distance below the back button (`AppSpacing.xxl`), same top-loaded
  pattern `start_choice_screen.dart` already uses elsewhere in onboarding.

Considered and rejected as a fix: a suspected duplicate "Send the code"
button on the login screen (inline OTP-block button + bottom primary
button both reading "إرسال الرمز"). Checked the actual code —
`login_screen.dart` only renders `AuthOtpBlock` once `_otpSent` is already
true, so the inline button never coexists with the bottom one; the
duplication that's visible in screenshots is on `register_screen.dart`
(pre-existing app behavior, `_submitLabel`'s workshop-path branch), not
something this change touched or introduced.

**Verified:** `flutter analyze` (0 issues) and `flutter test` (450/450) again
after the two fixes; re-ran the same sign-out → gate → login sequence on the
device to confirm the phone number and gate-screen layout render correctly
post-fix.

### 2026-08-04 second follow-up — explicit phone/email choice on login

User request: the login identifier field guessed phone vs. email from an
`@` in what was typed, with no real validation of either shape — a
half-typed phone number just looked like neither until enough digits went
in. Replaced the single guessing field with the same explicit picker the
register screen already uses for its OTP channel (`_ChannelCard`,
`AuthChannel.phone`/`.email`): two cards, one active field with the shape
and validation that matches whichever is selected.

Extracted `register_screen.dart`'s private `_ChannelCard` and
`_OmanMobileFormatter` into `auth_form_widgets.dart` as public
`AuthChannelCard` and `OmanMobileFormatter`, plus a new `AuthPhone` helper
(`digits`/`local`/`grouped`/`full`) replacing the register screen's private
`_digits`/`_local`/`_grouped` statics — same rationale as the first pass's
`AuthFieldRow`/`AuthOtpBlock` extraction: login now needs the identical
Oman-phone formatting and channel-card UI, and duplicating ~120 lines of
near-identical formatter/widget code across two files was the wrong call.
`register_screen.dart`'s own `OtpChannel` enum was replaced by the shared
`AuthChannel` throughout (`sed`-style token rename), its behavior
unchanged — verified by the full test suite before and after.

`login_screen.dart`: added `_phone`/`_email` controllers (phone using
`OmanMobileFormatter` + `+968` prefix, matching the register screen's field
exactly), a `_channel` selector defaulting to phone, and real validation —
`_phoneError` (8 Oman-local digits, must start with 7/9) and `_emailError`
(regex shape check) — surfaced inline under the active field, same as
every other form in this app. Switching channels clears the other
channel's error and voids any OTP already sent (a code proves the address
it was sent to, not the other one) — mirrors `register_screen.dart`'s
`_switchChannel`.

**Verified on-device (adb, same S918B):** typed `123` on the phone channel
→ "رقم عُماني من 8 أرقام" inline error; switched to email, typed
`notanemail` → "صيغة بريد غير صحيحة"; switched back to phone (value
persisted, as it should — only the OTP state resets on switch, not the
other channel's typed value), entered the real registered number, code
sent to the correctly-formatted "+968 9200 1234", verified with `7391`,
landed back on the profile. `flutter analyze` (0 issues) and
`flutter test` (450/450) both clean after the refactor.

---

## 2026-08-03 · Performance review — carousel opacity and image caching

**Baseline:** `00df6e1`. Follows the static-only review in
`AK_Cars_تعليمات_مراجعة_الأداء.md` (checked against
[docs.flutter.dev/perf/best-practices](https://docs.flutter.dev/perf/best-practices)),
not a DevTools/Performance-view session — that's a separate, later step.

### §1 — animated `Opacity` on scroll-linked carousels

Three call sites recomputed `Opacity` every frame of a drag, each wrapping a
composited, multi-widget subtree (so every frame paid for a `saveLayer`):

- `HomeOffersRail`'s `_DiscountCard` (`lib/features/home/home_widgets.dart`,
  the "this week's offers" carousel).
- `HomeAnnouncementsRail`'s `_AnnouncementCard` (same file — same pattern,
  found during the §4 sweep, not named in the brief but matching it exactly).
- `_SlideView` on the onboarding tour (`lib/features/onboarding/onboarding_screen.dart`).

None of the three have a transparent image layered over other content, so
none needed `Opacity`/`ColorFiltered` at all — the fade now applies straight
to each leaf's own colour (`Color.withValues(alpha: ...)`):

- The two carousel cards are a gradient-background `Container` + opaque text/
  pills with no image; `fade` is now a parameter threaded into the gradient
  colours and the border colour instead of wrapping the card.
- The onboarding slide is a `Column` of three independent widgets (icon tile,
  title, body) with no single background to fade; `opacity` is now applied to
  each one directly — the icon tile's surface/border/shadow/icon colours, and
  the two `Text` colours — rather than to the `Column` as a whole.

Visual result is unchanged (same interpolation curve, same 0–1 range); the
difference is zero `saveLayer` calls during the drag instead of one per frame
per visible card.

**Left alone, per the brief:** `Opacity` in `booking_screen.dart:475`,
`shop_screen.dart:871`, `shop_filter_sheet.dart:452`, `register_screen.dart:1448`,
`post_ad_screen.dart:289`, `add_car_screen.dart:783`, and
`cars_filter_screen.dart:1043,1135` — all fixed `enabled ? 1 : 0.4x` values,
not tied to scroll/animation state.

### §2 — image caching

`lib/core/widgets/car_media.dart` was the only file using `Image.network`
(confirmed by project-wide search — nothing else to extend this to). Both call
sites (`MakeLogo`, `CarImage`) now use `CachedNetworkImage` from the newly
added `cached_network_image: ^3.4.1` (`pubspec.yaml`), with the same
placeholder/error fallback behaviour as before (`_Monogram` / `_artwork` show
while loading and on failure) — Flutter's default cache is memory-only and
never survives an app restart, so every car/logo image was refetched from the
network on every cold start.

### §3 — technical debt noted, not fixed (as instructed)

> تبويبا "دفتر المستحقات" و"سجل التدقيق" في `admin_screen.dart` يبنيان
> قوائمهما بشكل غير كسول (`for` داخل `Column`). مقبول بحجم بيانات التجريبي
> الحالي؛ يجب التحويل إلى `ListView.builder` قبل الانتقال للإنتاج الفعلي،
> لأن هذين التبويبين تحديداً يتراكمان بلا حد أقصى مع الوقت (كل معاملة، كل
> قرار اعتماد). طابور الورشة النشط أقل إلحاحاً (محدود بالطلبات الجارية).

No code touched for this item.

### §4 — supplementary sweep

- Searched for other `Opacity(` sites reading a drag/animation-derived
  variable (`_page`, `.value`, scroll offset) — found the announcements-rail
  carousel above; everything else is the static list in §1.
- Searched for `Image.network` outside `car_media.dart` — none found.

### Files
| File | Change |
|---|---|
| `pubspec.yaml` | added `cached_network_image: ^3.4.1` |
| `lib/core/widgets/car_media.dart` | `Image.network` → `CachedNetworkImage` in `MakeLogo`/`CarImage` |
| `lib/features/home/home_widgets.dart` | `_DiscountCard`/`_AnnouncementCard` take a `fade` param applied to gradient/border colours; carousels no longer wrap cards in `Opacity` |
| `lib/features/onboarding/onboarding_screen.dart` | `_SlideView`/`_IconTile` apply `opacity` per-colour instead of wrapping the slide in `Opacity` |
| `EDIT_LOG.md` | this entry, plus the §3 technical-debt note |

### Verified
- `flutter analyze lib test` — clean (the one pre-existing info,
  `use_null_aware_elements` in `lib/core/utils/contact.dart:23`, is unrelated).
- `flutter test` — 450 passed.
- **Not** run through DevTools/Performance view — this pass is static-code-only,
  per the brief. Field verification (frame-timeline capture on the offers rail
  during a drag) is a separate follow-up.

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
