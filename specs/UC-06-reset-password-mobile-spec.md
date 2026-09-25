# UC-06 Mobile Specification — Reset Password

**Feature:** UC-06 Reset Password  
**Platform:** Mobile / Flutter  
**Status:** Approved  
**Revision:** 1.1 — 2026-09-25  
**Contract basis:** Current TripMate Backend UC-06 Reset Password API and current Frontend UC-06 behavior

---

## 1. Purpose

UC-06 allows a signed-out user who has forgotten the password of a local TripMate account to reset that password by receiving an email OTP and submitting the OTP together with a new password.

The Mobile application is responsible for:

- collecting email, OTP, New Password, and Confirm Password;
- performing client-side form validation;
- calling the Backend UC-06 APIs;
- presenting safe feedback;
- managing resend cooldown;
- returning the user to `LoginPage` after a successful reset.

The Backend remains authoritative for:

- reset eligibility;
- OTP generation;
- OTP delivery;
- OTP expiration;
- OTP failed-attempt counting;
- OTP single-use and superseding behavior;
- password hashing;
- password persistence;
- refresh-token revocation.

---

## 2. Actors

UC-06 is self-service password recovery.

Supported Backend eligibility:

- Active local-password account;
- PendingEmailVerification local-password account;
- local-password Administrator using the same reset API.

Not reset-eligible:

- Locked account;
- Inactive account;
- Google-only account.

TourOperator approval status does not affect UC-06 eligibility.

The Mobile application must not determine account eligibility itself.

---

## 3. User Flow

```text
LoginPage
  ↓
Forgot Password
  ↓
Enter Email
  ↓
Request Reset OTP
  ↓
OTP + New Password + Confirm Password
  ↓
Confirm Reset
  ↓
Reset Success
  ↓
LoginPage
```

There is no standalone OTP verification step.

OTP validity is checked only when the final password-reset confirmation request is submitted.

---

## 4. Backend API Contract

### 4.1 Request / Resend Reset OTP

```http
POST /api/v1/auth/password-reset/request
```

Request body:

```json
{
  "email": "user@example.com"
}
```

Rules:

- endpoint is anonymous;
- resend uses the same endpoint;
- request success is enumeration-safe;
- successful account-specific outcomes use the same generic `200` behavior.

Success response:

```json
{
  "message": "..."
}
```

The response is a direct DTO and is not wrapped in the legacy TripMate API envelope.

---

### 4.2 Confirm Password Reset

```http
POST /api/v1/auth/password-reset/confirm
```

Request body:

```json
{
  "email": "user@example.com",
  "code": "012345",
  "newPassword": "NewPassword123!"
}
```

`confirmPassword` is Mobile-only validation state and must never be sent to the Backend.

Success response:

```json
{
  "message": "..."
}
```

---

## 5. Error Contract

UC-06 uses:

- `ValidationProblemDetails` for field validation;
- `ProblemDetails` for reset/business/system failures.

Relevant Backend validation and business signals:

| Code | Meaning for Mobile |
|---|---|
| `ValidationProblemDetails.errors[field]` | Human-readable field validation messages from the current Backend middleware; FluentValidation `MSG01` / `MSG02` / `MSG05` codes are not serialized in this payload |
| `MSG14` | Invalid or unusable reset credential |
| `MSG127` | Generic system failure |

Other important HTTP behavior:

| HTTP | Meaning |
|---|---|
| `200` | Generic request success or reset success |
| `400` | Invalid/unusable reset credential or validation-related failure |
| `429` | Rate limited |
| `5xx` | System failure |

Mobile must not expose Backend implementation details.

---

## 6. Functional Requirements

### FR-01 — Forgot Password Entry

`LoginPage` must provide access to the UC-06 Forgot Password flow.

---

### FR-02 — Email Validation

Email must:

- be required;
- use the current TripMate email-format validation;
- have maximum length 254 characters;
- be normalized using the current authentication email-normalization convention.

---

### FR-03 — Request Reset OTP

When the user submits a valid email:

