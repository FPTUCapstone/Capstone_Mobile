# UC-02 Mobile: verify email before submitting an Operator application

Decision: 2026-10-08. This amendment supersedes the registration timing and
recovery sections of `UC-02-spec.md` for **Mobile Tour Operator registration
only**. Traveler registration and the existing Web Operator form are unchanged.

## Acceptance criteria

1. The three-step Mobile form validates all required account, business and
   document fields before creating a Firebase account. No BE application POST
   occurs until the matching Firebase email has been verified.
2. After account creation, Mobile sends a verification email and shows a
   dedicated verification step. The link uses
   `/verify-email?flow=operator-mobile`; the Web handler applies any action
   code and tells the applicant to return to Mobile. It does not attempt BE
   verification while no BE User exists. The existing `flow=operator` Web
   registration behavior is unchanged.
3. On an explicit submission tap, Mobile reloads the matching Firebase user,
   requires `emailVerified`, obtains a fresh ID token, and sends the multipart
   form to the existing BE endpoint. The BE 201 creates User, OperatorProfile
   and documents with `PendingApproval` status. Mobile then calls the existing
   BE Web verification endpoint to persist `EmailVerifiedAtUtc`. A sync failure
   after 201 never triggers a second registration POST.
4. If the app closes before verification or after verification but before
   submission, the user opens UC-02 again and chooses **Continue an unfinished
   registration**. The same email and password reauthenticate the existing
   Firebase identity. The applicant re-enters business details and selects
   files again; no password, document bytes or ID token is persisted as a
   draft. A verified identity skips resend. Submission still requires an
   explicit tap.
5. The old Operator verification shortcut is removed from Sign In. A legacy
   applicant whose application was already submitted can reach the existing
   email-confirmation recovery route from the UC-02 registration screen.
6. A definite BE field/business rejection retains the verified Firebase
   identity and allows correction with the same account. A transport-uncertain
   POST retains the frozen in-memory request for explicit same-identity retry;
   a later 409 is not automatically treated as success. No application is
   represented as submitted before a confirmed 201.

## Contract boundary

This is a Mobile workflow rule. The shared BE endpoint still accepts an
unverified token for the existing Web registration flow; the Mobile client
enforces verification before its POST. The BE marker is synchronized only
after the successful POST because the current BE verifier requires an existing
User. Requiring verified tokens for every client would be a separate shared
contract change affecting Web UC-02.

## Verification

Tests cover ordering, restart continuation, already-verified continuation,
duplicate tap, resend failure, definite rejection, ambiguous POST, and no
Traveler behavior change. Manual E2E remains necessary with Firebase, BE,
SQL Server, Cloudinary and the Web verification origin.
