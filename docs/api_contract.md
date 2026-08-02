# AK Cars — API contract

The endpoints the mobile app calls, what it sends, and what it expects back.

Written from the client side: every route below has an `Api*` implementation in
`lib/data/services/api/` that calls it, and a `Mock*` implementation that stands
in for it. **The two must be interchangeable** — same shapes, same failure
types, same error codes — because `lib/di/providers.dart` swaps between them on
one config value and nothing above the service layer knows which is bound.

- Base URL: `AppConfig.apiBaseUrl` (`/api`, no trailing slash).
- Paths: `lib/core/constants/api_endpoints.dart` is the authority. Nothing
  hard-codes a path outside that file.
- Auth: bearer token on every route except `/auth/*`.
- Language: bilingual content is a `{ "ar": "…", "en": "…" }` object, **not**
  resolved server-side from `Accept-Language`. A notification has to render in
  whichever language is active when it is read, not the one active when it was
  written.

## Switching the app over

```bash
flutter run --dart-define=AK_DATA_SOURCE=api
```

Acceptance behaviour: the app **boots** and the first request **fails with a
clear network error naming the base URL**. It must not silently fall back to
demo data — an app that looks healthy while talking to nothing is the failure
mode this switch exists to make impossible. `AK_DATA_SOURCE=mock` (the default)
runs the whole app offline against `MockSeed`.

This build ships `UnconfiguredApiClient`, which throws `NetworkException` on
every call because no HTTP package is wired in yet. Phase 2 replaces that one
class; no service, repository, provider or screen changes.

## Errors

Both data sources raise the same types from `lib/core/error/app_exception.dart`.
HTTP status maps as follows:

| Status | Exception |
|---|---|
| transport failure | `NetworkException` |
| timeout | `RequestTimeoutException` |
| 400 / 422 | `ValidationException`, or `BusinessRuleException` when the body carries a `code` |
| 401 | `UnauthorizedException` |
| 403 | `ForbiddenException` |
| 404 | `NotFoundException` |
| other non-2xx | `ApiException` |

Business-rule rejections carry a stable `code` that both paths use verbatim:

| Code | Meaning |
|---|---|
| `escrow_transition_not_allowed` | the actor may not fire that event from that state |
| `proof_missing_part_box_photo` | a part-and-fit job submitted proof without the part's box |
| `quote_not_allowed` | quoted a booking that is not at `requested` |
| `workshop_not_approved` | booked a workshop whose stage is not `approved` |
| `provider_rejection_reason_required` | suspended or rejected a workshop with no written reason |
| `review_already_exists` | second review for the same `(bookingId, direction)` |
| `review_rating_out_of_range` | rating outside 1–5 |

---

## Auth

### `POST /auth/register`

**One endpoint for both account kinds.** The body is `UserProfile.toJson()`; a
workshop account differs only in carrying `kind: "workshop"` and a `workshop`
object. There is deliberately no second registration endpoint — it is the same
account, the same verification, and the same validation, and a parallel route
would be a parallel copy of all three.

```jsonc
{
  "name": "Salim Al Hinai",
  "phone": "+968 9200 1234",
  "email": "salim@example.om",
  "region": "Muscat",          // canonical English governorate key
  "wilayat": "Seeb",
  "address": "Al Khuwair, street 12",
  "kind": "customer",          // or "workshop"

  // Present only when kind == "workshop". Omitted entirely otherwise.
  "workshop": {
    "businessNameAr": "ورشة النور",
    "businessNameEn": "Al Noor Workshop",   // optional
    "crNumber": "1198432",                   // 6–10 digits
    "vatNumber": "OM1100047382",             // optional — not every workshop is VAT registered
    "crDocumentUrl": "https://…/cr.pdf",
    "area": "Al Khuwair",                    // canonical English key, LocationCatalog
    "fulfillments": ["workshop", "pickup"],
    "submittedAt": "2026-08-01T09:14:00Z"
  }
}
```

→ `201` with the stored `UserProfile` (server assigns `id`).

Registering with `kind: "workshop"` **grants nothing**. The account is created,
and the application is filed separately (below). The client calls both as one
operation; a server that wants to do it in one transaction may key the
application off this body instead.

### `GET /user/profile` · `PUT /user/profile` · `POST /auth/logout`

`GET` returns `401` when nobody is signed in; the client reads that as "no
session" rather than as an error.

---

## Workshop onboarding

### `POST /service-marketplace/applications`

Files (or re-files) a workshop registration.

```jsonc
{
  "ownerUserId": "u-1042",
  "region": "Muscat",
  // …then every field of the `workshop` object above, flattened.
  "businessNameAr": "ورشة النور",
  "crNumber": "1198432",
  "crDocumentUrl": "https://…/cr.pdf",
  "area": "Al Khuwair",
  "fulfillments": ["workshop"],
  "submittedAt": "2026-08-01T09:14:00Z"
}
```

→ `201` with a `ServiceProvider` at **`stage: "documentsSubmitted"`** — not
`applied`, because the certificate was attached in the same step.

Re-posting for an `ownerUserId` that already has a workshop **updates that
workshop** rather than creating a second one, and puts it back to
`documentsSubmitted`. That is what makes "fix it and re-submit" work after a
rejection without filling the founder's queue with duplicates.

From this moment the workshop is invisible: it is excluded from every
customer-facing query, and `POST /service-marketplace/requests` against it
returns `422 workshop_not_approved`.

### `PATCH /service-marketplace/providers/{id}/stage`

The founder's decision.

```jsonc
{ "stage": "approved" }
{ "stage": "suspended", "reason": "صورة السجل التجاري غير واضحة" }
```

