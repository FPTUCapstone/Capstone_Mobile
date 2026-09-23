# UC-05 Mobile Sign Out — Implementation Plan

## Status

**APPROVED FOR IMPLEMENTATION** (2026-09-17; sequencing/traceability amended 2026-09-17 after T05)

Implementation is authorised subject to the task-by-task TDD and review gates in this plan, beginning with T01 only. No code, test or branch action outside that scope is authorised by this document.

**Post-T05 amendment record (2026-09-17):** this is a sequencing and traceability correction to the already-approved plan, not a reopening of M1–M7. **No implementation behaviour changed, no task scope expanded, and no technical decision altered** — only the verification ordering and the test-matrix traceability were corrected: T06 is restricted to the M3 login-screen verification, and the local-cleanup-failure UI verification is moved to the new **T08V** gate after T07/T08, because those UI surfaces do not exist earlier. The spec was synchronised in the same pass with the already-approved local-cleanup-failure copy.

## Authoritative Inputs

| Input | Value |
| --- | --- |
| Specification | `specs/UC-05-mobile-spec.md` — **APPROVED FOR PLANNING**, decisions M1–M7 resolved 2026-09-17 |
| Rules | `TEAM_ENGINEERING_RULES.docx` v2.0, `Dev_and_CrossReview_Checklist.docx` v2.0, `Capstone_Mobile/AGENTS.md` |
| Backend reference | `Capstone_BE/specs/UC-05-spec.md`, `plans/UC-05-plan.md`, `AuthController.Logout`, `SignOutCommandHandler`, `SignOutRequestDto`, `SignOutResponseDto` |
| Rule conflicts | NONE — rules, spec, baseline and this plan are mutually compatible |

## Branch / Base / Dependency

| Item | Value |
| --- | --- |
| Repository | `D:\FPTUCapstone\Capstone_Mobile` |
| Branch | `feature/PhucTV-sign-out-mobile` |
| HEAD / base | `cf736e1` — `feat(auth): complete UC-04 mobile sign-in` |
| Dependency | UC-05 Mobile is **intentionally stacked** on `feature/PhucTV-sign-in-mobile` because it depends on the UC-04 Mobile auth/session architecture. PR base/merge order must declare it: either UC-04 merges first, or the UC-05 PR targets that branch. |

## Baseline Record

| Item | Result |
| --- | --- |
| `flutter pub get` | PASS — no tracked file changed |
| `dart format --output=none --set-exit-if-changed .` | PASS — 100 files, 0 changed, exit 0 |
| `flutter analyze` | PASS — "No issues found!" (exit 0, 0 warnings, 0 errors) |
| `flutter test` | PASS — **149 passed / 0 failed / 0 skipped observed** |
| `flutter build apk --debug` | PASS — `build\app\outputs\flutter-apk\app-debug.apk` |
| `git diff --check` | PASS (exit 0) |
| Pre-implementation production/test diff | NONE |
| Toolchain | Flutter 3.47.2, Dart 3.13.2, windows_x64 |

Non-blocking pre-existing notes (NOT UC-05 tasks): 44 packages have newer incompatible versions; KGP 2.2.20 deprecation warning. No Flutter/Dart/package/Kotlin upgrade in UC-05.

## Scope Guard

- In scope: exactly the production/test files in §Expected File Footprint.
- Out of scope: Backend, `Capstone_FE`, new state-management or feedback frameworks, new architecture layers, confirmation-UX redesign, token refresh/rotation, access-token blacklist, package/Kotlin upgrades, unrelated refactors, stricter M3 acknowledgement semantics.
- Regression baseline: all 149 existing tests keep passing; UC-04 restore/session-invalidation semantics unchanged.

## Architecture Constraints

Preserved: **Page → `AuthSessionCubit` → `AuthRepository` → `AuthRemoteDataSource` → `DioClient`**.

- Widgets never call Dio and never read secure storage; the data source never reads storage; the repository owns neither UI state nor storage.
- Session cleanup keeps its single owner: `AuthSessionCubit`.
- `AuthSessionStatus.loading` must **not** be emitted for sign-out (`isAuthenticated == (status == authenticated)`, so `loading` would make the guard redirect mid-request). Busy state uses the existing operation marker instead (see §State Model).
- Navigation stays automatic (`BlocListener` → `_router.refresh()` → guard); no `context.go/push/replace` for logout.
- No new global message store; notices ride the existing `AuthSessionState` message field.

## State Model (amended)

Single source of truth for sign-out progress and notices is the existing Cubit state — no per-page async flag.

```dart
enum AuthSessionOperation { none, verifyEmail, resendVerificationEmail, signOut }
// AuthSessionState gains optional params on two existing factories; props are unchanged
const AuthSessionState.authenticated(UserRole role, {applicationStatus, operation = none, errorMessage});
const AuthSessionState.unauthenticated({String? errorMessage});
```

| Phase | status | operation | errorMessage | isAuthenticated |
| --- | --- | --- | --- | --- |
| Before sign-out | `authenticated` | none | null | true |
| Sign-out in flight | `authenticated` | **`signOut`** | null | **true** (no redirect) |
| Remote failure + local complete | `unauthenticated` | none | **M3 copy** | **false** |
| Local cleanup failure | `authenticated` | none | **local-cleanup-failure copy** | true (retry possible) |
| Success | `unauthenticated` | none | null | false |

