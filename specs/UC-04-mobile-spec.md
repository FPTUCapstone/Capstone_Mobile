# UC-04 Mobile Sign In Specification

## 1. Document status

- **Status:** **Approved for planning — NOT approved for implementation**
- **Revision:** v1.2 — final verification against current BE/Web/Mobile source and tests (2026-09-15); Google existing-account and first-time Traveler provisioning behavior confirmed in backend code and tests; no implementation performed
- **Date:** 2026-09-15
- **Repository:** `Capstone_Mobile` (branch `feature/PhucTV-sign-in-mobile`, based on `origin/develop`)
- **Scope note:** This spec defines the target behavior of Sign In on the TripMate Mobile app (Flutter). It is derived from the completed cross-repository audit (BE + Web FE + Mobile) and from the approved business decisions for UC-04 Mobile. It documents requirements and contract semantics only; it does not prescribe implementation steps, file assignments, or backend mechanics beyond the contract requirement.
- **Related documents:** BE spec `Capstone_BE/specs/UC-04-spec.md` (Revision 3), Web spec `Capstone_FE/specs/UC-04-web-spec.md`, shared requirements `Capstone_Docs/requirements/sign-in.md` + `mvp/sign-in-mvp.md`.

---

## 2. Objective

Let users authenticate on Mobile and be routed by backend-authoritative identity. Email/password sign-in authenticates an existing TripMate account only. Google Sign-In authenticates a matching existing account or — under the backend's existing inherited behavior — provisions and authenticates a new Traveler. In both cases the app obtains a securely persisted session and routes according to the backend response's role, account status, and — for Tour Operators — the current application status. Unsupported clients (Administrator) must be refused explicitly rather than silently mis-routed. All eligibility and role rules remain enforced by the shared backend; Mobile is a presentation/routing consumer, not an authority.

## 3. Actors

