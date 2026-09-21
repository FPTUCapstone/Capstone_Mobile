# UC-04 Mobile Sign In — Implementation Plan

**Status:** Revised per plan review — READY FOR FINAL REVIEW (not approved for execution)
**Date:** 2026-09-15
**Spec:** [`specs/UC-04-mobile-spec.md`](../specs/UC-04-mobile-spec.md) v1.2 (Approved for planning)
**Branches:** Mobile `feature/PhucTV-sign-in-mobile` (from `origin/develop`) · BE branch decided by Phase 0 (Mobile contract changes must not be silently appended to the Web UC-04 review branch) · Web FE untouched
**Rules:** Both `TEAM_ENGINEERING_RULES.docx` and `Dev_and_CrossReview_Checklist` re-read before each task. TDD red→green→refactor, one atomic task at a time, verify before advancing. No commit/push/PR unless explicitly requested. Preserve unrelated work.

---

## Scope guard

Touches ONLY:

- **BE:** legacy auth response DTOs + verify-email command/handler + their tests. No schema, no `/auth/web/*`, no Web DTO change, no new endpoint, no logout/revocation.
- **Mobile:** `lib/features/auth/**`, `lib/app/router/**`, `lib/core/{network,storage,error,di,constants}/**` and their tests.

Never touches: Web FE, database, `/auth/web/*`, UC-02 registration, operator application/resubmit implementation, Admin Mobile routes, normal Sign Out, refresh-token renewal.

Contract semantics are fixed by spec §7; this plan only sequences the work.

---

## Phase 0 — Branch/base gate (before any RED test)

- Verify the Mobile auth dependencies (firebase_auth, google_sign_in, flutter_secure_storage, dio, flutter_bloc, go_router, get_it) exist in `origin/develop`'s `pubspec.yaml` — the Mobile branch was created from `origin/develop` after confirming the UC-01/auth integration commits were merged; re-confirm before starting.
- Verify the required BE UC-04 commits (Web sign-in backend `c14dfe7` and its dependencies) are merged into BE `origin/develop`. If they are NOT merged, do not silently append Mobile BE contract changes to the existing Web UC-04 review branch `feature/PhucTV-sign-in`; instead create a dedicated BE branch from the appropriate base (e.g. `feature/PhucTV-sign-in-mobile-contract`) or STOP and report the safest branch/base strategy for a decision.
- If any required dependency is missing in the chosen base: STOP and report — do not code against an unverified base.
- **DoD:** Mobile base and BE base explicitly recorded (branch + SHA) in execution evidence before A1 RED.

### Phase 0 execution evidence — 2026-09-15 (STOP condition triggered on BE side)

- **Mobile base: PASS.** Branch `feature/PhucTV-sign-in-mobile` @ `833e7d8` (= `origin/develop` tip at creation; verified by `git merge-base --is-ancestor` for `cf79440`, `1bafc41`, `f21b25d` — all UC-01/auth integration commits are in develop). `pubspec.yaml` on this base contains every required auth dependency: firebase_auth ^6.1.0, firebase_core ^4.2.1, google_sign_in ^7.2.0, flutter_secure_storage ^10.0.0, dio ^5.9.2, flutter_bloc ^9.1.1, go_router ^17.1.0, get_it ^9.2.1, connectivity_plus, shared_preferences.
- **BE base: FAIL / GATE TRIGGERED.** BE `origin/develop` tip is `86516e2` (UC-18 merged). `git merge-base --is-ancestor` proves the UC-04 BE commits `c14dfe7` and `1cc9f64` are **NOT merged into develop** (exit 1), and `git ls-tree origin/develop` shows none of the UC-04 foundation files (`AccountEligibilityResolver.cs`, `WebAuthResponseDto.cs`, `WebRefreshCookie.cs`, `WebSignIn/`, `WebRefresh/`). The Mobile contract work (A1/A2) modifies files that exist only on the unmerged `feature/PhucTV-sign-in` branch, so it cannot base on develop, and per this plan it must not be appended to the Web UC-04 review branch either.
- **Status:** A1 RED is blocked until a BE base decision is made (see report: merge-first vs stacked branch). No BE code was created or modified.