1. disable duplicate submission;
2. display loading state;
3. call `POST /api/v1/auth/password-reset/request`;
4. send only the normalized email;
5. proceed to the reset form only after a valid Backend success response;
6. start the local resend cooldown after success.

A successful HTTP `200` response means only that the Backend accepted the
password-reset request. It does not guarantee that SMTP delivery has completed,
because the Backend sends password-reset email through a background queue.

Mobile must not claim that the reset email or OTP was definitely delivered.
Mobile does not poll Backend email-delivery state. If the user has not received
the email, they use the resend flow after the cooldown.

---

### FR-04 — Enumeration-Safe Request UX

The request screen must not reveal whether the email:

- exists;
- does not exist;
- belongs to a Google-only account;
- belongs to a Locked account;
- belongs to an Inactive account;
- is otherwise reset-ineligible.

All generic successful request responses must produce the same Mobile UX.

Request-success feedback must remain neutral. Recommended wording:

```text
If a reset code was sent, check your email.
```

Mobile must not present wording such as `Code sent successfully` as a confirmed
delivery fact.

---

### FR-05 — OTP Format

OTP must:

- be required;
- be handled as a `String`;
- contain exactly 6 ASCII digits;
- preserve leading zeroes.

Canonical validation:

```regex
^[0-9]{6}$
```

Valid example:

```text
012345
```

OTP must never be converted to an integer.

---

### FR-06 — OTP Lifetime

Backend OTP lifetime is:

```text
3 minutes
```

The Backend is authoritative for expiration.

Mobile may display informational copy such as:

```text
The code is single-use and expires in 3 minutes.
```

Mobile must not independently determine that an OTP is valid solely from a client timer.

---

### FR-07 — OTP Single-Use

A reset OTP is single-use.

After a successful reset, the credential cannot be reused.

If Backend restart/redeploy invalidates an outstanding OTP, Mobile must handle the result through the normal `MSG14` flow.

---

### FR-08 — New Password Validation

Mobile must use the same client password policy used by TripMate local-password flows:

- required;
- 8–72 characters;
- at least one uppercase letter;
- at least one lowercase letter;
- at least one digit;
- at least one special character;
- no leading or trailing whitespace.

Backend remains authoritative for final password validation.

---

### FR-09 — Confirm Password

Confirm Password must:

- be required;
- exactly match New Password;
- remain client-side only;
- never be sent to Backend.

---

### FR-10 — Confirm Reset

When the user submits the reset form:

1. validate OTP;
2. validate New Password;
3. validate Confirm Password;
4. prevent duplicate submission;
5. call `POST /api/v1/auth/password-reset/confirm`;
6. send exactly:
   - `email`;
   - `code`;
   - `newPassword`.

---

### FR-11 — Reset Success

On successful reset:

- clear transient recovery state;
- do not automatically sign the user in;
- navigate to `LoginPage`;
- display safe success feedback.

Backend success also revokes all active refresh tokens.

Mobile does not perform a second token-revocation request.

---

### FR-12 — Invalid / Expired / Unusable OTP

Backend returns generic `MSG14` for reset credentials that are:

- wrong;
- expired;
- replayed;
- already consumed;
- superseded;
- exhausted;
- otherwise unusable.

Mobile must show one safe reset-specific message and must not reveal the exact reason.

Recommended copy:

```text
The reset code is invalid or no longer usable. Request a new code and try again.
```

---

### FR-13 — Failed OTP Attempt Limit

Backend owns the maximum failed-attempt rule:

```text
5 actual wrong-code mismatches
```

The fifth real mismatch invalidates the current reset credential.

Mobile must not maintain an authoritative wrong-attempt counter and must not lock the account.

---

### FR-14 — Resend OTP

Resend uses:

```http
POST /api/v1/auth/password-reset/request
```

Local Mobile resend cooldown:

```text
60 seconds
```

Mobile must:

- disable resend during the cooldown;
- prevent duplicate resend calls;
- restart the cooldown after successful request handling;
- handle `429` without automatic retry.

---