- The three entry-point widgets derive disabled/busy from `state.operation == AuthSessionOperation.signOut` (via `context.watch`) — no second async source of truth.
- `AuthSessionStatus.loading` is never used; `failure` is **not** used for the completed-logout result (after safe local completion the authoritative status is `unauthenticated`).
- The M3 notice and the local-cleanup-failure copy both reuse the **existing** `errorMessage` field and `AppAlert` presentation — no new field, no new store, no acknowledgement API.

## Backend Contract

| Item | Value |
| --- | --- |
| Endpoint | `POST /api/v1/auth/logout` (`[AllowAnonymous]`) |
| Request | `application/json` → `{"refreshToken": <value or null>}` (`RefreshToken`, `string?`) |
| Success | HTTP 200, `ApiResponse<bool>` with `success: true`, `statusCode: 200`, `message: "Signed out successfully."`, `data: true`, and `errors: null` → validate through `_unwrapSignOut()`; do not use the map-oriented `_unwrap()` helper |
| Failure | Network/timeout → mapped `NetworkException`; non-2xx (e.g. 500 ProblemDetails) → mapped `ServerException` via the existing `_handleDioError` |
| Idempotency | null/blank/unknown/already-revoked → 200 |
| Authorization | Not required; `AuthInterceptor` may add a Bearer automatically; UC-05 must not depend on it |
| Access JWT | Not blacklisted; valid until natural expiry |
| Body-less POST | NOT APPLICABLE for Mobile; no Backend change |

## Approved Decisions M1–M7

| ID | Decision |
| --- | --- |
| M1 | SRS **BR-13** governs Mobile: remote logout network/timeout/5xx/infrastructure failure **still ends the local session when local invalidation can be safely completed**. UC-05 Web D1 is not copied; Web D1 stays Web-only. |
| M2 | Navigation is automatic via cubit → router refresh → guard → `/auth/login`. No explicit logout navigation. |
| M3 | Remote logout failure plus a successful local logout produces **exactly one** notice on the login screen with the approved copy: `You're signed out on this device, but we couldn't complete server-side sign-out.` This copy is **only** for remote invalidation failure after safe local completion. |
| M4 | Missing/null/blank/unreadable refresh token uses the same pipeline with `{"refreshToken": null}`; no separate error UX. |
| M5 | Body-less POST NOT APPLICABLE for Mobile; no Backend change. |
| M6 | All three entry points migrate (Traveler Shell AppBar, Operator Shell AppBar, Traveler Settings). UX unchanged: shells stay one-tap; Settings keeps its existing dialog and copy; no new dialog. |
| M7 | After sign-out intent, stale persisted credentials must never become eligible for future session restoration; do not silently claim local logout is complete while restorable credentials may remain. |

## M7 Design Resolution (amended)

### Mechanism: EXISTING RESTORE GATE INVALIDATION + VERIFIED RESTORE PREDICATE

The authoritative completion rule is the **actual restore predicate** used by `restoreSession()`, not "every physical key read back empty":

```
restorable =
      keep_signed_in == 'true'
  AND access_token is non-empty
  AND refresh_token is non-empty
  AND session_role maps to a valid UserRole ('traveler' | 'tourOperator')

localComplete = NOT restorable
```

The purpose of M7 is to make the old session **non-restorable**, not to require every physical delete to succeed before completion.

Flow inside `AuthSessionCubit.signOut()`:

1. Guard: return immediately if the session is not authenticated or a sign-out is already in flight (`state.operation == signOut`).
2. Emit the in-flight state: `authenticated(role, applicationStatus, operation: signOut)` — status stays authenticated.
3. Remote call: read the stored refresh token quietly (null on missing/blank/unreadable → M4), then `await repository.logout(token)`; record success/failure. **Remote failure never blocks local invalidation.**
4. **Invalidate the persistent restore gate as early as possible** using the existing storage API and existing representation: delete `keep_signed_in`; if that delete does not take effect, write `'false'` to it (the same representation `_saveSession` already uses). Either way `keep_signed_in == 'true'` becomes unsatisfiable. **No tombstone key is introduced** — source inspection shows the current storage API can invalidate the existing gate safely.
5. Best-effort clean the remaining keys: `access_token`, `refresh_token`, `session_role`, `session_application_status`, `keep_signed_in`.
6. **Read back and evaluate the same predicate** `restoreSession()` uses (including the role mapping). A thrown read-back means "unproven" → treat as not complete.
7. If **not restorable** (`localComplete = true`): best-effort provider/Firebase sign-out, then emit the terminal state — `unauthenticated()` on clean success, or `unauthenticated(errorMessage: <M3 copy>)` when the remote call failed. The guard then routes to `/auth/login`.
8. If the persisted state may still satisfy the predicate, or verification cannot be trusted (`localComplete = false`): **do not** emit `unauthenticated`, **do not** show the M3 copy, keep the authenticated state, release the in-flight marker, allow retry, and emit `authenticated(..., errorMessage: <local-cleanup-failure copy>)`. No raw storage exception is surfaced.
9. A **bounded** cleanup retry is allowed (single retry of the gate-invalidation + clean + verify sequence); no loop, no timing dependence.
10. `restoreSession()` semantics are **unchanged**. Source inspection confirms the invariant is reachable with the existing predicate, so no PLAN-TIME DESIGN CONSTRAINT is raised.

