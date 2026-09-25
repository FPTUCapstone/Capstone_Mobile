# UC-06 Mobile Implementation Plan — Reset Password

**Feature:** UC-06 Reset Password  
**Platform:** Mobile / Flutter  
**Status:** Approved  
**Revision:** 1.1 — 2026-09-25  
**Specification:** `specs/UC-06-reset-password-mobile-spec.md`

---

## 1. Goal

Implement the complete UC-06 Mobile password-recovery flow:

```text
LoginPage
→ Forgot Password
→ Enter Email
→ Request OTP
→ OTP + New Password + Confirm Password
→ Confirm Reset
→ Success
→ LoginPage
```

Implementation must match the current Backend UC-06 contract exactly:

```http
POST /api/v1/auth/password-reset/request
POST /api/v1/auth/password-reset/confirm
```

Core rules:

```text
OTP format                 6 ASCII digits, String
OTP TTL                    3 minutes
OTP usage                  single-use
Wrong-code maximum         5 actual mismatches, Backend-authoritative
Resend cooldown            60 seconds
Server rate limit          10 requests/minute/IP
Email max                  254 characters
Success response           direct { message } DTO
Validation errors          ValidationProblemDetails
Reset error                MSG14
System error               MSG127
Success destination        LoginPage
Automatic login            No
Firebase reset             No
```

---

## 2. Preconditions

Before implementation:

```powershell
git branch --show-current
git status --short
git log -3 --oneline
git stash list
```

Use a dedicated UC-06 Mobile branch.

Confirm the Backend UC-06 contract is available in the target development/integration environment.

If Backend UC-06 is not yet available in that environment:

- implement against the approved endpoint/DTO contract;
- use deterministic mocks for Mobile development;
- do not claim end-to-end integration PASS.

Run baseline:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Record any pre-existing failure before editing code.

---

## 3. Task 1 — Audit Existing Mobile Recovery Integration Points

Inspect only the Mobile components needed for UC-06:

```text
lib/features/auth/
DioClient
AuthRemoteDataSource
AuthRepository / AuthRepositoryImpl
existing auth error mapping
existing password-validation helper
LoginPage
routing/navigation
existing cooldown/timer helpers
```

Search:

```powershell
git grep -n -E "ForgotPassword|PasswordReset|password-reset|requestPasswordReset|confirmPasswordReset|sendPasswordResetEmail"
```

Also inspect Dio logging configuration.

### Deliverable

Document:

- reusable password validator;
- reusable error mapping;
- correct navigation entry point;
- correct data/repository integration point;
- whether a cooldown helper already exists.

---

## 4. Task 2 — Reuse the Existing Password Policy

### Tests first

Cover:

```text
required
8–72 chars
uppercase
lowercase
digit
special character
no leading whitespace
no trailing whitespace
valid password accepted
```

### Implementation

Reuse or extract the current TripMate client password policy.

Do not create a second UC-06-only password policy.

### Validation

Run focused validator tests.

---

## 5. Task 3 — Add UC-06 DTOs

Create transport models matching Backend.

### Request OTP

```dart
final class PasswordResetRequest {
  const PasswordResetRequest({required this.email});

  final String email;
}
```

Wire body:

```json
{
  "email": "user@example.com"
}
```

### Confirm reset

```dart
final class ConfirmPasswordResetRequest {
  const ConfirmPasswordResetRequest({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  final String email;
  final String code;
  final String newPassword;
}
```

Wire body:

```json
{
  "email": "user@example.com",
  "code": "012345",
  "newPassword": "NewPassword123!"
}
```

### Success DTO

```dart
final class PasswordResetMessageDto {
  const PasswordResetMessageDto({required this.message});

  final String message;
}
```

### Tests

Verify:

- exact JSON;
- `012345` remains `012345`;
- `confirmPassword` is absent;
- direct `{ message }` response parses correctly.

---

## 6. Task 4 — Implement Request OTP DataSource

Implement:

```http
POST /api/v1/auth/password-reset/request
```

### Required behavior

- anonymous request;
- exact email-only body;
- direct `{ message }` success DTO;
- no legacy response-envelope unwrap;
- propagate transport and Backend errors unchanged for Repository mapping;
- no sensitive logging.

### Tests first

Cover:

```text
correct endpoint
POST method
exact body
direct success DTO
Backend-shaped human-readable ValidationProblemDetails propagation
429 propagation
MSG127 propagation
network failure propagation
malformed success DTO
```

---

## 7. Task 5 — Implement Confirm Reset DataSource

Implement:

```http
POST /api/v1/auth/password-reset/confirm
```

Exact body:

```json
{
  "email": "...",
  "code": "012345",
  "newPassword": "..."
}
```

