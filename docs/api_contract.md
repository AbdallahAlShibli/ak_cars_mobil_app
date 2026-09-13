# AK Cars — API contract (v1, production)

The endpoints the mobile app calls, what it sends, and what it expects back.

Written from the client side: every route below has — or is scheduled to have —
an `Api*` implementation in `lib/data/services/api/` that calls it, and a
`Mock*` implementation that stands in for it. **The two must be
interchangeable** — same shapes, same failure types, same error codes — because
`lib/di/providers.dart` swaps between them on one config value and nothing above
the service layer knows which is bound.

The backend is the ASP.NET Core project at `C:\Projects\Cars Project\
AKCarsMobileAPI`, built as Clean Architecture + CQRS. This document is the
boundary between the two; `docs/backend_build_order.md` says how each route is
assembled on that side, and `docs/flutter_production_migration.md` says what
changes on this one.

## Ground rules

- **Base URL:** `AppConfig.apiBaseUrl`, ending `/api/v1`. Versioning is in the
  path from day one — a URL-versioned API can serve an old build and a new one
  from the same host, which is the only way to ship a breaking change to an app
  that lives on phones you do not control.
- **Transport:** HTTPS only. HTTP is not redirected, it is refused.
- **Paths:** `lib/core/constants/api_endpoints.dart` is the authority. Nothing
  hard-codes a path outside that file — see [Path drift](#path-drift) for what
  currently breaks that rule and has to be fixed as part of this migration.
- **Auth:** JWT bearer on every route except `/auth/login`,
  `/auth/login/verify`, `/auth/register` and `/auth/refresh`.
- **Language:** bilingual content is a `{ "ar": "…", "en": "…" }` object,
  **not** resolved server-side from `Accept-Language`. A notification has to
  render in whichever language is active when it is read, not the one active
  when it was written. A bare string is accepted on read and fills both fields.
- **Dates:** ISO-8601 UTC (`2026-08-01T09:14:00Z`). The one exception is the
  `?date=` slot query, a bare `YYYY-MM-DD`.
- **Files:** base64 on the record, never a URL. See [Attachments](#attachments).
- **Casing:** the client sends and reads camelCase. Configure
  `JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase` and
  do not rely on the default `[JsonPropertyName]` per DTO.

### Response envelope

There is none. `ApiClient.get`/`post`/… return a bare JSON **object**;
`getList` returns a bare JSON **array**. Wrapping either in
`{ "data": …, "success": true }` breaks every parse in
`lib/data/services/api/`. Errors are the exception — they are `ProblemDetails`,
below.

Routes that answer with an array: every catalogue `GET`,
`/service-marketplace/requests`, `/operator/requests`, `/payouts`, `/audit`,
`/reviews`, `/user/vehicles`, `/user/vehicles/maintenance`, `/notifications`,
`/notifications/read`, `/chat/threads/{id}/messages`.

---

## Scope

Phase 2 took eight services to production; a follow-on pass added the four
below (catalogue, cars marketplace, shop, orders) once the backend implemented
them end-to-end.

**Since 2026-08-10 every one of these is the only implementation there is.**
The offline `Mock*` services and the seeded world behind them were deleted from
`lib/` and now exist only as test doubles under `test/fakes/`, so an endpoint
listed here that is missing or broken shows up as a `NetworkException` on the
screen that needed it — not as plausible-looking demo data.

| Area | Service | Status |
|---|---|---|
| Auth / profile | `ApiAuthService` | ✅ written |
| Garage (saved cars) | `ApiGarageService` | ✅ written |
| Maintenance books | `ApiMaintenanceService` | ✅ written |
| Service marketplace | `ApiServiceMarketplaceService` | ✅ written |
| Reviews | `ApiReviewService` | ✅ written |
| Notifications | `ApiNotificationService` | ✅ written |
| Chat | `ApiChatService` | ✅ written |
| Challenges | `ApiChallengeService` | ✅ written |
| Vehicle catalogue (makes, trims, spec options, locations) | `ApiCatalogService` | ✅ written — `fetchServiceRegions` stays a client-side constant, see its doc comment; no backend concept of "operating regions" exists yet |
| Cars marketplace (listings, my-ads) | `ApiCarsService` | ✅ written — read-only; the interface has no publish/edit/delete method yet, so `POST`/`PUT`/`DELETE /cars/my-ads` are unused by this client |
| Shop (products, cart) | `ApiShopService` | ✅ written — `Product`/`PartCategory` are not seeded server-side yet, so `/products` and `/products/categories` return empty collections against a fresh database |
| Orders | `ApiOrderService` | ✅ written — `updateStatus` (store-side progression) has no backing endpoint and is a client-side no-op; see its doc comment. No payment gateway in this phase — `POST /payments` is not mapped server-side and this client never calls it |

`ApiEndpoints` declares `/cart` and `/payments` too: `/cart` is not yet
consumed by any `Api*` service (no cart-service interface exists in the app
yet), and `/payments` is intentionally unmapped on the backend — both remain
naming reservations for now.

### Not backed by any endpoint, by design

The Settings screen's **"Operating mode" / "وضع التشغيل"** section
(`lib/features/settings/settings_screen.dart`) switches the app between
customer, workshop and founder shells for demonstration. It is **trial-mode
plumbing**: local state only, no route, no field, no persistence. Real role
authorisation comes from the JWT's claims and the workshop's `stage` — never
from this switch. Before the production build ships, this section should be
hidden behind `kDebugMode` or removed; leaving a shell-switcher in a signed
release is a privilege-escalation button with a nice label on it.

`AppConfig.simulateProviderLifecycle` — the timer that walked a demo booking
through its states — was removed on 2026-08-10 along with the rest of the demo
plumbing. The backend owns those transitions; the app only reflects them.

---

## Who assigns ids

Most ids are the client's; some are not, and the difference matters. A server
that guesses wrong either loses the client's local reference to a record it just
sent, or silently creates duplicates.

**Client-generated (GUID v4, lowercase hyphenated).** The `POST` body arrives
*with* its `id` and the server stores it unchanged. This is what lets a record
be composed offline and uploaded intact.

`MediaAttachment` · `Review` · `Quote` · `ProofOfWork` · `PayoutRecord` ·
`AuditEntry` · `Car` (garage) · `ServiceRecord` · `CustomMaintenanceItem`

Store these as `uniqueidentifier` primary keys with **no** identity/default —
`ValueGeneratedNever()` in EF Core. A re-`POST` of an id that already exists is
an upsert where this contract says so, and a `409` where it does not.

**Server-assigned.** The client posts a DTO with no id and reads the id off the
response:

| Record | Posted as | Server assigns |
|---|---|---|
| `UserProfile` | `POST /auth/register` — `id` is present but **null** | `id` |
| `ServiceRequest` | `CreateServiceRequestDraft` / `CreatePartRequestDraft` — ids only | `id`, `total`, initial `escrow`, `createdAt` |
| `ServiceProvider` | `POST /service-marketplace/applications` | `id`, `stage`, `stageSince` |
| `AppNotification` | *never posted* — the server raises them | everything |
| `ChatMessage` | `POST …/messages` — text only | `id`, `time`, `fromUser` |

`UserProfile.toJson()` always emits the `id` key, holding `null` on a first
registration. The server must accept a null `id` on that route rather than
rejecting the body.

---

## Attachments

Anything a user uploads is an attachment object, inline on the record that
owns it:

```jsonc
{
  "id": "8c2f1a04-6d3b-4e17-9f52-0ab7c9d41e63",  // GUID, client-generated
  "base64Data": "iVBORw0KGgoAAAANSUhEUg…",        // the bytes, no `data:` prefix
  "mimeType": "image/jpeg",                        // authoritative: the client
                                                   // renders on this alone
  "fileName": "proof-1.jpg",
  "caption": "الفلتر القديم"                       // optional, user-authored
}
```

There is no upload endpoint and no file URL anywhere in this contract. The
client encodes at capture and sends the bytes with the record; the server
stores them in the column beside the row and returns them the same way.

- `base64Data` carries **no** `data:` prefix. The client tolerates one on read
  but never writes one.
- `mimeType` defaults to `application/octet-stream` if the server omits it,
  which renders as a generic document — so send it.
- The client refuses to attach a file over **4 MB** before encoding, and
  downscales camera captures to 1600px. Set Kestrel's
  `MaxRequestBodySize` above that (8 MB is a reasonable ceiling) and reject with
  `413` rather than truncating — a truncated attachment decodes to a broken
  image on the screen where a customer releases money.
- An attachment with an empty `base64Data` is treated as *absent*, not as
  evidence. Do not return placeholder attachments.
- Store as `varbinary(max)` and base64 at the DTO boundary, not as an
  `nvarchar` column holding base64. The column is bytes; base64 is a transport
  encoding.

---

## Errors — RFC 9457 `ProblemDetails`

Every non-2xx answer is `application/problem+json`, produced by a global
`IExceptionHandler` with `AddProblemDetails()`. No route hand-rolls an error
body.

```jsonc
{
  "type": "https://api.akcars.om/errors/escrow-transition-not-allowed",
  "title": "Escrow transition not allowed",
  "status": 422,
  "detail": "A customer may not fire 'approve' from 'inProgress'.",
  "instance": "/api/v1/service-marketplace/requests/…/status",
  "code": "escrow_transition_not_allowed",   // ← extension member, see below
  "traceId": "00-b7ad…-01"
}
```

**`code` is an extension member and it is the part the client switches on.**
`type`, `title` and `detail` are for humans and logs; the app never parses them.
A `ProblemDetails` without `code` on a 400/422 degrades to a generic
`ValidationException`, which shows the user "something was wrong with that" and
nothing more.

Field-level validation (FluentValidation) uses `ValidationProblemDetails`, whose
`errors` dictionary maps onto `ValidationException.fieldErrors`:

```jsonc
{ "status": 400, "code": "validation_failed",
  "errors": { "crNumber": ["Must be 6–10 digits"] } }
```

### Status → exception

Both data sources raise the same types from `lib/core/error/app_exception.dart`:

| Status | Exception |
|---|---|
| transport failure | `NetworkException` |
| timeout | `RequestTimeoutException` |
| 400 / 422 | `ValidationException`, or `BusinessRuleException` when the body carries a `code` |
| 401 | `UnauthorizedException` |
| 403 | `ForbiddenException` |
| 404 | `NotFoundException` |
| 409 | `BusinessRuleException` when the body carries a `code`, else `ApiException` |
| other non-2xx | `ApiException` (carries `statusCode`, `errorCode`, `details`) |

A `409` with a code is a business rule like any other: the server refused
because of a stable, documented condition, not because the request was
malformed. Leaving it in the `ApiException` catch-all made "that phone is
already registered" indistinguishable from a `500` at the call site, so the only
thing a screen could do with it was fail.

### Business-rule codes

Stable, `lower_snake_case`, used verbatim by both paths. They are a public part
of the contract: renaming one is a breaking change.

| Code | Meaning |
|---|---|
| `account_already_exists` | registered a phone or email that is already on an account (`409`) |
| `escrow_transition_not_allowed` | the actor may not fire that event from that state |
| `proof_missing_part_box_photo` | a part-and-fit job submitted proof without the part's box |
| `quote_not_allowed` | quoted a booking that is not at `requested` |
| `workshop_not_approved` | booked a workshop whose stage is not `approved` |
| `provider_rejection_reason_required` | suspended or rejected a workshop with no written reason |
| `review_already_exists` | second review for the same `(bookingId, direction)` |
| `review_rating_out_of_range` | rating outside 1–5 |
| `review_booking_not_released` | reviewed a booking that never reached `releasedToWorkshop` |
| `review_edit_window_closed` | edited a review after the window shut |
| `challenge_incomplete` | completed a challenge with steps still open |
| `chat_thread_not_participant` | read or posted to a thread the caller is not in |
| `workshop_not_owned` | a `/my-workshop/*` route called by a user who owns no `ServiceProvider` |
| `staff_permission_denied` | a `technician`/`receptionist` staff account attempted an owner/manager-only write |
| `offering_has_open_bookings` | deleted an offering that a non-terminal booking still references |
| `inventory_insufficient_stock` | a `consumed` movement would take `quantityOnHand` below 0 |
| `inventory_item_in_use` | deleted an inventory item referenced by a booking's parts |
| `staff_not_found` | assigned a booking to a staff id that isn't this workshop's, or isn't active |
| `schedule_slot_conflict` | working-hours edit would orphan an already-booked slot |
| `customer_not_a_client` | requested a customer detail/note for a user with no booking at this workshop |

> ⚠️ `MockChallengeService` currently throws `CHALLENGE_INCOMPLETE` in
> SCREAMING_CASE — the only code in the app that does. Change it to
> `challenge_incomplete` so the mock and the API agree; a UI branch keyed on
> the code would otherwise work against one and not the other.

### Non-errors

Two `404`s and one `401` are ordinary answers and must not be surfaced as
failures:

- `GET /user/profile` → `401` means "nobody is signed in". `ApiAuthService`
  returns `null`; the router reads that as a cold start.
- `POST /auth/login` → `404` means "no account matches". The login screen shows
  "no account found". `200` carries `{ "sent": true }` and nothing else — see
  the endpoint's own note for why it no longer returns the profile.

---

## Enum wire values

Every enum below serialises as its **exact Dart name**, camelCase, and parses
case-insensitively with a documented fallback. These are the strings the
database stores; do not translate, title-case or snake_case them. On the .NET
side, persist them as `string` (`.HasConversion<string>()`), not as `int` — an
integer enum column silently reorders the moment somebody inserts a value in the
middle of the C# enum.

| Enum | Values | Fallback on unknown |
|---|---|---|
| `EscrowState` | `requested` `quoted` `quoteAccepted` `createdPendingPayment` `fundsHeld` `acceptedByWorkshop` `inProgress` `proofSubmitted` `awaitingApproval` `releasedToWorkshop` `disputed` `cancelled` `refunded` | `createdPendingPayment` |
| `EscrowEvent` | `submitQuote` `acceptQuote` `declineQuote` `proceedToPayment` `autoAcceptQuotedJob` `confirmFundsHeld` `cancelBooking` `acceptJob` `rejectJob` `startWork` `submitProof` `handOffForApproval` `approve` `raiseIssue` `autoRelease` `resolveInFavourOfWorkshop` `resolveInFavourOfCustomer` | — |
| `EscrowActor` | `customer` `workshop` `founder` `system` | `system` |
| `ProviderOnboardingStage` | `applied` `documentsSubmitted` `verified` `approved` `suspended` | `applied` |
| `Fulfillment` | `workshop` `pickup` `roadside` | `workshop` |
| `ProviderCapability` | `evService` `evChargerInstall` | null (dropped) |
| `BookingType` | `catalogService` `customQuote` | `catalogService` |
| `ReviewDirection` | `customerToWorkshop` `workshopToCustomer` | `customerToWorkshop` |
| `AuditSubjectType` | `booking` `provider` `offer` `payout` | `booking` |
| `AccountKind` | `customer` `workshop` | `customer` |
| `Powertrain` | `petrol` `diesel` `hybrid` `pluginHybrid` `electric` | null |
| `MaintenanceType` | `oil` `tyres` `coolant` `cabinFilter` `brakeFluid` `battery12v` `evBattery` | `oil` |

`icon` fields on `ServiceCategory`, `Promotion` and `AppNotification` are
**opaque string keys** resolved by `lib/core/json/icon_codec.dart` — `build`,
`tire_repair`, `ac_unit`, `car_repair`, `notification`, `request_quote`,
`fact_check`, `lock_open`, `lock_clock`, `star`, `warning`, `chat`, and the
rest of that map. Store them as text and echo them back; an unknown key renders
a dashed circle rather than failing, so the server must pick from keys that file
declares. `bell`, `receipt` and `alarm_clock` are **not** keys — the nearest
real ones are `notification`, `request_quote` and `lock_clock`.

---

## Auth and the session

### `POST /auth/register`

**One endpoint for both account kinds.** The body is `UserProfile.toJson()`; a
workshop account differs only in carrying `kind: "workshop"` and a `workshop`
object. There is deliberately no second registration endpoint — it is the same
account, the same verification, and the same validation, and a parallel route
would be a parallel copy of all three.

```jsonc
{
  "id": null,                  // always present, always null on registration
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
    "businessNameEn": "Al Noor Workshop",   // optional, may be null
    "crNumber": "1198432",                   // 6–10 digits
    "vatNumber": "OM1100047382",             // optional, may be null
    "crDocument": {                          // the certificate itself, not a link
      "id": "8c2f1a04-…", "base64Data": "iVBORw0…",
      "mimeType": "image/png", "fileName": "cr-1198432.png", "caption": ""
    },
    "area": "Al Khuwair",                    // canonical English key
    "fulfillments": ["workshop", "pickup"],
    "submittedAt": "2026-08-01T09:14:00Z"
  }
}
```

→ `201` with a **session envelope** (below). Registering with
`kind: "workshop"` **grants nothing**: the account is created, and the
application is filed separately. The client calls both as one operation; a
server that prefers one transaction may key the application off this body.

### `POST /auth/login` · `POST /auth/login/verify`

Two-step OTP login, for a returning user who does not want to re-type their
registration. `identifier` is whatever the account was registered with — a
phone number or an email, in any of the formats the register screen accepts
(`+968 9200 1234`, `96892001234`, `9200 1234`). Normalise before matching.

```jsonc
// POST /auth/login   →  200 { "sent": true }   |   404 no account
{ "identifier": "+968 9200 1234" }
```

This call **also sends the OTP**. It answers with a fixed acknowledgement and
**never with the account** — the 200-vs-404 split is the whole of what the
client learns here.

> It used to answer `200 { UserProfile }`, "so the code screen can greet the
> user by name". The screen never did — its only use of the response was a null
> check — and the endpoint is unauthenticated, so anyone who could guess an
> eight-digit Oman mobile number was handed that person's name, e-mail,
> governorate and street address. Changed 2026-08-26; the client method is now
> `AuthService.requestOtp`, returning `bool`.

Rate-limit it: it is an unauthenticated endpoint that sends SMS, which is to
say it spends money on behalf of anyone who can reach it.

```jsonc
// POST /auth/login/verify   →  200 session envelope   |   401 wrong/expired
{ "identifier": "+968 9200 1234", "code": "7391" }
```

`kind` — and, for a workshop account, `workshop` — come back exactly as they
were registered. Nothing about login changes what the account *is*, only that
its session is active again.

### Session envelope

```jsonc
{
  "accessToken": "eyJhbGciOi…",     // JWT, short-lived
  "refreshToken": "b1c9…",          // opaque, rotating
  "expiresIn": 3600,                // seconds
  "user": { …UserProfile… }
}
```

> **Client change required.** `ApiAuthService.register` / `.login` currently
> parse a bare `UserProfile` from these two responses. They must be changed to
> read `user` and hand the tokens to the token store. This is step 3 of
> `docs/flutter_production_migration.md`. Every other route's shape is
> unchanged.

Access token claims: `sub` (the `UserProfile.id` GUID), `kind`
(`customer`/`workshop`), `providerId` and `stage` when the account owns a
workshop, plus `role: founder` for the operator account. **Authorisation is
decided from these claims, never from a body field** — `actor: "founder"` in an
escrow request is a statement about which transition is being fired, not a
credential.

### `POST /auth/refresh` · `POST /auth/logout`

`{ "refreshToken": "…" }` → a new session envelope; the old refresh token is
revoked on use (rotation). A reused token invalidates the whole family and
answers `401`.

`/auth/logout` takes no body, revokes the refresh token family, and deletes the
caller's device registrations (below).

### `GET /user/profile` · `PUT /user/profile`

`PUT` takes the full `UserProfile` and answers with the stored one. `GET`
returns `401` when nobody is signed in.

---

## Workshop onboarding

### `POST /service-marketplace/applications`

Files (or re-files) a workshop registration. The body is `ownerUserId` and
`region` plus every field of `WorkshopApplication.toJson()`, flattened.

```jsonc
{
  "ownerUserId": "3f6b1c88-77d2-4a1e-9c33-51ab0d7e2f40",
  "region": "Muscat",
  "businessNameAr": "ورشة النور",
  "businessNameEn": null,
  "crNumber": "1198432",
  "vatNumber": null,
  "crDocument": { "id": "…", "base64Data": "…", "mimeType": "image/png",
                  "fileName": "cr-1198432.png", "caption": "" },
  "area": "Al Khuwair",
  "fulfillments": ["workshop"],
  "submittedAt": "2026-08-01T09:14:00Z"
}
```

→ `201` with a `ServiceProvider` at **`stage: "documentsSubmitted"`** — not
`applied`, because the certificate was attached in the same step.

`ownerUserId` must equal the caller's `sub` claim. A body that names somebody
else is `403`, not a filed application.

Re-posting for an `ownerUserId` that already has a workshop **updates that
workshop** rather than creating a second one, and puts it back to
`documentsSubmitted`. That is what makes "fix it and re-submit" work after a
rejection without filling the founder's queue with duplicates.

From this moment the workshop is invisible: excluded from every customer-facing
query, and `POST /service-marketplace/requests` against it returns
`422 workshop_not_approved`.

### `PATCH /service-marketplace/providers/{id}/stage`

The founder's decision. Requires the `founder` role claim.

```jsonc
{ "stage": "approved" }
{ "stage": "suspended", "reason": "صورة السجل التجاري غير واضحة" }
```

`reason` is **required** for `suspended` — a rejection with no sentence after it
is not something the owner can act on. Omitting it returns
`422 provider_rejection_reason_required`. The client omits the key entirely
rather than sending null.

Moving off `suspended` clears the stored `rejectionReason`, so a re-approved
workshop stops showing its owner why it was once rejected.

Both transitions write an audit entry **and raise a notification to the owner**
(`workshop_approved` / `workshop_suspended`, carrying the reason).

### `ServiceProvider` stages

`applied` → `documentsSubmitted` → `verified` → `approved`, with `suspended`
reachable from any of them. Only `approved` grants anything:

- visible to customers (listings, search, offers, leaderboards);
- may take bookings;
- may open `/workshop`, re-checked on **every** entry, not once per session.

`isApproved` remains readable for older payloads: when `stage` is absent,
`isApproved: true` reads as `approved` and anything else as `applied`. New
payloads always send `stage`.

---

## Service marketplace

### Catalogue (all `GET`, all cacheable)

| Path | Returns |
|---|---|
| `/service-marketplace/categories` | `ServiceCategory[]` |
| `/service-marketplace/providers` | `ServiceProvider[]` |
| `/service-marketplace/offerings?categoryId=` | `ServiceOffering[]` — `categoryId` omitted when not filtering |
| `/service-marketplace/offerings/{id}` | `ServiceOffering` |
| `/service-marketplace/promotions` | `Promotion[]` |
| `/service-marketplace/offers` | `Offer[]` — approved and in-window only |
| `/service-marketplace/category-demand` | `CategoryDemand[]` |
| `/service-marketplace/workshop-demand` | `WorkshopDemand[]` |
| `/service-marketplace/ratings` | `WorkshopRating[]` — only rated workshops appear; **no entry means no rating**, never a zero |
| `/service-marketplace/providers/{id}/add-ons` | `AddOn[]` |
| `/service-marketplace/providers/{id}/slots?date=YYYY-MM-DD` | `{ "slots": ["09:00", …], "bookedSlots": ["10:30", …] }` |

`/providers` returns the **whole roster** including pending applications: it
feeds the founder's pipeline. A caller without the `founder` claim gets only
`approved` ones — `ServiceMarketplaceRepository` filters client-side too, but a
client is not where that rule is enforced.

Set `Cache-Control: public, max-age=300` and an `ETag` on the five static
catalogue routes. They are read on every home-screen open.

**`ServiceOffering` embeds its whole provider.** `ServiceOffering.fromJson`
requires a nested `provider` object, not a `providerId` — an offering whose
provider must be looked up separately cannot be rendered by the card that
displays it. Same for `ServiceRequest.offering` and `ServiceRequest.car`. On the
.NET side that means `.Include()`, and a projection that materialises the nested
DTO rather than a flat one.

### `PATCH /service-marketplace/offers/{id}`

The founder switches one offer on or off. `{ "activeByFounder": true }` →
`200` with the whole `Offer`.

### Bookings

| Path | Purpose |
|---|---|
| `POST /service-marketplace/requests` | place a catalogue booking |
| `POST /service-marketplace/part-requests` | open a part + installation request (starts with no price) |
| `POST /service-marketplace/requests/{id}/quote` | the workshop's itemised quote |
| `GET /service-marketplace/requests` | **the caller's own** bookings |
| `GET /service-marketplace/operator/requests` | **every** booking — `founder` claim only |
| `POST /service-marketplace/requests/{id}/status` | fire one escrow transition |

The last two are separate endpoints rather than one filtered route because they
are authorised differently. Merging them would put strangers' bookings in a
customer's own list the day somebody forgets a `where`.

```jsonc
// POST /service-marketplace/requests — CreateServiceRequestDraft
{
  "offeringId": "…", "carId": "…", "plate": "12345 A",
  "fulfillment": "workshop", "slot": "10:30",
  "addOnIds": ["…"],
  "maintenanceItemKey": "oil"   // null unless started from the maintenance book
}
```

```jsonc
// POST /service-marketplace/part-requests — CreatePartRequestDraft
{
  "providerId": "…", "carId": "…", "plate": "12345 A",
  "fulfillment": "workshop",
  "part": {
    "description": "مساعدات أمامية",
    "preferredBrand": "KYB",       // optional
    "symptom": "صوت عند المطبات"    // optional
  }
}
```

Neither body re-sends the provider, offering or car objects the caller already
holds: the server owns those records, and posting its own copies back would let
a client rename a workshop by booking it. Both answer with a full
`ServiceRequest` — including a synthesised quote-only `offering` for the part
request.

```jsonc
// POST …/requests/{id}/status
{
  "event": "approve",
  "actor": "customer",
  "proof": { … },          // submitProof only, ProofOfWork.toJson()
  "disputeNote": "…",      // raiseIssue only
  "slot": "10:30"          // optional reschedule
}
```

Optional keys are **omitted**, not sent as null.

The transition table in `lib/data/models/escrow.dart` is enforced **server-side
as well**, and it is the aggregate root's method — not a service that reads the
state, decides, and writes it back. An illegal `(state, event, actor)` returns
`422 escrow_transition_not_allowed`; a part-and-fit job submitting proof without
the part's box returns `422 proof_missing_part_box_photo`.

The returned `ServiceRequest` carries the position in **`escrow`** (not
`state`) and the full `history` of `{ state, actor, at, event }` entries. The
client renders progress from `history`; a response that drops it loses the
timeline on the booking screen.

Two transitions are the server's alone and no client fires them:
`autoRelease` after `AppConfig.approvalWindow` (72h) on `awaitingApproval`, and
the reminder at `approvalReminderLead` (24h) before it. Both are background
jobs, and both raise notifications.

### Money and audit

| Path | Purpose |
|---|---|
| `GET /service-marketplace/payouts` | `PayoutRecord[]` |
| `POST /service-marketplace/payouts` | record a transfer the founder made **by hand** |
| `GET /service-marketplace/audit` | `AuditEntry[]`, newest first |
| `POST /service-marketplace/audit` | append one line |

**Nothing here moves money.** A `PayoutRecord` is a note that a bank transfer
happened outside the app. There is no payment gateway in this phase, and
`ApiEndpoints.payments` is a phase-3 placeholder, not a route.

Audit lines are written from exactly one place in the client
(`ServiceMarketplaceRepositoryImpl._audit`) and cover four subjects: `booking`,
`provider`, `offer`, `payout`. The server writes its own rows for anything it
decides on its own (auto-release, stage changes) and treats the client's `POST`
as idempotent on `(action, subjectId, at)`. The workshop-dashboard writes below
add three more subjects to the same audit trail: `inventory`, `staff`,
`customer`.

---

## My workshop

Everything a workshop owner manages about their own workshop. Every route is
under `/service-marketplace/my-workshop`, requires auth, and resolves the
workshop from the caller's JWT (`providerId` claim) — **no `providerId`
appears in any of these paths**. A caller who owns no `ServiceProvider` gets
`403 workshop_not_owned` from every route in this section. Every *mutation*
additionally requires `stage == "approved"`, else `422 workshop_not_approved`
— re-checked per request, same as booking a workshop.

### Profile and summary

| Path | Purpose |
|---|---|
| `GET /my-workshop` | the caller's `ServiceProvider`, plus a completeness report and the booking-schedule config |
| `PUT /my-workshop` | edit `name`, `area`, `region`, `phone`, `whatsapp`, `hours`, `fulfillments`, `capabilities`, `pickupFee`, `vatNumber`, `crNumber` |
| `GET /my-workshop/summary` | one payload the dashboard home renders without a second round trip |

```jsonc
// GET /my-workshop
{
  "provider": { /* ServiceProvider, carrying `stage` */ },
  "isComplete": false,
  "missingFields": ["whatsapp", "vatNumber"],
  // The only route that reads these back. They are *written* through
  // `PUT /my-workshop/schedule`, which has no GET of its own, so without
  // them here the schedule config sheet has nothing to reopen with.
  "schedule": { "hours": { "ar": "…", "en": "…" }, "slotTemplate": ["09:00", "11:00"],
                "capacityPerSlot": 2, "closedDays": ["Friday"] }
}
```

`PUT /my-workshop` answers with the bare `ServiceProvider`, **not** this
envelope — the client re-derives `missingFields` from the saved provider using
the same six checks until the next `GET`.

```jsonc
// GET /my-workshop/summary
{
  "provider": { /* ServiceProvider */ },
  "jobs":   { "needsYou": 4, "inProgress": 3, "awaitingApproval": 2, "overdue": 1, "todays": 6 },
  "money":  { "heldInEscrow": 4200, "releasedGross": 18900, "totalCommission": 1890, "payoutDue": 3100 },
  "stock":  { "items": 42, "lowStock": 5, "outOfStock": 1, "stockValue": 12750 },
  "people": { "activeStaff": 4, "customers": 87, "repeatRate": 0.34 },
  "rating": { "avg": 4.6, "reviewCount": 31, "acceptanceRate": 0.92, "avgResponseMinutes": 47 },
  "alerts": [ { "code": "low_stock", "count": 5 }, { "code": "overdue_jobs", "count": 1 } ]
}
```

`money`/`rating` figures reuse the same server-side commission/metrics
computation as `/my-workshop/earnings` and `/my-workshop/metrics` below — one
calculation, three call sites.

### Offerings and add-ons

| Path | Purpose |
|---|---|
| `GET /my-workshop/offerings` | this workshop's offerings, **including inactive** (unlike the public `/service-marketplace/offerings`, which is active-only) |
| `POST /my-workshop/offerings` | create — body omits `id`/`provider` |
| `PUT /my-workshop/offerings/{id}` | replace `name`, `description`, `price`, `durationMin`, `includes`, `warrantyMonths`, `categoryId` |
| `PATCH /my-workshop/offerings/{id}/active` | `{ "isActive": false }` — publish/unpublish |
| `DELETE /my-workshop/offerings/{id}` | soft delete; `409 offering_has_open_bookings` if a non-terminal booking references it |
| `GET/POST /my-workshop/add-ons` | list / create |
| `PUT/DELETE /my-workshop/add-ons/{id}` | edit / remove |

```jsonc
// POST /my-workshop/offerings
{ "categoryId": "…", "name": { "ar": "تغيير زيت", "en": "Oil change" },
  "description": { "ar": "…", "en": "…" }, "price": 15, "durationMin": 30,
  "includes": [{ "ar": "فلتر زيت", "en": "Oil filter" }], "warrantyMonths": 1 }
```

### Inventory

| Path | Purpose |
|---|---|
| `GET /my-workshop/inventory` | this workshop's stock |
| `POST /my-workshop/inventory` | create an item, `quantityOnHand` starts at `0` |
| `PUT /my-workshop/inventory/{id}` | edit everything **except** `quantityOnHand` — quantity only moves through a movement |
| `DELETE /my-workshop/inventory/{id}` | `409 inventory_item_in_use` if a non-terminal booking's parts reference it |
| `POST /my-workshop/inventory/{id}/movements` | `{ "delta": -2, "reason": "consumed", "requestId": "…", "note": "…" }` → returns the item with recomputed `quantityOnHand` |
| `GET /my-workshop/inventory/low-stock` | items where `quantityOnHand <= reorderLevel` |

`quantityOnHand` is never sent on a write — the server derives it from the
`InventoryMovement` ledger, so two people recording a sale at the same moment
cannot lose a unit between them. A `consumed`/negative movement that would
take the count below `0` is `422 inventory_insufficient_stock`.

### Staff

| Path | Purpose |
|---|---|
| `GET /my-workshop/staff` | the roster, including inactive |
| `POST /my-workshop/staff` | `{ "name": "…", "phone": "…", "role": "technician", "specialties": ["brakes"] }` |
| `PUT /my-workshop/staff/{id}` | edit name/phone/role/specialties |
| `DELETE /my-workshop/staff/{id}` | deactivate (`isActive: false`) — staff are never hard-deleted, a completed job still points at them |
| `POST /my-workshop/requests/{id}/assign` | `{ "staffId": "…" }` → returns the `ServiceRequest` with `assignedStaffId` set |

`role` is one of `owner \| manager \| technician \| receptionist`. Only
`owner`/`manager` accounts may call any *write* route in this whole "My
workshop" section — a `technician`/`receptionist` gets
`403 staff_permission_denied`. Assigning a job does not touch `escrow`; it is
orthogonal to the escrow state machine.

### Requests, customers, schedule

| Path | Purpose |
|---|---|
| `GET /my-workshop/requests?status=&from=&to=&q=` | this workshop's bookings, filterable — the workshop-scoped equivalent of the founder-only `/operator/requests` |
| `GET /my-workshop/customers?q=&tag=` | derived customer list (see below) |
| `GET /my-workshop/customers/{userId}` | one customer: profile, their bookings with this workshop, notes |
| `POST /my-workshop/customers/{userId}/notes` | `{ "body": "…" }` → `404 customer_not_a_client` if this user has never booked here |
| `GET /my-workshop/schedule?date=YYYY-MM-DD` | working slots, booked slots, assigned jobs for one day |
| `PUT /my-workshop/schedule` | working hours, slot template, capacity per slot, closed days |

`GET /my-workshop/customers` is **derived, not stored** — there is no
customer table. Each row is a projection over this workshop's
`ServiceRequest`s:

```jsonc
{ "userId": "…", "name": "…", "phone": "+968 9…" /* omitted, not null, until escrow unlocks contact */,
  "carCount": 2, "bookingsCount": 5, "lifetimeGross": 340,
  "lastBookingAt": "2026-07-20T…Z", "avgRatingGiven": 4.5,
  "tags": ["repeat"] }
```

`tags` ⊂ `{repeat, new, disputed, lapsed}`, computed server-side each request
— `repeat` (>1 booking), `new` (exactly one, not lapsed), `disputed` (any
booking ever reached `disputed`), `lapsed` (no booking in 90 days). `phone`
follows the same escrow-gated visibility rule as booking-screen contact
buttons (`fundsHeld` state onward, including `disputed`) — it is the key
omitted, never sent as `null`, when gating hides it.

### Earnings and metrics

| Path | Purpose |
|---|---|
| `GET /my-workshop/earnings?window=30d` | `{ heldInEscrow, releasedGross, releasedCommission, totalCommission, lines: [...], window }` — same shape as the client's former `WorkshopEarnings` |
| `GET /my-workshop/metrics?window=30d` | `{ received, accepted, completed, disputed, avgResponseTimeMinutes, avgRating, reviewCount, recentReviews }` — same shape as `WorkshopMetrics.toJson()` |

Both were purely client-computed before this stage (the repository summed
`fetchOperatorQueue()` results in memory) — these routes move that
computation server-side so the dashboard summary and a workshop's own figures
can never disagree.

---

## Reviews

| Path | Purpose |
|---|---|
| `GET /reviews` | reviews visible to this user |
| `POST /reviews` | write one — body is the full `Review`, id included |
| `PATCH /reviews/{id}` | correct one inside the edit window — `{ "rating": 5, "comment": "…" }`, `comment` omitted when null |
| `GET /service-marketplace/providers/{id}/reviews` | one workshop's reviews |

Two rules the **server owns**, and they are the whole verification mechanism:

1. a review may only be created against a booking that reached
   `releasedToWorkshop` → else `422 review_booking_not_released`;
2. `(bookingId, direction)` is unique — enforce it with a unique index, not a
   `SELECT` first → else `409 review_already_exists`.

`ApiReviewService` deliberately does **not** re-check these client-side. The
mock does, because it is standing in for the server; a duplicate check in front
of a real API is a convenience that hides which side actually guarantees the
rule.

`rating` outside 1–5 is `422 review_rating_out_of_range`. The edit window is
server-enforced (`422 review_edit_window_closed`) and `editedAt` is the
server's to stamp. There is no delete: a review that can be withdrawn on demand
is a review a workshop can pressure someone into withdrawing.

---

## Garage and maintenance

| Path | Purpose |
|---|---|
| `GET/POST /user/vehicles` | the user's cars — `POST` body is a full `Car` with a client-generated GUID |
| `PUT /user/vehicles/{id}` | replace one (the edit screen rebuilds the whole `Car`, which is how an optional field gets cleared) |
| `PATCH /user/vehicles/{id}` | one field: `{ "plate": "…" }` or `{ "odometerKm": 78400 }` |
| `DELETE /user/vehicles/{id}` | remove one |
| `POST /user/vehicles/{id}/primary` | make this car primary; returns the **whole reordered list** |
| `GET /user/vehicles/maintenance` | every maintenance book, as an array whose entries each carry their own `carId` |
| `POST/DELETE /user/vehicles/{carId}/maintenance` | create (idempotent) or remove a book |
| `PUT /user/vehicles/{carId}/maintenance/odometer` | `{ "km": 78400 }` |
| `POST/PUT/DELETE …/maintenance/records[/{recordId}]` | service history; `POST` upserts by id |
| `PUT …/maintenance/intervals/{itemKey}` | `{ "km": 10000 }` or `{ "months": 6 }`; **null clears the override** |
| `POST/DELETE …/maintenance/items[/{itemId}]` | the owner's own extra lines |

> ⚠️ **`…/primary` is currently a `GET` in the client.** `ApiGarageService.
> setPrimary` calls `getList` on `/user/vehicles/{id}/primary` because it needs
> the reordered array back. A `GET` that changes state is cacheable by
> everything between the phone and the database, and one day something will
> cache it. Build the endpoint as `POST`; changing the client is one line and it
> is listed in the migration doc.

`GET /user/vehicles/maintenance` returns a **JSON array**, not a map keyed by
car — the client builds the map from each entry's `carId`, so `carId` is
required on every book.

Every maintenance write answers with the **whole book**, never with the patch it
applied. A client that reconstructs a book from patches is a client that can
disagree with the server about a car's history.

`PUT …/intervals/{itemKey}` sends `null` **explicitly** rather than omitting the
key: null *is* the value there — it clears the override and puts the item back
on its default — and an omitted field would read as "leave it alone". Note that
`setKmInterval` and `setMonthInterval` hit the same path with different single
keys (`km` vs `months`); an absent key means "unchanged", a present null means
"clear". Bind to `int?` on a DTO that can tell the two apart
(`JsonElement`/optional wrapper), because plain `int?` cannot.

`POST …/records` upserting by id is what makes a repeated booking-completion
event harmless.

---

## Notifications

The inbox is **server-owned**. Today the app writes its own notification copy in
`NotificationRepositoryImpl.notify*()` as the simulated lifecycle moves a
booking along; in production those bodies are deleted and the server raises
every notification as a side effect of the event that caused it. Two sources of
wording for the same event is how a customer ends up with two subtly different
sentences about one booking.

| Path | Purpose |
|---|---|
| `GET /notifications` | `AppNotification[]`, **newest first** |
| `POST /notifications/read` | mark every notification read; returns the whole updated inbox |
| `POST /notifications/devices` | register this device for push |
| `DELETE /notifications/devices/{token}` | unregister (also done implicitly by `/auth/logout`) |

```jsonc
// AppNotification
{
  "id": "b31c…",                       // GUID, server-generated
  "title": { "ar": "تم استلام سيارتك", "en": "Your car has been received" },
  "body":  { "ar": "…", "en": "…" },
  "icon": "car_repair",                 // IconCodec key
  "time": "2026-08-05T11:02:00Z",
  "read": false,
  "route": "/track/8c2f1a04-…"          // deep link, optional
}
```

- **Bilingual, always.** Both `ar` and `en` are stored on the row when it is
  raised. Do not localise from `Accept-Language` — the user switches language
  inside the app and expects the inbox to follow.
- `route` is a **client route path**, and it must be one `lib/core/router/`
  actually declares. The ones a notification can point at:
  `/track/{requestId}` · `/approve/{requestId}` · `/quote/{requestId}` ·
  `/review/{requestId}` · `/chat/{requestId}` · `/chat/provider/{providerId}` ·
  `/workshop` · `/garage` · `/challenge` · `/notifications`. There is **no**
  `/bookings/…` route — a booking is tracked at `/track/{id}`. An unknown route
  is ignored on tap rather than crashing, which makes a wrong one a silent dead
  end.
- `icon` is an `IconCodec` key from `lib/core/json/icon_codec.dart`.
  `notification` is the safe default; `bell` is **not** a key and renders a
  dashed circle.
- `POST /notifications/read` returns the array rather than `204` because
  `markAllRead()` is typed `Future<List<AppNotification>>` and the screen
  rebuilds from what it returns.

### Push

```jsonc
// POST /notifications/devices
{ "token": "fcm-registration-token", "platform": "android" }  // or "ios"
```

FCM carries a **data-only** message whose payload is the `AppNotification`
above, so a push and a fetched inbox row are the same object and the app never
renders two different versions of one event. `(userId, token)` is unique;
re-registering the same token refreshes its timestamp rather than duplicating.
Prune tokens FCM reports as unregistered.

### What raises a notification

The server, not the client, on each of these:

| Trigger | Icon key | Route |
|---|---|---|
| booking placed / part request opened | `car_repair` | `/track/{id}` |
| quote received | `request_quote` | `/quote/{id}` |
| escrow moved to `acceptedByWorkshop`, `inProgress`, `disputed`, `refunded`, `cancelled` | `build_circle` / `hourglass` / `gavel` / `undo` / `warning` | `/track/{id}` |
| escrow moved to `awaitingApproval` | `fact_check` | `/approve/{id}` |
| escrow moved to `releasedToWorkshop` | `lock_open` | `/track/{id}` |
| approval window closing (24h before auto-release) | `lock_clock` | `/approve/{id}` |
| review unlocked after release | `star` | `/review/{id}` |
| workshop approved / suspended | `assignment_turned_in` / `warning` | `/workshop` |
| new booking in a workshop's queue | `notification` | `/workshop` |
| new chat message | `chat` | `/chat/{id}` |

`handOffForApproval` raises **nothing** — the automatic proof hand-off is
invisible by design, and telling a customer about a state change they did not
cause and cannot act on is noise.

---

## Chat

One thread per conversation, and a thread hangs off one of two things. Normally
it is a booking and the key is the request id. But contact details are gated on
escrow (`core/utils/provider_contact.dart`), so a customer who has not booked
yet still needs somewhere to ask — that thread belongs to a **workshop** and is
keyed `provider:{providerId}`. Anything answering a thread has to know which of
the two it is: *"your car is with us"* is a fine reply on a booking and nonsense
on an enquiry.

| Path | Purpose |
|---|---|
| `GET /chat/threads/{threadId}/messages` | `ChatMessage[]`, oldest first |
| `POST /chat/threads/{threadId}/messages` | send one — `{ "text": "…" }` |
| `GET /chat/threads` | the caller's threads with last message and unread count *(optional, phase 2.1)* |

`threadId` is either a booking GUID or the literal string
`provider:{providerGuid}`. **URL-encode it** — the colon must arrive as `%3A`.
Route it as `{threadId}` with a constraint that accepts both forms; do not
invent two endpoints, because the client holds one opaque key
(`providerThreadId()` in `lib/data/models/chat_message.dart`) and does not
branch on it.

```jsonc
// ChatMessage
{
  "id": "9d0e…",                  // GUID, server-generated
  "fromUser": true,               // true = the customer sent it
  "text": "السيارة جاهزة؟",
  "time": "2026-08-05T11:02:00Z"
}
```

`fromUser` is **relative to the reader**, and the server sets it from the
caller's claims — the customer's `true` is the workshop's `false` for the same
row. Store the real `senderUserId`; compute `fromUser` in the DTO projection.
Never let the client assert it.

Authorisation: only the booking's customer and its workshop may read or post to
a booking thread; only the enquiring customer and the workshop for an enquiry
thread. Anything else is `403 chat_thread_not_participant`. A workshop's stage
does not matter here — a suspended workshop can still answer a customer it
already has a booking with.

### Real-time — SignalR

```
HUB  /hubs/chat        (JWT in the access_token query string)
  → JoinThread(threadId) / LeaveThread(threadId)
  ← ReceiveMessage(threadId, ChatMessage)
```

`ChatService.awaitProviderReply(requestId)` was written as *"resolve when the
provider next replies"* precisely so this swap does not touch the screen: today
a canned answer completes it, tomorrow an inbound hub frame does. The REST
routes stay the whole truth — the hub is a delivery optimisation, and a client
that misses a frame catches up on the next `GET`. Fall back to a 5-second poll
while the hub is disconnected; never leave the screen with no path to new
messages.

Each inbound message also raises a notification if the recipient has no live
hub connection for that thread.

---

## Challenges

The weekly challenge and the loyalty totals it feeds. Two **tracks** —
`combustion` and `electric` — are the same board with different tasks: same
rewards, same streak, same history. Anything else would mean an EV owner's
streak resetting the moment the app worked out what they drive.

| Path | Purpose |
|---|---|
| `GET /challenges/board?powertrain=` | the caller's `ChallengeBoard` |
| `POST /challenges/steps/{stepId}/toggle` | flip one step; returns the whole board |
| `POST /challenges/current/complete` | award, archive, extend the streak; returns the whole board |

`powertrain` is the primary car's, omitted when unknown, and the **server**
derives the track from it: anything that plugs in (`electric`, `pluginHybrid`)
gets `electric`, everything else `combustion`. A plug-in hybrid owner has a
cable and a charge port to look after just like a full EV. The rule lives in
`ChallengeTrackX.of` on the client and must be duplicated exactly on the server
— it decides which board a person sees, and two answers to that is two streaks.

`POST /challenges/current/complete` takes `{ "powertrain": "petrol" }` so the
server knows which board to close, and returns `422 challenge_incomplete` when
any step is still open. It writes:

- `rewardPoints` onto the balance, `badgeCount + 1`, `streakWeeks + 1`,
  `completedCount + 1`;
- the challenge into `history` as a `PastChallenge`;
- `current: null` until the next week's board opens;
- **and, when `feedsMaintenance` is set, a `ServiceRecord` on the primary car's
  maintenance book**, titled `recordTitle` (falling back to
  `challengeRecordTitle`), attributed to the workshop name `AK Challenge`.
  That last one is the product rule that makes the challenge worth doing: an EV
  owner who inspected a charging cable must not find "tyre pressure check" in
  their service history.

```jsonc
// ChallengeBoard
{
  "current": {
    "id": "…", "title": {…}, "description": {…},
    "steps": [ { "id": "…", "title": {…}, "done": false } ],
    "rewardPoints": 50,
    "badgeName": {…},
    "endsInDays": 3,
    "feedsMaintenance": "tyres",     // MaintenanceType key, or null
    "recordTitle": {…}               // or null
  },
  "next":    { "title": {…}, "points": 60 },   // teased, not startable; or null
  "history": [ { "title": {…}, "points": 50 } ],
  "streakWeeks": 4, "completedCount": 11, "points": 540, "badgeCount": 11
}
```

`endsInDays` is a **computed integer, not a stored date** — the client renders
it directly. Compute it per request from the challenge's end date in UTC.

Steps are per-user state over a shared challenge definition: the definition
(`WeeklyChallenge`) is one row for everyone on that track, and `done` comes from
a `UserChallengeStep` join. Toggling a step for one user must not move anyone
else's board.

`current: null` is a legitimate answer — the week's challenge is finished and
the next has not opened. The screen renders the empty state; it does not error.

---

## Production readiness

Things that are not a route but are part of shipping this.

- **Health checks:** `/health/live` and `/health/ready` (database + FCM),
  excluded from auth and from versioning.
- **OpenAPI:** published for `v1`. The shapes in this document and the ones in
  Swagger must not disagree; when they do, this document is wrong and gets
  fixed, because the client was written against it.
- **Idempotency:** `POST /service-marketplace/audit` on
  `(action, subjectId, at)`; `POST …/maintenance/records` on the record id;
  `POST /user/vehicles` on the car id. A phone on a bad connection retries, and
  a retry must not double a record.
- **Rate limits:** `/auth/login` and `/auth/login/verify` per identifier and per
  IP — they send SMS and they guess codes respectively.
- **Pagination:** none in v1. Every list route returns everything the caller
  owns. `/service-marketplace/operator/requests`, `/audit` and `/notifications`
  are the three that will need it first; when they get it, it is a new route or
  a v2, not a changed response shape — the client parses a bare array.
- **Logging:** Serilog, structured, with the `traceId` that appears in
  `ProblemDetails`. Never log `base64Data`.
- **Timeouts:** the client gives up at 15s connect / 20s receive
  (`AppConfig`). Anything slower than that is a failure on the phone whatever
  the server eventually returns — which matters for the routes that carry
  attachments.

---

## Path drift

The rule at the top — *nothing hard-codes a path outside
`api_endpoints.dart`* — is currently broken. None of it blocks the backend,
because this document lists the real paths, but it is what makes the endpoint
file untrustworthy as a checklist. Fixing it is step 2 of the migration doc.

**Fully hard-coded, no constant involved:**

| Path | Service |
|---|---|
| `/user/vehicles/maintenance` | `ApiMaintenanceService` |
| `/user/vehicles/{carId}/maintenance` + all six sub-paths | `ApiMaintenanceService` (`_book()`) |
| `/service-marketplace/applications` | `ApiServiceMarketplaceService` (`_base`) |
| `/service-marketplace/operator/requests` | `ApiServiceMarketplaceService` (`_base`) |
| `/service-marketplace/payouts` | `ApiServiceMarketplaceService` (`_base`) |
| `/service-marketplace/audit` | `ApiServiceMarketplaceService` (`_base`) |

**Half-derived** — a constant with a segment concatenated at the call site, so
renaming the sub-path is still a change in two files:

| Path | Built from |
|---|---|
| `/user/vehicles/{id}/primary` | `garageVehicle(id)` + `'/primary'` |
| `/service-marketplace/offerings/{id}` | `serviceOfferings` + id |
| `/service-marketplace/offers/{id}` | `serviceOffers` + id |
| `/service-marketplace/providers/{id}/stage` | `serviceProviders` + id + `'/stage'` |

**Stale constants that describe routes which do not exist.**
`ApiEndpoints.maintenance`, `.maintenanceRecords`, `.maintenanceOdometer`,
`.maintenanceIntervals` name a flat `/maintenance` namespace; the real books are
nested under `/user/vehicles/{carId}`. `.serviceRequestApproval` is superseded
by `…/requests/{id}/status`. `.requestChat` is superseded by
`/chat/threads/{threadId}`. Delete all six.

**Placeholders** — `/cart` (no cart-service interface exists in the app yet)
and `/payments` (no payment gateway in this phase, see above) — are harmless
as long as nobody reads them as a specification. `/cars*`, `/products`,
`/orders` and `/locations` are no longer placeholders: `ApiCatalogService`,
`ApiCarsService`, `ApiShopService` and `ApiOrderService` call them for real —
see the [Scope](#scope) table.