### FR-15 — Resend Inside Backend Cooldown

Backend may return generic `200` during its cooldown without issuing or emailing a new OTP.

The currently valid OTP may remain usable.

Therefore Mobile resend feedback must be neutral.

Recommended wording:

```text
If a new reset code was sent, any previous code may no longer be valid.
```

Mobile must not claim that a new code was definitely sent.

---

### FR-16 — Backend Rate Limit

Current Backend password-reset limiter:

```text
10 requests per minute per IP
```

Mobile must handle `429` safely.

Mobile must not reimplement the server-side per-IP rate limiter.

---

### FR-17 — Validation Errors

`ValidationProblemDetails.errors[field]` must be mapped into the current Mobile form-error pattern where applicable.

Mobile must preserve the current Backend's human-readable field messages and
normalize known Backend field names (`Email`, `NewPassword`, `Code`) to the
corresponding Mobile form keys. It must not assume the arrays contain
`MSG01`, `MSG02`, or `MSG05`.

---

### FR-18 — Network / System Errors

For network errors or `5xx / MSG127`:

- remain on the current step;
- release loading state;
- show generic retryable feedback;
- allow explicit retry.

Recommended copy:

```text
Something went wrong. Please try again later.
```

---

## 7. Security Requirements

### SR-01 — Sensitive Data Is Transient

Do not persist:

- OTP;
- New Password;
- Confirm Password.

Do not store them in:

- SecureStorage;
- SharedPreferences;
- local database;
- route/query parameters;
- persisted Cubit state.

---

### SR-02 — No Sensitive Logging

Do not log:

- OTP;
- New Password;
- Confirm Password.

Dio/request logging must not expose UC-06 request bodies.

---

### SR-03 — No Client Password Hashing

Mobile sends `newPassword` to Backend through HTTPS according to the API contract.

Mobile must not hash the password locally.

---

### SR-04 — No Client OTP Authority

Mobile must not compare the OTP against a locally stored value.

Backend is the sole OTP authority.

---

### SR-05 — No Firebase Password Reset

UC-06 Mobile must use the TripMate Backend reset-password APIs.

Firebase Password Reset must not be used.

---

## 8. Mobile Architecture

UC-06 follows:

```text
Page
  ↓
Cubit
  ↓
Repository
  ↓
RemoteDataSource
  ↓
DioClient
```

Recommended feature location:

```text
lib/features/auth/password_recovery/
```

Logical repository contract:

```dart
abstract interface class PasswordRecoveryRepository {
  Future<void> requestPasswordReset(String email);

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
```

The RemoteDataSource must parse Backend direct `{ message }` success DTOs even if the Repository intentionally exposes `Future<void>`.

---

## 9. Presentation State

Recommended logical states:

```text
idle
requesting
requestAccepted
confirming
resending
cooldown
success
failure
```

Cubit may retain:

- normalized email;
- safe error information;
- cooldown metadata.

OTP and password values should remain in form controllers and be disposed with the page.

---

## 10. Required Tests

### TR-01 — Request OTP

Verify:

- correct endpoint;
- POST method;
- exact email-only body;
- direct `{ message }` success parsing;
- no legacy envelope handling;
- duplicate submission prevention;
- request success proceeds to the reset form with neutral copy;
- request success does not claim that email or OTP delivery completed;
- no polling of Backend email-delivery state.

### TR-02 — Email Validation

Verify:

- required;
- invalid format;
- maximum 254 characters;
- normalization.

### TR-03 — OTP Validation

Verify:

- `012345` accepted;
- leading zero preserved;
- fewer than 6 digits rejected;
- more than 6 digits rejected;
- alphabetic characters rejected;
- non-ASCII digits rejected;
- no numeric coercion.

### TR-04 — Password Validation

Verify:

- shared password policy;
- invalid password blocked;
- Confirm Password mismatch blocked;
- Confirm Password never sent to Backend.

### TR-05 — Confirm Reset

Verify:

- correct endpoint;
- exact body fields `email`, `code`, `newPassword`;
- direct `{ message }` success parsing;
- success returns to `LoginPage`;
- no automatic login.

### TR-06 — MSG14

Verify safe behavior for:

- wrong OTP;
- expired OTP;
- replay;
- consumed OTP;
- restart-invalidated OTP;
- exhausted credential.

### TR-07 — Validation Error Mapping

Verify a sanitized response shaped like the current Backend output, including
human-readable `ValidationProblemDetails.errors[field]` values and Backend
field-name normalization. Do not fabricate code-valued field arrays.

### TR-08 — Resend

Verify:

- same request endpoint;
- 60-second cooldown;
- duplicate resend prevention;
- neutral success copy;
- `429` handling;
- no automatic retry.

### TR-09 — Failed Attempt Authority

Verify Mobile does not:

- own the 5-attempt counter;
- display remaining attempts;
- lock the account.

### TR-10 — Security

Verify:

- no OTP/password persistence;
- no OTP/password logging;
- no client hashing;
- no client OTP verification;
- no Firebase Password Reset.

---

## 11. Acceptance Criteria

| AC | Criterion |
|---|---|
| AC-01 | Forgot Password is reachable from `LoginPage`. |
| AC-02 | Request uses `POST /api/v1/auth/password-reset/request`. |
| AC-03 | Request body contains only normalized email. |
| AC-04 | Email validation supports max 254 characters. |
| AC-05 | Request success UX is enumeration-safe. |
| AC-06 | Direct `{ message }` success DTO is handled without legacy envelope logic. |
| AC-07 | OTP is exactly six ASCII digits and remains a String. |
| AC-08 | Leading zeroes are preserved. |
| AC-09 | OTP lifetime is 3 minutes and remains Backend-authoritative. |
| AC-10 | OTP is single-use. |
| AC-11 | There is no separate verify-OTP API call. |
| AC-12 | Reset form contains OTP + New Password + Confirm Password. |
| AC-13 | Shared client password policy is reused. |
| AC-14 | Confirm Password is client-only. |
| AC-15 | Confirm uses `POST /api/v1/auth/password-reset/confirm`. |
| AC-16 | Confirm body contains only `email`, `code`, `newPassword`. |
| AC-17 | Success returns to `LoginPage`. |
| AC-18 | Success does not automatically sign the user in. |
| AC-19 | Human-readable `ValidationProblemDetails.errors[field]`, `MSG14`, `MSG127`, `429`, and network failures are handled safely. |
| AC-20 | Resend uses the same request endpoint with a 60-second local cooldown. |
| AC-21 | Resend feedback remains neutral when Backend may suppress a new send. |
| AC-22 | Backend remains authoritative for the 5 wrong-code limit. |
| AC-23 | Mobile handles Backend `429` and does not duplicate the 10 req/min/IP limiter. |
| AC-24 | OTP/password values are not persisted or logged. |
| AC-25 | No Firebase Password Reset is used. |
| AC-26 | A successful request is presented as accepted, with neutral copy that does not claim SMTP/OTP delivery completed; Mobile does not poll delivery status. |

---

## 12. Definition of Done

UC-06 Mobile is complete only when current-run evidence confirms:

| Gate | Required result |
|---|---|
| Request endpoint contract | PASS |
| Confirm endpoint contract | PASS |
| Direct `{ message }` DTO handling | PASS |
| ValidationProblemDetails mapping | PASS |
| Backend-shaped human-readable field-error mapping | PASS |
| `MSG14` mapping | PASS |
| `MSG127` mapping | PASS |
| OTP leading-zero handling | PASS |
| 3-minute TTL behavior | PASS |
| Single-use handling | PASS |
| 5-attempt Backend authority | PASS |
| 60-second resend UX | PASS |
| Neutral resend feedback | PASS |
| Sensitive-data audit | PASS |
| Focused tests | PASS |
| Full `flutter test` | PASS |
| `flutter analyze` | PASS |
| `flutter build apk --debug` | PASS |
| formatter check | PASS |
| `git diff --check` | PASS |