### Why this mechanism

- It is the spec's own definition of local completion, expressed in the code's real terms.
- Invalidation of the single gate key (`keep_signed_in`) is the cheapest deterministic operation that makes the whole predicate unsatisfiable; the existing representation (`'false'`) is a fallback that still uses only the existing storage API.
- It avoids the previous over-strict rule ("all three reads empty") **as the completion criterion**, which would have demanded physical deletion of every key simply to call the logout complete. **The normal success path is not relaxed by this**: on a clean run all five keys are deleted and verified physically absent (TC-MOB-05/06); the predicate rule exists only so the flow stays correct in the fault-injected partial-cleanup cases, where a surviving leftover must never be able to restore the session.
- It survives restart without in-memory state, keeps one cleanup owner, needs no new key, and touches no infrastructure file.
- Self-healing: if the remote call succeeded but local cleanup failed, the refresh row is already revoked and the next 401 clears the session through the existing `handleSessionExpired()` path.

### Alternatives rejected

| Candidate | Rejected because |
| --- | --- |
| "All restore-critical reads empty" as the only completion rule (previous draft) | Too strict and inconsistent with the real restore semantics: it demands physical deletion success rather than non-restorability, so a survivable-but-harmless leftover key would block completion. |
| Persistent tombstone/invalidation marker key | Unnecessary: the existing `keep_signed_in` gate can be invalidated with the existing API; a new key would add a write/clear lifecycle and a stale-marker failure mode without adding guarantee. |
| In-memory `SessionCoordinator`/restore guard only | Dies with the process, so it violates "must not depend on in-memory state alone". |
| Restore-predicate hardening in `restoreSession()` | The spec forbids changing UC-04 restore semantics, and the invariant is already reachable without touching it. |
| Cleanup ordering alone | Ordering adds no guarantee; the amended flow keeps the gate-first ordering **and** verification. |

### Files affected by M7

`lib/features/auth/presentation/cubit/auth_session_cubit.dart` (gate invalidation, verified predicate, completion rule) and `lib/features/auth/presentation/cubit/auth_session_state.dart` (operation marker + optional message on the two factories). Explicitly unchanged: `secure_storage_service.dart`, `session_coordinator.dart`, `auth_interceptor.dart`, `restoreSession()` semantics.

### Failure semantics

| Condition | Status after | operation | Message | isAuthenticated |
| --- | --- | --- | --- | --- |
| Non-restorable after cleanup (remote OK) | `unauthenticated` | none | null | false |
| Non-restorable after cleanup (remote failed) | `unauthenticated` | none | **M3 copy** | false |
| Still restorable / unproven after bounded retry | `authenticated` | none | **local-cleanup-failure copy** | true — no M3, no success claim, retry possible, no raw storage error |

## Expected File Footprint

### NEW — production (1)

`lib/features/auth/data/models/sign_out_request.dart` — hand-written model per `LoginRequest` convention: `toJson() => {'refreshToken': refreshToken}`, `String? refreshToken`.

### MODIFIED — production (9)

| File | Change |
| --- | --- |
| `lib/features/auth/domain/repositories/auth_repository.dart` | Add `Future<void> logout(String? refreshToken);` |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Delegate `logout` to the data source |
| `lib/features/auth/data/datasources/auth_remote_data_source.dart` | Add `Future<void> logout(String? refreshToken)` (interface + impl): POST, body via `SignOutRequest`, validate the `ApiResponse<bool>` through `_unwrapSignOut()`, `DioException` → existing `_handleDioError` |
| `lib/features/auth/presentation/cubit/auth_session_state.dart` | Add `AuthSessionOperation.signOut`; allow `operation`/`errorMessage` on `authenticated(...)` and `errorMessage` on `unauthenticated(...)` (props unchanged; existing const usages keep compiling) |
| `lib/features/auth/presentation/cubit/auth_session_cubit.dart` | Add `signOut()` orchestration + M7 gate invalidation/verification; add the two approved copy constants; keep the local-only cleanup as the internal primitive |
| `lib/features/auth/presentation/pages/login_page.dart` | Render the carried notice (`AppAlert`) when the unauthenticated state carries the M3 copy — minimal condition extension of the existing block |
| `lib/features/traveler/presentation/pages/traveler_shell_page.dart` | AppBar action calls `signOut()`; busy/disabled from `state.operation == signOut`; render the local-cleanup-failure notice via `AppAlert`; one-tap preserved |
| `lib/features/tour_operator/presentation/pages/operator_shell_page.dart` | Same migration for the operator shell |
| `lib/features/traveler/presentation/pages/traveler_settings_page.dart` | Confirmed dialog action calls `signOut()`; dialog/title/copy unchanged; busy state; renders the local-cleanup-failure notice |

### NEW — tests (3)

