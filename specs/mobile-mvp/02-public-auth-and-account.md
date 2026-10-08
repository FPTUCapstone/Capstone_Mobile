# 02 — Public, Auth and Account (Screens #35–#46)

> **Revision 2026-10-08 (QA) — how to read this file.** Preservation records P-36, P-38, P-39, P-05 remain valid. The S-35, S-37, S-40, S-41, S-43, S-44, S-45, S-46 sections below remain the **structural design**; `13-v2-completion-specs.md` Part 1 adds the Report 3 V2 layer (fields, rules, messages, conflicts) and **replaces every `SRS_TEXT_REQUIRED` placeholder and every status line**. Where they disagree, `13` wins. Readiness per spec: `13` §6.
> **Stale statements below:** S-35 forbids featured content — V2 Table 4.2 requires trending tours/featured POIs (see `13` S-35, D-14). S-40 describes a demo licence picker and "Backend NONE" — develop now has the PR #34 wizard calling `/auth/register/operator` (BE PR #52 open); platform mismatch C-04. S-45's hard-coded identity finding is still true on develop (A-08); S-45 is `DESIGN_PARTIAL` pending D-15. P-42: the BE expires reset codes after 3 minutes while V2 BR-14 requires 15 (`00` C-07, `BACKEND_CONTRACT_GAP`); the copy must state no lifetime until the BE is corrected (`13` S-42, A-03).

Shared standards: `C-RESP`, `C-A11Y`, `C-STATE`, `C-TOKENS`, `C-AUTH`, `C-DEMO`, `C-BE` — see `01-mobile-shells-and-navigation.md` §1.
Status vocabulary and per-screen status: `09-mobile-mvp-screen-index.md`.

---

## Part 1 — EXISTING SCREEN PRESERVATION RECORDS (do not redesign from zero)

### P-36 Sign In (UC-04) — `MERGED_IMPLEMENTED`, `IMPLEMENTED_BE_INTEGRATED`
- Route `/auth/login` (`login_page.dart`), Cubit `AuthSessionCubit`, repository `AuthRepositoryImpl` → `AuthRemoteDataSource.login`.
- Tests: `auth_session_cubit_test`, `auth_remote_data_source_test`, `session_response_dto_test`, `route_guards_test`, `auth_interceptor_session_test`.

**BACKEND INTEGRATION CONTRACT**
- Screen/Route: #36 `/auth/login`
- API: `POST /api/v1/auth/login` · Auth required: none (anonymous); optional Firebase bearer may be attached by the data source
- Request: `{ email, password }`
- Response (keys parsed): `userId, status, role, accessToken, refreshToken, email, fullName, accessTokenExpiresAtUtc`, operator sessions also `applicationStatus`
- Status/Enum mapping: role `Traveler | TourOperator | Administrator`; status `PendingEmailVerification | Active | Locked | PendingApproval | Rejected | Inactive`; `applicationStatus` → `TourOperatorApplicationStatus` (`pendingApproval`, `rejected`, `approved`, unresolved fails closed)
- Validation/errors: client validators + `ErrorMapper` (e.g. invalid credentials 401, unverified 403, locked/inactive 403, validation 400, 5xx generic). Messages from `docs/mobile-api-contract.md` (stale — re-verify against `ErrorMapper` before relying on codes)
- Mutation: creates session; tokens persisted via secure-storage abstraction; sign-out `POST /api/v1/auth/logout {refreshToken}`
- Pagination/Upload/Deep link/Caching: none; return location via `from` query parameter (relative paths only, validated by `_safeReturnLocation`)
- Device: secure storage
- Components: `AuthSessionCubit`, `AuthRepositoryImpl`, `AuthRemoteDataSource`, `RouteGuards`
- **INTEGRATION CONTRACT: FROZEN**
- Safe to change: layout, spacing, typography, illustration, copy tone, field decoration, Stitch-inspired visuals (`ng_nh_p_tripmate_mobile`).
- MUST NOT change: request fields, role/status mapping, token storage, route guard behaviour, `from` sanitisation, error-to-message mapping semantics.

### P-38 Traveler Registration (UC-01) — `MERGED_IMPLEMENTED`
- Route `/auth/register/traveler`; `RegisterCubit`; data source `registerTraveler`; requires Firebase ID token.

**BACKEND INTEGRATION CONTRACT**
- API: `POST /api/v1/auth/register` · Auth: `Authorization: Bearer <Firebase ID token>`
- Request: `{ fullName, email, password, phoneNumber, acceptedTerms }` (no `confirmPassword` on the wire)
- Response: `{ userId, email, fullName, role, status, emailSent, messageCode }`; the page rejects any status other than `PendingEmailVerification` as an authenticated session
- Validation: see `docs/auth-validation-contract.md` (password 8–72 with upper/lower/digit/special; phone `^0\d{9}$` when supplied; terms must be true)
- Components: `RegisterCubit`, `AuthRemoteDataSource`, `AuthIdentityService` (Firebase)
- **FROZEN.** Safe: visuals (`ng_k_t_i_kho_n_traveler_tripmate_mobile`), step grouping, helper text. Must not change: Firebase-token requirement, field names, pending-status handling.

