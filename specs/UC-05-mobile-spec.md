# UC-05 Mobile Sign Out Specification

## Status

**APPROVED FOR PLANNING** (2026-09-17)

Developer decisions **M1–M7 were resolved on 2026-09-17** and are authoritative for UC-05 Mobile. No open developer decisions remain for the approved UC-05 Mobile scope. The implementation plan phase may begin on this specification; no code, test, plan or branch is created by this document.

## Mandatory Sources

| Source | Used for |
| --- | --- |
| `TEAM_ENGINEERING_RULES.docx` v2.0 | Workflow gate (§6), impact-based verification (§7), client state/error-flow rules (§16, U05), evidence rules (§19, §20), branch/commit rules (§24) |
| `Dev_and_CrossReview_Checklist.docx` v2.0 | G0–G3, C01–C16, I05, U01/U05, V01/V02/V05, C25–C34 acceptance items |
| `Capstone_Mobile/AGENTS.md` | Feature-first Clean Architecture, Page → Cubit → Repository → Data Source, `go_router`, secure-storage-only credentials, no raw Dio in widgets, required validation commands |
| `Capstone_BE/specs/UC-05-spec.md` (APPROVED FOR PLANNING) and `Capstone_BE/plans/UC-05-plan.md` (APPROVED FOR IMPLEMENTATION) | Mobile endpoint contract, idempotency, failure semantics, SRS §3.2.5 quotes (PC-01…PC-06, BR-12…BR-17, MSG13) |
| `Capstone_BE/src/TripMate.Api/Controllers/V1/AuthController.cs` and `src/TripMate.Application/Features/Authentication/SignOut/*` | Actual runtime DTO/route/response shape |
| Actual Mobile source under `lib/` and `test/` | All architecture, storage, navigation, error and test claims below |

SRS §3.2.5 wording is cited here through the **verbatim quotes recorded in the approved Backend spec**; the SRS document itself was not re-read for this phase.

## Scope

### In Scope

- Server-side revocation during Mobile sign-out: call `POST /api/v1/auth/logout` with the locally stored refresh token.
- Migrating **all three** existing user-initiated sign-out entry points from local-only clearing to the backend-integrated flow (M6): Traveler Shell AppBar, Operator Shell AppBar, Traveler Settings.
- The Mobile failure policy for network/timeout/5xx/infrastructure failures (M1: SRS BR-13 governs Mobile).
- The remote-failure notice shown on the sign-in screen after the local session ends (M3).
- Reuse of the existing centralized local cleanup (`AuthSessionCubit`) — no second cleanup mechanism.
- The local credential-cleanup invariant (M7) and its required safety behaviour.
- Duplicate-tap protection and in-flight state rules consistent with existing Cubit conventions.
- Post-logout navigation via the existing router/guard architecture (M2).
- Error presentation via the existing Mobile feedback widgets.
- Security requirements and a Mobile test matrix (TC-MOB-01…21).

### Out of Scope

- Any Backend change (UC-05 Backend is FINAL PASS; this feature consumes it as-is). The Backend body-less-POST 400 observation stays a contract note only.
- Redesigning confirmation behaviour: the two AppBar actions keep their current one-tap behaviour and Traveler Settings keeps its existing dialog and copy (M6). Confirmation parity is a separate future UX task.
- "Sign out all devices" — Backend BR-15/§10.2 keep sign-out strictly single-session.
- Access-token blacklisting / server-side JWT revocation — excluded by the approved Backend decision.
- Refresh-token rotation and any Mobile token-refresh endpoint call (see §Current Mobile Authentication Architecture: Mobile has no refresh call today; UC-05 does not add one).
- Firebase/provider account management beyond the existing `AuthIdentityService.signOut()` already invoked by the existing cleanup.
- Administrator sign-out on Mobile — the app fails closed for Administrator accounts and has no Administrator feature or route.
- Offline-trip data retention changes; the existing settings copy ("Downloaded offline trips stay on the device") is unchanged.
- UC-05 Web behaviour and its D1 decision — see §Compatibility Notes.
- New UI screens, SnackBar/Toast/global feedback frameworks, new state-management libraries.
- **Implementation mechanism** for guaranteeing local credential invalidation (cleanup ordering, invalidation marker/tombstone, hardened `SessionCoordinator` behaviour, retry strategy) — deliberately deferred to the implementation plan (M7).

## Current Mobile Authentication Architecture

All statements verified against the working tree on branch `feature/PhucTV-sign-in-mobile` (HEAD `cf736e1c95d8b914a815a3adfbe7a3e46c764b53`, clean tree).