`test/features/traveler/presentation/pages/traveler_shell_page_test.dart`, `test/features/tour_operator/presentation/pages/operator_shell_page_test.dart` (new feature test directory per convention), `test/features/traveler/presentation/pages/traveler_settings_page_test.dart`.

### MODIFIED — tests (3)

`test/features/auth/data/datasources/auth_remote_data_source_test.dart`, `test/features/auth/presentation/cubit/auth_session_cubit_test.dart`, `test/features/auth/presentation/pages/demo_auth_flows_test.dart` (existing home of LoginPage widget tests).

Conditional: `test/app/app_session_invalidation_test.dart` and/or router-guard suites — only if T09 proves a concrete gap.

### UNCHANGED (protected)

`lib/core/storage/secure_storage_service.dart`, `lib/core/network/session_coordinator.dart`, `lib/core/network/interceptors/auth_interceptor.dart`, `lib/app/router/*`, `lib/app/app.dart`, `pubspec.yaml`, `pubspec.lock`, the Backend repository, `Capstone_FE`, other specs/plans. `login_page.dart` is modified **only** for the notice condition described above (no redesign).

## TDD Task Sequence

Task types: **IMPLEMENTATION** (RED → confirm expected failure → GREEN → focused verification → review → next task; no production code before a meaningful RED) and **VERIFICATION** (explicit PASS evidence; no artificial RED when no production behaviour is added — a true RED is created only if the verification exposes a production gap, followed by the minimal GREEN fix).

### T01 — Sign-out request model + remote data source — IMPLEMENTATION

- **Goal**: the API-layer pieces exist and behave exactly per the Backend contract.
- **Production files**: `sign_out_request.dart` (new); `auth_remote_data_source.dart`.
- **Tests**: `auth_remote_data_source_test.dart`.
- **RED reason**: `SignOutRequest` and `logout` do not exist (focused test file cannot compile/pass).
- **RED cases**: `toJson()` emits `{'refreshToken': <value>}` and `{'refreshToken': null}`; POST to `/api/v1/auth/logout` with that body (asserted via the existing `RecordingHttpClientAdapter`); a valid **200 `ApiResponse<bool>` envelope** succeeds; a malformed 200 is rejected safely; a 500 maps to `ServerException`; a connection error maps to `NetworkException`.
- **GREEN action**: add the model and the data-source method reusing `_handleDioError`, with `_unwrapSignOut()` validating `success == true` and `data == true`, and no Authorization/timeout logic added.
- **Focused command**: `flutter test test/features/auth/data/datasources/auth_remote_data_source_test.dart`.
- **Review checklist**: use `_unwrapSignOut()` rather than the map-oriented `_unwrap()`; no Authorization dependency; no blacklist logic; error mapping reuses the existing table; malformed envelopes fail safely.
- **Matrix coverage**: TC-MOB-02, TC-MOB-10 (API level), parts of TC-MOB-15/16.
- **DoD**: focused tests green; `dart format`/`flutter analyze` clean; no other file touched.

### T02 — Repository contract + Cubit sign-out foundation — IMPLEMENTATION

- **Goal**: introduce the logout contract and the orchestration skeleton through a meaningful RED (this replaces the previous "T02 has no RED" exception, which is removed).
- **Production files**: `auth_repository.dart`, `auth_repository_impl.dart`, `auth_session_cubit.dart` (foundation), `auth_session_state.dart` (operation marker).
- **Tests**: `auth_session_cubit_test.dart` (fake repository extended with `logout`).
- **RED reason**: `AuthRepository.logout`, `AuthSessionCubit.signOut`, `AuthSessionOperation.signOut` and the fake's `logout` support do not exist — the new cubit tests cannot compile/pass.
- **RED cases**: an authenticated cubit's `signOut()` reads the stored refresh token and forwards it to `AuthRepository.logout`; during the operation the state is `authenticated` with `operation == signOut`; a second call while in flight performs no additional repository call; `AuthSessionStatus.loading` is never emitted; the terminal success state is `unauthenticated`.
- **GREEN action**: add `AuthRepository.logout`, the one-line `AuthRepositoryImpl` delegation, the state operation marker, and the minimal `signOut()` foundation (guard → in-flight emission → remote call → local cleanup → terminal emission).
- **Focused command**: `flutter test test/features/auth/presentation/cubit/auth_session_cubit_test.dart`.
- **Review checklist**: repository performs no storage/UI work; widgets untouched so far; existing cubit behaviour (sign-in, verify, role refusal, restore) unchanged; storage access stays in the cubit.
- **Matrix coverage**: TC-MOB-01, 03, 07, 13, 14 (foundation half).
- **DoD**: focused tests green; all pre-existing cubit tests green.

### T03 — Success / null-token / duplicate / in-flight — IMPLEMENTATION

