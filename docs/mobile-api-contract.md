# TripMate Mobile API Contract

Date: 2026-09-09

This document records only contracts verified in the current backend source. It does not invent Mobile-specific routes. All successful auth responses except `/health` use the backend envelope:

```json
{
  "success": true,
  "statusCode": 200,
  "message": "...",
  "data": {},
  "errors": null
}
```

Failure responses use the same envelope when produced by the controller failure mapper, but validation/model-binding paths may still emit framework ProblemDetails. Mobile must support the actual response observed in integration tests, not silently assume one error shape.

## GET `/health`

- Authentication: not required.
- Request: none.
- Success: `200`, raw `{ "status": "healthy" }`.
- Errors: not specified by the controller audit.
- FE usage: none identified.
- Mobile usage: optional connectivity/diagnostic check only; never use it as authentication.

## POST `/api/v1/auth/register`

- Authentication: controller allows anonymous, but the action manually requires `Authorization: Bearer <Firebase ID token>`.
- Request JSON:

```json
{
  "email": "traveler@example.com",
  "password": "Password1!",
  "fullName": "Traveler Name",
  "phoneNumber": "0123456789",
  "acceptedTerms": true
}
```

- Request fields: `email` required, `password` required, `fullName` required, `phoneNumber` nullable, `acceptedTerms` required and must be `true`. There is no verified `confirmPassword` field in the BE DTO.
- Validation: email valid and max 254; password 8-72 with uppercase, lowercase, digit, special character; full name trimmed 2-150 letters/spaces; phone, when supplied, matches `^0\\d{9}$`; terms must be true.
- Success: `201`, `data` contains `userId`, `email`, `fullName`/name as emitted by the current handler, `role` `Traveler`, `status` `PendingEmailVerification`, `emailSent` `true`, and `messageCode` `MSG07`.
- Token response: no access or refresh token is issued while pending email verification.
- Errors: missing bearer `401` with `AUTH_HEADER_MISSING`; invalid Firebase token `400` with `AUTH_TOKEN_INVALID`; email mismatch `400` with `AUTH_EMAIL_MISMATCH`; duplicate email `409` with `MSG03`; duplicate phone/other handler failures currently map to `400`; validation failures `400`.
- FE usage: `src/lib/authApi.ts` calls `POST /auth/register`, sends the same JSON, and optionally sends the Firebase token as bearer. The FE registration flow obtains and supplies that token.
- Mobile usage: must obtain a Firebase ID token, send it as bearer, send exactly the fields above, reject a pending response as unauthenticated, and direct the user to the verified email flow. Current Mobile data source sends the JSON but does not establish the required Firebase bearer contract.

## POST `/api/v1/auth/verify-email`

- Authentication: controller allows anonymous, but manually requires a Firebase bearer token.
- Request: no body; Firebase token supplies email and verification state.
- Validation/behavior: token must be valid and Firebase `email_verified` must be true; matching user is activated if not already active.
- Success: `200`, `data` contains user ID, email, active status, verification time, access token, refresh token, and access-token expiry.
- Token handling: Mobile/FE must persist returned access and refresh tokens securely; no refresh endpoint exists.
- Errors: missing bearer `401` with `AUTH_HEADER_MISSING`; invalid/expired token `400` with `MSG14`; unverified Firebase email `400` with `MSG_EMAIL_NOT_VERIFIED`; no matching user `400` with `MSG_USER_NOT_FOUND`.
- FE usage: `src/lib/authApi.ts` calls `POST /auth/verify-email` with the Firebase token in the bearer header after Firebase email-link verification.
- Mobile usage: implement only after Firebase email-link handling is agreed. Do not implement OTP fields because BE does not currently accept an OTP body.

## POST `/api/v1/auth/google`

- Authentication: no normal JWT required. Token may be supplied in JSON or bearer header.
- Request JSON: `{ "idToken": "<Firebase-or-Google-token>" }`; bearer fallback is also accepted.
- Behavior: backend tries Firebase ID-token validation, Google ID-token validation, then Google userinfo access-token validation; creates or authenticates a Traveler.
- Success: `200`, `data` contains `userId`, `status`, access token, refresh token, and `isNewAccount`.
- Errors: missing token `400` with `AUTH_TOKEN_MISSING`; invalid token currently `400` with `MSG_GOOGLE_TOKEN_INVALID`; unexpected/persistence failure `500` with `MSG127`.
- Token handling: persist returned JWT access/refresh tokens; no refresh/logout route exists.
- FE usage: sends both bearer token and JSON `idToken`.
- Mobile usage: not production-ready until an approved Flutter Google/Firebase provider flow and backend provider-link policy are confirmed. Do not use the current visual-only Google demo.

## POST `/api/v1/auth/login`

- Authentication: anonymous.
- Request JSON:

```json
{
  "email": "traveler@example.com",
  "password": "Password1!"
}
```

- Validation: email required and valid; password required.
- Success: `200`, `data` contains `userId`, `email`, `fullName`, `role`, `status`, `accessToken`, `refreshToken`, and `accessTokenExpiresAtUtc`.
- Token handling: access token is JWT with configured issuer/audience/lifetime; refresh token is a random token whose hash is persisted for seven days. No refresh endpoint is exposed.
- Errors: invalid credentials `401` with `auth.invalid_credentials`; pending email verification `403` with `MSG_UNVERIFIED`; locked/inactive account `403`; validation `400`; unexpected failure `500` with `MSG127`.
- FE usage: `src/lib/authApi.ts` calls `POST /auth/login` and saves returned tokens in localStorage.
- Mobile usage: replace hard-coded demo login with this route, persist tokens through secure storage, restore session only from valid persisted state, and route by the returned role. Do not add Firebase login as a substitute for this password contract.

## Explicitly Unavailable Contracts

The current BE source does not expose verified endpoints for:

- Refresh, logout, revocation, or token rotation.
- Password reset or change password.
- Traveler profile or travel preferences.
- Explore/POI, itinerary, map, weather, tours, booking, payment, history, or review.
- Tour operator registration/application, uploads, tours, revenue, or bookings.
- Administrator authentication or admin operations.

Mobile must not call guessed paths for these features. Existing screens for them remain demo/placeholder scope until BE contracts are implemented and documented.

## Cross-cutting Mobile Rules

- Use the shared BE base URL; do not create `/mobile-api`, a separate database, or a separate authentication system.
- Never log request bodies containing passwords or tokens.
- Store tokens only through the Mobile secure-storage abstraction.
- Treat missing required response fields as a contract failure; do not default them to valid-looking values.
- Map known error codes to safe user messages and never expose raw exceptions, stack traces, or internal server details.
- The checked-in JWT signing key is empty; runtime environment configuration must provide it before token integration can pass end to end.