| Concern | Actual mechanism |
| --- | --- |
| Framework | Flutter (Dart), Material 3. `pubspec.yaml`: `flutter_bloc ^9.1.1`, `go_router ^17.1.0`, `dio ^5.9.2`, `get_it ^9.2.1`, `flutter_secure_storage ^10.0.0`, `firebase_auth`, `google_sign_in`, `equatable`. |
| Routing | `go_router` — `createAppRouter(AuthSessionCubit)` in `lib/app/router/app_router.dart`; routes centralized in `lib/app/router/app_routes.dart` (`/auth/*`, `/traveler/*`, `/operator/*`). |
| Route guards | `lib/app/router/route_guards.dart` → `RouteGuards.redirect(session, routerState)`: when `!session.isAuthenticated`, requests for `/` (splash) or any protected route are redirected to `AppRoutes.login` (`/auth/login`). Guards key on role and on the backend-issued operator application status only. |
| Guard re-evaluation | `lib/app/app.dart`: `BlocListener<AuthSessionCubit, Object?>(listener: (_, _) => _router.refresh(), …)` — **every** Cubit state change re-runs the redirect. Navigation therefore follows auth state automatically. |
| Auth state | `AuthSessionCubit` (`lib/features/auth/presentation/cubit/auth_session_cubit.dart`) with `AuthSessionState` (`…/cubit/auth_session_state.dart`): statuses `unauthenticated / loading / authenticated / verificationEmailSent / failure`; `isAuthenticated => status == authenticated`; operations enum `{none, verifyEmail, resendVerificationEmail}`; optional `errorMessage`, `successMessage`, `role`, `applicationStatus`. |
| Session restore | `restoreSession()` replays backend-issued identity persisted at sign-in — provisional only ("not proof the access token is still server-valid; a later 401 clears it"). Restore requires `keep_signed_in == 'true'` **and** non-empty access token, refresh token and role. There is **no** Mobile token-refresh endpoint call anywhere in `lib/`; the Web refresh endpoint is not part of the Mobile contract. |
| API layer | `AuthRemoteDataSource` (`…/data/datasources/auth_remote_data_source.dart`) is the only auth HTTP layer, using the shared `DioClient`. It currently exposes `registerTraveler`, `verifyEmail`, `googleAuth`, `login` — **no logout method exists**. Domain contract `AuthRepository` mirrors those four operations only; `AuthRepositoryImpl` delegates to the data source. |
| DI | `lib/core/di/service_locator.dart`: `AuthRemoteDataSource`, `AuthRepository`, `DioClient`, `SecureStorageService`, `SessionCoordinator` are lazy singletons; `AuthSessionCubit` is a factory. |
| Network auth | `AuthInterceptor`: attaches `Authorization: Bearer <access_token>` from secure storage to any request lacking an explicit Authorization header; a 401 on a **non**-`/api/v1/auth/` request with a Bearer header triggers `SessionCoordinator.invalidate()`. **A 401 under `/api/v1/auth/` never triggers global invalidation** (explicit `_authPathPrefix` exemption). |
| Error mapping | `_handleDioError` maps HTTP status/codes to `ServerException`/`NetworkException` with allow-listed copy; unknown codes fall back to a generic message. No raw ProblemDetails detail is surfaced. |
| Tests | `flutter_test` + `bloc_test ^10.0.0`; hand-written fakes (`FakeAuthRepository`, `FakeSecureStorageService`, `FakeFirebaseAuthService`) in `test/features/auth/presentation/cubit/auth_session_cubit_test.dart`; Dio tests use a stub `RecordingHttpClientAdapter`; app-level wiring covered by `test/app/app_session_invalidation_test.dart` and `test/core/network/auth_interceptor_session_test.dart`. |

## Token Storage and Session Ownership

| Item | Actual behaviour |
| --- | --- |
| Access token | Persisted in **secure storage** (`flutter_secure_storage` via `SecureStorageService`) under `AppConstants.accessTokenKey` = `'access_token'`. Written by `AuthSessionCubit._saveSession`, read by `restoreSession()` and by `AuthInterceptor`. Unlike Web, the Mobile access token **is** persisted (encrypted platform storage), not memory-only. |
| Refresh token | Persisted in secure storage under `AppConstants.refreshTokenKey` = `'refresh_token'`. Written by `_saveSession`; read today only by `restoreSession()` and, after UC-05, by the sign-out flow. **App-readable**: a plaintext string available to app code via `SecureStorageService.read`. No rotation handling (no refresh call exists). |
| Expiry metadata | The Backend returns `accessTokenExpiresAtUtc` (present in `SessionResponseDto`), but Mobile **does not persist** it and does not use local expiry; expiry is enforced by the server (401 → session invalidation). |
| Other session state | `session_role`, `session_application_status`, `keep_signed_in` — all in secure storage (`lib/core/constants/app_constants.dart`). |
| Owner of cleanup | `AuthSessionCubit` owns all session persistence. UI widgets never touch storage directly; neither does the API layer. |
| Central cleanup mechanism | **Already exists — do not create a second one.** `AuthSessionCubit.clearSession()` (line 30) deletes the five keys via `_clearStoredSession` (line 361), best-effort signs out Firebase, and emits `AuthSessionState.unauthenticated()`. Tolerant variants already exist (`_clearStoredSessionBestEffort` line 369, `handleSessionExpired()` line 81). |
| Existing precedent for "local cleanup must not depend on remote success" | `handleSessionExpired()` emits `unauthenticated`, then clears storage best-effort, and wraps provider sign-out in `try/catch` with the documented rule: "A provider failure must never keep a server-rejected Mobile session visible after its local identity and credentials have been cleared." Same principle on role refusal (`_establishSession` → `_clearStoredSession` + best-effort provider sign-out). |
| M7 caveat on today's code | `clearSession()` currently uses the **strict** `_clearStoredSession` before emitting, so a delete failure aborts before the unauthenticated emission; conversely the best-effort helper tolerates partial deletion. Neither today's tolerance nor today's strictness by itself satisfies the M7 invariant — the plan must choose the mechanism that guarantees stale credentials are not restorable. |

## Existing Sign-Out Behavior

