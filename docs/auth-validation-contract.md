# TripMate Validation Contract Audit

Date: 2026-09-09

This contract records runtime validation found in the current Flutter Mobile, Next.js FE, and ASP.NET Core BE repositories. Backend runtime is authoritative for accepted data. No rules are invented for APIs that do not exist.

## Runtime Scope

Implemented BE validation/API surface:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/google`
- `POST /api/v1/auth/verify-email`

No runtime BE DTO/controller/validator was found for forgot-password, profile, scheduling, or booking. Existing FE/Mobile implementations for those areas are prototypes/local state and cannot define a shared production contract.

## AUTH REGISTER

| Field | Mobile | FE | BE DTO/property | Required | Type | Min/Max | Format | Error/message | Result |
|---|---|---|---|---|---|---|---|---|---|
| `email` | `Validators.email`; trim/lowercase in Cubit | trim; max 254; `/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/` | `RegisterTravelerRequestDto.Email`, string | Yes | string | max 254 | FluentValidation email | FE: `Please enter your email.` / invalid email; BE: `Email is required.` / `Invalid email format.` | Same acceptance intent; messages differ |
| `password` | required; 8-72; upper/lower/digit/special | required; rejects leading/trailing spaces; 8-72; upper/lower/digit/special | `Password`, string | Yes | string | 8-72 | upper/lower/digit/special | FE has detailed messages; BE has separate policy messages | Rules align except Mobile does not explicitly reject edge spaces |
| `confirmPassword` | UI-only local comparison | UI-only local comparison | Not in BE DTO | Yes locally | string | none | must equal password | FE: `Passwords do not match...`; Mobile differs slightly in reset flow | Must never serialize to register API |
| `fullName` | `Validators.fullName`; trim/normalize; 2-150; Unicode letters/spaces | trim; 2-150; rejects digits/non-letters/spaces | `FullName`, string | Yes | string | 2-150 trimmed | `^[\\p{L}\\p{Zs}]+$` | Messages differ by platform | Acceptance aligns |
| `phoneNumber` | optional; blank -> null; exact `^0\\d{9}$` | optional; removes whitespace; exact `^0\\d{9}$` | `PhoneNumber`, nullable string | No | string/null | exactly 10 digits when present | `^0\\d{9}$` | FE: invalid 10-digit phone; BE `MSG04`; Mobile equivalent | Aligns runtime BE/FE |
| `acceptedTerms` | UI checkbox; Cubit default currently true if caller omits it | checkbox required and payload sends true | `AcceptedTerms`, bool | Must be true | bool | n/a | exact `true` | FE and BE terms message | Mobile API caller must not rely on default; UI must explicitly pass true |
| `role` | Not sent | Not sent | Not in register request; BE assigns `Traveler` | No | n/a | n/a | n/a | n/a | Correct |
| Firebase bearer | Current Firebase service obtains ID token | `getIdToken()` | Controller requires nonblank bearer; handler validates Firebase token and email match | Yes | header string | n/a | Firebase ID token | `AUTH_HEADER_MISSING`, `AUTH_TOKEN_INVALID`, `AUTH_EMAIL_MISMATCH` | Mobile must send token explicitly |

Register payload must be exactly:

```json
{
  "email": "...",
  "password": "...",
  "fullName": "...",
  "phoneNumber": null,
  "acceptedTerms": true
}
```

`confirmPassword`, `googleToken`, `phone`, role, user ID, and JWT fields are not register properties.

BE response is HTTP `201` with `data.status = PendingEmailVerification`. It does not issue JWTs. Mobile must not create an authenticated session at this point.

## AUTH LOGIN

| Field | Mobile | FE | BE | Result |
|---|---|---|---|---|
| `email` | `Validators.email` before request; payload trimmed/lowercase | required; basic email regex | required; FluentValidation email | Mobile is stricter in message only; accepted format is intended to align |
| `password` | login UI uses required-only validator; payload unchanged | required; payload unchanged | required only; no registration complexity rule | Correct |

Payload:

```json
{
  "email": "...",
  "password": "..."
}
```

BE returns `401 auth.invalid_credentials`, `403 MSG_UNVERIFIED`, `403 auth.account_locked`, or `403 auth.account_inactive` as applicable. These must not be collapsed into an email-verification error indiscriminately.

## GOOGLE AUTH

- FE uses Firebase `GoogleAuthProvider` and `signInWithPopup`, then obtains a Firebase ID token.
- Mobile uses `GoogleSignIn`, exchanges the Google credential through Firebase Auth, then obtains a Firebase ID token.
- Both send `POST /api/v1/auth/google` with bearer token and body `{ "idToken": "<Firebase ID token>" }`.
- BE first attempts Firebase ID-token validation, then supports raw Google token fallback.
- BE creates/returns an `Active` Traveler and JWTs immediately; no `acceptedTerms`, phone, or password validation exists for this endpoint.
- Invalid/missing token runtime codes are `AUTH_TOKEN_MISSING` and `MSG_GOOGLE_TOKEN_INVALID`.

## EMAIL VERIFICATION

- The runtime BE endpoint is `POST /api/v1/auth/verify-email` with no body.
- Mobile/FE send a refreshed Firebase ID token in the bearer header.
- BE requires Firebase `email_verified = true`, then returns JWT access/refresh tokens.
- Mobile stores JWTs only after strict response parsing and then authenticates the session.
- The Firebase action-code/deep-link handling is not represented by a BE DTO. Mobile currently provides a return-to-app verification page, not a verified Android action-code deep-link integration.

## FORGOT PASSWORD

No BE endpoint or DTO exists. FE `PasswordRecoveryFlow` and Mobile `ResetPasswordPage` use local/demo behavior. Their email/code/password rules are not a production contract and must not be copied into API models.

## PROFILE, SCHEDULING, AND BOOKING

No runtime BE controller/DTO/validator/repository was found for:

- Profile: `fullName`, avatar, phone, date of birth, gender, address/location.
- Scheduling: destination, dates, travelers, budget, style, preferences, notes.
- Booking: tour/service ID, quantity, booking date, customer data, payment method, terms.

FE legacy/mock UI and Mobile local screens do not establish API validation. These forms remain out of scope until BE contracts exist.

## Concrete Mismatches

1. Mobile `Validators.phone` treats blank phone as valid. This matches current BE/FE optional runtime behavior, but conflicts with older requirement documents that called phone mandatory.
2. Mobile and FE error text is not identical to BE validator text. Error code-to-field mapping should be used where BE supplies codes; validation text should be centralized later without changing BE rules.
3. Mobile `RegisterCubit.registerTraveler` has a default `acceptedTerms = true`; production UI must always pass the checkbox value explicitly. A caller could otherwise bypass local terms validation, although BE still rejects `false`.
4. Mobile password validation accepts leading/trailing spaces if the other policy rules pass; FE rejects them locally, while BE does not explicitly reject them. This is a FE/Mobile UX mismatch requiring a product decision before changing the rule.
5. FE register API type makes the Firebase ID token optional even though BE requires it; Mobile implementation treats it as required.
6. Mobile strict response models correctly reject missing JWT fields for authenticated responses; register response is a separate non-JWT model and must remain separate.

## Required Validation Tests

### Mobile/FE local tests

- Empty and whitespace-only full name, email, password, phone, confirm password.
- Unicode/Vietnamese full name.
- Full name lengths 1, 2, 150, 151.
- Email invalid, 254, 255 characters.
- Password lengths 7, 8, 72, 73 and each missing character class.
- Password leading/trailing whitespace.
- Confirm mismatch.
- Phone null, empty, spaced valid input, invalid prefix, 9/11 digits.
- Terms false and true.
- Exact JSON payload and absence of `confirmPassword`, `googleToken`, and `phone`.

### BE/API tests

- Missing property, null, empty, whitespace-only property.
- Invalid Firebase bearer, email mismatch.
- Duplicate email (`409 MSG03`) and duplicate phone (`400 MSG_PHONE_DUP`).
- Validation response field dictionary mapping.
- Register `201 PendingEmailVerification` with no JWT.
- Verify-email unverified/invalid token and successful JWT response.
- Login `401`, `403`, and successful `200` responses.
- Manual/Postman payload mutation must still be rejected by BE validation.

## Validation Status

This file is an audit/contract artifact only. No implementation mismatch has been changed by this audit.
