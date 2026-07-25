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
