# AK Cars — Mobile App

A Flutter client for **AK Cars**, a car-services and marketplace platform for
Oman: book maintenance with a workshop, track the job through an escrow-backed
lifecycle, browse a cars marketplace and a parts shop, and run a workshop's
own back office from the same app.

Talks to [`AKCarsMobileAPI`](../AKCarsMobileAPI) — a separate .NET 8 backend —
over REST and one SignalR hub for chat. There is no offline/mock data path in
the shipped app; see [Architecture](#architecture) below.

## Features

- **Booking → escrow → approval** — a customer books a service, funds are
  held in escrow, the workshop does the work and submits proof, the customer
  approves (or a 72-hour timer auto-releases), funds are released.
- **Maintenance follow-up** — per-car service schedule computed only from
  odometer readings and service records the owner actually entered; no
  invented "health score".
- **Request a part + fitting** — a customer describes a part/fault, a
  workshop answers with an itemised quote, and it rides the same escrow
  machine as a catalogue booking.
- **Verified reviews** — a review can only be filed from a booking that
  actually completed; nothing is seeded or fabricated.
- **Workshop dashboard** — a workshop's own CRUD for offerings, add-ons,
  inventory, staff, schedule, customers, and server-computed earnings/metrics.
- **Founder/admin console** — provider approvals, dispute resolution, offer
  governance, platform-wide money audit.
- **Cars marketplace & parts shop** — feature-flagged pillars (see
  `lib/config/app_flags.dart`), hidden rather than deleted when out of scope.
- Bilingual **Arabic (default, RTL) / English**, light **"Sand"** and dark
  **"Ink"** themes, both fully token-driven.

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter (Dart SDK `^3.12.2`) |
| State management | [Riverpod](https://riverpod.dev) (`flutter_riverpod`) — notifiers + derived providers, no NgRx-style store |
| Routing | [`go_router`](https://pub.dev/packages/go_router), one shell route per bottom-nav tab |
| HTTP | [`dio`](https://pub.dev/packages/dio) behind an `ApiClient` contract |
| Realtime | [`signalr_netcore`](https://pub.dev/packages/signalr_netcore) — chat hub |
| Auth storage | [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) (tokens) + `shared_preferences` (guest-local data, settings) |
| Push | Firebase Cloud Messaging (`firebase_core`, `firebase_messaging`) |
| i18n | Hand-rolled bilingual strings (`lib/core/i18n`) + bilingual `L(ar, en)` values on models — see [Architecture](#architecture) |
| Fonts / icons | `google_fonts` (IBM Plex Sans Arabic, Chakra Petch for numerals), `lucide_icons_flutter` |
| Charts | `fl_chart` (workshop statistics) |
| Images | `cached_network_image`, `image_picker` |
| Testing | `flutter_test` — 47 test files, incl. golden tests |

## Getting started

```bash
flutter pub get

# Point the app at a running AKCarsMobileAPI instance.
# There is no default — an unset base URL fails loudly on first request
# rather than silently serving fake data.
flutter run --dart-define=AK_API_BASE_URL=http://127.0.0.1:5116/api/v1
```

### Configuration (`--dart-define`)

Read once, in `lib/config/`, and nowhere else in the app:

| Define | Default | Purpose |
|---|---|---|
| `AK_ENV` | `development` | Selects `AppEnvironment` |
| `AK_API_BASE_URL` | *(none — required)* | Root of the REST API, no trailing slash |
| `AK_REMOTE_CAR_IMAGES` | `true` | Toggle CDN vehicle imagery vs. offline vector artwork |
| `AK_PARTS_STORE` | `false` | Show the parts shop pillar |
| `AK_CAR_MARKETPLACE` | `false` | Show the cars marketplace pillar |
| `AK_HOME_TAB` | `true` | Show the home tab |
| `AK_PART_INSTALL` | `true` | "Request a part + fitting" flow |
| `AK_REVIEWS` | `true` | Verified reviews flow |

See `lib/config/app_flags.dart` for the full list of compile-time feature
flags (they hide a pillar's routes and nav entry; they never delete its code
or tests).

### Testing

```bash
flutter analyze lib test
flutter test
```

## Project structure

```
ak_cars_mobil_app/
├── lib/
│   ├── app/                     Composition root — AkCarsApp, AppBootstrap
│   ├── config/                  AppEnvironment, AppConfig, AppFlags — the only readers of --dart-define
│   ├── core/
│   │   ├── constants/           API endpoint paths, app-wide constants
│   │   ├── error/                AppException hierarchy (network/domain errors)
│   │   ├── i18n/                  Bilingual strings — S.of(context).t(ar, en)
│   │   ├── json/                   Null-safe JSON decode helpers
│   │   ├── media/                   Attachment codec (files travel as base64, never a path)
│   │   ├── network/                  ApiClient contract + DioApiClient, chat SignalR hub
│   │   ├── push/                      Firebase push wiring
│   │   ├── router/                     go_router routes, shell branches, auth/role guards
│   │   ├── theme/                       Sand & Ink design tokens (AkColors, typography, shape)
│   │   ├── utils/                        GUID/derived-GUID helpers, JWT claim decoding
│   │   └── widgets/                       Shared UI kit — AppCard, StatusBadge, SelectChip, …
│   ├── data/
│   │   ├── models/                Immutable domain models (fromJson/toJson/copyWith, value equality)
│   │   ├── repositories/          One per feature — caching, warm caches, domain rules
│   │   └── services/
│   │       ├── api/               ApiXService — the real REST implementations
│   │       └── *Service.dart      Interfaces + session-routed / local-store variants
│   ├── di/
│   │   └── providers.dart         Every service/repository binding — the only file naming a concrete impl
│   ├── features/                  One folder per screen/flow — reads providers, builds no data
│   │   ├── auth/                  Login, register, phone/email choice
│   │   ├── cars/                  Cars marketplace, listings, post-an-ad
│   │   ├── challenge/             Weekly challenge / loyalty
│   │   ├── garage/                Registered vehicles
│   │   ├── home/                  The home feed (offers, workshops, suggestions)
│   │   ├── onboarding/            First-run flow
│   │   ├── operations/            Founder console + a workshop's own escrow queue
│   │   ├── profile/                Account, payments, settings entry
│   │   ├── search/                  Cross-catalogue search
│   │   ├── services/                 Booking, tracking, quotes, reviews
│   │   ├── settings/                  Language/theme/notifications
│   │   ├── shell/                      Bottom-nav shell — single source of truth for tabs
│   │   ├── shop/                        Parts shop, cart, checkout, orders
│   │   └── workshop_dashboard/          A workshop's own CRUD: offerings, inventory, staff, schedule, stats
│   └── state/                     Riverpod notifiers + derived providers (no data logic of its own)
├── test/
│   ├── fakes/                     Test doubles + the seeded demo world — never imported from lib/
│   ├── goldens/                    Golden-image baselines
│   ├── helpers/                     Test harness wiring fakes into the DI container
│   └── web/                          Web-only test target (secure-storage race, etc.)
├── android/ ios/ web/ windows/ linux/ macos/   Platform shells
├── assets/                        Bundled fonts, currency glyphs, launcher icon sources
├── ARCHITECTURE.md                Layering, data flow, and every non-obvious decision — read before changing lib/
├── EDIT_LOG.md                    Chronological record of what changed and why, newest first
├── DESIGN_HANDOFF.md              The "Sand & Ink" visual design spec (tokens, screens, mockup references)
└── docs/
    └── api_contract.md            The REST contract this app is written against
```

## Architecture

Layering is strict and one-directional:

```
UI (features/) → State (state/) → Repositories (data/repositories/) → Services (data/services/) → ApiClient → REST API
```

There is no second, offline data source in `lib/` — every service binding in
`lib/di/providers.dart` resolves to a real `Api*` implementation, and a build
that cannot reach the configured API host fails loudly with a
`NetworkException` rather than falling back to invented data. The full mock
world used to live in `lib/`; since 2026-08-10 it exists only as test doubles
under `test/fakes/`.

For the full picture — the escrow state machine, warm caches, the
maintenance-projection logic, the workshop dashboard, and the technical debt
being carried on purpose — see **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## Related docs

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — the authoritative architecture reference
- [`EDIT_LOG.md`](EDIT_LOG.md) — running history of changes, newest first
- [`DESIGN_HANDOFF.md`](DESIGN_HANDOFF.md) — visual design spec (colors, type, spacing, per-screen references)
- [`docs/api_contract.md`](docs/api_contract.md) — the REST API contract
- [`AKCarsMobileAPI`](../AKCarsMobileAPI) — the backend this app talks to