### Phase 0 branch-strategy override — 2026-09-15 (user decision, execution unblocked)

- **Execution evidence reaffirmed 2026-09-16:** The user approved this plan for execution and explicitly authorized A1/A2 on BE `feature/PhucTV-sign-in`. The earlier Phase 0 STOP applied only to the unmerged BE branch strategy and is lifted; no separate BE mobile-contract branch will be created. The existing BE PR will be updated only after user review and an explicit commit/push decision. All Web behavior must remain unchanged.
- The user explicitly approves implementing A1/A2 directly on the existing BE branch `feature/PhucTV-sign-in` (currently at `c14dfe7`, PR awaiting review).
- The previous Phase 0 STOP was caused only by the unmerged-branch strategy question and is now lifted.
- No separate BE mobile-contract branch will be created. The existing BE PR will be updated later, after user review, when the user explicitly decides to commit/push.
- All Web behavior must remain unchanged: `/api/v1/auth/web/*`, `WebAuthResponseDto`, HttpOnly `tripmate_refresh` cookie semantics, and Web role/application routing are untouched by A1/A2; Web integration tests serve as the regression proof.
- Approved business semantics from spec v1.2 are unchanged by this override.
- Recorded bases: Mobile `feature/PhucTV-sign-in-mobile` @ `833e7d8` (origin/develop); BE `feature/PhucTV-sign-in` @ `c14dfe7`.

### Phase 0 execution evidence — 2026-09-16 (override confirmed, execution unblocked and performed)

- **Override confirmed against the user decision.** The three conditions the user set are all recorded above and were verified in this session: (a) A1/A2 implemented directly on `feature/PhucTV-sign-in`; (b) no separate BE mobile-contract branch created; (c) the existing BE PR will be updated only after user review and an explicit commit/push decision.
- **Base/head re-verified in this session (read-only `git`):** BE worktree `D:\FPTUCapstone\Capstone_BE`, branch `feature/PhucTV-sign-in`, HEAD `c14dfe74636f7a2ce5f1916c391179fa9387ae0b` (= `c14dfe7`, confirmed an ancestor of HEAD), uncommitted A1/A2 changes preserved. Mobile worktree `D:\FPTUCapstone\Capstone_Mobile`, branch `feature/PhucTV-sign-in-mobile`, HEAD `833e7d8bd8389f7b926aa11b6966974f4c211116` (= `833e7d8`). Web worktree `D:\FPTUCapstone\Capstone_FE` was not modified by this task.
- **A1/A2 RED was reproduced on an isolated diagnostic copy** of the BE worktree (outside both repos) holding the `c14dfe7` versions of the four changed non-test files: the new Mobile-wire assertions fail there (10/11 HTTP integration cases fail, 11 unit cases fail), proving the tests are non-vacuous. Acceptance evidence is the GREEN run on the real worktree, not the diagnostic copy.
- **No commit/push/PR was performed.** All BE and Mobile changes remain uncommitted in the working tree for user review, per the standing instruction.

---

## Phase A — Backend additive contract (shared endpoints; Web unaffected)

### A1 — Expose `applicationStatus` on legacy login/Google wire

- **RED** (unit serialization cases in `LoginCommandHandlerTests`/`GoogleAuthCommandHandlerTests` PLUS new HTTP integration tests hitting `POST /api/v1/auth/login` and `POST /api/v1/auth/google`): prove `applicationStatus` is present on successful Mobile wires — `"Approved"`, `"PendingApproval"`, `"Rejected"` for recognized TourOperators and an explicit JSON `null` for Traveler. Administrator password login is now rejected by `/api/v1/auth/login` with `403 auth.admin_mobile_sign_in_disabled` before session side effects; Google keeps its existing Google-specific 403.
- **GREEN:** implement the smallest additive serialization change selected after the RED evidence and source verification — removing `[JsonIgnore]` from the internal `ApplicationStatus` properties is only a candidate; a dedicated Mobile projection remains an alternative. `RefreshTokenExpiresAtUtc` must stay internal. `WebAuthResponseDto` is a separate type and must remain untouched so the Web contract is byte-identical.
- **Verify:** `dotnet test --filter Login|GoogleAuth` then full suite.
- **DoD:** field always present incl. null on the Mobile wire (proven over HTTP); Admin-Google 403 behavior unchanged; Web integration tests still green; no other wire change.