### Rules

- OTP remains String;
- preserve leading zero;
- do not send Confirm Password;
- do not add verify-OTP call;
- do not use Firebase reset.

### Tests first

Cover:

```text
correct endpoint
POST method
exact fields
012345 transmitted unchanged
direct success DTO
Backend-shaped human-readable ValidationProblemDetails propagation
MSG14 propagation
MSG127 propagation
429 propagation
network failure propagation
```

---

## 8. Task 6 — Repository Capability

Expose:

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

The RemoteDataSource parses Backend `{ message }`.

The Repository may expose `Future<void>` if Mobile uses approved local UI copy.

The Repository owns Backend error interpretation: it delegates common transport,
status, and validation mapping to the centralized `ErrorMapper`, then applies only
password-recovery-specific normalization such as `MSG14` and field-name mapping.

### Tests

Verify exact forwarding, common centralized error mapping, feature-specific
specialization, and normalized human-readable validation field errors.

---

## 9. Task 7 — Password Recovery Cubit

Create UC-06 recovery state management.

Recommended operations:

```dart
Future<bool> requestReset(String email);

Future<bool> confirmReset({
  required String email,
  required String code,
  required String newPassword,
});

Future<bool> resend();
```

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

```text
normalized email
safe error
cooldown metadata
```

Do not persist:

```text
OTP
New Password
Confirm Password
```

### Tests

Cover:

```text
request success
→ navigate to reset form
→ neutral copy
→ does not claim email was definitely delivered
request failure
request retry
confirm success
confirm failure
confirm retry
resend success
resend failure
```

---

## 10. Task 8 — Implement Resend Cooldown

Use:

```text
60 seconds
```

Flow:

```text
request success
→ start cooldown
→ disable resend
→ countdown
→ enable resend
```

Resend:

```text
tap resend
→ POST /password-reset/request
→ generic success
→ restart cooldown
```

Backend may return `200` inside its own cooldown without issuing a new OTP.

Use neutral copy:

```text
If a new reset code was sent, any previous code may no longer be valid.
```

Do not claim a new code was definitely sent.

### Tests

Use fake timers if compatible with the current test stack.

Cover:

```text
initial cooldown
disabled resend
countdown
reenable at zero
successful resend restarts cooldown
429
duplicate resend
neutral copy
```

---

## 11. Task 9 — Implement Forgot Password Page

Create the UC-06 email request screen.

### UI

```text
Email
Send Reset Code
Loading state
Error feedback
Back to Login
```

### Validation

```text
required
valid email format
max 254 chars
normalization
```

### Submit

```text
validate
→ requestReset
→ Backend request accepted
→ open combined reset form
→ show neutral copy: If a reset code was sent, check your email.
```

HTTP `200` means the Backend accepted the request; it does not guarantee that
background SMTP delivery has completed. Do not poll email-delivery state. If the
user has not received the email, use the resend flow after the cooldown.

### Tests

Cover:

```text
render
empty email
invalid email
>254 email
pending state
duplicate submit
success navigation
failure stays on page
generic request-success UX
neutral request-accepted copy
does not claim email or OTP was definitely delivered
does not poll Backend email-delivery state
```

---

## 12. Task 10 — Implement Combined Reset Form

One screen contains:

```text
OTP
New Password
Confirm Password
Reset Password
Resend OTP
3-minute expiry information
```

### OTP validation

```regex
^[0-9]{6}$
```

Explicitly test:

```text
012345
```

### Password validation

Use shared client password policy.

### Submit

```text
validate
→ confirmReset
→ POST /password-reset/confirm
→ success
→ LoginPage
```

Do not auto-login.

### Tests

Cover:

```text
OTP validation
leading zero
password policy
confirm mismatch
exact API values
loading
success
failure
LoginPage navigation
no automatic login
```

---

## 13. Task 11 — Implement UC-06 Error Mapping

Map:

| Backend signal | Mobile behavior |
|---|---|
| `ValidationProblemDetails.errors[field]` | preserve current Backend human-readable field messages and normalize known field names; do not assume code-valued arrays |
| `MSG14` | generic invalid/unusable reset-code error |
| `MSG127` | generic system error |
| `429` | wait/retry-later feedback |
| network failure | connection feedback |

`MSG14` must remain generic for:

```text
wrong OTP
expired OTP
replayed OTP
consumed OTP
superseded OTP
5-attempt exhaustion
restart-invalidated OTP
```

Do not display raw Backend exception text.

---

## 14. Task 12 — Verify OTP Lifecycle Compatibility

Confirm Mobile behavior for Backend rules.

### TTL

```text
3 minutes
```

Backend is authoritative.

Mobile displays informational copy only.

### Single-use

