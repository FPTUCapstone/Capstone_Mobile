# TripMate Mobile Rebuild Audit

Date: 2026-09-09

Scope: read-only audit of `Capstone_BE`, `Capstone_FE`, and `Capstone_Mobile` on branch `feature/PhucTV-register-traveler`.

## 1. Git Safety Baseline

- Backend working tree: clean.
- Frontend working tree: modified `AGENTS.md`, `CONTRIBUTING.md`, `README.md`, `docs/CODEBASE_RULES.md`; deleted `src/lib/__tests__/useVerificationEmailCooldown.test.ts`.
- Mobile working tree: modified router, DI, auth session, traveler registration, password field, analysis options, lockfile, and demo auth test; untracked auth data/repository/Cubit tests, `plans/`, `specs/`, and `windows/`.
- No reset, clean, checkout, commit, or deletion was performed.
- Existing local changes are not part of this audit's proposed deletion list.

## 2. Current Mobile Architecture

Mobile is a Flutter/Dart null-safe application using:

- Feature-first folders under `lib/features/`.
- `flutter_bloc`/Cubit for presentation state.
- `go_router` for navigation.
- `get_it` for dependency injection.
- Dio with connectivity and auth interceptors.
- `flutter_secure_storage` for token storage and SharedPreferences for non-sensitive preferences.
- Material 3 and shared widgets under `lib/shared/widgets/`.

The intended page flow is Page -> Cubit -> Use Case/Repository -> Data Source -> Dio. The current registration slice partially follows this design, but the domain repository exposes a data DTO and most other features remain local demo flows.

Current route groups:

- Auth: splash, login, traveler registration, operator registration, reset password.
- Traveler: shell, settings, profile, preferences, change password.
- Operator: shell and application.
- Debug demos: `/demo` and `/demo/uc-01` through `/demo/uc-09`.

There is no Administrator Mobile feature; repository rules explicitly keep administration on Web.

## 3. Current Frontend Architecture

The Web app is a Next.js App Router application. Routes are composed in `app/`, while reusable and feature implementations live under `src/components/`, `src/features/`, and `src/lib/`.

Implemented route areas:

- Public landing page.
- Traveler sign-in, registration, verification instructions, verification-link handling, and local password-recovery prototype.
- Partner registration, application status, and resubmission prototypes.
- Admin login, dashboard, and tour-review prototypes.

The only backend client is `src/lib/authApi.ts`. It uses the shared `/api/v1/auth/*` backend routes for traveler registration, password login, Firebase email verification synchronization, and Google authentication. Tokens are currently stored in browser localStorage. No production API/service layer exists yet for profile, preferences, planning, POI, tours, bookings, payments, history, or reviews.

The FE has reusable auth shells, form controls, action buttons, feedback alerts, status badges, route constants, and Firebase/backend error mapping. It also clearly contains mock data and simulated requests for non-auth prototype screens.

## 4. Current Backend Architecture

The backend is a .NET solution following the intended dependency direction Domain <- Application <- Infrastructure <- API. It uses CQRS/MediatR handlers, FluentValidation, EF Core against the SQL schema, Firebase/Google token validation, JWT access tokens, and hashed refresh-token persistence.

The API currently exposes only `/health` and four authentication routes. Current controllers are anonymous; no controller currently enforces JWT role authorization. Roles defined by the domain are `Traveler`, `TourOperator`, and `Administrator`.

Important backend constraints:

- JWT signing key is empty in checked-in appsettings and must be supplied by environment configuration.
- There is no refresh, logout, revocation, or token-rotation endpoint.
- Registration does not create a traveler profile or send email itself.
- OTP lifecycle, Redis storage, rate limiting, and email delivery are not implemented.
- Database SQL contains broader product tables, but the current EF DbContext maps only the implemented auth/message slice.
- Firebase fallback verification must not be treated as production-safe until signature/audience validation is confirmed.

## 5. Verified API Inventory

| Method | Endpoint | Current purpose |
|---|---|---|
| GET | `/health` | Anonymous health response |
| POST | `/api/v1/auth/register` | Traveler account creation; requires Firebase bearer token |
| POST | `/api/v1/auth/verify-email` | Firebase email verification synchronization and JWT issuance |
| POST | `/api/v1/auth/google` | Firebase/Google token authentication |
| POST | `/api/v1/auth/login` | Email/password login and JWT issuance |

No other production Mobile-capable endpoint was found in the current backend source. In particular, no endpoint was verified for refresh, logout, password reset/change, traveler profile, preferences, POI, itinerary, map, weather, tour operator applications, tours, booking, payment, or admin operations.

## 6. FE Screens and Integration State

| FE route | State | Mobile implication |
|---|---|---|
| `/sign-in` | Real password login; Firebase/Google paths present | Can be implemented only against the verified login contract |
| `/register` | Real Firebase + backend traveler registration | Primary first Mobile rebuild slice |
| `/verify-account`, `/verify-email` | Firebase email-link flow plus backend sync; docs and route naming differ | Requires explicit UX decision for Mobile |
| `/forgot-password` | Local simulated request | Cannot be implemented as production Mobile flow yet |
| `/partner/register`, `/partner/application*` | Local/mock prototype | No verified Mobile API exists |
| `/admin*` | Local/mock prototype and no real auth boundary | Not a Mobile scope; Admin remains Web-only |
| `/` | Static landing/discovery prototype | No production discovery API verified |

