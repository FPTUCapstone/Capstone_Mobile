# 01 — Mobile Shells, Navigation Map, Journeys and Common Standards

> **Revision 2026-10-08 (QA).** Written on develop `af8daa0` before Report 3 V2 was available. **Still valid:** shell structure, common standards C-RESP/C-A11Y/C-STATE/C-TOKENS/C-AUTH/C-DEMO/C-BE, the master navigation map as a route proposal, journeys A–H. **Added by V2:** CR-01…CR-15 mapping, state set and copy rules in `13` §0; current journey gaps in `13` §5.1. **Stale statements in this file (corrected here, not rewritten below):**
> - §2.3 and §3: PR #24 is **merged**; `/traveler/trips/:id/live|alerts|offline` exist on develop.
> - §3 row 61: `/traveler/groups/:groupId/location-sharing` **exists** on develop (PR #27), no longer PROPOSED.
> - §2.4: the Operator shell now has **6** destinations (Dashboard, Tours, Bookings, Revenue, Coupons, Profile) since PR #29.
> - §2.2: the five Traveler tab labels are still Vietnamese on develop — CR-09 defect A-04; `13` S-44 gives the English labels.
> - §3 row 70: #70 has a V2 basis (Table 4.2 description; UC-28 alternative flow "Cancel the booking instead of paying").

> Design specification only. Route names marked `PROPOSED` do not exist in `AppRoutes` on `origin/develop` and are **not** Backend contracts.

## 1. Common Standards (referenced by every screen spec as `C-*`)

### C-RESP — responsive / device
- Design widths: **360×800**, **390×844**, **412×915**. Also verify 320 wide, text scale **200 %**, keyboard open, safe-area insets, Android 3-button and gesture navigation.
- No horizontal overflow. Long Vietnamese strings wrap or ellipsize; critical values (price, status, time) never ellipsize.
- Minimum touch target **48×48 dp**. Primary action never hidden behind system navigation or keyboard (use `SafeArea` + scrollable body + bottom action bar that rides above the keyboard).
- Bottom sheets: max height ~90 % of the viewport, internally scrollable, drag handle plus an explicit close button; primary action stays reachable at 200 % text.
- Orientation: portrait is the design target; landscape must not crash or clip (scrollable).

### C-A11Y — accessibility
- Every interactive control has a semantic label; icon-only buttons have tooltips.
- Status is conveyed by **icon + text + colour**, never colour alone (severity, availability, payment, ticket).
- Reading order follows visual order; screen titles are semantic headers.
- Dynamic updates (loading finished, error, success, reroute proposal) use a live region/announcement.
- Loading is announced ("Loading …"); errors announced with the recovery action name.
- Focus: after a dialog/sheet closes, focus returns to the control that opened it. Forms move focus to the first invalid field.
- Contrast: use existing `AppColors`; do not place `muted` text on `primarySoft` at small sizes without checking 4.5:1.

### C-STATE — loading / empty / error pattern
- Loading: `LoadingIndicator` (existing). Skeletons only where list height is known. No blocking spinner longer than the request.
- Empty: distinguishes **"no data"** from **"could not load"**. Empty states offer the next sensible action (e.g. "Search tours").
- Error: `ErrorView` / `AppAlert` with safe user text; never raw exception, stack trace, URL or token. Retry only for retryable failures: validation (400) → fix input; 401 → session handling (guard redirects to login with `from`); 403 → "not permitted", no retry; 404 → "not found", no retry; timeout on a **write** → "outcome unknown", check state before re-submitting (rules §16); 5xx/network on a read → Retry.
- Unknown outcome of a mutation never reports success.

### C-TOKENS — visual tokens
Material 3 with existing theme: `AppColors` (`primary`, `primarySoft`, `secondary`, `ink`, `muted`, `line`, `surface`, `success`, `warning`, `error`), `AppSpacing`, `AppTypography`. **No new colour/spacing tokens** unless a gap is recorded in `10-component-ownership-map.md`. Stitch colours/gradients are reference only and are mapped to these tokens, not copied.

### C-AUTH — auth / session
- `RouteGuards.redirect` is authoritative: unauthenticated → `/auth/login?from=<location>`; Traveler confined to `/traveler/*`, Operator to `/operator/*`; non-approved operator confined to `/operator/application`. New routes must live under the correct prefix to inherit this.
- Role of every screen is decided by the Backend-issued session role/status, never inferred locally.
- 401 on a data call → `AuthSessionCubit` invalidation path (`app_session_invalidation_test` covers it); screens must not implement their own logout.
- No Administrator screen exists on Mobile.

### C-DEMO — demo / production boundary
Demo data must be (a) explicit (`kDebugMode` or test-only), (b) visibly labelled `DEMO_ONLY`, (c) unreachable from production navigation, (d) never rendered as Backend-derived truth. A production screen without a Backend capability shows `UNAVAILABLE` / `PENDING_INTEGRATION`, not fabricated data or success.

### C-BE — Backend-ready sheet legend (A–U)
A Identity · B Read data · C Mutation intent · D Authoritative state owner · E Pagination · F Search · G Filter · H Sort · I Error states · J Authentication · K Authorization · L Device dependency · M Deep link · N Offline/cache · O Optimistic update (YES/NO) · P Backend capability missing · Q Design-only fields · R Retry semantics · S Refresh semantics · T Security-sensitive fields · U Persistence. Each missing/partial screen spec fills these in a `Backend Readiness` block. A `DESIGN_ONLY_FIELD` is shown only in a design preview and is **not** an implementation requirement; a field the SRS needs but BE cannot supply is tagged `BACKEND_SUPPORT_REQUIRED`.

## 2. Product shells

### 2.1 PUBLIC MOBILE SHELL
| Aspect | Specification |
|---|---|
| Routes | `/` (splash), `/auth/*`, `/explore`, `/explore/poi/:id`, `/explore/tours` (public, unguarded today) |
| Top app bar | title + back; on Home (#35) brand header with **Sign in** / **Register** actions |
| Bottom navigation | none (single-purpose pages) |
| Back | system back pops the stack; from a root public page exits app; from `/auth/*` returns to previous public page, never into a protected page |
| Primary navigation | Home (#35) → Explore POIs (#50), Search Tours (#63), Sign in (#36), Register (#38 / #40) |
| Secondary | Forgot password (#42) from Sign in |
| Notification entry | none |
| Account entry | Sign in / Register only |
| Page padding | `AppSpacing` page padding, `AppPageScaffold` |
| Loading boundary | per page (`LoadingIndicator`); splash while session restores |
| Error boundary | `ErrorView`; unknown route → "Page not found" (exists) |
| Empty | per list screen |
| Permission | location permission requested only when the user taps "Use my location" (#50) |
| Deep link | `/explore/poi/:id` is a valid public entry; unauthenticated invitation/QR entry for #62 must pass through sign-in and **return** (`from`) — `DEVICE_INTEGRATION_MISSING` for OS-level links |
| Keyboard | forms scroll; submit on `done`; no content hidden |
| Large text | forms reflow, no clipping of validation text |
| Transitions | platform default push; replace (not push) when moving from auth success to home |
| System back / session expiry | after sign-in success the stack is replaced; expiry on a public page does nothing |

### 2.2 TRAVELER MOBILE SHELL (exists: `TravelerShellPage`, `/traveler`)
Current tabs (5): **Trang chủ · Chuyến đi · Khám phá · Đặt chỗ · Hồ sơ**. Bodies are placeholders with buttons. Specified mapping:

| Tab | Root content | Reaches |
|---|---|---|
| Trang chủ (#44) | greeting from session `fullName`, resume/next-step cards that exist, quick actions | Planner #47, Tour search #63, Join group #62, Explore #50 |
| Chuyến đi | list capability is `BACKEND_SUPPORT_REQUIRED` (no itinerary/trip list endpoint, see 08) → until then show entry actions only | Planner #47, Suggested itinerary #48 (from a known id), Travel Groups #55, Trip History #73 |
| Khám phá | segmented: POIs (#50) / Tours (#63) / Recommendations (#64) | detail pages |
| Đặt chỗ | My Tour Bookings #68; **PENDING_INTEGRATION** until BE exists | #69, #70 |
| Hồ sơ | profile #45, preferences #46, security #43, settings, sign out (exists) | |

| Aspect | Specification |
|---|---|
| Top app bar | `Traveler · <tab>` (exists) + notification bell (opens #53 only when an active trip exists; otherwise hidden) + account menu |
| Bottom navigation | existing `NavigationBar` with 5 destinations; state kept (`IndexedStack`) |
| Back | on a tab root: system back exits the app (or returns to tab 0 first); in a pushed detail: pop |
| Notification entry | bell → #53 for active-trip alerts. Booking/payment/refund notifications have **no Backend source**; surface through booking detail state instead (see 06) |
| Account entry | Hồ sơ tab; sign out in settings (existing, `POST /auth/logout`) |
| Deep link | `/traveler/itineraries/:id`, `/traveler/groups/:id` exist; guard returns to `from` after login |
| Session expiry | guard redirects to login with `from`; after login return to same location |
| Others | follow C-RESP / C-STATE |

### 2.3 ACTIVE TRIP MOBILE SHELL (PROPOSED boundary for #49, #52–#54; implemented in PR #24 as separate pages)
| Aspect | Specification |
|---|---|
| Routes (PR #24) | `/traveler/trips/:itineraryId/live`, `/alerts`, `/offline` |
| Layout | full-screen map/route canvas; **no bottom navigation** |
| Top app bar | trip title (**real metadata by `itineraryId` or loading/error, never a default name**), GPS status pill, alerts bell with unread count (count source = alert source, absent today) |
| Back / system back | pops to #48 (Suggested Itinerary). Leaving does not end the trip; an explicit "End navigation" action is `SRS_TEXT_REQUIRED` |
| Persistent surfaces | GPS status, upcoming-stop banner, alert banner, reroute sheet |
| Loading boundary | itinerary metadata load before showing the canvas |
| Error boundary | itinerary not Active / not found / forbidden → error state with link back to #48 |
| Permission | location permission gate before navigation; denied → explanatory state + open settings |
| Deep link | `…/live` from a restored route must resolve the itinerary by id; no `state.extra` dependence |
| Keyboard | not applicable |
| Large text | banner text wraps, never truncates stop names |
| Session expiry | guard redirect; navigation state is not persisted locally unless an approved offline design says so |

### 2.4 TOUR OPERATOR MOBILE SHELL (exists: `OperatorShellPage`, `/operator`, approved operators only)
Current tabs (5): **Dashboard · Tours · Bookings · Revenue · Profile** (placeholders).

| Tab | Root | Reaches |
|---|---|---|
| Dashboard (#75) | summary cards (read-only, Backend-derived) + quick actions | Scan QR #88, Tours, Bookings |
| Tours | #77 list | #78, #79, #80 |
| Bookings | #84 list | #85, #86, #87; **Scan QR** primary action → #88 |
| Revenue | #89 | #90, #91, #92 |
| Profile | #76 | edit profile, coupons entry (#81–#83), security #43, sign out |

Coupons (#81–#83) have no tab; entry from Dashboard and Profile. All Operator screens share one app bar `Operator · <tab>`, one empty/error pattern and one confirmation-dialog component. Non-approved operator: guard confines to `/operator/application` (#41) — unchanged.

## 3. Master navigation map

`Status` = implementation status on `origin/develop` (PR #24 shown as OPEN). `Auth` Y/N. `Deep link` = can be a restored/direct entry.

| # | Screen | Route | Role | Shell | Primary entry | Back | Next | Alt | Deep link | Auth | Required context |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 35 | Home | `/` PROPOSED public home (today splash→login) | Guest | Public | app launch | exit | #36 | #50, #63, #38 | N | N | — |
| 36 | Sign In | `/auth/login` | Guest | Public | #35 | #35 | role home | #37, #42, #38 | N | N | `from` |
| 37 | Sign in with Google | `/auth/login` (action) | Guest | Public | #36 | #36 | role home | — | N | N | — |
| 38 | Traveler Registration | `/auth/register/traveler` | Guest | Public | #36 | #36 | #39 | — | N | N | — |
| 39 | Confirm Email | `/auth/verify-email` | Guest | Public | #38 | #38 | traveler home | resend | email-link | N | email |
| 40 | Operator Registration | `/auth/register/operator` | Guest | Public | #36 | #36 | #41 | — | N | N | — |
| 41 | Operator Application Status | `/operator/application` | Operator | Operator (confined) | login (non-approved) | sign out | operator home when approved | resubmit | Y | Y | session application status |
| 42 | Password Reset | `/auth/forgot-password` | Guest | Public | #36 | #36 | #36 | — | N | N | email |
| 43 | Change Password | `/traveler/security/password` and `/operator/security/password` PROPOSED | Traveler/Operator | Traveler / Operator | Profile | Profile | Profile | — | N | Y | — |
| 44 | Traveler Home | `/traveler` | Traveler | Traveler | login | exit | #47, #63, #62, #50 | — | N | Y | session |
| 45 | Profile | `/traveler/profile` | Traveler | Traveler | Hồ sơ tab | tab | #46 | #43 | N | Y | — |
| 46 | Preferences | `/traveler/preferences` | Traveler | Traveler | Hồ sơ tab | tab | #47 | — | N | Y | — |
| 47 | Planner | `/traveler/itineraries/create` | Traveler | Traveler | #44, Chuyến đi | tab | #48 | #51 (POI pick) | N | Y | start location, preferences |
| 48 | Suggested Itinerary | `/traveler/itineraries/result` (extra) · `/traveler/itineraries/:id` | Traveler | Traveler | #47 | #47/tab | #52, #49, #56 | #51 | detail: Y | Y | `itineraryId` |
| 49 | Offline Map & Itinerary | `/traveler/trips/:id/offline` (PR #24) | Traveler | Active Trip | #48 | #48 | — | — | restored route | Y | `itineraryId` |
| 50 | POI Explore | `/explore` | Guest/Traveler | Public | #35, Khám phá | exit/tab | #51 | filters | N | N | — |
| 51 | POI Details | `/explore/poi/:id` | Guest/Traveler | Public | #50, #48 | #50/#48 | — | add to plan | Y | N | `poiId` |
| 52 | Live Navigation | `/traveler/trips/:id/live` (PR #24) | Traveler | Active Trip | #48 | #48 | #53, #54 | — | restored route | Y | `itineraryId` (Active) |
| 53 | Trip Alerts | `/traveler/trips/:id/alerts` (PR #24) | Traveler | Active Trip | banner/bell | #52 | #54 | — | Y | Y | `itineraryId` |
| 54 | Re-routing Proposal | sheet over #52 (PR #24) | Traveler | Active Trip | alert/proposal | #52 | #52 | — | N | Y | proposal id |
| 55 | Travel Groups | `/traveler/groups` (constant exists, **no GoRoute**) | Traveler | Traveler | Chuyến đi | tab | #57 | #56, #62 | Y | Y | — |
| 56 | Create Group | `/traveler/groups/create` | Traveler | Traveler | #48 | #48 | #57 | — | N (needs extra) | Y | `itineraryId`, title |
| 57 | Group Details & Members | `/traveler/groups/:groupId` + `/members` | Traveler | Traveler | #55/#56/#62 | #55 | #58, #59, #60, #61 | — | Y | Y | `groupId`, role |
| 58 | Invite Members | `/traveler/groups/:groupId/invitation` | Traveler (host) | Traveler | #57 | #57 | — | share/QR | Y | Y | `groupId` |
| 59 | Remove Member Confirm | dialog in #57 | Traveler (host) | Traveler | #57 | #57 | #57 | — | N | Y | `groupId`, `memberId` |
| 60 | Leave Group Confirm | dialog in #57 | Traveler (member) | Traveler | #57 | #57 | #55 | — | N | Y | `groupId` |
| 61 | Location Sharing | `/traveler/groups/:groupId/location-sharing` PROPOSED (branch has `groupLocationSharing`) | Traveler | Traveler | #57 | #57 | #57 | — | Y | Y | `groupId` |
| 62 | Join Shared Trip | `/traveler/groups/join` | Traveler | Traveler | #44, Chuyến đi | prev | #57 | QR scan | invitation link `DEVICE_INTEGRATION_MISSING` | Y | invitation code |
| 63 | Search Tours | `/explore/tours` | Guest/Traveler | Public | #35, #44, Khám phá | exit/tab | #65 | #64 | N | N | filters |
| 64 | Tour Recommendations | `/traveler/tours/recommendations` PROPOSED | Traveler | Traveler | Khám phá | tab | #65 | — | N | Y | — |
| 65 | Tour Details | `/explore/tours/:tourId` PROPOSED (public) | Guest/Traveler | Public | #63, #64 | previous | #66 | — | Y | N (book needs auth) | `tourId` |
| 66 | Booking Confirmation | `/traveler/bookings/new` PROPOSED | Traveler | Traveler | #65 | #65 | #67 | — | N | Y | `tourId`, `scheduleId`, quantity, price |
| 67 | Electronic Payment | `/traveler/bookings/:bookingId/payment` PROPOSED | Traveler | Traveler | #66 | #66 | #69 | — | return deep link `DEVICE_INTEGRATION_MISSING` | Y | `bookingId` |
| 68 | My Tour Bookings | `/traveler/bookings` PROPOSED | Traveler | Traveler | Đặt chỗ tab | tab | #69 | — | N | Y | — |
| 69 | Booking Details & QR | `/traveler/bookings/:bookingId` PROPOSED | Traveler | Traveler | #68, #67 | #68 | #70, #74 | — | Y | Y | `bookingId` |
| 70 | Confirm Cancellation | modal in #69 | Traveler | Traveler | #69 | #69 | #69 | — | N | Y | `bookingId` |
| 71 | Commercial Services | `/traveler/services` PROPOSED | Traveler | Traveler | #48, #51 | prev | #72 | — | N | Y | POI/itinerary context |
| 72 | Service Details & Booking | `/traveler/services/:serviceId` PROPOSED | Traveler | Traveler | #71 | #71 | result | — | Y | Y | `serviceId` |
| 73 | Trip History | `/traveler/history` PROPOSED | Traveler | Traveler | Chuyến đi / Hồ sơ | tab | #74 | — | N | Y | — |
| 74 | Trip Review | `/traveler/history/:tripId/review` PROPOSED | Traveler | Traveler | #73 | #73 | #73 | — | N | Y | `tripId` |
| 75–92 | Operator screens | `/operator/...` PROPOSED (see `07`) | Operator | Operator | Operator tabs | tab | — | — | partial | Y | see `07` |

## 4. Product journeys (context to preserve between screens)

| Journey | Path | Context passed forward (kept in screen args / route params; **no new persistence mechanism is invented**) |
|---|---|---|
| **A Public/Auth** | Home → Sign In → Register → Confirm Email → Traveler Home; Forgot → Reset → Sign In; Operator: Register → Application Status → Pending/Approved/Rejected → Resubmit → Operator Home | `from`, email, session role/status |
| **B Traveler account** | Home → Profile → Preferences → Security (#43) | none beyond session |
| **C Planning** | Home → Planner → Suggested Itinerary → POI → back to itinerary | destination/start, time, budget, travellers, preferences, mandatory POIs (request), `itineraryId`, version, status |
| **D Active trip** | Suggested Itinerary → (Offline prep) or Start Navigation → Live → Alert → Reroute Proposal → explicit decision → continue | `itineraryId`, itinerary status Active, proposal status (pending → accepted / declined / expired, single decision) |
| **E Travel group** | Groups → Create / Details → Members → Invite → Remove → Leave → Location sharing; Invitation/QR → Join → Details | `groupId`, `itineraryId`, host flag, invite code |
| **F Tour commerce** | Search → Recommendations → Details → Booking → Payment → verified Booking/ticket → My Bookings → History → Review | `tourId`, `scheduleId`, quantity, displayed price, `bookingId`, payment state, ticket state |
| **G Commercial** | Itinerary/POI → Services → Detail → Booking → resulting booking state | POI/itinerary context, `serviceId`, option |
| **H Operator** | Dashboard → Profile / Tours (list→create→update→preview→submit) / Coupons / Bookings (list→detail→cancel→refund) / QR check-in / Revenue (analytics→export) / Payout (history→request) | `tourId`, `couponId`, `bookingId`, `ticket` read result, `payoutId` |

Rule for all journeys: an identifier shown to the user (booking number, status, price) is Backend-derived; if the Backend cannot supply it the screen shows `UNAVAILABLE`, never a client-made value.
