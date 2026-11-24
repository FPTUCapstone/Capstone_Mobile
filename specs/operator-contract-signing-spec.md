# Operator contract signing — Mobile spec
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
Approved signing method: drawn PNG + full name + explicit consent + OTP sent to the registered email.
Reuse the dedicated signing purpose with the existing OTP policy: 180-second TTL, five failed attempts and 60-second resend cooldown. The backend returns these policy values.
Existing Active TO accounts retain access; new approvals require signing. Use the user-approved test contract while testing. Representative name/title/capacity are explicitly declared, not inferred as verified legal authority from the contact person. This implementation does not claim a certified digital signature.

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

## Current client contract
- `/operator/contract` is a restricted onboarding route and later a read-only signed-contract view.
- Read `GET /api/v1/operator/contracts/current`; unknown onboarding/status values fail closed.
- Confirm signer details through `POST /{id}/prepare`; bounded polling reads the current document state.
- Read private, SHA-256-verified `GET /{id}/documents/unsigned` before enabling consent and signing. A PDF network download alone does not mark the viewer opened successfully.
- Capture transparent PNG bytes at 600×200; clear/cancel/disabled/unmount cannot restore stale PNG exports.
- Request `POST /{id}/signing-challenges` for the accepted content hash and row version. Submit signature PNG, exact signer name, consent version, challenge, six-digit OTP and idempotency key to `POST /{id}/sign`.
- Exact-payload retries retain their idempotency key. A lost response is reconciled with current server state; a 409 clears signature/OTP/consent and reloads metadata.
- After Signed, renew using the existing single-flight auth refresh mechanism, then reload backend-issued onboarding metadata under the existing session identity lock. No local Signed-to-Active conversion.
- Keep private PDF bytes and signature/OTP in screen memory. User-initiated PDF download/share uses the system share sheet; no browser bearer URL.
