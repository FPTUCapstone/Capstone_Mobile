# UC-02 Register Tour Operator Account Mobile Implementation Plan

> **2026-10-08 Mobile amendment:** Follow
> [UC-02-verified-first-amendment-plan.md](UC-02-verified-first-amendment-plan.md)
> for the verified-before-submission change. The original tasks below record
> the previous BE-before-email implementation and its historical test evidence.

Status: **Tasks 0–4 implemented locally on 2026-10-06; Task 5 automated checks passed, live end-to-end verification pending.**
The BE UC-02 endpoint remains on its feature branch; final integration evidence
requires that implementation. Tasks are sequenced and tests come first.

Branch: `feature/linhnv-register-tour-operator-account` (based on latest `origin/develop`,
`1f17a61`). Follow Page → Cubit → use case → Domain contracts → Data
repository/identity adapter → central Dio/Firebase. The Cubit owns UI state;
the use case owns registration order and recovery. The older
`Capstone_Mobile-uc02` worktree is 120 commits behind `develop` and dirty;
preserve its changes, but do not transplant its old Firebase/bootstrap setup
or treat its previous checks as validation for this branch.

## Business identifier format follow-up (2026-10-08)

Add the owner-decided Tax Code and Travel Licence Number checks to the
three-step UC-02 registration's company step and domain use case. Reuse the
domain format messages in BE error mapping, show input examples on the company
step, and update UC-02 test fixtures. Test rejection before Firebase creation,
valid head-office/branch and domestic/international examples, and safe mapping
of BE field error codes. Preserve Vietnamese IME input without a formatter.

## Baseline evidence (recorded 2026-10-06 — repository and SHA recorded separately)

- **Repository:** `Capstone_Mobile` — Commit `1f17a61` (`origin/develop` tip).
- `flutter pub get` — successful (61 packages, some newer incompatible versions noted).
- Before Task 0: `flutter analyze` 0 issues; `flutter test` 679 passed.
- After Task 0: `flutter pub get`, format check and `flutter analyze` passed;
  `flutter test` 683 passed; `flutter build apk --debug` passed; and
  `git diff --check` passed. These are local working-tree results, not
  final-head UC-02 integration evidence.
- After Tasks 0–4 and review fixes, local working tree on baseline `1f17a61`:
  `flutter pub get` passed; `dart format --output=none --set-exit-if-changed .`
  changed 0 files; `flutter analyze --no-pub` found no issues;
  `flutter test --no-pub --reporter compact` passed 734 tests;
  `flutter build apk --debug` succeeded; `git diff --check` passed.
  These checks do not replace the Mobile → BE → SQL Server/Cloudinary →
  Firebase/Web email-verification manual flow in Task 5.

## Task 0 — Baseline verification + file_picker dependency

1. Record exact HEAD, `git status -sb`, `flutter --version`, `flutter analyze`
   and `flutter test` before implementation; record any baseline failures.
2. Add `file_picker: ^11.0.3` (MIT) to `pubspec.yaml`; run `flutter pub get`; lock in
   `pubspec.lock`. Version 12+ conflicts with the existing `share_plus` 12
   dependency through incompatible `win32` constraints; avoid an unrelated
   `share_plus` major upgrade. Record the new dependency in the PR and run an Android build.
   `firebase_auth` and `firebase_core` already exist; do not add them again.
3. Reuse `lib/app/bootstrap.dart` and `lib/firebase_options.dart`. Add a
   centrally validated Web verification origin to `lib/app/config/app_config.dart`
   with README setup/placeholder guidance. Do not hard-code a localhost or
   production origin, commit secrets, or initialize another Firebase app.

DoD: baseline results recorded, dependency resolves, Android build passes
when the local SDK supports it, and missing verification origin fails safely.

## Task 1 — Domain model + repository contract

`lib/features/auth/domain/`:

- `entities/tour_operator_registration.dart`: input with the SRS fields and a
  result with `userId`, `applicationStatus`, `messageCode`. Do not add a
  `message` property to the Domain result solely because the API envelope
  carries one.
- `entities/operator_document_upload.dart`: `OperatorDocumentUpload` (fileName, contentType,
  bytes); no invented `taxCertificate` upload type is needed for this contract.
- `repositories/tour_operator_registration_repository.dart`: abstract contract with
  `Future<TourOperatorRegistrationResult> register(TourOperatorRegistration registration,
  String firebaseIdToken)` or an equivalent Domain-safe input.
- `usecases/register_tour_operator.dart`: validates the required fields,
  password policy, optional phone, file type/size/count and terms before any
  external call; also requires the Web verification origin **before** creating
  a Firebase identity or sending the BE POST, then coordinates identity, BE
  and email states.

Extend `AuthIdentityService`/its Firebase implementation only as needed for
same-user recovery, an unverified-user ID token, guarded deletion of the
newly created user, and a verification email with the configured Web continue
URL. Keep the Traveler `refreshIdToken()` verified-only behavior unchanged.
Tests first: validation and no external call on invalid input, identity
ownership and cleanup. Avoid declaration-only equality/mock tests.

## Task 2 — Data layer: multipart DTO + datasource

`lib/features/auth/data/`:

