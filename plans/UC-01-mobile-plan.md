# Implementation Plan: UC-01 Register Traveler Account (Mobile Flutter)

**Status:** Implemented; aligned with the current Mobile code.
**Specification:** `specs/UC-01-mobile-spec.md` version 3.0

Implement the complete Traveler lifecycle:

```text
Register form -> Firebase account -> POST /api/v1/auth/register
-> verification email -> Verify Email/resend
-> Firebase reload + getIdToken(true) -> POST /api/v1/auth/verify-email
-> parse and persist Traveler session -> Traveler area -> logout
```

## User Review Required

> [!IMPORTANT]
> - **API and Firebase:** Android emulator uses `http://10.0.2.2:5000`. Firebase creates the account before the backend register request.
> - **Token lifecycle:** Registration never stores a TripMate session. Session values are written only after Firebase verification, forced ID-token refresh, successful `/auth/verify-email`, and `SessionResponseDto` parsing.
> - **Password Safety:** Passwords are NEVER trimmed or transformed.

---

## Implemented components

### Data & Domain Layer

#### [NEW] [register_traveler_request.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/features/auth/data/models/register_traveler_request.dart)
Serializes exactly `fullName`, `email`, `password`, `phoneNumber`, and
`acceptedTerms`. Empty phone becomes `null`; `confirmPassword` remains a local
validation field and `googleToken` is not sent.

#### [NEW] `register_traveler_response.dart` and `session_response_dto.dart`

`RegisterTravelerResponse` parses the pending-verification registration result.
`SessionResponseDto` separately validates the authenticated response returned
after backend email verification.

#### [NEW] [auth_remote_data_source.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/features/auth/data/datasources/auth_remote_data_source.dart)
Uses `DioClient` for `POST /api/v1/auth/register` and
`POST /api/v1/auth/verify-email`, preserves the explicit Firebase bearer,
unwraps the common response envelope, and maps known backend/network errors.
Register send/receive timeouts are 10 seconds.

#### [NEW] [auth_repository.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/features/auth/domain/repositories/auth_repository.dart) & [auth_repository_impl.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/features/auth/data/repositories/auth_repository_impl.dart)
Auth repository contract and implementation returning
`RegisterTravelerResponse` for register and `SessionResponseDto` for verify.

---

### Presentation Layer & State Management

#### [NEW] [register_cubit.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/features/auth/presentation/cubit/register_cubit.dart) & [register_state.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/features/auth/presentation/cubit/register_state.dart)
Cubit/state handling Firebase account creation, Firebase token acquisition,
backend register, sending the verification email, normalized payload values,
and safe failure mapping.

#### [MODIFY] [auth_session_cubit.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/features/auth/presentation/cubit/auth_session_cubit.dart)
Own resend/check-verification actions, reload and refresh Firebase token through
the Firebase service, call backend verification, persist a successfully parsed
session, authenticate Traveler, and clear the session during logout.

#### [MODIFY] [service_locator.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/core/di/service_locator.dart)
Register Firebase service, `AuthRemoteDataSource`, `AuthRepository`,
`AuthSessionCubit`, and `RegisterCubit` in GetIt.

#### [MODIFY] [traveler_registration_page.dart](file:///d:/FPTUCapstone/Capstone_Mobile/lib/features/auth/presentation/pages/traveler_registration_page.dart)
Connect the form to `RegisterCubit`, disable all controls during loading, accept
`PendingEmailVerification`, and navigate to Verify Email with the email in
`GoRouter.extra`. It does not write session tokens.

#### [NEW] `verify_email_page.dart`

Resolve a route-extra or Firebase fallback email and render only its masked
form. Provide resend, a widget-owned 60-second cooldown, **I verified my
email**, Back to sign in, safe feedback, and Traveler navigation after the
authenticated state.

#### [NEW] `firebase_auth_service.dart`

Create Firebase email/password users, send verification mail, reload the
current user, verify `emailVerified`, force `getIdToken(true)`, and sign out.
The current shared service also contains sign-in methods outside UC-01.

---

### Tests

#### [NEW] [auth_remote_data_source_test.dart](file:///d:/FPTUCapstone/Capstone_Mobile/test/features/auth/data/datasources/auth_remote_data_source_test.dart)
Tests register/verify transport, the explicit Firebase bearer, response parsing,
known backend failures, network failures, and malformed responses.

#### [NEW] [register_cubit_test.dart](file:///d:/FPTUCapstone/Capstone_Mobile/test/features/auth/presentation/cubit/register_cubit_test.dart)
Tests Firebase-first sequencing, payload normalization, state transitions,
network failure, and Firebase duplicate-email mapping.

#### [NEW] `verify_email_page_test.dart` and updated `auth_session_cubit_test.dart`

Cover email masking/fallback, missing session/email, resend feedback and
double-submit protection, cooldown/disposal, unverified state, backend failure,
successful session persistence, Traveler navigation, and Back to sign in.

---

## Verification Plan

### Automated checks

```text
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug --no-pub
```

### Manual Android flow

1. Register a fresh valid Traveler.
2. Confirm the Verify Email page masks the email.
3. Confirm resend feedback/cooldown and the unverified state.
4. Open the Firebase verification link.
5. Return and select **I verified my email**.
6. Confirm backend verification and authenticated Traveler navigation.
7. Confirm logout clears the session.

## Current implementation notes

- Registration duplicate-tap protection is currently UI-level through
  `RegisterLoading`; no separate RegisterCubit in-flight guard exists.
- Verify resend/check actions have a Cubit-level concurrency guard.
- A successful resend (or Firebase rate limit) starts the 60-second cooldown.
- No TripMate session is saved until `/auth/verify-email` parses successfully.
- The role mapper treats `TourOperator` explicitly and otherwise maps the
  parsed/missing role to Traveler.

## Explicitly excluded

- Deep links/app links and Mobile `oobCode` handling.
- Recovery when Firebase creation succeeds but backend registration fails.
- Deleting the Firebase user after a partial failure.
- Web changes and UC-02 or later use cases.