### P-39 Confirm Email (UC-01) — `MERGED_IMPLEMENTED`
- Route `/auth/verify-email`; `verify_email_page.dart`; test `verify_email_page_test`.

**BACKEND INTEGRATION CONTRACT**
- API: `POST /api/v1/auth/verify-email` · no body · Auth: Firebase bearer (after email-link verification)
- Response: session DTO (tokens issued only when verified). Errors: unverified email, invalid/expired token.
- **FROZEN.** Safe: visuals, resend/countdown presentation. Must not change: Firebase email-link semantics (not OTP), token persistence.

### P-42 Password Reset (UC-06) — `MERGED_IMPLEMENTED`
- Route `/auth/forgot-password`; `PasswordRecoveryCubit`; `password_recovery/*`; tests exist for data source, models, repository, cubit, page.

**BACKEND INTEGRATION CONTRACT**
- API: `POST /api/v1/auth/password-reset/request` `{ email }` and `POST /api/v1/auth/password-reset/confirm` `{ email, code, newPassword }` · Auth: none (`skipAuth`)
- **FROZEN.** Safe: visuals (`kh_i_ph_c_i_m_t_kh_u_tripmate_mobile`), step layout. Must not change: two-step contract, code field name, no auto-login after reset unless BE changes.

### P-05 Sign Out (UC-05) — `MERGED_IMPLEMENTED`
Action in settings (`traveler_settings_page`) and operator app bar → `POST /api/v1/auth/logout {refreshToken}` + local clean-up (failure notice `signOutLocalCleanupFailureMessage`). **FROZEN.**

---

## Part 2 — DESIGN SPECIFICATIONS FOR MISSING / PARTIAL SCREENS

### S-35 Home Page