### A2 — Verify-email session carries full routing identity

- **Source verification first:** `VerifyEmailResponse` already carries a `Status` string (`user.Status.ToString()` after the activation transition) — during RED, confirm whether that value is the effective status required by spec §7 or whether it must be normalized through the shared resolver like login.
- **RED** (`VerifyEmailCommandHandlerTests` + a new HTTP integration case): the verify-email success response must provide **role + effective status + applicationStatus + the existing accessToken/refreshToken** — `null` applicationStatus for the Traveler activation path; the correct value if a TourOperator account is activated; Administrator verify-email keeps its existing BE behavior.
- **GREEN:** extend the response with the identity fields proven missing by RED (`Role`, `ApplicationStatus`, and effective-status normalization if verification shows it is needed), populated from the same shared resolver the login path uses (role from DB, applicationStatus from current `OperatorProfiles`). Preserve activation-only semantics (still only activates `PendingEmailVerification`; no status mutation for others) and the existing Mobile token fields.
- **Verify:** `dotnet test --filter VerifyEmail`; confirm existing verify-email/Mobile-compat tests still pass (additive fields only).
- **DoD:** recovery session returns full routing identity; no second login needed.

### A3 — BE regression + quality gate

- **Verify:** `dotnet format --verify-no-changes`; `dotnet build -c Release`; full `dotnet test`. Report pass/fail/skip honestly (SQL-gated skips unchanged).
- **DoD:** 0 warnings/errors; focused + full BE green; Web auth behavior provably unchanged.

---

## Phase B — Mobile client (consume contract + routing + session)

### B1 — DTO + domain identity

- **RED** (`session_response_dto` test): parse `applicationStatus` (validated enum `Approved`/`PendingApproval`/`Rejected`, else null) and require `role`. `Traveler` and `TourOperator` parse as supported roles; `Administrator` parses as a **known-but-Mobile-unsupported** role (a valid parse, refused later by B2 — NOT a format failure); any unknown/missing role fails closed as malformed (never fabricate Traveler).
- **GREEN:** add `applicationStatus` to `SessionResponseDto`; add a domain application-status type; extend the role parser to distinguish supported / known-unsupported / unknown as above.
- **Verify:** `flutter test test/features/auth/data`.

### B2 — Administrator Web-only refusal (fail closed before persistence)

- **RED** (`auth_session_cubit_test`): password `403 auth.admin_mobile_sign_in_disabled` must produce the Web-only message, persist no TripMate session, remain unauthenticated, and best-effort sign out Firebase without cleanup failure masking the result. Unexpected password/verify-email session responses carrying `role=Administrator` remain a defensive rejection before persistence. Google Administrator keeps its distinct existing 403 and the same friendly Mobile outcome.
- **GREEN:** map the new password-specific code and perform best-effort provider cleanup; retain the response-role guard before `_saveSession`, the Google-specific mapping, and the strict Traveler/TourOperator classifier.
- **Verify:** `flutter test test/features/auth/presentation/cubit`.

### B3 — Application-status routing

- **RED** (`route_guards_test`): Traveler→`/traveler`; TO Approved→`/operator`; TO Pending/Rejected/unresolved(null)→`/operator/application`; unresolved never renders approved Operator content; Administrator has no authenticated state.
- **GREEN:** extend session state to carry `applicationStatus`; `RouteGuards.redirect` uses it for the operator destination. Reuse existing routes (`app_routes.dart`) — no new routes.
- **Verify:** `flutter test test/app/router`.

### B4 — Provisional startup restore + 401/403 session handling