`reason` is **required** for `suspended` — a rejection with no sentence after it
is not something the owner can act on. Omitting it returns
`422 provider_rejection_reason_required`.

Moving off `suspended` clears the stored reason, so a re-approved workshop stops
showing its owner why it was once rejected.

Both transitions write an audit entry.

### `ServiceProvider` stages

`applied` → `documentsSubmitted` → `verified` → `approved`, with `suspended`
reachable from any of them. Only `approved` grants anything:

- visible to customers (listings, search, offers, leaderboards);
- may take bookings;
- may open `/workshop`, re-checked on **every** entry, not once per session.

`isApproved` remains on the wire for older clients, derived from `stage`.

---

## Service marketplace

### Catalogue (all `GET`, all cacheable)

| Path | Returns |
|---|---|
| `/service-marketplace/categories` | `ServiceCategory[]` |
| `/service-marketplace/providers` | `ServiceProvider[]` |
| `/service-marketplace/offerings?categoryId=` | `ServiceOffering[]` |
| `/service-marketplace/offerings/{id}` | `ServiceOffering` |
| `/service-marketplace/promotions` | `Promotion[]` |
| `/service-marketplace/offers` | `Offer[]` — approved and in-window only |
| `/service-marketplace/category-demand` | `CategoryDemand[]` |
| `/service-marketplace/workshop-demand` | `WorkshopDemand[]` |
| `/service-marketplace/ratings` | `WorkshopRating[]` — only rated workshops appear; **no entry means no rating**, never a zero |
| `/service-marketplace/providers/{id}/add-ons` | `AddOn[]` |
| `/service-marketplace/providers/{id}/slots?date=` | `{ slots: string[], bookedSlots: string[] }` |

`/providers` returns the **whole roster** including pending applications: it
feeds the founder's pipeline. Customer-facing filtering by `stage` happens in
`ServiceMarketplaceRepository`, and the server should apply the same rule for
any client that cannot be trusted to.

### Bookings

| Path | Purpose |
|---|---|
| `POST /service-marketplace/requests` | place a catalogue booking |
| `POST /service-marketplace/part-requests` | open a part + installation request (starts with no price) |
| `POST /service-marketplace/requests/{id}/quote` | the workshop's itemised quote |
| `GET /service-marketplace/requests` | **the signed-in user's own** bookings |
| `GET /service-marketplace/operator/requests` | **every** booking — operator panels only |
| `POST /service-marketplace/requests/{id}/status` | fire one escrow transition |

The last two are separate endpoints rather than one filtered route because they
are authorised differently. Merging them would put strangers' bookings in a
customer's own list.

```jsonc
// POST …/requests/{id}/status
{
  "event": "approve",
  "actor": "customer",
  "proof": { … },          // submitProof only
  "disputeNote": "…",      // raiseIssue only
  "slot": "10:30"          // optional reschedule
}
```

The transition table in `lib/data/models/escrow.dart` is enforced **server-side
as well**. An illegal `(state, event, actor)` returns
`422 escrow_transition_not_allowed`; a part-and-fit job submitting proof without
the part's box returns `422 proof_missing_part_box_photo`.

### Money and audit

| Path | Purpose |
|---|---|
| `GET /service-marketplace/payouts` | `PayoutRecord[]` |
| `POST /service-marketplace/payouts` | record a transfer the founder made **by hand** |
| `GET /service-marketplace/audit` | `AuditEntry[]`, newest first |
| `POST /service-marketplace/audit` | append one line |

**Nothing here moves money.** A `PayoutRecord` is a note that a bank transfer
happened outside the app. There is no payment gateway in this phase.

Audit lines are written from exactly one place in the client
(`ServiceMarketplaceRepositoryImpl._audit`) and cover four subjects: `booking`,
`provider`, `offer`, `payout`. A server that writes its own audit rows should
treat the client's `POST` as idempotent on `(action, subjectId, at)`.

---

## Reviews

| Path | Purpose |
|---|---|
| `GET /reviews` | reviews visible to this user |
| `POST /reviews` | write one |
| `PATCH /reviews/{id}` | correct one inside the edit window |
| `GET /service-marketplace/providers/{id}/reviews` | one workshop's reviews |

Two rules the **server owns**, and they are the whole verification mechanism:

1. a review may only be created against a booking that reached
   `releasedToWorkshop`;
2. `(bookingId, direction)` is unique — enforce it with a database constraint.

There is no delete. A review that can be withdrawn on demand is a review a
workshop can pressure someone into withdrawing.

---

## Garage and maintenance

| Path | Purpose |
|---|---|
| `GET/POST /user/vehicles` | the user's cars |
| `PUT/PATCH/DELETE /user/vehicles/{id}` | update or remove one |
| `GET /user/vehicles/maintenance` | every maintenance book, keyed by `carId` |
| `POST/DELETE /user/vehicles/{carId}/maintenance` | create (idempotent) or remove a book |
| `PUT /user/vehicles/{carId}/maintenance/odometer` | `{ "km": 78400 }` |
| `POST/PUT/DELETE …/maintenance/records[/{recordId}]` | service history; `POST` upserts by id |
| `PUT …/maintenance/intervals/{itemKey}` | `{ "km": 10000 }` or `{ "months": 6 }`; **null clears the override** |
| `POST/DELETE …/maintenance/items[/{itemId}]` | the owner's own extra lines |

Every maintenance write answers with the **whole book**, never with the patch it
applied — a client that reconstructs a book from patches is a client that can
disagree with the server about a car's history.

`POST …/records` upserting by id is what makes a repeated
booking-completion event harmless.