- **Screen Index:** 35 · **UC:** none owns Home; it is the public entry to UC-12, UC-24, UC-01, UC-04, UC-02
- **Screen Name:** Home Page · **Domain:** Public · **Role:** Guest · **Platform:** Mobile (R3 Mobile Screen Index)
- **Presentation Type:** FULL_PAGE · **Route:** `/` PROPOSED public home (today `/` = splash → login) · **Parent Shell:** Public
- **Implementation Status:** NOT_STARTED · **Implementation Nature:** NOT_STARTED · **Backend Integration:** NONE (no public landing endpoint; landing content authoring is UC-66, Admin Web) · **UI Design Permission:** FULL · **Backend Contract Status:** `NO_CONTRACT_NEEDED` for navigation-only content
- **Previous Screen:** app launch / splash · **Next Screen:** #36 Sign In · **Alternative Destinations:** #38 Register, #40 Operator register, #50 Explore POIs, #63 Search Tours
- **Entry Points:** cold start when no valid session; sign-out result; session expiry on a public page
- **Entry Conditions:** unauthenticated. Authenticated users are redirected by `RouteGuards` to their role home
- **Exit Conditions:** navigates to any entry above; after sign-in the stack is replaced
- **User Goal:** understand TripMate and reach discovery or sign-in in one tap
- **Page Header:** brand mark + "Sign in" text button (top right)
- **Layout:** single scroll column: hero → primary CTAs → discovery shortcuts → partner CTA → footer
- **Sections:** (1) Hero with product line (static copy) (2) CTA row: **Sign in** (primary), **Create account** (secondary) (3) "Explore" cards: Places (→#50), Tours (→#63) (4) "Become a partner" card (→#40) (5) footer links (terms/support are static text only)
- **Components:** `AppPageScaffold`, `AppButton`, feature-local `HomeShortcutCard`, existing `StatusBadge` not needed
- **Primary Action:** Sign in · **Secondary Actions:** Create account, Explore Places, Search Tours, Become a partner
- **Navigation:** `context.go/push` named routes; no bottom navigation
- **Displayed Data:** static copy only. **No** featured tours, ratings, counts or images from fabricated data. `DESIGN_ONLY_FIELD`: featured/popular content — `BACKEND_SUPPORT_REQUIRED` (no public content endpoint)
- **Form Inputs:** none · **Validation:** none
- **Loading State:** none (static); splash covers session restore
- **Empty State:** n/a · **Error State:** n/a (no network on this page)
- **Success State:** n/a
- **Dialogs / Sheets:** none
- **Offline State:** fully usable; shortcuts that need network show their own error on arrival
- **Permission State:** none
- **Responsive / Device Sizes:** C-RESP; hero scales, CTA row stacks vertically below 360 wide or at 200 % text
- **Accessibility:** C-A11Y; hero image decorative (`excludeFromSemantics`), headings semantic
- **Reusable Components:** `AppPageScaffold`, `AppButton` · **Unique Components:** `HomeShortcutCard`
- **Visual Tokens:** C-TOKENS (Stitch landing visuals are reference only)
- **Context Received:** none · **Context Passed Forward:** none (the `from` param is set by guards, not by Home)
- **Backend Readiness (C-BE):** A none · B none · C none · D n/a · E–H none · I none · J none · K none · L none · M none · N static · O NO · P none · Q featured content · R n/a · S n/a · T none · U none
- **Authoritative State Owner:** none · **Required Backend Capability:** none
- **Device Dependencies:** none · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** no demo content in production
- **Design-only Assumptions:** hero imagery and tagline text
- **Implementation Notes:** requires a router decision (not made here): `RouteGuards` currently maps `splash → login` for unauthenticated users; moving to Home is a guard change that needs `route_guards_test` updates. Out of scope for this task.
- **Non-goals:** personalised recommendations, promotions, partner marketing content
- **Acceptance Criteria:** AC1 unauthenticated launch shows Home with no fabricated data; AC2 each shortcut reaches its real screen; AC3 authenticated launch never shows Home; AC4 no overflow at 360/390/412 and 200 % text; AC5 all controls ≥48 dp with labels.

### S-37 Sign in with Google (missing part only)

- **Screen Index:** 37 · **UC:** UC-04 (alternative path) · **Screen Name:** Sign in with Google · **Domain:** Auth · **Role:** Guest · **Platform:** Mobile
- **Presentation Type:** ACTION + STATE on #36 · **Route:** `/auth/login` (button "Continue with Google") · **Parent Shell:** Public
- **Implementation Status:** MERGED_PARTIAL · **Implementation Nature:** PARTIAL_BE_INTEGRATION · **Backend Integration:** PARTIAL · **UI Design Permission:** MISSING_PART_ONLY · **Backend Contract Status:** `POST /api/v1/auth/google` verified; client Firebase/Google provider flow is configuration-dependent (`UnavailableFirebaseAuthService` is bound when Firebase is not configured)
- **Previous Screen:** #36 · **Next Screen:** role home · **Alternative Destinations:** #36 (cancel), #41 (operator not approved)
- **Entry Points:** button on #36 · **Entry Conditions:** Firebase configured on this build · **Exit Conditions:** session created, or user cancelled, or error shown
- **User Goal:** sign in with an existing Google account
- **Page Header / Layout / Sections / Components:** unchanged button on #36; add the missing states below
- **Primary Action:** Continue with Google · **Secondary Actions:** back to email sign-in
- **Navigation:** same as #36 · **Displayed Data:** none
- **Form Inputs / Validation:** none
- **Loading State:** button shows progress, other sign-in controls disabled (single in-flight intent)
- **Empty State:** n/a
- **Error State (missing part):** (a) **provider unavailable** — when `AuthIdentityFailure.unavailable`: show "Google sign-in is not available on this build" and disable or hide the button; never imply the user's account is at fault (b) **user cancelled** — silent return, no error banner (c) token/BE errors mapped through existing `ErrorMapper`; `AUTH_TOKEN_MISSING`/invalid → "Google sign-in failed, try again" (d) operator not approved → handled by guard (#41)
- **Success State:** session established → guard routes by role/status
- **Dialogs / Sheets:** none
- **Offline State:** failure with retry (read-style retry is safe: the call has no side effect before BE accepts the token)
- **Permission State:** none (OS account chooser)
- **Responsive / Accessibility:** C-RESP, C-A11Y; announce "Signing in with Google" and failures
- **Reusable / Unique Components:** `AppButton`, `AppAlert`; none new
- **Visual Tokens:** C-TOKENS
- **Context Received:** `from` · **Context Passed Forward:** session
- **Backend Readiness (C-BE):** A Firebase/Google ID token · B session DTO · C sign-in · D Backend (JWT issuer) · E–H none · I per `ErrorMapper` · J anonymous + bearer token · K n/a · L Google account chooser / Firebase · M none · N none · O NO · P none for the call; **provider-link policy for existing email accounts is BE-owned (`SRS_TEXT_REQUIRED`)** · Q none · R retry safe · S n/a · T ID token, access/refresh tokens (secure storage only, never logged) · U secure storage
- **Authoritative State Owner:** Backend · **Required Backend Capability:** none new
- **Device Dependencies:** Firebase/Google Sign-In SDK · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** no visual-only Google flow in production
- **Design-only Assumptions:** none · **Implementation Notes:** keep frozen contract of P-36/P-37; the only change is states/copy.
- **Non-goals:** phone/OTP login (BE verifies Firebase email link, not OTP), account linking UI
- **Acceptance Criteria:** AC1 unavailable provider disables button with explanation; AC2 cancel produces no error; AC3 one in-flight sign-in at a time; AC4 no tokens in logs; AC5 contract unchanged.

### S-40 Tour Operator Registration & Verification

- **Screen Index:** 40 · **UC:** UC-02 · **Screen Name:** Tour Operator Registration & Verification · **Domain:** Auth/Operator · **Role:** Guest → Tour Operator · **Platform:** SHARED (Mobile + Web)
- **Presentation Type:** FULL_PAGE (multi-step) · **Route:** `/auth/register/operator` · **Parent Shell:** Public
- **Implementation Status:** MERGED_PARTIAL · **Implementation Nature:** IMPLEMENTED_UI_ONLY (local state, `selectDemoLicence`, "Mock selection") · **Backend Integration:** NONE · **UI Design Permission:** MISSING_PART_ONLY (truthfulness first, then visual) · **Backend Contract Status:** `BACKEND CAPABILITY REQUIRED` — operator account/application submission does not exist in BE develop
- **Previous Screen:** #36 · **Next Screen:** #41 · **Alternative Destinations:** #36 sign in
- **Entry Points:** "Become a partner" on #35/#36 · **Entry Conditions:** unauthenticated · **Exit Conditions:** submitted application → #41; or cancel
- **User Goal:** apply for a Tour Operator account with business information and verification documents
- **Page Header:** "Partner registration" + step indicator (n of N)
- **Layout:** stepper (account → business → documents → review). Visual reference: `ng_k_i_t_c_l_h_nh_tripmate_partner`
- **Sections (semantic, exact fields `SRS_TEXT_REQUIRED`):** account identity (email, password, terms) · business identity (business/company name, registration or tax identity, address, contact person, phone) · verification documents (licence) · review & submit. All field names above are `DESIGN_ONLY_FIELD` and `BACKEND_SUPPORT_REQUIRED`
- **Components:** `AppTextField`, `AppPasswordField`, `AppButton`, `AppAlert`, `StatusBadge`; NEW_SHARED `StepProgressHeader`; feature-local `DocumentPickerTile`
- **Primary Action:** Continue / Submit application · **Secondary Actions:** Back, Save-nothing (no draft persistence is invented)
- **Navigation:** step-internal back; system back asks to discard entered data
- **Displayed Data:** user input only
- **Form Inputs / Validation:** per step; reuse `validators.dart` (email, password per `auth-validation-contract.md`); document type/size limits are `SRS_TEXT_REQUIRED` — the existing demo hint "PDF or JPG, up to 10 MB" must not be presented as a real rule
- **Loading State:** submit progress, controls disabled
- **Empty State:** n/a
- **Error State:** field errors kept on the field; server errors via `AppAlert`; **unavailable** state when the capability is missing (see Production behaviour)
- **Success State:** only after Backend confirms creation → navigate to #41. Never a locally simulated "Pending Approval"
- **Dialogs / Sheets:** discard-changes confirm; document source sheet
- **Offline State:** submit disabled with message; entered data kept in memory only
- **Permission State:** file/camera/photo access when a picker is introduced (`DEVICE_INTEGRATION_MISSING`)
- **Responsive / Accessibility:** C-RESP, C-A11Y; stepper announced ("Step 2 of 4")
- **Reusable / Unique Components:** reuse form fields; unique `DocumentPickerTile`
- **Visual Tokens:** C-TOKENS
- **Context Received:** none · **Context Passed Forward:** none beyond Backend-created application (status read by #41 from session)
- **Backend Readiness (C-BE):** A none before submit; after: user/application identity (BE) · B n/a · C submit operator application with documents · D Backend · E–H none · I validation, duplicate email, upload rejected, too large, 5xx · J anonymous (new account) · K n/a · L file/image picker, camera · M none · N none · O NO · P **operator registration + document upload capability missing** · Q all business/document fields · R retry only for network failure; ambiguous timeout → check status before resubmitting · S n/a · T password, identity documents (PII) — never logged, never cached beyond upload · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_REGISTRATION_CONTRACT_MISSING`, `OPERATOR_DOCUMENT_UPLOAD_CONTRACT_MISSING`
- **Device Dependencies:** file/image picker (none present) · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** `_DemoLicencePicker` / `selectDemoLicence` is `INVALID_PRODUCTION_FIXTURE`; must be test/debug only. **Recommended current production behaviour:** `UI_ONLY_WITH_DISABLED_MUTATION` — show the form, disable Submit, banner "Operator registration is not available in the app yet"
- **Design-only Assumptions:** step count, field list, document types
- **Implementation Notes:** keep `OperatorApplicationCubit` shape; replace simulated success with a repository call when BE exists; do not add the packages until approved.
- **Non-goals:** admin approval UI (Admin Web), document viewing by others
- **Acceptance Criteria:** AC1 production never shows "Pending Approval" without a Backend response; AC2 no demo file picker outside debug/test; AC3 disabled-mutation banner explains why; AC4 field errors stay on fields; AC5 no PII in logs.

### S-41 Operator Application Status (missing part only)

- **Screen Index:** 41 · **UC:** UC-03 (resubmit), status display for UC-02 · **Role:** Tour Operator (non-approved) · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/operator/application` · **Parent Shell:** Operator (confined)
- **Implementation Status:** MERGED_PARTIAL · **Implementation Nature:** PARTIAL_BE_INTEGRATION (status from BE session; resubmit simulated) · **Backend Integration:** PARTIAL · **UI Design Permission:** MISSING_PART_ONLY · **Backend Contract Status:** status read verified (`applicationStatus` in login/session response); resubmit/reason contract missing
- **Previous Screen:** #36 (via guard) · **Next Screen:** `/operator` when approved · **Alternative Destinations:** sign out, resubmit (rejected only)
- **Entry Points:** guard for any non-approved operator · **Entry Conditions:** role TourOperator, status ≠ approved · **Exit Conditions:** approved → operator home; sign out
- **User Goal:** know application state and act on a rejection
- **Page Header:** "Application status" · **Layout:** status card + guidance + actions. Visual reference: `tr_ng_th_i_h_s_n_p_l_i_tripmate_partner`
- **Sections:** status badge (Pending / Rejected / unresolved) · what happens next (neutral text) · rejection reason (**`BACKEND_SUPPORT_REQUIRED`**, not in session) · Resubmit (rejected only) · Sign out
- **Components:** `StatusBadge` (icon+text), `AppAlert`, `AppButton`
- **Primary Action:** Resubmit (rejected) / Refresh status (pending) · **Secondary Actions:** Sign out, Contact support (**no number invented**; static text only if SRS provides)
- **Navigation:** guard owned; no back to workspace
- **Displayed Data:** status from session only. Pending/Rejected copy must not say "demo" or claim documents were uploaded
- **Form Inputs:** resubmission form = same fields as S-40 (semantic) · **Validation:** as S-40
- **Loading/Empty/Error/Success:** C-STATE; "status unresolved" fails closed (already tested by `operator_application_unresolved_test`); success only after BE confirms resubmission
- **Dialogs / Sheets:** confirm resubmit
- **Offline State:** last known status shown labelled "may be out of date"; no mutation offline
- **Permission State:** as S-40
- **Responsive / Accessibility:** C-RESP, C-A11Y; status announced
- **Reusable / Unique Components:** reuse; none new
- **Visual Tokens:** C-TOKENS (warning for pending, error for rejected — always with icon + text)
- **Context Received:** session `applicationStatus` · **Context Passed Forward:** none
- **Backend Readiness (C-BE):** A user id from session · B application status, rejection reason · C resubmit · D Backend · E–H none · I 401/403/409 (not resubmittable) · J Traveler? no — TourOperator JWT · K only own application · L file picker · M none · N last known status · O NO · P **resubmission, rejection reason, refresh endpoint** · Q reason text · R refresh safe, resubmit needs idempotency decision (BE) · S pull-to-refresh re-reads session/status source — **source is BE-owned, undefined** · T documents · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_APPLICATION_STATUS_REFRESH_MISSING`, `OPERATOR_RESUBMISSION_CONTRACT_MISSING`
- **Device Dependencies:** file picker · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** verified in `operator_application_cubit.dart`: `submit()` fakes success with `Future.delayed(500 ms)` then emits `pending`, and the cubit defaults to a `rejected` state carrying a made-up file name a fabricated licence file name. Remove the simulated transition, the fake file names and the "simulated locally" copy from production; keep them in tests only
- **Design-only Assumptions:** resubmit limit/cooldown (`SRS_TEXT_REQUIRED`)
- **Implementation Notes:** preserve guard semantics and `applicationStatus` mapping (frozen).
- **Non-goals:** approval/rejection actions (Admin Web)
- **Acceptance Criteria:** AC1 no simulated state in production; AC2 unresolved status fails closed; AC3 resubmit disabled until BE capability; AC4 sign out always available; AC5 status never colour-only.

### S-43 Change Password

- **Screen Index:** 43 · **UC:** UC-07 · **Screen Name:** Change Password · **Domain:** Account · **Role:** Traveler, Tour Operator (Admin excluded on Mobile) · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/traveler/security/password` and `/operator/security/password` PROPOSED · **Parent Shell:** Traveler / Operator
- **Implementation Status:** NOT_STARTED (an earlier local demo was removed from develop) · **Implementation Nature:** NOT_STARTED · **Backend Integration:** NONE · **UI Design Permission:** FULL · **Backend Contract Status:** `BACKEND CAPABILITY REQUIRED` — no change-password endpoint in BE develop
- **Previous Screen:** #45 Profile / settings · **Next Screen:** back to settings · **Alternative Destinations:** #42 (forgot current password → sign out first)
- **Entry Points:** Hồ sơ tab → Security · **Entry Conditions:** authenticated · **Exit Conditions:** success or cancel
- **User Goal:** replace the account password with a new one
- **Page Header:** "Change password" · **Layout:** single form card + policy checklist
- **Sections:** current password · new password (+ policy hints) · confirm new password · submit
- **Components:** `AppPasswordField` ×3, `AppButton`, `AppAlert`; feature-local `PasswordPolicyChecklist`
- **Primary Action:** Change password · **Secondary Actions:** Cancel
- **Navigation:** pop on cancel/success
- **Displayed Data:** none from Backend
- **Form Inputs:** `currentPassword`, `newPassword`, `confirmPassword` (confirm is client-side only) — names are presentation names, **not transport fields**
- **Validation:** new password per `docs/auth-validation-contract.md` (8–72, upper, lower, digit, special); new ≠ current; confirm matches; show errors on fields, keep input on failure
- **Loading State:** submit in progress, fields disabled · **Empty State:** n/a
- **Error State:** wrong current password, policy violation, 401 (session), network; errors on the matching field; never reveal whether an account exists
- **Success State:** only after Backend confirms. Post-success session handling (token rotation / forced re-login) is **BE-owned and unknown** → `BACKEND_SUPPORT_REQUIRED`; UI must follow what BE returns
- **Dialogs / Sheets:** discard changes confirm
- **Offline State:** submit disabled
- **Permission State:** none
- **Responsive / Accessibility:** C-RESP, C-A11Y; show/hide toggles labelled; password managers allowed (autofill hints)
- **Reusable / Unique Components:** reuse fields; unique `PasswordPolicyChecklist`
- **Visual Tokens:** C-TOKENS
- **Context Received:** session · **Context Passed Forward:** none
- **Backend Readiness (C-BE):** A user from token (never from body) · B none · C change password · D Backend · E–H none · I 400 policy, 401, 403, 429? (`SRS_TEXT_REQUIRED`), 5xx · J JWT · K own account only · L none · M none · N none · O NO · P **endpoint missing** · Q none · R safe retry only for network failure before a response · S n/a · T all three passwords, never logged/persisted · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `CHANGE_PASSWORD_CONTRACT_MISSING` (semantic: authenticated user supplies current and new password; result indicates success and session effect)
- **Device Dependencies:** none · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** entry hidden or disabled with "not available yet" until BE exists; no fake success
- **Design-only Assumptions:** policy hint wording
- **Implementation Notes:** FE Web UC-07 is in the same state; align semantics with Web when BE defines them.
- **Non-goals:** forgot-password (exists as #42)
- **Acceptance Criteria:** AC1 no success without Backend confirmation; AC2 passwords never logged; AC3 field-level errors keep input; AC4 inputs ≥48 dp, labelled; AC5 entry hidden/disabled until capability exists.

### S-44 Traveler Home / Dashboard

- **Screen Index:** 44 · **UC:** none owns the dashboard (entry to UC-10/12/23/24) · **Role:** Traveler · **Platform:** Mobile
- **Presentation Type:** FULL_PAGE (tab root) · **Route:** `/traveler` · **Parent Shell:** Traveler (tab "Trang chủ")
- **Implementation Status:** PLACEHOLDER (`_TravelerDestination` body: title + buttons) · **Implementation Nature:** IMPLEMENTED_UI_ONLY · **Backend Integration:** NONE for dashboard data (buttons lead to real flows) · **UI Design Permission:** FULL · **Backend Contract Status:** no dashboard endpoint exists
- **Previous Screen:** login · **Next Screen:** #47 / #63 / #62 / #50 · **Alternative Destinations:** other tabs
- **Entry Points:** after sign-in, tab 0 · **Entry Conditions:** Traveler session · **Exit Conditions:** navigation
- **User Goal:** start the next useful action quickly
- **Page Header:** greeting using session `fullName` (real) · **Layout:** quick-action grid + "continue" area + discover strip
- **Sections:** (1) greeting (2) Quick actions: Plan a trip (#47), Search tours (#63), Join a group (#62), Explore places (#50) (3) "Continue" area — shows a resume card **only** when a real source exists (none today; hidden, not stubbed) (4) Discover: shortcuts to #50/#63
- **Components:** `AppPageScaffold`, `AppButton`, `StatusBadge`; feature-local `QuickActionTile`
- **Primary Action:** Plan a trip · **Secondary Actions:** other quick actions
- **Navigation:** named routes; tab bar persists
- **Displayed Data:** `fullName` from session; nothing else. `DESIGN_ONLY_FIELD`: upcoming trip, active-trip banner, booking reminders, recommendations — each `BACKEND_SUPPORT_REQUIRED`
- **Form Inputs / Validation:** none
- **Loading:** only session restore · **Empty:** quick actions always visible · **Error:** n/a · **Success:** n/a
- **Dialogs / Sheets:** none · **Offline:** page works; destinations show own errors
- **Permission State:** none · **Responsive / Accessibility:** C-RESP, C-A11Y (tiles are buttons with labels)
- **Reusable / Unique Components:** reuse; unique `QuickActionTile`
- **Visual Tokens:** C-TOKENS
- **Context Received:** session · **Context Passed Forward:** none
- **Backend Readiness (C-BE):** A user · B none now; future: next trip / active trip / reminders · C none · D Backend · E–H none · I n/a · J JWT · K Traveler · L none · M none · N n/a · O NO · P **trip list / active trip / reminders endpoints** · Q resume card, banners · R n/a · S pull-to-refresh only when real data exists · T none · U none
- **Authoritative State Owner:** Backend for any future card · **Required Backend Capability:** `TRAVELER_TRIP_LIST_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep-Link Behavior:** `/traveler` is the post-login default
- **Demo / Production Boundary:** no fake upcoming trip or recommendations
- **Design-only Assumptions:** tile order and icons
- **Implementation Notes:** keep `NavigationBar` and `IndexedStack`; replace placeholder body only.
- **Non-goals:** analytics, promotions
- **Acceptance Criteria:** AC1 shows only real data (name) plus navigation; AC2 each tile reaches its screen; AC3 role boundary unchanged; AC4 no overflow at 200 % text.

### S-45 Traveler Profile (missing part: truthfulness + integration boundary)

- **Screen Index:** 45 · **UC:** UC-08 · **Role:** Traveler · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/traveler/profile` · **Parent Shell:** Traveler (Hồ sơ)
- **Implementation Status:** MERGED_PARTIAL · **Implementation Nature:** IMPLEMENTED_UI_ONLY / LOCAL_ONLY ("Profile changes saved locally for the demo", "Phone verification simulated locally") · **Backend Integration:** NONE · **UI Design Permission:** MISSING_PART_ONLY (+ VISUAL) · **Backend Contract Status:** `BACKEND CAPABILITY REQUIRED` — no traveler profile endpoint
- **Previous Screen:** Hồ sơ tab · **Next Screen:** #46 Preferences · **Alternative Destinations:** #43 Security, sign out
- **Entry Points:** Hồ sơ tab · **Entry Conditions:** Traveler · **Exit Conditions:** pop
- **User Goal:** view and edit personal details
- **Page Header:** "Profile" · **Layout:** avatar header + details list + edit form. Visual reference: `ch_nh_s_a_h_s_c_nh_n_tripmate_mobile`
- **Sections:** identity (name, email — email read-only from session) · contact (phone) · personal (birth date, city) · account actions
- **Components:** `AppTextField`, `AppButton`, `StatusBadge`, NEW_SHARED `Avatar`
- **Primary Action:** Save changes (**disabled in production until BE**) · **Secondary Actions:** Cancel
- **Navigation:** pop
- **Displayed Data:** session `fullName`, `email` are real. Phone/birth date/city: `DESIGN_ONLY_FIELD` + `BACKEND_SUPPORT_REQUIRED` (no source)
- **Form Inputs / Validation:** reuse registration validators (name 2–150 letters/spaces; phone `^0\d{9}$`); birth date not future
- **Loading/Empty/Error:** C-STATE; empty profile fields show "Not provided"
- **Success State:** **only after Backend confirms**. The current local success snackbar must not appear in production
- **Dialogs / Sheets:** discard-changes confirm; phone verification (UC-08 detail `SRS_TEXT_REQUIRED`)
- **Offline State:** read-only
- **Permission State:** photo access if avatar upload exists (`DEVICE_INTEGRATION_MISSING`, `SRS_TEXT_REQUIRED`)
- **Responsive / Accessibility:** C-RESP, C-A11Y
- **Reusable / Unique Components:** reuse; NEW_SHARED `Avatar`
- **Visual Tokens:** C-TOKENS
- **Context Received:** session · **Context Passed Forward:** none
- **Backend Readiness (C-BE):** A user from token · B profile fields · C update profile · D Backend · E–H none · I 400 field errors, 401, 409 (phone in use?) `SRS_TEXT_REQUIRED` · J JWT · K own profile · L none/photo · M none · N cache last read, marked stale · O NO · P **profile read/update** · Q phone/birth/city/avatar · R retry on network only · S pull-to-refresh once readable · T phone, birth date (PII) · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRAVELER_PROFILE_CONTRACT_MISSING`
- **Device Dependencies:** none (photo later) · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** `INVALID_PRODUCTION_FIXTURE` — local save toast and simulated phone verification. Recommended current behaviour: `UI_ONLY_WITH_DISABLED_MUTATION` + read-only session data
- **Design-only Assumptions:** field set and avatar
- **Implementation Notes:** verified in `traveler_profile_page.dart:16-19`: the form is pre-filled with hard-coded identity constants (a sample full name, phone number, date of birth and city — values intentionally not reproduced here) shown as if they were the signed-in user's data. This is a worse leak than the "saved locally" toast: production must show only real session data (`fullName`, `email`) and "Not provided" for fields with no source.
- **Non-goals:** KYC/identity documents
- **Acceptance Criteria:** AC1 no success message without Backend; AC2 no hard-coded profile values shown as real; AC3 email read-only from session; AC4 disabled Save explains why; AC5 field errors preserved.

### S-46 Travel Preferences (missing part)

- **Screen Index:** 46 · **UC:** UC-09 · **Role:** Traveler · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/traveler/preferences` · **Parent Shell:** Traveler
- **Implementation Status:** MERGED_PARTIAL · **Implementation Nature:** LOCAL_ONLY — `TravelPreferencesCubit()` is created per route entry, so even local state is **lost when the page closes**, yet the UI says "saved locally for demo" · **Backend Integration:** NONE · **UI Design Permission:** MISSING_PART_ONLY · **Backend Contract Status:** `BACKEND CAPABILITY REQUIRED` — no preferences endpoint in BE develop (an unmerged BE branch `feature/phuctv-tm213-traveler-preference-profile` exists; contract unverified)
- **Previous Screen:** #45 / Hồ sơ · **Next Screen:** #47 Planner · **Alternative Destinations:** none
- **Entry Points:** Hồ sơ tab, optionally Planner · **Entry Conditions:** Traveler · **Exit Conditions:** pop
- **User Goal:** tell TripMate interests and constraints for better itineraries
- **Page Header:** "Travel preferences" · **Layout:** chip groups + toggles. Visual reference: `s_th_ch_du_l_ch_tripmate`
- **Sections:** interests (beach, heritage, museum, local food, nature, nightlife — **local enum, not a BE catalogue**) · pace/budget/transport (only as the SRS defines `SRS_TEXT_REQUIRED`)
- **Components:** `FilterChip`/choice chips, `AppButton`, `AppAlert`
- **Primary Action:** Save (disabled until BE) · **Secondary Actions:** Reset
- **Navigation:** pop · **Displayed Data:** user selections only. **Catalogue/category IDs must come from an authoritative source** (rules §34, L20): the interest list is `DESIGN_ONLY_FIELD` / `BACKEND_SUPPORT_REQUIRED`
- **Form Inputs / Validation:** at least the SRS-required minimum `SRS_TEXT_REQUIRED`
- **Loading/Empty/Error/Success:** C-STATE; success only after Backend confirms
- **Dialogs / Sheets:** discard confirm · **Offline:** read-only · **Permission:** none
- **Responsive / Accessibility:** C-RESP, C-A11Y; selected state = icon + text, not colour only
- **Reusable / Unique Components:** reuse chips; none new
- **Visual Tokens:** C-TOKENS
- **Context Received:** none · **Context Passed Forward:** preferences used by Planner (#47) **only after** a BE-owned source exists
- **Backend Readiness (C-BE):** A user from token · B preferences · C update preferences · D Backend · E–H none · I 400/401 · J JWT · K own · L none · M none · N cache stale-marked · O NO · P **preferences read/update + catalogue** · Q interest list · R network retry · S refresh once readable · T none (non-sensitive) · U Backend (SharedPreferences allowed only for non-sensitive local cache if approved)
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRAVELER_PREFERENCES_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** `INVALID_PRODUCTION_FIXTURE` for the "saved" claim; recommended: `UI_ONLY_WITH_DISABLED_MUTATION`
- **Design-only Assumptions:** interest set
- **Implementation Notes:** if local persistence is later approved it must be labelled "stored on this device".
- **Non-goals:** recommendation scoring display
- **Acceptance Criteria:** AC1 no "saved" claim without durable Backend or approved local persistence; AC2 interest list not presented as authoritative; AC3 state not lost silently; AC4 selection not colour-only.