## 7. Mobile Screens and Demo Classification

Real backend-backed slice:

- Traveler registration request through `/api/v1/auth/register`.

Demo or placeholder in the current Mobile production route tree:

- Login with hard-coded demo accounts.
- Phone/OTP login with hard-coded `123456`.
- Google login visual flow.
- Reset password and change password.
- Operator registration, document selection, application status, and resubmission.
- Traveler profile and preferences local state.
- Traveler Home, Trips, Explore, and Bookings shell tabs.
- Operator Dashboard, Tours, Bookings, Revenue, and Profile shell tabs.

Debug demo routes may remain for test/demo purposes, but must never be reachable from a production flow or used as an auth fallback.

## 8. Reusable Mobile Code

Keep and evaluate for reuse:

- `DioClient`, network info, error/failure types, and secure storage abstraction.
- `go_router`, route constants, route guards, and DI setup after correcting lifecycle behavior.
- Shared page scaffold, text/password fields, buttons, alerts, loading, error, and status widgets.
- Existing Cubit/test conventions.
- Auth registration DTO/data source only after strict envelope and response validation are corrected.

Do not treat demo Cubits, hard-coded credentials, simulated requests, or local business state as production implementations.

## 9. Key Unsynchronized Points

1. Mobile login is demo-only even though BE login exists.
2. Mobile Android now defaults to `http://10.0.2.2:5000`; web and desktop keep
   `https://api.example.invalid` until an environment-specific URL is supplied.
3. Mobile registration currently does not send a Firebase ID token, although BE manually requires one.
4. Registration resolves a new `AuthSessionCubit` factory instead of updating the app-provided instance, so successful registration may not enter the traveler area.
5. Mobile registration logging includes request bodies and can expose passwords.
6. Mobile sign-out clears memory but not persisted access/refresh tokens.
7. Mobile phone and password validation differ from the BE validator and approved spec.
8. Mobile response parsing defaults missing fields instead of rejecting malformed responses.
9. FE stores tokens in localStorage without refresh or expiry handling; Mobile has no refresh handling either.
10. FE verification documentation describes a code-entry flow while implementation uses Firebase email links.
11. FE operator, admin, recovery, and product screens are prototypes without BE contracts.
12. Backend success/error behavior is a custom envelope, while some Mobile error parsing expects RFC-7807-style `detail`/`title` fields.

## 10. Proposed Rebuild Plan

### Phase 0: Contract and boundary decisions

- Confirm this audit and the API contract document.
- Supply/verify backend environment values, especially JWT signing key, Firebase settings, CORS, and Mobile base URL.
- Decide whether backend will add refresh/logout, password recovery, profile/preferences, and product endpoints before Mobile work begins.
- Reconcile Firebase email-link verification versus OTP wording.

### Phase 1: Mobile foundation

- Preserve current stack: Flutter, Cubit, Dio, secure storage, GetIt, and GoRouter.
- Correct the API envelope/error parser, strict DTO parsing, auth header policy, logging redaction, and route/session guard lifecycle.
- Establish an environment-specific base URL without an invalid production fallback.
- Add focused unit tests for network, storage, routing, and response/error contracts.

### Phase 2: Real authentication

- Implement splash/session restore, email/password login, traveler registration, Firebase verification synchronization, logout token deletion, and role-aware traveler routing using only verified BE behavior.
- Keep operator registration and reset/change password blocked or explicitly marked unavailable until BE contracts exist.

### Phase 3: Traveler account

- Implement profile, preferences, and settings only after BE endpoints, DTOs, authorization, and persistence are available.

### Phase 4: Travel planning

- Implement Explore/POI, itinerary, map, and weather only after endpoint ownership, data contracts, and external-provider policy are confirmed.

### Phase 5: Commercial workflows

- Implement booking and commercial services only after backend booking/payment contracts and authorization rules are present.

Each implementation phase must stop after code, tests, app/API verification, and a report for explicit confirmation.

## 11. Planned File Scope

Created by this audit only:

- `docs/mobile-rebuild-audit.md`
- `docs/mobile-api-contract.md`

Expected future edits, after approval and contract decisions:

- `lib/app/config/`, `lib/app/router/`, `lib/core/network/`, `lib/core/storage/`, and `lib/core/di/`.
- `lib/features/auth/` and focused auth tests.
- Later feature folders only when matching BE APIs exist.

No source file is proposed for deletion in this audit. Do not delete existing demo screens, tests, docs, generated/config files, or user-modified files until their replacement and scope are explicitly approved.

## 12. Confirmations Needed Before Coding

1. Should Mobile phase 2 support only email/password login plus Firebase verification, or must BE first provide a dedicated refresh/logout contract?
2. Is Firebase ID-token acquisition available and approved in the Flutter app for registration and verification?
3. Should the backend implement the missing product/auth endpoints before Mobile phases 3-5?
4. Is the intended verification UX Firebase email link or OTP? Current BE implements Firebase email verification, not OTP.
5. Which development/staging/production API base URLs and Firebase configuration should be used?
6. Should the existing local changes on this feature branch be treated as the starting implementation, or should they be reviewed and stabilized first?