- **Goal**: complete the success path and the M4 null-token path with correct in-flight semantics.
- **Production files**: `auth_session_cubit.dart`.
- **Tests**: `auth_session_cubit_test.dart`.
- **RED reason**: null/blank/read-throw handling and full key cleanup are not yet implemented.
- **RED cases**: missing/blank/unreadable refresh token → `refreshToken: null` and the flow continues with no error UX (M4); on a 200 all five keys are physically absent (asserted per key, including `access_token` and `refresh_token` — TC-MOB-05/06), Firebase sign-out invoked, terminal `unauthenticated`, operation cleared; the session stays `authenticated` for the whole pending window (gated fake) and no redirect-triggering status is emitted; the in-flight marker is released on success and on failure.
- **GREEN action**: implement the quiet token read, the full best-effort key cleanup, provider sign-out, and the terminal emission.
- **Focused command**: `flutter test test/features/auth/presentation/cubit/auth_session_cubit_test.dart`.
- **Review checklist**: one request per intent; single cleanup owner; no explicit navigation; operation cleared on every path.
- **Matrix coverage**: TC-MOB-03, 04, 05, 06, 07, 09, 13, 14, 20.
- **DoD**: focused tests green; baseline suites unaffected.

### T04 — Remote failure + M3 + unauthenticated terminal semantics — IMPLEMENTATION

- **Goal**: remote network/500 failure still ends the local session and carries exactly one safe notice on the `unauthenticated` state.
- **Production files**: `auth_session_cubit.dart`, `login_page.dart` (notice render condition).
- **Tests**: `auth_session_cubit_test.dart`, `demo_auth_flows_test.dart`.
- **RED reason**: the remote-failure branch, the approved copy constant and the notice rendering do not exist.
- **RED cases**: repository throws `NetworkException` → local cleanup still completes, terminal state is `unauthenticated` with `errorMessage` equal to the exact M3 copy, `isAuthenticated == false`; `ServerException(500)` → identical; the emitted message contains no token, status code, or ProblemDetails text; exactly one terminal emission carries the notice; the login screen renders that copy once via `AppAlert` and renders no notice on a clean success.
- **GREEN action**: record remote failure, still complete the local flow, emit `unauthenticated(errorMessage: <M3 copy>)`, and extend the login page's existing `AppAlert` condition to include the unauthenticated-with-message case.
- **Focused command**: `flutter test test/features/auth/presentation/cubit/auth_session_cubit_test.dart test/features/auth/presentation/pages/demo_auth_flows_test.dart`.
- **Review checklist**: status is `unauthenticated` (never a still-authenticated failure state); the copy is the exact approved string; no raw detail; no `loading`; no new feedback framework.
- **Matrix coverage**: TC-MOB-11, 12, 15 (message hygiene), 08 (terminal redirect precondition).
- **DoD**: focused tests green; the M3 string appears exactly once in production code.

### T05 — M7 restore-predicate fail-closed safety — IMPLEMENTATION

- **Goal**: implement gate invalidation + verified restore predicate + fail-closed not-complete path exactly as designed above.
- **Production files**: `auth_session_cubit.dart`.
- **Tests**: `auth_session_cubit_test.dart` (fault-injecting fake storage).
- **RED reason**: gate invalidation, predicate verification, the bounded retry and the local-cleanup-failure outcome do not exist.
- **RED cases (A–H)**: A) all restore-critical state invalidated → complete → `unauthenticated`. B) some physical keys remain but the predicate is unsatisfiable (e.g. `keep_signed_in` no longer `'true'` while old token bytes remain) → complete → a fresh `restoreSession()` stays unauthenticated. C) the first cleanup attempt fails, the bounded retry makes the state non-restorable → complete. D) after retry the persisted state still satisfies the full predicate → not complete: status stays `authenticated`, `operation` cleared, **local-cleanup-failure copy** carried, **no M3**, retry possible. E) read-back throws → unproven → fail closed (as D). F) after every path that claims local completion, a fresh `restoreSession()` must NOT authenticate. G) remote failure + local complete → `unauthenticated` + exact M3 copy. H) remote failure + local cleanup failure → `authenticated` + local-cleanup-failure copy + NO M3.
- **GREEN action**: implement gate-first invalidation (delete, fallback write `'false'`), the predicate read-back, the single bounded retry, and the completion gate driving the two terminal shapes.
- **Focused command**: `flutter test test/features/auth/presentation/cubit/auth_session_cubit_test.dart`.
- **Review checklist (strict)**: no new storage key; no change to `SecureStorageService`/`SessionCoordinator`/`AuthInterceptor`/`restoreSession()`; the predicate mirrors `restoreSession()` exactly (including role mapping); **the normal-path tests keep the strict physical-absence expectation for `access_token` and `refresh_token` (TC-MOB-05/06), and the predicate rule is asserted only in the fault-injected partial-cleanup cases**; no false success claim; no storage exception surfaced; no infinite retry; no timing dependence; single cleanup owner.
- **Matrix coverage**: TC-MOB-18 (both halves), TC-MOB-21.
- **DoD**: focused tests green; production footprint unchanged beyond the two cubit/state files already listed.

### T06 — M3 Login notice verification — VERIFICATION

