# UC-07 Mobile Specification — Change Password

**Feature:** UC-07 Change Password  
**Platform:** Mobile / Flutter  
**Status:** Draft — awaiting team approval and Backend API availability  
**Contract basis:** SRS §3.2.7 and `Capstone_BE/specs/UC-07-change-password-spec.md`

---

## 1. Purpose

UC-07 lets an authenticated Mobile user replace the password of their own local
TripMate account. The user proves knowledge of the current password, chooses a
new password, and confirms it in the app.

Mobile owns form validation, safe feedback, session replacement storage, and
navigation. The Backend remains the authority for authentication, current
password verification, password-policy validation, hashing, session revocation,
new token issuance, and audit logging.

---

## 2. Actor and platform scope

### Supported Mobile actors

- Traveler
- Tour Operator

The Mobile page is available only to an authenticated Traveler or Tour Operator
and changes only the currently authenticated account.

### Explicit exclusions

- Staff: no Mobile UC-07 screen, route, or action.
- Administrator: no Mobile UC-07 screen, route, or action. Administration is
  owned by the Web system.
- Changing another user's password, password reset/OTP, Firebase password
  management, MFA, password history, and account unlock are out of scope.

The Backend must still enforce the authenticated subject and local-password
eligibility. Hiding Mobile UI is not authorization.

---

## 3. User flow

```text
Traveler or Tour Operator account/settings page
  ↓
Change Password
  ↓
Current Password + New Password + Confirm New Password
  ↓
Submit
  ├── invalid/error → remain on form with safe feedback
  └── success → securely replace current session → account/settings page
```

No email, OTP, logout screen, or automatic role change is part of a successful
password change. The session is renewed so the user can continue using the app.

---

## 4. Backend API contract

### Request

```http
POST /api/v1/auth/change-password
Authorization: Bearer <access-token>
Content-Type: application/json
```

```json
{
  "currentPassword": "CurrentPassword1!",
  "newPassword": "NewPassword2@"
}
```

- The body contains no user ID, role, email, or `confirmNewPassword`.
- `confirmNewPassword` is Mobile-only state and is never transmitted.
- Password values must never be logged, displayed in errors, persisted in
  SharedPreferences, or included in analytics.

### Success

The exact Mobile authentication-response DTO must reuse the existing sign-in
session contract: a replacement access token, replacement refresh token, and
expiry metadata. After a valid success response, Mobile atomically replaces the
existing secure-storage session using the current auth/session abstraction.

If the Backend finalizes a different response envelope or token field names,
update this specification and the data DTO before implementation; do not invent
a second Mobile contract.

---

## 5. Validation and safe feedback

### Mobile validation

| Field | Rule |
| --- | --- |
| Current password | Required. |
| New password | Required; reuse the canonical local-password validator: 8–72 characters, uppercase, lowercase, digit, special character, and no leading/trailing whitespace. |
| Confirm new password | Required and exactly matches the new password; never sent to Backend. |
| New vs current | Mobile may show early feedback when strings match; Backend remains authoritative because it checks hashes. |

Passwords remain obscured by default, with accessible visibility toggles. Submit
is disabled while a request is in flight, but the user can correct validation
errors after a failure.

### Backend result mapping

**SRS_INTERNAL_CONFLICT — message codes:** see `Capstone_BE/specs/UC-07-change-password-spec.md` §5. The catalog/codebase code for password-policy/same-as-current is `MSG05` (not `MSG03`); confirm-mismatch is `MSG06` (not `MSG04`, client-side only).

| Outcome | Mobile behavior |
| --- | --- |
| `200` success | Replace secure session, clear password fields, show success feedback, return to account/settings. |
| `400` `MSG01` | Show required-field feedback. |
| `400` `MSG05` | Show new-password policy/distinct-password feedback without echoing a secret. |
| `400` `MSG17` | Attach safe feedback to Current Password: `Current password does not match our records.` |
| `401` | Clear invalid session using the existing auth flow and redirect to sign-in. |
| `403` local-password unavailable / unsupported role | Show safe access/unavailable feedback; do not create a local password. |
| network, `5xx`, or `MSG127` | Keep entered values locally for retry where safe; show generic retry feedback. |

Mobile must never show raw HTTP bodies, stack traces, password hashes, tokens,
or provider details.

---

## 6. Security and session requirements

1. Current user identity and role come from the authenticated session, never
   from editable screen state.
2. Access and refresh tokens use the established secure-storage abstraction;
   never use SharedPreferences for them.
3. Replace stored credentials only after a complete valid success response.
   A malformed response leaves the previous session intact and shows a safe
   failure.
4. The app must not locally hash, compare against stored hashes, or persist any
   password.
5. A successful change may invalidate other sessions. The new session returned
   for this device is the only session Mobile keeps.
6. Deep links and direct navigation to the page follow the same Traveler/Tour
   Operator route guard as in-app navigation.

---

## 7. Presentation requirements

- Reuse Material 3 theme tokens and the account/settings visual language.
- Use a scrollable, safe-area-aware form that remains usable with the keyboard
  open and on small screens.
- Include loading, validation-error, API-error, and success states.
- Long localized error text must wrap without breaking layout.
- The page must be accessible through semantic labels, focus order, visible
  focus targets, and labeled password-visibility controls.

---

## 8. Acceptance criteria

1. An authenticated Traveler or Tour Operator can open the Mobile change
   password page from account/settings.
2. Staff and Administrator have no Mobile UC-07 navigation or route access.
3. A valid request sends exactly `currentPassword` and `newPassword` to the
   approved authenticated endpoint.
4. Confirm password, user ID, role, email, passwords, and tokens are never
   sent or logged incorrectly.
5. Local validation blocks empty, invalid, mismatched, and obviously equal
   password entries before submission.
6. Backend `MSG17`, `MSG05`, `401`, `403`, and generic failures display safe
   UX without disclosing technical details.
7. On success, the replacement session is saved through secure storage and the
   user remains signed in.
8. The Mobile feature introduces no Administrator route or UI.

---

## 9. Dependencies and non-goals

- Backend UC-07 API, authenticated Mobile response DTO, and token replacement
  semantics must be finalized before implementation.
- The existing Mobile auth/session abstraction must expose atomic replacement
  of a valid renewed session.
- This document defines only Mobile Traveler/Tour Operator behavior. Any Web
  Staff/Administrator behavior is owned by the Web UC-07 delivery.