- `models/register_operator_request.dart`: builds `FormData` with the correct field names
  (`firebaseIdToken`, `email`, `password`, `confirmPassword`, `companyName`,
  `businessLicenseNo`, `taxCode`, `contactPerson`, optional `businessAddress`
  and `contactPhone`, `businessLicenseDocument`, repeated
  `supportingDocuments`, `acceptTerms`). Use `MultipartFile.fromBytes` with
  the selected filename and MIME type for each file.
- `datasources/auth_remote_data_source.dart`: add
  `Future<RegisterOperatorResponse> registerOperator(FormData formData)` posting to
  `/api/v1/auth/register/operator` through `DioClient.dio`. Override the
  default JSON content type for multipart and set `extra: {'skipAuth': true}`
  so a saved TripMate session cannot attach an Authorization header.
- `mappers/operator_registration_mapper.dart`: maps the BE response JSON to
  `TourOperatorRegistrationResult`, requiring 201, `success: true`, and
  `data.userId/applicationStatus/messageCode`. Map `ProblemDetails.errorCode`
  and `errors` field-code arrays (including MSG157–MSG160, MSG_TOS and token
  errors) to safe Domain failures. Do not pass raw BE titles to the UI.
  Distinguish definite BE responses from timeout/connection loss or malformed
  success data that may follow a committed registration.

Tests first: exact keys (especially `businessAddress` and repeated
`supportingDocuments`), file bytes, generated multipart boundary, guest
headers, 201 envelope, field-code mapping and ambiguous response handling.

## Task 3 — Registration and verification lifecycle

- `repositories/tour_operator_registration_repository_impl.dart`: implements the domain
  contract and translates Data errors to Domain failures.
- The use case coordinates validation → Firebase create/token → BE POST →
  email verification **after** a valid 201. Use the token returned by
  `registerWithEmail`, not the current verified-only `refreshIdToken()`.
- A definite non-committing BE rejection triggers best-effort cleanup of only
  the user created in that attempt. A timeout/malformed success response
  retains the same identity and freezes the original request for explicit
  retry/recovery. A 409 after an unknown outcome is not automatic success.
  Recovery after app restart reauthenticates the same Firebase user, never
  calls create again. Email-send failure after 201 allows resend but never
  sends a second registration POST.
- Add Operator confirmation via `POST /api/v1/auth/web/verify-email` using a
  **fresh verified Firebase Bearer token**. Check `emailVerified` response,
  then direct the applicant to normal Mobile sign-in. Do not use the existing
  session-producing Mobile `/auth/verify-email` path for this Operator flow.
  Preserve the Traveler verification behavior.

Tests first: call order, definite-error/failed cleanup, unknown-outcome
retention, same-identity recovery, email-send failure/resend, verified and
unverified confirmation, and no TripMate session from confirmation.

## Task 4 — Page + wizard UI

Rewrite `OperatorRegistrationPage` from the mock into a 3-step wizard:

- Wire `lib/app/router/app_router.dart` through DI to a feature-scoped
  `presentation/cubit/register_operator_cubit.dart`. The Cubit owns step index,
  values/files, inline errors, loading and success states; it invokes the
  use case and does not implement Firebase/HTTP operations.

- Step 1 (Account): Email, Password, Confirm Password — client guards MSG01/02/05/06.
- Step 2 (Company): Company Name, Business Licence Number, Tax Code, Contact Person
  (required), Business Address (optional), Contact Phone (optional) — client guards MSG01,
  phone format.
- Step 3 (Documents + Terms): real `file_picker` for Business Licence (required) +
  supporting files (max 5); Terms checkbox; [Submit Application] with loading +
  duplicate-submit guard.
- Step indicator (1/2/3) with Next/Back; values preserved across steps.
- Success: transition to a dedicated **Check your email** screen after the
  completed form, with masked email, MSG08 + MSG07 guidance, resend with a
  60-second cooldown after success, and an **I've verified my email** action
  that invokes the Operator confirmation flow. Keep interrupted-attempt
  recovery separate from the normal account step. If the app closes, Sign In
  links to same-identity email recovery without repeating registration.
  Explain Pending Approval without rendering the current
  `/operator/application` demo as if it were real application data.

Widget/Cubit tests: step navigation, retained values/files, validation,
file selection, loading/duplicate tap, success/error/delivery states,
confirmation feedback, small screen and keyboard behavior.

## Task 5 — Verification

1. Run `flutter pub get`, `dart format --set-exit-if-changed .`,
   `flutter analyze`, `flutter test`, and `flutter build apk --debug` (plugin
   and Android runtime change). Record pass/fail/skip against the final head.
2. With the UC-02 BE branch, SQL Server/Cloudinary, Firebase and reachable Web
   verification origin: Mobile submit → BE 201 → verification email → Web
   link → Mobile verified-token confirmation → Mobile sign-in → BE-reported
   Pending Approval. Check document records through the existing Admin
   **detail** endpoint. If the Admin collection queue is absent, record SRS
   PC-03 as an external dependency, not a passed test. The current
   `/operator/application` demo is not proof of live detail integration.
3. Manually cover one definite validation failure, email-delivery failure,
   and controlled ambiguous-response recovery; record actual evidence.
4. Inspect changed/staged files for secrets, generated output and unrelated
   edits. Do not claim tests from the older worktree as final-head evidence.

Non-goals: new BE verification handler, Google sign-in for operators,
document preview, direct Cloudinary upload, approval/rejection, resubmission,
automatic sign-in, Mobile deep-link verifier or a Mobile Admin route.
