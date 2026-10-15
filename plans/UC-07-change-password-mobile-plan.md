# UC-07 Mobile Implementation Plan — Change Password

**Feature:** UC-07 Change Password
**Platform:** Mobile / Flutter
**Status:** Draft — execute only after specification and Backend contract approval
**Specification:** `specs/UC-07-change-password-mobile-spec.md`

---

## 1. Delivery boundary

This plan delivers self-service password change for authenticated **Traveler**
and **Tour Operator** Mobile users only.

It does not create Staff or Administrator Mobile functionality, routes, or
navigation. It does not implement reset-password OTP, Firebase password reset,
or another password authority.

---

## 2. Preconditions

1. Backend confirms `POST /api/v1/auth/change-password`, required request
   fields, error shape/codes, and the exact Mobile renewed-session DTO.
2. Inspect current Mobile auth feature, session storage, route guards, account
   pages, Dio client, error mapping, and password validator.
3. Confirm the current session abstraction can replace access and refresh tokens
   atomically only after a valid complete response.
4. Create a dedicated feature branch before implementation; preserve unrelated
   working-tree files.
5. Run and record baseline:

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
```

If the Backend contract is unavailable, stop after UI-independent validation
tests and record the blocked integration; do not add synthetic production data
or a fake success flow.

---

## 3. Task 1 — Discover integration points

Read existing files only:

```text
lib/features/auth/
lib/app/router/
lib/core/di/
centralized Dio client and failure mapper
secure-storage/session abstraction
Traveler and Tour Operator account/settings pages
```

Document in the implementation PR:

- existing password validation helper to reuse;
- current session/refresh-token storage and replacement API;
- Traveler and Tour Operator account entry points;
- role-aware route guard and redirect behavior;
- API error mapper and localization/resource pattern.

**Verification:** no source change; scope review confirms no Staff/Admin Mobile
route is planned.

---

## 4. Task 2 — Domain request and validation rules

### Tests first

Add focused tests for:

- missing current password;
- canonical new-password policy boundaries;
- mismatched confirmation;
- equal current/new password early feedback;
- valid form state.

### Implement

Create only the domain value/request models or use case required by the existing
architecture. Reuse the current canonical password validator; do not duplicate
or weaken it.

`confirmNewPassword` stays presentation-only and cannot appear in the domain
request sent to Data.

**Verification:** focused domain/validation tests pass.

---

## 5. Task 3 — Data contract and authenticated request

### Tests first

Add data-source tests asserting:

- authenticated `POST /api/v1/auth/change-password`;
- exact JSON contains only `currentPassword` and `newPassword`;
- no user ID, role, email, confirmation, or secrets in logs;
- valid renewed-session DTO parsing;
- malformed success DTO does not replace stored session;
- mapping for `400`/`MSG05`, `400`/`MSG17`, `401`, `403`, `5xx`, and network
  failure.

### Implement

Under the existing auth feature boundaries:

1. add request/response data DTOs;
2. add remote data-source method using centralized Dio;
3. map DTOs to a domain result/failure;
4. expose the capability through the existing auth repository contract and use
   case.

Do not create alternate Dio clients, hard-code a URL, or encode a role in the
request body.

**Verification:** focused data/repository tests pass.

---

## 6. Task 4 — Session renewal and role-safe routing

### Tests first

Cover:

- a successful complete response replaces the current secure session once;
- a failed/malformed response preserves the old stored session;
- `401` invokes existing invalid-session sign-out/redirect behavior;
- Traveler and Tour Operator can enter the route;
- direct navigation by another role is denied/redirected;
- no Administrator route exists.

### Implement

Use the existing auth/session Cubit or Bloc and secure-storage abstraction. The
state sequence must distinguish submitting, success, validation failure,
credential failure, unauthorized, forbidden, and retryable failure.

Register one centralized Mobile route in an approved Traveler/Operator
account/settings scope. Do not make a `/admin/*` Mobile route.

**Verification:** Cubit/Bloc and route-guard tests pass.

---

## 7. Task 5 — Material 3 page and account entry points

### Tests first

Add widget tests for:

- obscured Current/New/Confirm password fields and semantic visibility toggles;
- inline validation and focus order;
- disabled duplicate submit during loading;
- safe backend error mapping;
- long localized feedback wrapping on a narrow viewport;
- keyboard/scroll-safe layout;
- success returning to account/settings with password fields cleared.

### Implement

Create a feature-scoped change-password page and Cubit/Bloc widgets following
the existing account design. Add entry points only to Traveler and Tour Operator
account/settings areas. Do not display a fictitious confirmation of server-side
delivery, use raw exception text, or keep passwords after success.

**Verification:** focused widget tests and manual Android/iOS emulator smoke
test with a non-production account.

---

## 8. Task 6 — Security and regression verification

Review the final diff for:

- no password, access token, refresh token, or credential-derived value in
  logs, analytics, route parameters, exceptions, or SharedPreferences;
- no Staff/Administrator Mobile UI or route;
- no hand-written raw HTTP outside the Data source;
- no fake production success state when Backend integration is unavailable.

Run:

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Document any unavailable backend/emulator validation honestly. Do not commit,
push, or open a PR until the user requests it.

---

## 9. Delivery gate

The feature is ready for review only when:

1. Backend contract and role boundary are confirmed.
2. Traveler/Tour Operator self-service flow passes focused and full checks.
3. Role guards prevent unsupported Mobile access.
4. Secure session replacement is tested.
5. No secret is logged or stored insecurely.
6. Scope remains Mobile-only and excludes Staff/Administrator.