- **Goal**: verify that the M3 login notice (remote-failure copy) is presented correctly through the existing feedback widgets. Scope is limited to the login screen, because only that surface exists at this point in the sequence.
- **Type**: verification (no production behaviour added; T04 already implemented the login rendering). If the verification exposes a real gap, a true RED is written first and the minimal GREEN fix is applied and reported.
- **Production files**: none expected.
- **Tests**: `demo_auth_flows_test.dart`.
- **Evidence required**: with `unauthenticated(errorMessage: <M3 copy>)` the login screen renders that exact text exactly once (one `AppAlert`); a clean unauthenticated state renders no notice; no raw Backend/exception detail is rendered.
- **Focused command**: `flutter test test/features/auth/presentation/pages/demo_auth_flows_test.dart`.
- **Review checklist**: exact copy string; rendered once per UI instance; existing `AppAlert` only; no acknowledgement API, no dismissal store, no new framework.
- **Matrix coverage**: TC-MOB-11, TC-MOB-12 (presentation half — login screen only).
- **DoD**: verification recorded as PASS with the test evidence; production footprint unchanged or the justified minimal change reported.
- **Not in scope (moved)**: the local-cleanup-failure notice cannot be verified here — its UI surfaces are created by T07/T08. That verification is **T08V**.

### T07 — Traveler + Operator shell migration — IMPLEMENTATION

- **Goal**: both AppBar actions use the backend-integrated flow with unchanged one-tap UX.
- **Production files**: `traveler_shell_page.dart`, `operator_shell_page.dart`.
- **Tests**: `traveler_shell_page_test.dart` (new), `operator_shell_page_test.dart` (new).
- **RED reason**: both pages still call the local-only cleanup, so no repository logout call is recorded and no busy state exists.
- **RED cases**: a single tap triggers exactly one `signOut()`/repository call; the action is disabled while `state.operation == signOut`; no dialog appears; no explicit navigation is performed by the page; the local-cleanup-failure copy renders when the state carries it.
- **GREEN action**: switch the actions to `signOut()`, derive disabled state from the operation marker, and render the notice via `AppAlert`.
- **Focused command**: `flutter test test/features/traveler/presentation/pages/traveler_shell_page_test.dart test/features/tour_operator/presentation/pages/operator_shell_page_test.dart`.
- **Review checklist**: no local-only path remains in these pages; no dialog added; no explicit navigation; widgets touch neither storage nor Dio.
- **Matrix coverage**: TC-MOB-19 (shells).
- **DoD**: both suites green; existing traveler/operator tests unaffected.

### T08 — Traveler Settings migration — IMPLEMENTATION

- **Goal**: the confirmed settings action uses the backend-integrated flow with unchanged confirmation UX.
- **Production files**: `traveler_settings_page.dart`.
- **Tests**: `traveler_settings_page_test.dart` (new).
- **RED reason**: the confirmed action still calls the local-only cleanup.
- **RED cases**: Cancel closes the dialog and triggers no logout; Confirm triggers `signOut()` exactly once; the dialog title/content copy is byte-identical to the current strings; the busy state disables the footer control; the local-cleanup-failure copy renders on the page.
- **GREEN action**: switch the confirmed action to `signOut()`; leave the dialog markup and copy untouched.
- **Focused command**: `flutter test test/features/traveler/presentation/pages/traveler_settings_page_test.dart`.
- **Review checklist**: dialog/copy unchanged (asserted); offline-trip sentence preserved; no UX redesign; no local-only path remains.
- **Matrix coverage**: TC-MOB-19 (settings + Cancel).
- **DoD**: focused suite green; copy strings unchanged in the diff.

### T08V — Entry-point local-cleanup notice verification — VERIFICATION

- **Goal**: verify the M7 local-cleanup-failure notice on the three migrated sign-out entry-point screens. The surfaces only exist after T07/T08, which is why this gate sits after them instead of inside T06.
- **Type**: verification (no production behaviour added; T05 already carries the copy on the authenticated state and T07/T08 render it). If it exposes a real gap, a true RED is written first and the minimal GREEN fix applied and reported.
- **Production files**: none expected.
- **Tests**: the three entry-point page tests from T07/T08.
- **Evidence required**: with an authenticated state carrying the local-cleanup copy, Traveler Shell, Operator Shell and Traveler Settings each render that exact text once (one `AppAlert` per screen); the M3 copy never appears in the `localCleanupFailed` case; no raw storage or remote exception text is rendered; the retry action remains possible (the control is not left disabled); no new feedback framework is introduced.
- **Focused command**: `flutter test test/features/traveler/presentation/pages/traveler_shell_page_test.dart test/features/tour_operator/presentation/pages/operator_shell_page_test.dart test/features/traveler/presentation/pages/traveler_settings_page_test.dart`.
- **Review checklist**: exact copy; one alert per screen; M3/local-copy mutual exclusion; no acknowledgement API, dismissal store or timer; existing `AppAlert` only.
- **Matrix coverage**: local-cleanup-failure UI verification (TC-MOB-18/TC-MOB-21 UI half), plus the TC-MOB-19 entry-point integration evidence already produced by T07/T08.
- **DoD**: verification recorded as PASS with the per-screen test evidence, or the justified minimal change reported.
- **Dependencies**: T07 and T08 complete.

### T09 — Regression / security / router integration — VERIFICATION / REVIEW