| Item | Finding |
| --- | --- |
| Classification | **LOCAL-ONLY** — the UI calls `AuthSessionCubit.clearSession()` directly; no HTTP request is made to the Backend. Server-side refresh revocation therefore does **not** happen today, which is exactly the gap UC-05 Mobile closes. |
| Entry point 1 (in scope, M6) | `lib/features/traveler/presentation/pages/traveler_shell_page.dart:33` — AppBar `IconButton` (`tooltip: 'Sign out'`, `Icons.logout`) with `onPressed: context.read<AuthSessionCubit>().clearSession`. **No confirmation dialog**; keeps one-tap behaviour. |
| Entry point 2 (in scope, M6) | `lib/features/tour_operator/presentation/pages/operator_shell_page.dart:31` — identical pattern; keeps one-tap behaviour. |
| Entry point 3 (in scope, M6) | `lib/features/traveler/presentation/pages/traveler_settings_page.dart:64` — footer `OutlinedButton.icon('Sign out')` → `_confirmSignOut()` (line 76) shows an `AlertDialog` (title `'Sign out of TripMate?'`, content `'Your session on this device will end. Downloaded offline trips stay on the device.'`, actions `Cancel` / `Sign out`), then calls `clearSession()`. **Dialog and copy are preserved unchanged.** |
| Navigation after current sign-out | None is issued. The state change to `unauthenticated` makes `BlocListener → _router.refresh()` re-run `RouteGuards.redirect`, which sends the user from `/traveler*` or `/operator*` to `/auth/login`. |
| Loading / duplicate protection | None on any sign-out path today. The Cubit's in-flight guard pattern exists elsewhere: `bool _verificationActionInProgress` guarding `verifyEmail`/`resendVerificationEmail`. |
| Error feedback | None on the sign-out paths today. The app's auth-failure convention is inline `AppAlert(type: AppAlertType.error)` driven by `AuthSessionState` (`login_page.dart:96-100`); `ErrorView` is used for route-level failures. No SnackBar/Toast usage exists in these screens. No localization/i18n layer exists in the app — UI copy is inline English string literals, so M3's copy follows that existing mechanism rather than a parallel one. |

## Backend Contract

Verified against the actual Backend implementation and approved spec/plan. **Unchanged by this amendment.**

| Item | Value |
| --- | --- |
| Endpoint | `POST /api/v1/auth/logout` (`AuthController.Logout`, `[HttpPost("logout")]`; class-level `[AllowAnonymous]`) |
| Method | POST |
| Authorization | Not required and not validated. The Mobile `AuthInterceptor` may attach a Bearer token automatically (the path is not excluded); the Backend ignores it. **UC-05 must not add an Authorization requirement, and no code may depend on the header.** |
| Request body | `application/json`, `[FromBody] SignOutRequestDto` → `{ "refreshToken": "..." }`; property `RefreshToken` (`string?`, optional/nullable), binding from camelCase JSON. |
| Success | `HTTP 200` with `ApiResponse<bool>`: `{"success":true,"statusCode":200,"message":"Signed out successfully.","data":true,"errors":null}`. Mobile validates the sign-out envelope through `_unwrapSignOut()` (`success == true` and `data == true`); it does not use the map-oriented `_unwrap()` helper. |
| Failure | Infrastructure/database failure → `HTTP 500` RFC-7807 `ProblemDetails` (existing global title). Never converted to a false 200. |
| Idempotency | `null` / empty / whitespace refresh token → 200 with no DB access; unknown token → 200 no mutation; already-revoked token → 200 preserving the original `RevokedAtUtc`; active token → `RevokedAtUtc` stamped and saved. |
| Scope of revocation | The matched refresh row only. Other sessions of the same user stay active (BR-15). No `Users`/`OperatorProfiles` mutation (BR-14). |
| Cookie | Not applicable to Mobile (Web-only deletion path). |
| Access JWT | Not blacklisted; remains cryptographically valid until natural expiry (~15 min). |
| Mobile-specific Backend verification technique | Backend TC-01/TC-13 verify non-reusability by presenting the revoked token to the **Web** refresh endpoint (expects 401 `AUTH_TOKEN_INVALID`). Mobile never calls that endpoint. |
| SRS message code | The Backend spec cites SRS §5.3 `MSG13` for sign-out, but no `MSG13` string or sign-out copy exists in the Mobile codebase; M3 therefore approves explicit copy (below). |
| Body-less POST (contract note only) | A completely body-less request can return 400 because the action binds `[FromBody]`. `{"refreshToken":null}` and `{"refreshToken":""}` are both idempotent 200. Mobile always sends a body, so this is not reachable from this client (M5). **No Backend change is requested or permitted.** |

## Functional Flow

All flows reuse the existing layers: Page → `AuthSessionCubit` → `AuthRepository` → `AuthRemoteDataSource` → `DioClient`. Storage access stays inside the Cubit; the API layer never reads storage and widgets never call Dio.

### Success Flow

1. Authenticated user triggers sign-out from one of the three entry points (AppBar one-tap, or settings footer after its existing confirmation).
2. Duplicate/in-flight guard activates (F7). The session **remains `authenticated`** while the request is in flight.
3. `AuthSessionCubit` reads the refresh token from secure storage. A read failure is treated as "no token" (F5) and never blocks sign-out.
4. `AuthRepository.logout(refreshToken)` → `AuthRemoteDataSource.logout(refreshToken)` → `POST /api/v1/auth/logout` with `{"refreshToken": <stored value or null>}`. No explicit Authorization header is added by UC-05 code.
5. Backend returns `HTTP 200` (idempotent for null/blank/unknown/already-revoked).
6. Local logout completes through the existing single cleanup owner: the five secure-storage keys are invalidated, Firebase sign-out is attempted best-effort, and the session reaches the approved **local completion point** at which locally stored credentials can no longer be used for session restoration (M7).
7. The Cubit emits `AuthSessionState.unauthenticated()`.
8. The router re-evaluates the guard and the user lands on `/auth/login`. Loading/in-flight state is released.
9. A later app start finds no restorable session (`restoreSession()` requires `keep_signed_in` + tokens + role), and the old access token is no longer present locally.

### Network Failure (F1 — M1 governs)

| Aspect | Required behaviour |
| --- | --- |
| Server result | Request never reached the Backend (network error/timeout); server-side revocation did not happen and the refresh row may remain active until natural expiry. |
| Local credentials | **Local session still ends.** Credentials are invalidated under the M7 guarantee. |
| Auth UI | Becomes unauthenticated. |
| Error / notice | One safe one-shot notice on the login screen (M3): "You're signed out on this device, but we couldn't complete server-side sign-out." Never claims remote revocation succeeded, never exposes raw detail. |
| Navigation | Automatic guard redirect to `/auth/login` (M2). |
| Retry | Not required for the local session (already ended); the user may sign in again, and the stale server session expires naturally. Wording must not imply the local session still exists. |

