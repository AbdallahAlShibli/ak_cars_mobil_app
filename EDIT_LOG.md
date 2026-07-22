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