- **Guest** — a person signing in on Mobile: either the holder of an existing TripMate account (Traveler or Tour Operator) or, via Google only, a Google identity with no matching TripMate account yet (the backend's inherited first-time provisioning may then create a Traveler — see MFR-02).
- **Traveler** — authenticated user of role `Traveler`.
- **Tour Operator** — authenticated user of role `TourOperator`, in one of four application states: `Approved`, `PendingApproval`, `Rejected`, or unresolved (null).
- **Administrator** — authenticated identity that is **not a supported Mobile destination**; must be refused with a Web-only message.
- **System (TripMate backend)** — validates credentials/Firebase evidence, resolves role and account eligibility from the database, issues session tokens, and enforces authorization for protected operations.

## 4. Preconditions

- Email/password sign-in requires an existing TripMate account and never provisions one (account registration is UC-01 for Traveler and UC-02 for Tour Operator — both outside this spec).
- Google Sign-In may authenticate a matching existing account or, under the backend's existing inherited behavior, result in a newly provisioned Traveler (MFR-02); that provisioning never creates a Tour Operator or Administrator.
- The shared backend exposes the auth endpoints listed in §7 and enforces account eligibility via the same rules already applied to Web sign-in.
- The Mobile app has network reachability to the TripMate API and Firebase.

## 5. Existing architecture constraints (current reality)

These facts come from the audit of current source and must not be assumed away:

1. **BE is shared** by Web and Mobile. Web uses `/api/v1/auth/web/*` with an HttpOnly `tripmate_refresh` cookie and browser session restoration. Mobile uses the legacy/shared contract `/api/v1/auth/login`, `/api/v1/auth/google`, `/api/v1/auth/verify-email` and receives `accessToken` + `refreshToken` in the JSON body. **Mobile must not adopt `/auth/web/*`, cookies, or the Web session provider.**
2. **Role is database-authoritative** (confirmed in current backend code and tests). The backend resolves role and account eligibility through the shared eligibility resolver; Google/Firebase identity never determines, elevates, or modifies the role of an existing account. The existing inherited behavior provisions a brand-new Traveler/Active account on first-time Google sign-in with no matching account, and that behavior is not expanded by UC-04. Administrator Google sessions are already refused by an existing BE rule.
3. **`Users.status` (account status) and `OperatorProfiles.approval_status` (application status) are separate concepts.** Sign-in must not mutate either. A Tour Operator with `PendingApproval` or `Rejected` application may still authenticate (shared rule BR3).
4. **`applicationStatus` is currently NOT on the Mobile wire.** The legacy `AuthResponseDto`/`GoogleAuthResponse` carry `ApplicationStatus` only as internal state marked `[JsonIgnore]`; only the Web DTOs serialize it. Mobile therefore cannot today distinguish Approved vs Pending vs Rejected vs unresolved.
5. **The Mobile verify-email recovery path issues a session** (`VerifyEmailResponse`) that today contains no `role` and no `applicationStatus`; the current client treats a missing role as Traveler, which can mis-route a Tour Operator completing verification.
6. **Mobile session storage** uses `flutter_secure_storage` (OS-backed) for access token, refresh token, session role, and keep-signed-in flag; the Dio interceptor attaches the access token as `Authorization: Bearer`.
7. **Startup restoration is local-only:** the app replays the persisted role without server validation. There is **no mobile refresh endpoint** (`/auth/refresh` does not exist), no handling that clears the session on an authenticated 401, and no differentiated 401/403 handling.
8. **Administrator is currently mis-mapped to Traveler** by the Mobile session logic. The Mobile repository rules explicitly forbid creating any Administrator feature/route.
9. **The operator application/status screen exists** (`/operator/application`) but its content is a local prototype; real application-status content belongs to other UCs. This spec only defines **routing** to it.

## 6. Functional requirements

- **MFR-01 Password Sign In.** Mobile shall sign in with email + password through the existing shared backend contract. Email is normalized (trim + lowercase) client-side; password is sent unchanged. Password sign-in authenticates an existing account only and never provisions a new one. Credential failures surface a generic invalid-credentials message.
- **MFR-02 Google Sign In.** Mobile shall support Google sign-in through the existing shared backend contract.
  - **Existing account:** the verified Google/Firebase identity authenticates the matching TripMate account, and the TripMate role comes from the backend/database response. Google/Firebase claims must never determine, elevate, or modify the role of an existing account — in particular never turn an existing user into a Tour Operator or Administrator through client-side claims.
  - **No matching account:** the current backend flow provisions a brand-new account as **Traveler / Active** and authenticates it (inherited first-time Google provisioning, confirmed in current backend code and tests). This flow can never create a Tour Operator or Administrator.
  - First-time Google Traveler provisioning is inherited backend behavior exercised through the Google Sign-In flow. UC-04 preserves and consumes this behavior and regression-protects it; it does not redefine or expand provisioning rules, and it is not a registration feature of this UC.
- **MFR-03 Email Verification Recovery.** When sign-in is refused because the account email is not yet verified, Mobile shall continue the existing recovery flow (Firebase verification evidence → backend verify-email). The verification session result must provide sufficient backend-authoritative identity for correct routing — role, effective account status, and applicationStatus for a Tour Operator, alongside the session tokens — without requiring the user to re-enter credentials or perform a second login merely to obtain that identity (see §7).
- **MFR-04 Account Eligibility.** The backend validates credentials, authorizes access, and determines eligibility; Mobile shall honor those backend eligibility outcomes without local override: `Active` proceeds; `Locked`, `Inactive`, and other restricted/unresolved states are refused with the backend-provided message and no session is persisted. Sign-in must not mutate account status or operator approval status.
- **MFR-05 Secure Credential Storage.** All session credentials shall be persisted only in OS-backed secure storage (`flutter_secure_storage`). No plaintext credential storage (no SharedPreferences for tokens), no browser cookies, no Web local/session storage semantics.
- **MFR-06 Session Restoration.** On app startup, if a persisted session identity exists and restoration is enabled, Mobile shall provisionally restore that backend-issued identity so a returning user is not forced to re-enter credentials. Provisional restoration is **not** proof that the stored access token is still server-valid: subsequent authenticated server responses remain authoritative, and a 401 must invalidate the restored session (see MFR-07).
- **MFR-07 Invalid/Expired Session Handling (401).** Any authenticated API call returning **401 Unauthorized** means the session credential is invalid, expired, or otherwise not accepted. Mobile shall clear the complete local authenticated session and return the user to sign-in; the app must never continue showing authenticated UI.
- **MFR-08 Traveler Routing.** An authenticated Traveler shall land on the normal Traveler destination (`/traveler`).
- **MFR-09 TourOperator Approved Routing.** A Tour Operator whose current application status is `Approved` shall land on the normal Operator destination (`/operator`).
- **MFR-10 TourOperator PendingApproval Routing.** A Tour Operator with `PendingApproval` shall land on the operator application/status destination (`/operator/application`) and **not** the approved Operator area.
- **MFR-11 TourOperator Rejected Routing.** A Tour Operator with `Rejected` shall land on the operator application/status destination (`/operator/application`). The resubmission action itself is outside this UC.
- **MFR-12 TourOperator Unresolved Fail-Closed.** A Tour Operator whose application status is missing/null/unknown shall land on the operator application/status destination in a fail-closed state and **must not** be granted approved Operator content. Unresolved must never be inferred as `Approved`, `PendingApproval`, or `Rejected`.
- **MFR-13 Administrator Web-Only Handling (hard rule).** Administrator accounts are supported exclusively by the Web client. For password sign-in, `POST /api/v1/auth/login` shall reject an eligible Administrator with `403 auth.admin_mobile_sign_in_disabled` before issuing any TripMate token/session or updating last-login state; only `POST /api/v1/auth/web/admin/login` supports Administrator password sign-in. Mobile shall remain unauthenticated, persist no session data, perform best-effort Firebase sign-out, and display *"Administrator accounts are supported on Web only."*; cleanup failure must not hide that message. Any unexpected session response identifying `role = Administrator` is still rejected before persistence. Administrator must never be mapped to Traveler or Tour Operator, and no Administrator Mobile feature, route, or screen may be introduced.
- **MFR-14 Backend-Authoritative Role.** The client shall derive role, account status, and application status exclusively from the backend authentication response — never from Firebase/Google claims, stored display data, or client guesses.
- **MFR-15 Authorization Boundary.** Protected backend operations remain server-side authorized. Mobile routing/navigation guards are UX protection only and are not a security boundary.
- **MFR-16 Authorization Denial Handling (403).** **403 Forbidden** means the user may still be authenticated but lacks permission for the requested operation. Mobile shall surface/handle it as an authorization denial appropriate to the feature and shall **not** automatically clear the entire session. Backend authorization remains the security boundary.

## 7. Authentication contract requirements

Semantics required from the shared backend for Mobile sign-in. **CURRENT** = verified by audit; **REQUIRED** = needed before UC-04 Mobile can be accepted.

| Item | CURRENT | REQUIRED FOR UC-04 |
|---|---|---|
| Password sign-in endpoint | `POST /api/v1/auth/login` | unchanged (Mobile keeps this endpoint; **not** `/auth/web/login`) |
| Administrator password sign-in | previously returned a Mobile session that the client refused | **403 `auth.admin_mobile_sign_in_disabled` before token/session/last-login side effects**; Web Administrator password sign-in remains supported only at `/api/v1/auth/web/admin/login` |
| Google sign-in endpoint | `POST /api/v1/auth/google` | unchanged |
| Verification recovery endpoint | `POST /api/v1/auth/verify-email` (issues a session) | unchanged endpoint; the session result must carry the full routing identity below (approved requirement) without a second credential entry |
| `userId`, `email`, `fullName` | present in login/Google response | unchanged |
| `role` | present in login/Google response (DB-authoritative); **absent from verify-email response** | **APPROVED REQUIREMENT:** present and DB-authoritative on **every session-issuing path** used by Mobile, including the verification-recovery session |
| `status` (effective account status) | present; eligibility enforced by shared resolver | unchanged |
| `applicationStatus` | **NOT on the Mobile wire** (`[JsonIgnore]` internal field) | **MUST be available to Mobile** on every session-issuing path that may authenticate a Tour Operator, with semantics identical to the shared backend/Web contract: string enum `Approved`/`PendingApproval`/`Rejected` for a recognized operator application; `null`/not-applicable for Traveler; `null`/unrecognized for a Tour Operator means **unresolved → fail closed**, never an inferred state. Contract requirement — not a current capability. |
| `accessToken` + expiry | present (15-min JWT) | unchanged |
| `refreshToken` | present in JSON body (opaque, 7-day, hash-stored server-side) | The current Mobile contract returns a refreshToken; UC-04 introduces no refresh-token renewal behavior and no mobile refresh endpoint. If the existing client retains the refresh token for contract compatibility, it must remain in OS-backed secure storage and must never be exposed through logs or insecure persistence. |
| Web cookie behavior | HttpOnly `tripmate_refresh` for `/auth/web/*` only | **must not change**; Mobile must not depend on cookies |
| Backwards compatibility | legacy wire shape consumed by existing Mobile code and tests | the contract addition must be **additive/minimal** and must not alter Web DTOs unless strictly necessary |

The exact backend mechanism for exposing `applicationStatus` and the full verify-email session identity is an implementation decision for the future plan; this spec fixes only the **semantics above**, which are approved requirements.

## 8. Routing decision table

| Role | Account state | Application state | Expected Mobile result |
|---|---|---|---|
| Traveler | Active | n/a (null) | → `/traveler` |
| First-time Google-provisioned Traveler | Active (newly provisioned by inherited BE behavior) | n/a (null) | → `/traveler` |
| TourOperator | Active | `Approved` | → `/operator` |
| TourOperator | Active | `PendingApproval` | → `/operator/application` (status view; no approved workspace) |
| TourOperator | Active | `Rejected` | → `/operator/application` (resubmit action itself out of scope) |
| TourOperator | Active | unresolved / `null` / unknown | → `/operator/application` **fail-closed**; approved Operator content must not render; no state inference |
| TourOperator | Locked / Inactive / restricted | any | sign-in refused by backend; no session persisted |
| Administrator | eligible + correct password | n/a | backend `403 auth.admin_mobile_sign_in_disabled` before session issuance; Mobile remains unauthenticated, clears Firebase best-effort, and shows: Administrator accounts are supported on Web only |
| Any role | unverified email at sign-in | n/a | verification recovery flow (MFR-03); on success, the recovery session carries full identity and routes per the row matching the resolved identity, without a second credential entry |

## 9. Error behavior

- **Invalid credentials** (unknown email / wrong password / account without password): generic "invalid email or password" message; no session; no account-existence disclosure.
- **Unverified email**: backend refusal triggers the recovery flow; the user is told to verify and offered resend; repeated resend rate-limits are surfaced as friendly messages (existing cooldown behavior).
- **Locked / Inactive / restricted account:** refusal with the backend-provided message; no session created or persisted.
- **Unresolved account state** (backend `account_state_unresolved`): refusal; no session; support-oriented message.
- **Administrator on Mobile:** rejected before any credential persistence with an explicit Web-only message (MFR-13); never a silent Traveler or Tour Operator fallback.
- **Google provider errors:** a user-cancelled Google sign-in is non-fatal and handled silently; verification/identity mismatch and provider failures map to friendly messages without raw SDK/server internals.
- **Network / timeout / 5xx:** recoverable failure message; no fabricated success; retry allowed.
- **401 on an authenticated call:** the complete local session is cleared and the user is returned to sign-in (MFR-07).
- **403 on an authenticated call:** the user may remain authenticated; the denial is surfaced/handled per the feature and the session is **not** automatically cleared (MFR-16).

## 10. Session behavior

- Credentials are persisted only in `flutter_secure_storage` (access token, refresh token, minimal session identity data, keep-signed-in flag).
- On startup, a persisted session identity may be provisionally restored to skip credential re-entry (MFR-06); the restored identity data used for routing must be the backend-issued values persisted at sign-in, and provisional restoration is never treated as server-validated.
- The access token is attached as `Authorization: Bearer` to API calls by the centralized HTTP client/interceptor.
- An authenticated 401 clears the complete stored session and forces re-authentication (MFR-07); an authenticated 403 is an authorization denial and does not automatically clear the session (MFR-16).
- **No** HttpOnly cookies, **no** WebSessionProvider analogue, and **no** browser-storage semantics. UC-04 introduces no mobile refresh/renewal endpoint and no session-extension UX; the refresh token returned by the current contract is not used for renewal and, if retained for compatibility, stays in OS-backed secure storage only.

## 11. Security requirements

- No plaintext storage of tokens/credentials; no secrets in source or logs; raw tokens/stack traces never surfaced to users.
- Role and application status are trusted **only** from the backend response; Google/Firebase claims never determine, elevate, or modify the role of an existing account. Google/Firebase proves identity, not authorization: first-time provisioning may only create a Traveler (inherited backend behavior), never a Tour Operator or Administrator (unchanged by UC-04).
- No client-side role escalation; no client path may grant the approved Operator area without `applicationStatus = Approved` from the server.
- Unresolved/unknown state fails closed everywhere (routing and content).
- The backend remains the authorization boundary for all protected operations; Mobile guards are UX only.
- Web and Mobile share business rules and the same account/application data, but intentionally use different session transports; neither may be silently converted to the other's model.

## 12. Acceptance criteria

- **AC-01** Password sign-in with valid Active Traveler credentials → session persisted securely → lands on `/traveler`. (MFR-01, MFR-05, MFR-08)
- **AC-02** Invalid credentials → generic error, no session persisted, stays on sign-in. (MFR-01)
- **AC-03** Locked/Inactive/unresolved account → refusal with backend message, no session. (MFR-04)
- **AC-04** Google sign-in success → role from backend response only; Traveler and Tour Operator behave per the routing table; Google never determines, elevates, or modifies the role of an existing account (first-time Traveler provisioning remains inherited behavior). (MFR-02, MFR-14)
- **AC-05** Unverified email at sign-in → recovery flow completes → the verify-email session carries full authoritative identity (role, effective status, applicationStatus, tokens) without a second credential entry → routed per table. (MFR-03, §7)
- **AC-06** TourOperator `Approved` → `/operator`; `PendingApproval` → `/operator/application`; `Rejected` → `/operator/application`. (MFR-09/10/11)
- **AC-07** TourOperator unresolved/null → `/operator/application` fail-closed view; no approved Operator content; no inferred status. (MFR-12)
- **AC-08** Administrator password through `/api/v1/auth/login` → backend `403 auth.admin_mobile_sign_in_disabled` with no TripMate token, refresh row, or last-login update; Mobile remains unauthenticated, performs best-effort Firebase cleanup, shows the explicit Web-only message, and exposes no Admin route. Dedicated Web Admin password login remains supported. (MFR-13)
- **AC-09** App restart with a persisted session → identity provisionally restored without credential re-entry and routed per the persisted backend-issued identity; provisional restoration alone is never treated as server-validated. (MFR-06)
- **AC-10** Authenticated API 401 → complete local session cleared → sign-in required; authenticated UI never continues afterwards. (MFR-07)
- **AC-11** Protected backend calls still enforce server-side authorization independently of Mobile routing. (MFR-15)
- **AC-12** Existing Web sign-in behavior and the HttpOnly cookie contract are unchanged by any Mobile-related contract addition. (§7)
- **AC-13** Authenticated API 403 → authorization denial surfaced; the session is not automatically cleared. (MFR-16)
- **AC-14** Google sign-in with no matching TripMate account → the inherited backend provisioning creates a Traveler/Active account, a session is established, and the user routes to `/traveler`; this flow never creates a Tour Operator or Administrator. (MFR-02)

## 13. Out of scope

- UC-02 Tour Operator registration (backend or Mobile flow) and normal email/password account registration (UC-01).
- Inherited first-time Google Traveler provisioning is existing backend behavior consumed by Google Sign-In — it is not a new UC-01/UC-02 registration task for this UC.
- Operator application submission and resubmission implementation (including the prototype status page's real content).
- Administrator Mobile feature/screens/routes (prohibited by Mobile repository rules).
- Normal Sign Out UC and refresh-token revocation-on-signout.
- A new Mobile refresh/renewal endpoint or session-extension UX.
- Unrelated backend modernization, unrelated Web changes, unrelated navigation/UI refactors.
- Phone/OTP sign-in (backend contract does not exist).

## 14. Open implementation questions

Only genuine implementation/detail questions remain; every related business decision is approved and closed (verify-email must carry full identity; provisional restore + 401 invalidation is the UC-04 scope; Administrator is Web-only and Mobile must never retain its credentials):

1. **BE contract mechanism:** the exact additive shape used to expose `applicationStatus` and the full verify-email session identity on the Mobile/shared responses (DTO field addition vs shared projection) — to be fixed during BE contract review in the implementation plan; the required semantics are settled in §7.
2. **Final message wording:** localized user-facing copy for the Administrator Web-only message and the unresolved Tour Operator fail-closed status view.

---

*End of specification — UC-04 Mobile Sign In, v1.2 (2026-09-15; final verification against current BE/Web/Mobile source and tests). Approved for planning; NOT approved for implementation.*