- **RED:** startup restores persisted backend-issued identity (role + applicationStatus) without re-entry and is not treated as server-validated; a **401 on an authenticated/Bearer request** clears the complete session and returns to sign-in; a **403 never globally clears the session**; failures from the auth endpoints themselves (login/google/verify-email, before a session exists) use normal auth error handling and must NOT trigger the global invalidation path.
- **GREEN:** persist only the identity fields actually required for restore/routing (role, applicationStatus, tokens; email only if the existing model needs it for display); `restoreSession` replays the full identity; add a session-invalidation hook reachable from the Dio layer (via DI), scoped to Bearer-carrying requests, that clears storage + emits unauthenticated on 401 only. Keep `flutter_secure_storage` as the only token store; no cookies.
- **Verify:** `flutter test` (cubit + interceptor/repository).

### B5 — Error mapping + messages

- **RED:** map new/known backend codes to friendly copy (invalid credentials, unverified, locked/inactive, unresolved account, network/timeout); user-cancelled Google sign-in handled silently; no raw SDK/server internals surfaced.
- **GREEN:** extend `ErrorMapper`/datasource `_messageForCode`; finalize Administrator + unresolved wording (spec Open Question 2 — provide default English copy, flag localization).
- **Verify:** `flutter test test/core/error`.

### B6 — Mobile quality gate

- **Verify:** `flutter pub get`; `dart format --output=none --set-exit-if-changed .`; `flutter analyze`; `flutter test`; `flutter build apk --debug` (Android runtime touched). Report results honestly.
- **DoD:** analyze 0 issues, all tests pass, debug APK builds.

---

## Phase C — Cross-cutting verification

- **C1 Web regression (read-only):** confirm no Web FE change and BE A1/A2 did not alter `/auth/web/*` responses (BE Web integration tests green).
- **C2 Manual sign-in matrix (device/emulator):** Traveler, TO Approved/Pending/Rejected/unresolved, Administrator (Web-only message), first-time Google→Traveler, unverified→recovery→routed, restart→provisional restore, 401→relogin, 403→stays signed in.
- **C3 Zero-regression:** full BE suite + full Mobile suite green; all existing 74 baseline Mobile tests remain green; no existing tests are deleted, disabled, skipped, or weakened; new UC-04 tests are additive and the total count is expected to increase.

---

## Acceptance mapping (spec → task)

| Spec                                      | Task                                   |
| ----------------------------------------- | -------------------------------------- |
| §7 applicationStatus on Mobile wire (A1) | A1                                     |
| §7 verify-email full identity (A2)       | A2                                     |
| MFR-01/02/03 sign-in paths                | B1, B2, B5                             |
| MFR-04 eligibility honored                | B2, B5                                 |
| MFR-05 secure storage                     | B4 (no change to store type)           |
| MFR-06 provisional restore                | B4                                     |
| MFR-07 401 / MFR-16 403                   | B4                                     |
| MFR-08..12 routing incl. fail-closed      | B3                                     |
| MFR-13 Administrator Web-only             | B2                                     |
| MFR-14/15 authoritative role + boundary   | A1/A2 + B1/B3                          |
| AC-14 first-time Google Traveler          | B1/B3 (consumes inherited BE behavior) |

## Out of scope (unchanged from spec §13)

UC-02/UC-01 registration, operator application submission/resubmit implementation, Admin Mobile, normal Sign Out/revocation, new Mobile refresh endpoint, refresh-token renewal UX, unrelated BE/Web/Mobile refactors, phone/OTP.

## Open items to confirm before/at execution

1. BE mechanism for A1/A2 is NOT pre-approved: removing `[JsonIgnore]` is only one candidate. The smallest additive BE solution will be selected after RED evidence and source verification (A1/A2), keeping `WebAuthResponseDto` and Web behavior untouched.
2. Session-invalidation wiring from Dio → cubit (DI callback vs a session controller) — smallest testable seam chosen in B4.
3. Final localized copy for Administrator + unresolved messages (default English provided).

## Definition of Done (whole plan)

Every task red→green→reviewed; Phase A/B/C gates pass; spec AC-01…AC-14 demonstrably satisfied; no Web/BE regression; no secrets, no generated artifacts committed; nothing staged/committed/pushed without explicit request.

---

*End of plan — UC-04 Mobile Sign In. Draft; awaiting approval before any code is written.*