- **Goal**: prove no regression and no security/architecture drift.
- **Type**: verification/review (no artificial RED).
- **Production files**: none expected.
- **Tests**: full suite; targeted re-runs of the auth/interceptor/app-invalidation and router-guard suites; `test/app/app_session_invalidation_test.dart` or router suites touched only if a concrete gap is proven.
- **Evidence required**: full `flutter test` green (149 baseline preserved + new tests); post-logout guard destination `/auth/login`; no token logging; no raw ProblemDetails displayed; no blacklist assumption; no explicit logout navigation; no local-only logout path among the three entry points; expected footprint only.
- **Focused command**: `flutter test` plus the targeted suites.
- **Review checklist**: security review below; diff review against the footprint; findings classified and either fixed with a test or explicitly deferred with developer agreement.
- **Matrix coverage**: TC-MOB-08, 15, 16, 17, 20 and cross-task wiring.
- **DoD**: verification recorded as PASS with evidence; no unexplained failures or skips.

## Test Matrix Traceability

| Case | Task | Automated test | Manual/review |
| --- | --- | --- | --- |
| TC-MOB-01 | T02 | cubit: exactly one repository call + one cleanup | device tap |
| TC-MOB-02 | T01 | data source: path/method/body; no Authorization added | dev-tools request shape |
| TC-MOB-03 | T02/T03 | cubit: stored token value forwarded | — |
| TC-MOB-04 | T03 | cubit: five keys invalidated + provider sign-out invoked | — |
| TC-MOB-05 | T03 (+T05 fault case) | normal successful cleanup: `access_token` absent; M7 partial-failure fallback separately proves stale leftover cannot restore | — |
| TC-MOB-06 | T03 (+T05 fault case) | normal successful cleanup: `refresh_token` absent; M7 partial-failure fallback separately proves stale leftover cannot restore | — |
| TC-MOB-07 | T02/T03 | cubit: terminal `unauthenticated`; no `loading` emission | — |
| TC-MOB-08 | T04/T09 | router/guard: protected location → `/auth/login` after the terminal state | device walkthrough |
| TC-MOB-09 | T03 | cubit: null/blank/read-throw → `refreshToken: null`, no error UX | — |
| TC-MOB-10 | T01 (+T03) | data source: valid 200 `ApiResponse<bool>` success envelope; cubit: treated as success | Backend covers token states (BE TC-05/11/12) |
| TC-MOB-11 | T04 (+T06) | cubit: local ends + exact M3 copy; widget: login notice once | airplane-mode device check |
| TC-MOB-12 | T04 (+T06) | cubit: same for 500; widget: login renders no raw detail | optional failing-Backend check |
| TC-MOB-13 | T02/T03 | cubit: gated fake, two taps → one call | rapid-tap device check |
| TC-MOB-14 | T02/T03 | cubit: operation marker set then cleared on success and failure | — |
| TC-MOB-15 | T04 + T09 | message hygiene assertions; diff review | diff review |
| TC-MOB-16 | T09 | — | review-only: no blacklist claim/code |
| TC-MOB-17 | T09 | full `flutter test` (149 baseline preserved) | — |
| TC-MOB-18 | T05 | cubit: read failure → null path; delete/cleanup failure → predicate-based fail-closed rule, no false claim | mechanism review |
| TC-MOB-19 | T07 + T08 | three page tests: one call each; Cancel path; copy unchanged | device walkthrough of both shells + settings |
| Local-cleanup-failure UI (M7 notice on entry points) | T08V | three page tests: exact local copy once per screen, M3 never shown, no raw detail, retry possible | device walkthrough of both shells + settings |
| TC-MOB-20 | T02/T09 | cubit/widget: no redirect while pending | — |
| TC-MOB-21 | T05 | cubit: partial cleanup then a fresh `restoreSession()` must not authenticate | mechanism review |

No case is dropped. TC-MOB-18 and TC-MOB-21 are M7-owned and use the amended test cases A–H above.

## Manual Validation

Automated validation first, then device/emulator checks:

- **Success** — sign in → sign out (shell and settings) → `POST /api/v1/auth/logout` observed → credentials non-restorable → app lands on `/auth/login` → restart stays unauthenticated.
- **Remote failure** — sign in → make the Backend unavailable → sign out → local session still ends → login displayed → the exact M3 copy shown once → restart stays unauthenticated.
- **Entry points** — Traveler Shell (one tap), Operator Shell (one tap), Traveler Settings (dialog → Confirm), Settings Cancel (no request). Confirmation copy identical to the current strings.

M7 is validated automatically with fault-injected fake storage; forcing real secure-storage hardware failure is not required and must not be claimed as verified if not performed.

## Full Validation

After all tasks: `flutter pub get` → `dart format --output=none --set-exit-if-changed .` → `flutter analyze` → `flutter test` → `flutter build apk --debug` → `git diff --check` → `git status --short`, each recorded with command, exit code and pass/fail counts against the 149-test baseline. Additionally: no token logs; no raw ProblemDetails displayed; no blacklist assumption; no explicit logout navigation; no local-only logout path among the three entry points; no package/Kotlin upgrade; no Backend/FE change; expected footprint only.

## Security Review

