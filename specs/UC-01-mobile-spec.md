# Technical Specification: UC-01 Register Traveler Account (Mobile Flutter)

**Document Version:** 3.0 (aligned with the current Mobile implementation)
**Target Repository:** `Capstone_Mobile` (`d:\FPTUCapstone\Capstone_Mobile`)
**Target Branch:** `feature/UC-01-register-traveler-mobile`

---

## 1. Scope and implemented flow

UC-01 creates a Traveler in Firebase Authentication and TripMate, sends the
Firebase verification email, and creates a TripMate session only after both
Firebase and the backend accept email verification.

```text
TravelerRegistrationPage -> RegisterCubit
-> Firebase createUserWithEmailAndPassword -> Firebase ID token
-> POST /api/v1/auth/register -> Firebase sendEmailVerification
-> VerifyEmailPage -> Firebase reload -> emailVerified
-> getIdToken(true) -> POST /api/v1/auth/verify-email
-> parse SessionResponseDto -> persist session
-> authenticated Traveler area
```

The registration response never creates or stores a TripMate session.

---

## 2. API Contract & Timeout Configuration

### Request Endpoint & Timeout
- **URL:** `POST /api/v1/auth/register`
- **Headers:** `Content-Type: application/json`, `Accept: application/json`
- **Request Timeout:** 10 seconds (`connectTimeout: 10s`, `receiveTimeout: 10s`, `sendTimeout: 10s`)

### Payload sanitization

1. `email`: `trim().toLowerCase()`.
2. `fullName`: trim outer whitespace.
3. `phoneNumber`: trim; convert an empty value to `null`.
4. `password`: send exactly as entered; never trim or transform it.
5. `acceptedTerms`: send the selected Boolean value.
6. `confirmPassword` is validated locally and is not sent.
7. `googleToken` is not part of the standard registration request.

### Request Body (`RegisterTravelerRequest`)
```json
{
  "fullName": "Nguyen Van A",
  "email": "traveler@example.com",
  "phoneNumber": "0912345678",
  "password": "Password123!",
  "acceptedTerms": true
}
```

### Registration response
```json
{
  "userId": 1,
  "email": "traveler@example.com",
  "fullName": "Nguyen Van A",
  "role": "Traveler",
  "status": "PendingEmailVerification",
  "emailSent": true,
  "messageCode": "..."
}
```

The API response is wrapped as `{ "success": true, "data": { ... } }`.
`RegisterTravelerResponse` requires every field shown above with its declared
type. The page accepts `PendingEmailVerification` as the expected success
status; another status is reported as unrecognized and does not authenticate.

---

## 3. Client Validation Rules

1. `fullName`: Required, 2-150 normalized characters, Unicode letters/spaces only.
2. `email`: Required, valid email format regex `^\S+@\S+\.\S+$` ("Invalid email format. Please enter a valid email address.").
3. `phone`: Optional. If provided (non-empty), must match `^0\d{9}$` ("Invalid phone number. Phone number must be 10 digits starting with 0.").
4. `password`: Required, 8-72 characters, no leading/trailing space, and containing uppercase, lowercase, digit, and special character.
5. `confirmPassword`: Required, must equal `password` ("Passwords do not match. Please re-enter.").
6. `terms`: Terms & privacy policy checkbox must be checked.

---

## 4. Firebase and backend registration

`FirebaseAuthService.registerWithEmail` creates the Firebase user and obtains
its ID token. A missing token prevents the backend request. The token is passed
explicitly as `Authorization: Bearer <Firebase ID token>` to
`POST /api/v1/auth/register`; `AuthInterceptor` must preserve it instead of
substituting a stored TripMate JWT.

After a valid backend response, Mobile calls Firebase
`sendEmailVerification()`, emits `RegisterSuccess`, and navigates to Verify
Email using `GoRouter.extra`. If sending the email fails, the UI reports
registration failure even though Firebase/backend creation may already have
succeeded.

---

## 5. Verify Email