### Backend Failure (F2 — HTTP 500 / infrastructure, M1 governs)

| Aspect | Required behaviour |
| --- | --- |
| Server result | Revocation did not complete; response is 500 ProblemDetails. |
| Local credentials | **Local session still ends**, identical to F1. |
| Auth UI | Becomes unauthenticated. |
| Error / notice | Same approved M3 notice; raw ProblemDetails title/detail is never surfaced. |
| Navigation | Automatic guard redirect. |
| Retry | Not required locally; documented as "the server may still hold a valid session until natural expiry", never as a false success. |

### Missing Local Refresh Token (F3 — M4 governs)

| Aspect | Required behaviour |
| --- | --- |
| Situation | The app is authenticated but `refresh_token` is missing, null, blank or unreadable. |
| Behaviour | Use the **same** logout pipeline and send `{"refreshToken": null}`; the Backend treats this as idempotent 200 with no DB mutation; then perform normal local cleanup. |
| UX | No separate missing-token error UI, no branch into a different flow. |

### Unknown / Already Revoked Token (F4)

| Aspect | Required behaviour |
| --- | --- |
| Backend | 200 idempotent (unknown → no mutation; already-revoked → original `RevokedAtUtc` preserved). |
| Mobile | Normal local cleanup, unauthenticated, redirect to `/auth/login`, **no error and no notice** (this is a success outcome; the token's state is intentionally not disclosed). |

### Secure Storage Read Failure (F5)

| Aspect | Required behaviour |
| --- | --- |
| Situation | Reading `refresh_token` throws or returns unusable data. |
| Behaviour | Treat as `refreshToken: null`, continue the remote call, then perform local cleanup. Sign-out must never be blocked solely because the refresh token could not be read. No storage error is shown to the user. |

### Secure Storage Cleanup Failure (F6 — M7 governs)

| Aspect | Required behaviour |
| --- | --- |
| Distinction | **Remote logout failure ≠ local credential cleanup failure.** F1/F2 are remote failures and still require local logout (BR-13). F6 is a local failure where credential deletion cannot be guaranteed. |
| Invariant | "After a user initiates sign-out, stale locally persisted credentials must never be eligible for future session restoration, even if secure storage deletion partially fails." |
| Local completion definition | "Logout is considered locally complete only when the application can guarantee that locally stored authentication credentials are no longer usable for session restoration." |
| Prohibited | Local credential cleanup must **not** be silently treated as a successful local logout while stale credentials may remain usable or restorable; the app must not falsely report local logout as safely complete in that condition, and the M3 copy ("You're signed out on this device…") must not be used when local credential invalidation is not guaranteed. |
| User-visible | No raw storage exception is shown. When local invalidation/verification cannot be proven safe, the user is shown the **already-approved local-cleanup-failure copy** (documentation synchronisation of the plan's approved decision, 2026-09-17 — not a new business rule):<br><br>> "We couldn't complete sign out on this device. Please try again."<br><br>Conditions for this copy: it applies **only** to local invalidation/verification failure; the session **remains authenticated**; the operation marker is **released** (no stuck busy state); **retry is allowed**; the **M3 copy is NOT shown** (it would falsely claim a completed local sign-out); and no raw storage or remote exception text is exposed. It is distinct from the M3 copy `You're signed out on this device, but we couldn't complete server-side sign-out.`, which requires a proven local completion. |
| Mechanism | Deliberately **not** prescribed here. Cleanup ordering, an invalidation marker/tombstone, hardened `SessionCoordinator` behaviour, retry strategy and secure-storage recovery are implementation-plan decisions to be chosen after inspecting the lowest-risk approach. If the current architecture cannot satisfy the invariant without a larger architectural change, the plan must record it as a **PLAN-TIME DESIGN CONSTRAINT** with the required scope approval. |

### Duplicate Submission (F7)

One user intent → one backend request → one cleanup transition. A second trigger while the first is in flight issues no additional HTTP request and produces no second cleanup or state transition.

## State Management

- Existing state owner: `AuthSessionCubit` / `AuthSessionState` (no new store, no new provider).
- The session must remain `AuthSessionStatus.authenticated` while the remote logout request is in flight.
- **Architectural constraint (verified, not a preference):** sign-out must **not** emit `AuthSessionStatus.loading`. `isAuthenticated` is defined as `status == authenticated`; emitting `loading` would make `RouteGuards.redirect` treat the user as unauthenticated and redirect to `/auth/login` *before* the request completes, breaking the failure policy and showing the login screen on a failed sign-out.
- In-flight indication is therefore a non-state flag on the Cubit (existing `_verificationActionInProgress` precedent), optionally combined with UI-local disabled/busy state on the trigger control. Extending `AuthSessionOperation` is acceptable only if it does not change `status`.
- The transition to `unauthenticated` happens only when local logout processing reaches the approved local completion point (M7). Remote network/500 failure does not prevent that transition (M1); a local cleanup failure does not permit a false claim that local logout safely completed (M7).
- The M3 notice is the one new user-visible state element: it is carried through the existing `AuthSessionState` message pattern so the login screen can render it once via `AppAlert`. Its exact shape follows the existing `successMessage` precedent and is finalised in the plan; no new feedback framework is introduced.

## Session Cleanup

One owner: **`AuthSessionCubit`**. Cleanup must not move into a page/widget, the repository, or the remote data source.

| Cleared item | Required |
| --- | --- |
| Access token (`access_token`) | YES |
| Refresh token (`refresh_token`) | YES |
| Session role (`session_role`) | YES |
| Application status (`session_application_status`) | YES |
| Keep-signed-in flag (`keep_signed_in`) | YES |
| In-memory auth state | YES — emit `AuthSessionState.unauthenticated()` at the local completion point |
| Firebase/provider identity | YES — best-effort via the existing `AuthIdentityService.signOut()`; a provider failure must not block the local transition |
| Expiry metadata | NOT APPLICABLE — never persisted on Mobile |
| Other persisted auth metadata | None (`PreferencesService` holds non-credential preferences; UC-05 does not touch it) |

**M7 invariant (prominent):** after a user initiates sign-out, persisted credentials that survived a partial storage failure must **not** be eligible for session restoration. The cleanup path is security-critical: it must guarantee the invariant, must not report local logout as safely complete while usable credentials may remain, and must not expose storage exceptions to the user.

## Navigation

- **M2 — resolved:** navigation is **automatic**. Emitting `unauthenticated` triggers `BlocListener → _router.refresh()` in `lib/app/app.dart`, which re-runs `RouteGuards.redirect`; any protected `/traveler/*` or `/operator/*` location resolves to `AppRoutes.login` (`/auth/login`), as does the splash route when unauthenticated.
- **Explicit navigation is prohibited for logout:** no `context.go(...)`, `context.push(...)` or `context.replace(...)` is added by UC-05 code.
- All three entry points are inside protected routes, so every sign-out path resolves to `/auth/login`.

## Loading / Duplicate Submission

| Requirement | Detail |
| --- | --- |
| In-flight guard | A single non-state flag on the Cubit (existing `_verificationActionInProgress` precedent). A second trigger while set returns immediately without a new request. |
| Control state | The trigger control must not start a second request; busy/disabled presentation follows Material 3 conventions (`AppButton.isLoading`; AppBar `IconButton` disabled via `onPressed: null`). Exact widget treatment is for the plan. |
| Release | The flag is released on every outcome — success, HTTP failure, network failure, storage read/cleanup failure — including exceptions, so the control never remains permanently disabled. |
| No global mutex | The app has no global mutex; none is introduced. |
| No `loading` state | Per §State Management, `AuthSessionStatus.loading` must not be emitted for sign-out. |

## Error Handling

- Presentation reuses the existing convention: the `AuthSessionState` message pattern plus inline `AppAlert(type: AppAlertType.error)` on the login/auth screen. No SnackBar, Toast or new global feedback framework is introduced, and no parallel copy/localization mechanism is created (the app already uses inline English literals).
- **M3 — resolved.** When the **remote** logout fails (network/timeout/5xx/infrastructure) while local logout completes under M1, the user receives **one safe one-shot notice on the login screen**, using the approved copy:

  > "You're signed out on this device, but we couldn't complete server-side sign-out."

- The notice is informational and must communicate both facts: the device is signed out locally, and server-side sign-out could not be completed. It must **not** claim server revocation succeeded, display raw Backend detail, or expose credentials.
- The previous "silent local logout with logging only" option is **withdrawn** by M3.
- **Scope of the copy:** this notice applies to **remote invalidation failure** only. A local credential-cleanup failure under M7 is a different condition and must not use wording that claims "signed out on this device" unless local credential invalidation is guaranteed.
- **M7 local-cleanup failure — distinct copy (documentation synchronisation, 2026-09-17).** When local invalidation or verification cannot be proven safe, the single user-facing text is the already-approved:

  > "We couldn't complete sign out on this device. Please try again."

  It is presented through the same existing `AuthSessionState` message + `AppAlert` mechanism while the session stays authenticated, the operation marker released, retry available, **no M3 copy**, and no raw storage/remote exception. The M3 and local-cleanup copies are mutually exclusive.
- Unknown/already-revoked token (success) and missing-token (M4) paths show **no** error or notice.
- Never displayed: access token, refresh token, Authorization value, cookie/header values, stack traces, internal exception text, or raw ProblemDetails `detail`/`title`.
- Error handling never alters the M1 outcome: the local session ends regardless of what the remote error says (subject to the M7 guarantee).

## API Requirements

| Item | Specification |
| --- | --- |
| Domain contract | `AuthRepository.logout(String? refreshToken) → Future<void>` (or an equivalent typed request object) added to `lib/features/auth/domain/repositories/auth_repository.dart`. No use-case class is introduced unless the plan proves the existing Cubit→repository flow insufficient (AGENTS.md forbids empty layers). |
| Data source | `AuthRemoteDataSource.logout(String? refreshToken) → Future<void>` implemented in `AuthRemoteDataSourceImpl` using the shared `DioClient`: `POST /api/v1/auth/logout` with `data: {'refreshToken': refreshToken}`. |
| Request model | `lib/features/auth/data/models/sign_out_request.dart` following the existing hand-written `LoginRequest` convention (`toJson()` → `{'refreshToken': refreshToken}`). No `json_serializable` code generation is introduced for it, matching the existing auth request models. |
| Authorization header | Not added by UC-05. The shared `AuthInterceptor` may attach the stored access token automatically; the Backend ignores it and no code may depend on it. |
| Refresh token source | Read from secure storage by `AuthSessionCubit` via `AppConstants.refreshTokenKey` and passed as a parameter. The API layer never reads storage. |
| Success handling | HTTP 200 is accepted only when the `ApiResponse<bool>` envelope has `success == true` and `data == true`. Use `_unwrapSignOut()`; do not call the map-oriented `_unwrap()` helper. |
| 500 / non-2xx handling | Propagate the existing safe `ServerException` shape from `_handleDioError` (message, status code, optional code). No retry loop, no silent success. |
| Network error handling | Propagate the existing `NetworkException` with the app's standard connectivity copy. |
| Timeouts | Shared `DioClient` configuration (`ApiConstants`: 20 s connect/send, 30 s receive). No logout-specific timeout unless the plan justifies it. |
| Idempotency | Safe to repeat; the Backend guarantees 200 for null/blank/unknown/already-revoked. UC-05 still avoids duplicate intent from a single user action. |
| No blacklist assumption | No blacklist lookup, token-version check, or access-token invalidation logic anywhere. |

## Security Requirements

1. The refresh token must never be logged, printed, embedded in an error message, or included in analytics/crash text.
2. The access token must never be logged or displayed.
3. No raw credential (token, header, cookie, stack trace, internal error) may reach the UI.
4. Secure-storage conventions are preserved: tokens stay in `flutter_secure_storage` through `SecureStorageService`; nothing auth-related is written to `SharedPreferences`/`PreferencesService`.
5. No unnecessary token copying/duplication beyond the single value passed into the repository call.
6. The logout request carries only the refresh credential the Backend defines; no extra identity fields.
7. No assumption that the already-issued access JWT becomes invalid server-side at logout.
8. Local cleanup uses the existing centralized mechanism — one owner, no duplicated cleanup in widgets or data sources.
9. **M7:** after sign-out intent, stale locally persisted credentials must never become eligible for future session restoration, and local logout must not be reported as safely complete while such credentials may remain usable.
10. Duplicate submission must not create unsafe state transitions (e.g. two concurrent cleanups, or a late failure emitting an authenticated state after cleanup).
11. The flow must not weaken the existing rule that a 401 under `/api/v1/auth/` never triggers global session invalidation, and must not require changing `AuthInterceptor`/`SessionCoordinator` behaviour unless the plan identifies it as the M7 mechanism (in which case it is a plan-time design item, not a spec change).
12. **M3:** the failure notice must be informational only and must never imply successful server-side revocation.

## Access JWT Semantics

- The Backend does **not** blacklist access tokens (approved UC-05 decision; the SRS PC-02/BR-12 blacklist wording is a recorded known deviation).
- After successful sign-out the Mobile app no longer possesses the access token: it is removed from secure storage (or otherwise made non-restorable per M7) and the session state is unauthenticated.
- An already-issued JWT may remain cryptographically valid on the server until natural expiry (~15 minutes). No Mobile code, comment, copy, or test may claim immediate server-side invalidation.
- The revoked refresh token can no longer be exchanged for a new access token (Backend PC-01). Mobile calls no refresh endpoint, so renewal cannot occur locally either.
- Because local logout is unconditional on remote failure (M1), a failed remote logout cannot leave the app holding a usable credential — subject to the M7 guarantee about partial storage failures.

## Test Matrix

Automated = achievable with the existing stack (`flutter_test` + `bloc_test`, hand-written fakes, Dio stub adapter, `testWidgets` with the real router/guards). Manual/review = device/emulator or review-only assertion.

| ID | Scenario | Expected result | Automated | Manual/review |
| --- | --- | --- | --- | --- |
| TC-MOB-01 | Authenticated user triggers sign-out exactly once | One repository/data-source logout call; one cleanup; one `unauthenticated` emission | YES — Cubit test with counting fake | Device tap check |
| TC-MOB-02 | Correct endpoint/method/request DTO | `POST /api/v1/auth/logout` with `{'refreshToken': …}`; no Authorization added by UC-05 code | YES — Dio stub adapter asserting path, method, body | Request shape checked in dev tools |
| TC-MOB-03 | Correct stored refresh token sent | Value read from `AppConstants.refreshTokenKey` is the value in the body | YES — Cubit test with fake storage; adapter test for the data source | — |
| TC-MOB-04 | Successful 200 performs approved local cleanup | All five secure-storage keys invalidated; Firebase sign-out invoked | YES — Cubit test with fake storage/firebase | — |
| TC-MOB-05 | Access token removed locally after success | `access_token` absent after sign-out | YES | — |
| TC-MOB-06 | Refresh token removed locally after success | `refresh_token` absent after sign-out | YES | — |
| TC-MOB-07 | Auth state becomes unauthenticated | Emitted state is `AuthSessionState.unauthenticated()`; no `loading` emission during the flow | YES | — |
| TC-MOB-08 | Correct navigation/Guest state after success | Router resolves to `/auth/login` for a protected location after the state change | YES — `testWidgets` with `createAppRouter` | Device/emulator walkthrough |
| TC-MOB-09 | Missing local refresh token (null/blank/unreadable) | Single flow with `refreshToken: null`; Backend 200 treated as success; normal cleanup; no missing-token error UI | YES — Cubit tests (null, empty, read-throw) | — |
| TC-MOB-10 | Unknown / already revoked token → Backend 200 | Treated as success: local cleanup, unauthenticated, **no** error or notice | YES — fake repository returning success | Backend integration covered by BE TC-05/TC-11/TC-12 |
| TC-MOB-11 | **Network failure (M1)** | Remote revoke fails; local auth still ends (credentials invalidated, state unauthenticated); router goes to `/auth/login`; exactly one safe one-shot M3 notice is shown on the login screen; no false claim of successful server-side revocation | YES — fake repository throwing `NetworkException` + widget test asserting the notice appears once | Airplane-mode device check |
| TC-MOB-12 | **HTTP 500 (M1)** | Same local outcome and same single safe notice as TC-MOB-11; raw ProblemDetails title/detail never rendered | YES — `ServerException(500)` + widget assertion on the notice text and absence of raw detail | Optional: point the app at a failing Backend |
| TC-MOB-13 | Duplicate tap blocked | Only one repository call and one cleanup for two rapid triggers; control disabled/busy in between | YES — Cubit test with completer-gated fake | Rapid-tap device check |
| TC-MOB-14 | Loading state settles correctly | In-flight flag released on success and on every failure; control usable again; no `loading` status emitted | YES | — |
| TC-MOB-15 | No access/refresh token logging | No token value in any produced log or user-facing message; error/notice copy contains no token | YES (message assertions) + diff review | Review of the diff |
| TC-MOB-16 | No server-side access-JWT blacklist assumption | No blacklist/cache/version lookup in the diff; no code, comment or copy claims immediate invalidation | Review-only | Review against §Access JWT Semantics |
| TC-MOB-17 | Existing login/refresh/session behaviour does not regress | Existing auth suites stay green: `auth_session_cubit_test`, `auth_remote_data_source_test`, `auth_interceptor_session_test`, `app_session_invalidation_test`, guard tests | YES — full `flutter test` | — |
| TC-MOB-18 | **Local storage failure — split by kind** | (a) READ failure → `refreshToken: null`, flow continues, cleanup proceeds. (b) DELETE/CLEANUP failure → the M7 invariant holds: stale persisted credentials cannot restore a session on a later restore/restart, and the app does not falsely claim safe local completion while they may remain usable; no raw storage exception shown | YES — fake storage throwing on read and on delete, with a follow-up `restoreSession()` assertion | Review of the chosen mechanism in the plan |
| TC-MOB-19 | **All three entry points use the same backend-integrated flow** | Traveler Shell AppBar, Operator Shell AppBar and Traveler Settings each trigger the repository logout exactly once; one-tap behaviour preserved on both shells; the settings dialog and its existing copy are preserved | YES — widget test per entry point | Device walkthrough of both shells + settings |
| TC-MOB-20 | No premature redirect while the remote request is pending | While the request is in flight the session remains `authenticated` and the guard does **not** redirect; the redirect happens only after the local completion point | YES — `testWidgets` with gated fake repository and the real router | — |
| TC-MOB-21 | **Post-logout restoration safety (M7)** | After a partially failing secure-storage cleanup, stale credentials are not eligible to restore authentication on a subsequent `restoreSession()`/app-restart path | YES — fake storage that fails specific deletes, then a fresh `restoreSession()` must settle unauthenticated | Review of the mechanism; the exact implementation-level assertion is finalised in the approved plan |

## Definition of Done

Specification phase (this document):

- Mandatory sources read (TEAM_ENGINEERING_RULES, Dev_and_CrossReview_Checklist, Mobile AGENTS.md).
- Actual Mobile auth code inspected: Cubit, state, repository, data source, storage, interceptor/coordinator, router/guards, all three sign-out entry points, error-presentation widgets, existing tests.
- Access-token, refresh-token and metadata storage verified against code.
- Existing centralized cleanup (`AuthSessionCubit`) verified and reused; no second cleanup owner proposed.
- Backend request DTO, response shape, idempotency and failure semantics verified from Backend source/spec.
- **M1–M7 resolved** and internally consistent.
- **All three entry points migrate**; no local-only logout path remains among the approved UC-05 entry points; confirmation UX unchanged (shells one-tap, settings dialog + copy preserved).
- Remote logout failure still ends the local Mobile session (M1) and produces exactly one safe one-shot login notice (M3).
- Missing refresh token uses `refreshToken: null` with no separate error UX (M4).
- Body-less POST remains NOT APPLICABLE for Mobile (M5); no Backend change requested.
- Access JWT blacklist is not assumed anywhere.
- Stale locally persisted credentials cannot restore a session after sign-out intent (M7); the implementation mechanism is deferred to the plan, with a PLAN-TIME DESIGN CONSTRAINT recorded if the current architecture cannot satisfy it without a larger change.
- Web D1 remains valid for UC-05 Web only; Mobile and Web intentionally differ because session ownership differs.
- Test matrix written with automated/manual mapping (TC-MOB-01…21).
- No production implementation in this phase; only this spec file is created/modified.

Implementation phase (for later, not authorised here): `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, plus `flutter build apk --debug` when Android runtime is affected, and the manual/device checks in the matrix.

## Decision Log

**M1 — Mobile logout failure policy**

- Question: should Mobile always clear local credentials even when backend invalidation fails, or preserve the session as UC-05 Web does?
- Sources: SRS §3.2.5 **BR-13** ("the local session data and the stored tokens must always be cleared on the client, even when the server-side invalidation cannot be completed") and PC-03, verbatim via the approved Backend spec §5; the approved Backend decision §6.2 item 3 ("client applications clear their local authentication and session state immediately"); the Mobile precedent in `handleSessionExpired()` ("a provider failure must never keep a server-rejected Mobile session visible after its local identity and credentials have been cleared"); and Mobile's session ownership (Mobile owns both tokens in secure storage and is responsible for making its locally controlled credentials non-restorable during sign-out; M7 governs the exceptional case where secure-storage cleanup cannot be guaranteed).
- Decision: **SRS BR-13 governs Mobile.** If the remote logout fails for any reason — network error, timeout, HTTP 5xx, infrastructure failure — the app **still** ends the local session: locally controlled authentication/session data is cleared, the auth state becomes unauthenticated, and the router guard moves the user to the login/auth flow. **UC-05 Web D1 is not copied to Mobile and remains valid for UC-05 Web only.** The difference is intentional: Web refresh ownership is an HttpOnly cookie that frontend JavaScript cannot reliably clear on a failed remote logout, whereas Mobile owns both tokens in secure storage and is responsible for making its locally controlled credentials non-restorable during sign-out. If secure-storage cleanup cannot be guaranteed, M7 requires a fail-closed mechanism that prevents stale credentials from becoming eligible for future restoration.
- Status: **RESOLVED (2026-09-17).**
- Developer approval required: NO — approved.

**M2 — Post-logout navigation**

- Decision: automatic through the existing architecture — `AuthSessionCubit` emits `unauthenticated` → existing `BlocListener`/router refresh → `RouteGuards.redirect` → `/auth/login`. Explicit `context.go(...)`, `context.push(...)` or `context.replace(...)` for logout is prohibited; duplicate navigation logic is avoided.
- Status: **RESOLVED (2026-09-17).**
- Developer approval required: NO — approved.

**M3 — Remote logout failure notice**

- Decision: if remote logout fails but local logout completes, the user receives **one** safe, one-shot notice on the login screen, implemented through the existing `AuthSessionState` message/state pattern plus `AppAlert` on the login/auth screen. No SnackBar, Toast or new global feedback framework; no parallel copy mechanism (the app uses inline English literals).
- Approved copy: "You're signed out on this device, but we couldn't complete server-side sign-out."
- The notice states both facts (local sign-out completed, server-side sign-out not completed), never claims server revocation succeeded, and never shows raw ProblemDetails, tokens, Authorization values, stack traces or internal exception text.
- The previously considered "silent local logout with logging only" option is **withdrawn**.
- Scope: applies to **remote** invalidation failure only; a local credential-cleanup failure (M7) must not use wording that claims "signed out on this device" unless local credential invalidation is guaranteed.
- Status: **RESOLVED (2026-09-17).**
- Developer approval required: NO — approved.

**M4 — Missing local refresh token**

- Decision: a missing, null, blank or unreadable `refresh_token` uses the **same** logout pipeline, sending `{"refreshToken": null}` to `POST /api/v1/auth/logout` (Backend idempotent 200) and then performing normal local cleanup. No separate error UX for the missing token; one deterministic pipeline is simpler and matches the Backend idempotency contract.
- Status: **RESOLVED (2026-09-17).**
- Developer approval required: NO — approved.

**M5 — Body-less POST semantics**

- Decision: **NOT APPLICABLE to Mobile** because Mobile always sends a JSON request body, including the `{"refreshToken": null}` case. The Backend-side body-less 400 observation is retained only as a contract note. **No Backend change.**
- Status: **RESOLVED (2026-09-17).**
- Developer approval required: NO — approved.

**M6 — Sign-out entry points**

- Decision: **all three** current entry points migrate from local-only sign-out to the backend-integrated UC-05 flow — Traveler Shell AppBar, Operator Shell AppBar and Traveler Settings. No approved entry point may remain local-only, otherwise the refresh session could remain active server-side and UC-05 would be only partially implemented.
- Confirmation UX is **unchanged**: both AppBar actions keep their current one-tap behaviour, and Traveler Settings keeps its existing confirmation dialog and copy. No new dialog is added to the AppBar actions in this UC; confirmation parity is a separate future UX task.
- Status: **RESOLVED (2026-09-17).**
- Developer approval required: NO — approved.

**M7 — Local credential cleanup failure**

- Question: what is required when local secure-storage cleanup itself fails, as opposed to the remote logout failing?
- Decision (security rule): a local secure-storage cleanup failure **must not** be silently treated as a successful local logout if stale authentication credentials may still remain usable or restorable. The two failure classes are distinct: a remote failure (network/5xx) still requires local logout under BR-13, while a local cleanup failure means credential deletion cannot be guaranteed.
- Spec-level invariants:
  - "After a user initiates sign-out, stale locally persisted credentials must never be eligible for future session restoration, even if secure storage deletion partially fails."
  - "Logout is considered locally complete only when the application can guarantee that locally stored authentication credentials are no longer usable for session restoration."
- Approved failure copy (documentation synchronisation of the plan's approved decision, 2026-09-17): `We couldn't complete sign out on this device. Please try again.` — used only when local invalidation/verification cannot be proven safe, with the session retained, the operation released, retry allowed, no M3 and no raw storage/remote detail.
- The implementation mechanism is deliberately **not** prescribed here: cleanup ordering, an invalidation marker/tombstone, hardened `SessionCoordinator` behaviour, retry cleanup and secure-storage recovery strategy are to be decided in the implementation plan after inspecting the lowest-risk approach. If the current architecture cannot satisfy the invariant without a larger architectural change, the plan records it as a **PLAN-TIME DESIGN CONSTRAINT**.
- Status: **RESOLVED (2026-09-17).**
- Developer approval required: NO — approved.

## Open Decisions

**NONE.** No open developer decisions remain for the approved UC-05 Mobile scope. M1–M7 were resolved on 2026-09-17. Implementation mechanisms explicitly deferred to the implementation plan are listed in §Functional Flow F6 and M7 above; they are plan-time design work, not open product decisions.

## Compatibility Notes

| Area | Status |
| --- | --- |
| Backend UC-05 contract | **Unchanged.** `POST /api/v1/auth/logout` with `{"refreshToken": …}`; null/blank/unknown/already-revoked → 200 idempotent; infrastructure failure → 500 ProblemDetails; access JWT **not** blacklisted; single refresh session only; no cookie behaviour for Mobile; optional Bearer tolerated but not required. UC-05 Mobile requests no Backend change. |
| UC-05 Web (Capstone_FE) | **Unchanged.** D1 session-preserving failure remains valid for Web. No Web file, spec or behaviour is touched by this amendment. |
| Mobile M1 vs Web D1 | **Intentionally different, not inconsistent.** Web cannot reliably clear an HttpOnly refresh cookie from JavaScript on a failed remote logout, so Web preserves the session to avoid desynchronising the UI from the still-valid cookie. Mobile owns both tokens in secure storage and is responsible for making its locally controlled credentials non-restorable during sign-out; where secure-storage cleanup cannot be guaranteed, M7 requires a fail-closed mechanism that prevents stale credentials from becoming eligible for future restoration, so BR-13 governs. Each policy is correct for its platform's session ownership model; neither may be copied to the other. |
| SRS deviations | The SRS PC-02/BR-12 access-token blacklist wording is a recorded known deviation on the Backend. BR-13 is **followed** by Mobile (this specification). |
| Localization | The app has no i18n layer; the approved M3 copy is an inline English literal consistent with existing Mobile UI copy. |