Replay after reset must resolve through `MSG14`.

### Backend restart

If in-memory reset state is lost, Mobile handles the result as `MSG14`.

### Five failed attempts

Backend owns the counter.

Mobile must not:

```text
track remaining attempts authoritatively
show attempts remaining
lock the account
```

---

## 15. Task 13 — Security and Rate-Limit Audit

Backend rate limit:

```text
10 requests / minute / IP
```

Mobile only handles `429`.

Do not duplicate the limiter.

Run:

```powershell
git diff | Select-String -Pattern "password|code|otp|print|debugPrint|log|requestBody"
```

Verify:

```text
no OTP persistence
no password persistence
no OTP/password route or URL serialization
no OTP/password logging
no client-side password hashing
no local OTP verification authority
no Firebase Password Reset
Dio logging does not expose UC-06 request bodies
```

---

## 16. Task 14 — Focused UC-06 Test Pass

Run every UC-06-focused test added in Tasks 2–13.

Required categories:

```text
DTO
RemoteDataSource
Repository
Cubit
Forgot Password page
Reset form
Cooldown
Error mapping
Security assertions
```

All UC-06-focused tests must pass before full validation.

---

## 17. Task 15 — Full Mobile Validation

Run:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Record:

```text
HEAD SHA
command
exit code
result
```

Do not mark PASS without current-run evidence.

---

## 18. Task 16 — UC-06 Scope Review

Run:

```powershell
git status --short
git diff --stat
git diff --check
```

Confirm every changed production file is required by UC-06.

Expected change categories:

```text
password recovery feature
auth API integration required by UC-06
shared password validation used by UC-06
LoginPage Forgot Password entry
UC-06 error mapping
UC-06 tests
```

Remove unrelated changes before delivery.

---

## 19. Task 17 — Code Review Gate

Run the project's code-review process for the current UC-06 changes.

Required final review state:

```text
P0 = 0
P1 = 0
blocking P2 = 0
```

Do not proceed to delivery with a blocking finding.

---

## 20. Task 18 — Final UC-06 Evidence Report

Report only UC-06 evidence:

### 1. Branch / HEAD

### 2. Files changed

Separate:

```text
Production
Tests
```

### 3. API contract

```text
POST /api/v1/auth/password-reset/request
POST /api/v1/auth/password-reset/confirm
```

### 4. Request behavior

```text
email only
direct { message } DTO
enumeration-safe success
```

### 5. OTP behavior

```text
6 ASCII digits
String
leading zero preserved
3-minute Backend TTL
single-use
5-attempt Backend authority
```

### 6. Password behavior

```text
shared client policy
Confirm Password client-only
```

### 7. Resend behavior

```text
same request endpoint
60-second cooldown
neutral copy
429 behavior
```

### 8. Error mapping

```text
Backend-shaped human-readable field errors
MSG14
MSG127
ValidationProblemDetails
429
network
```

### 9. Security audit

```text
no sensitive persistence
no sensitive logs
no client hashing
no local OTP authority
no Firebase reset
```

### 10. Test evidence

```text
focused tests
flutter test
flutter analyze
debug APK build
format check
git diff --check
```

### 11. Verdict

```text
PASS
PASS WITH CONDITION
FAIL
BLOCKED
```

---

## 21. Implementation Checklist

Initial state is intentionally unverified.

| Item | Initial status |
|---|---|
| Request endpoint | NOT VERIFIED |
| Confirm endpoint | NOT VERIFIED |
| Direct `{ message }` DTO | NOT VERIFIED |
| Email max 254 | NOT VERIFIED |
| OTP 6-digit String | NOT VERIFIED |
| Leading zero | NOT VERIFIED |
| 3-minute TTL | NOT VERIFIED |
| OTP single-use behavior | NOT VERIFIED |
| 5-attempt Backend authority | NOT VERIFIED |
| Shared password policy | NOT VERIFIED |
| Confirm Password client-only | NOT VERIFIED |
| 60-second resend cooldown | NOT VERIFIED |
| Neutral resend feedback | NOT VERIFIED |
| Backend-shaped human-readable field-error mapping | NOT VERIFIED |
| `MSG14` mapping | NOT VERIFIED |
| `MSG127` mapping | NOT VERIFIED |
| `429` handling | NOT VERIFIED |
| ValidationProblemDetails | NOT VERIFIED |
| No sensitive persistence/logging | NOT VERIFIED |
| No Firebase reset | NOT VERIFIED |
| Focused UC-06 tests | NOT RUN |
| Full `flutter test` | NOT RUN |
| `flutter analyze` | NOT RUN |
| debug APK build | NOT RUN |
| formatter check | NOT RUN |
| `git diff --check` | NOT RUN |