### Email display

The registered email is passed in memory through `GoRouter.extra`. If extra is
missing, the page falls back to `FirebaseAuth.currentUser.email`. Only a masked
value such as `t***@example.com` is rendered. If neither source exists, the
screen remains usable without showing an email.

### Resend

- Resend calls `currentUser.sendEmailVerification()`.
- Successful resend starts a 60-second countdown; `too-many-requests` also
  requests a cooldown.
- Resend is disabled while loading and while the countdown is active.
- `AuthSessionCubit` blocks concurrent resend/verify actions.
- The page owns the timer and cancels it in `dispose()`.
- Errors distinguish rate limiting, missing Firebase session, network failure,
  and an unknown safe fallback.

### Check verification

Selecting **I verified my email** performs this exact sequence:

1. Require a current Firebase user.
2. Call `user.reload()`.
3. Read `FirebaseAuth.currentUser` again and check `emailVerified`.
4. If false, emit a non-loading failure state, stay on Verify Email, continue
   any active countdown, and do not call the backend.
5. If true, call `getIdToken(true)`.
6. Pass the refreshed token explicitly to `POST /api/v1/auth/verify-email`.

Only verification booleans, token-refresh-requested status, endpoint, HTTP
status, backend code, and sanitized response metadata may be logged. Full email,
password, cookie, Authorization header, and token contents must not be logged.

---

## 6. Session parsing and persistence

`POST /api/v1/auth/verify-email` must return a valid API envelope parsed by
`SessionResponseDto`. Required values are integer `userId`, a supported status,
and non-empty `accessToken` and `refreshToken`. Role, email, full name, and
access-token expiry are optional. String and numeric role/status forms are
normalized by the DTO.

Only after parsing succeeds does `AuthSessionCubit` store `access_token`,
`refresh_token`, `session_role`, and `keep_signed_in`, then emit authenticated.
The current role mapper treats `TourOperator` explicitly and treats any other
parsed/missing role as Traveler. Verify Email then navigates to
`AppRoutes.traveler`.

Malformed responses and Firebase/backend/network failures never create a
TripMate session.

Traveler logout clears all four session values, signs out Firebase and the
shared Google Sign-In service, and emits unauthenticated.

---

## 7. Error handling

The implementation maps Firebase duplicate email and network failures; known
backend Firebase-token, duplicate email/phone, rate-limit and auth codes; HTTP
409/429; timeouts; connection errors; malformed envelopes; and malformed DTOs.
Verify Email additionally maps an unverified user, missing Firebase session,
rate limiting, network failure, backend failure, and unknown safe fallbacks.

## 8. Current acceptance criteria

- [x] Firebase account creation precedes backend registration.
- [x] Explicit Firebase bearer reaches `/api/v1/auth/register` unchanged.
- [x] Request sends `fullName`, `email`, `password`, `phoneNumber`, and
  `acceptedTerms` only.
- [x] `PendingEmailVerification` routes to Verify Email without storing a
  TripMate session.
- [x] Verify Email masks route-extra or Firebase-fallback email.
- [x] Resend has feedback, a 60-second cooldown, timer disposal, and
  Cubit-level verification-action double-submit protection.
- [x] Unverified state remains on Verify Email and never calls backend verify.
- [x] Verified state reloads Firebase and forces `getIdToken(true)`.
- [x] `/api/v1/auth/verify-email` receives the refreshed Firebase bearer.
- [x] Session values are stored only after successful DTO parsing.
- [x] Successful verification enters the Traveler area; logout clears session.
- [x] Sensitive credentials and token contents are not logged.

Registration duplicate-tap protection currently exists at the UI layer through
`RegisterLoading`; `RegisterCubit` has no separate in-flight guard.

## 9. Accepted limitation

UC-01 does not recover automatically when Firebase user creation succeeds but
backend registration fails. It does not delete the Firebase user and does not
retry backend registration independently. Deep links/app links and Mobile
`oobCode` handling are also outside the current scope.
