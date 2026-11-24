# Operator contract signing — Mobile plan
Status: Implementation authorized by the user. Updated: 24/11/2026.
Branch: fix/linhnv-operator-sign-up.

## Canonical cross-repository documents
- ../../Capstone_BE-confirm-booking-refund/specs/operator-contract-signing-spec.md
- ../../Capstone_BE-confirm-booking-refund/plans/operator-contract-signing-plan.md
Use the corresponding BE PR links when reviewing outside this workspace.

## Scope
Staff approval moves the account to PendingContractSignature while the application is Approved.
TO login redirects to the contract. Business access remains blocked by backend authorization.
A successfully verified and durably saved signature activates the account; no TripMate countersignature follows.
Existing registration consent remains separate. Rejection/resubmission behavior is retained.
Approved: drawn signature + full name + consent + email OTP. Existing active operators retain their access; newly approved applications require signing. Follow the canonical Backend plan for retention and activation invariants.

Mobile owns contract entities/use cases/repository, DTO/source mapping, Cubit and pages, auth/onboarding mapping, route guards, DI and signed-document profile entry. Do not introduce Staff or Administrator Flutter features.

## Execution and completion
Follow implementation plan section 7, after BE contract and persisted authorization are available.
Split viewer, capture/confirmation, submit/retry, session refresh and signed-document viewing into separate units.
Write behavioral tests first: awaiting-signature routing, owner/version validation, failed signing, duplicate requests, changed contract and cross-device completion.
Keep API dates ISO and display dates dd/MM/yyyy. Do not infer activation locally.
Check long documents, keyboard/accessibility and narrow layouts visually; do not add automated tests solely for CSS/positioning, following the user's preference.
Run pub get, format, analyze, relevant tests and APK build when native/runtime changes require it.
Complete real BE integration and two-pass review; report skipped checks and provider limitations.
Preserve existing unrelated UI/UX changes. No implementation, commit, push or deployment is authorized merely by drafting these documents.

## Execution units and verification
1. Capture widget and behavior tests: transparent PNG export, empty tap, clear, cancellation, disabled and stale/unmounted callbacks. Six tests passed; scoped analyzer passed before integration.
2. Auth DTO/domain/state + route guard tests: server onboarding and contract metadata, legacy absence compatibility, unknown-state denial, deep links to the contract. Four focused tests passed before the PDF dependency was introduced.
3. Contract Domain entities/repository; Data DTO/remote source/repository: preserve opaque IDs, validate known states, verify PDF hashes, multipart PNG signing and owner inferred only by BE. Tests in `test/features/operator_contracts/operator_contract_dto_test.dart` and `operator_contract_repository_test.dart`.
4. `OperatorContractCubit`: preparation, bounded poll, private document review, consent/PNG, email challenge, expiry/cooldown, immutable-payload retries and reconciliation. Behavior tests in `operator_contract_cubit_test.dart`.
5. `/operator/contract` UI + native byte PDF viewer + Profile entry + DI. Widget tests use an injected document view solely for state behavior and do not claim native PDF coverage.
6. Reuse `AuthInterceptor` refresh with session lock; persist backend onboarding/contract metadata, reload it into `AuthSessionCubit`, preserve it during sign-out transitions and clear it on logout/account replacement. Extend existing refresh tests.
7. Run `flutter pub get`, scoped/full analyze, focused and auth/router regression tests. Rebuild APK only when the parent asks after API integration; then verify Android native PDF + actual email OTP + signed download.

## Verification note
Updated by parent on 24/11/2026: `flutter pub get` completed, scoped analyzer reports no issues, and 88 feature/auth-session regression tests passed. The logout test now verifies deletion of the three added onboarding fields. The application-status action renews the server session before opening the contract, covering an operator already signed in when Staff approves.

Android debug APK build succeeded with pdfx native integration and `API_BASE_URL=http://10.0.2.2:5022`. On 24/11/2026 it was installed on the existing Android emulator and the app reached its landing screen. The 23 contract tests passed again. Native PDF viewing, drawing, OTP and final signing were not interactively verified because the emulator was not signed into a pending-contract TO account. APK remains a generated local artifact. Existing Gradle/AGP/Kotlin deprecation warnings are unchanged and were not bypassed.

Actual local DB/private-storage/LibreOffice/PDF signature workflow passed through activation and idempotent retry, using a temporary capture-only OTP test transport outside product code. Real mailbox delivery and interactive Android PDF viewing/signing remain manual checks; they are not claimed as passed. Product code uses the configured real email transport and does not return codes to the client.