- Tokens are never logged, printed, or embedded in user-facing copy; the request model carries the token only into the HTTP body.
- No raw credential, storage exception, stack trace or ProblemDetails text reaches the UI.
- Secure storage remains the only credential store.
- No Authorization requirement added; no blacklist/token-version assumption.
- Single cleanup owner; no duplicated cleanup in widgets or data sources.
- M7: no state in which the user is told they signed out while restorable credentials remain; the not-complete path is fail-closed, retryable and silent about storage internals.
- Duplicate submission cannot produce two cleanups or a late authenticated emission after cleanup.

## BE / FE Compatibility

| Area | Statement |
| --- | --- |
| Backend | **No change.** Mobile still calls `POST /api/v1/auth/logout` with `{"refreshToken": value\|null}`. Mobile never assumes immediate access-JWT invalidation. A remote 500/network failure may leave server-side refresh state active, but Mobile still ends its local session once local non-restorability is proven. |
| Web FE | **No change.** Web D1 remains: remote logout failure → preserve the Web client session, because Web JavaScript cannot reliably invalidate the HttpOnly refresh cookie. |
| Mobile | Remote logout failure → local logout continues, because Mobile controls its persisted auth material and can make the session non-restorable. |
| Relationship | These policies are intentionally platform-specific, not a cross-platform inconsistency: session ownership differs. |

## Out-of-Scope Guard

Not touched: Backend, `Capstone_FE`, `pubspec.yaml`/`pubspec.lock`, Kotlin/Gradle files, `docs/`, other specs/plans, `SecureStorageService`, `SessionCoordinator`, `AuthInterceptor`, `app_router`/`route_guards`/`app.dart`, `restoreSession()` semantics. No token refresh/rotation, no sign-out-all-devices, no Administrator flow, no confirmation redesign, no new screen, no new package, no acknowledgement API.

## Delivery Gate

After implementation → TDD/verification evidence → review → full validation: **STOP**. The developer alone chooses keep / commit / push / open PR / discard. No automatic `git add`, commit, push or PR. Delivery dependency: UC-05 Mobile is stacked on the UC-04 Mobile commit `cf736e1`; if UC-04 is not merged first, the PR base/merge order must reflect that dependency.

## Plan Approval Decisions

All previously open plan-level items are resolved:

1. **Local cleanup failure copy** — APPROVED: `We couldn't complete sign out on this device. Please try again.` It applies only when local invalidation cannot be proven safe; the session stays authenticated, retry is possible, the M3 copy is never used, no storage exception text and no server-success implication is shown, and presentation reuses the existing `AuthSessionState`/`AppAlert` pattern (no SnackBar/Toast/new framework).
2. **`clearSession()` visibility** — a repo-wide caller check is required at implementation time before any visibility change. Preliminary inspection found only the three UC-05 entry points plus the definition, and no test references. If no legitimate external caller remains after M6, the local-only method becomes private/internal; if a legitimate non-UC-05 caller exists, it stays available for that flow. The acceptance condition is unchanged either way: **no local-only logout path among the three approved entry points**.
3. **M3 notice lifetime** — the minimal existing state lifetime: emitted once as part of the terminal logout result, shown once on the Login UI instance, and retained in state until the next auth action/state transition replaces it. No acknowledgement API, no dismissal store, no new feedback framework, no scope expansion.

No unresolved developer question remains at plan level.

## Definition of Done

- All **implementation** tasks have recorded RED→GREEN evidence; all **verification/review** tasks have explicit PASS evidence.
- The M3 login notice presentation is verified in **T06** (login screen only).
- The local-cleanup-failure notice presentation is verified only after the entry-point surfaces exist, via **T08V**, on Traveler Shell, Operator Shell and Traveler Settings.
- No task may claim PASS for UI that does not yet exist at that point in the sequence; a verification gate whose surface is created later must be placed after that task (this is why the local-cleanup verification is T08V, not part of T06).
- M7 uses the actual `restoreSession()` predicate; every claimed local completion is followed by proof that a fresh `restoreSession()` cannot authenticate. The normal success path additionally deletes the five keys and verifies `access_token` and `refresh_token` are physically absent (TC-MOB-05/06); the predicate-based rule applies only to the fault-injected partial-cleanup cases and never relaxes the normal-path expectation.
- Remote failure + localComplete → `unauthenticated` + the exact M3 copy; localCleanupFailed → authenticated + the approved local-cleanup-failure copy + retry, with **no** M3.
- `AuthSessionStatus.loading` is never used for sign-out; busy state uses the existing `AuthSessionOperation.signOut` marker.
- All three entry points use `signOut()`; the Settings confirmation UX is unchanged; no explicit navigation anywhere.
- No Backend change, no FE change, no blacklist logic, no package/Kotlin upgrade.
- Full validation green (`pub get`, format check, analyze 0 issues, tests with the 149 baseline preserved and 0 failures, debug APK build, `git diff --check`, clean status with only expected files), manual validation performed or explicitly reported as not run.
- Delivery decision left to the developer, with the stacked-branch dependency recorded.

## Plan Approval Rule

This plan is **APPROVED FOR IMPLEMENTATION** by the developer on 2026-09-17.

Implementation allowed: **YES**, subject to the task-by-task TDD and review gates defined in this plan.

Implementation must begin with T01 only.
No later task may begin until the current task has completed RED → GREEN → focused verification → review PASS.

No commit, push or PR is authorised by this approval.
