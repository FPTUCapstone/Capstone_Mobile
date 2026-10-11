# UC-02 Register Tour Operator Account Mobile Specification

> **2026-10-08 Mobile amendment:** The verified-before-submission decision in
> [UC-02-verified-first-amendment.md](UC-02-verified-first-amendment.md)
> supersedes this document's older BE-before-email ordering and recovery
> instructions. The older text remains as the implementation history.

## Status

**Implemented locally on 2026-10-06; live end-to-end verification pending.**
Branch `feature/linhnv-register-tour-operator-account`, baseline `1f17a61`.
`Capstone_BE/specs/UC-02-spec.md` and the BE request/response types are the API
contract. The UC-02 BE implementation is still on
`feature/linhnv-register-tour-operator`; integrated Mobile testing depends on it.

## Sources and scope

### Business identifier format decision (2026-10-08)

After trimming, Tax Code is 10 ASCII digits or 10 digits, `-`, 3 digits
for a branch (`0101234567`, `0315678901-001`). Business Licence Number is
two province digits, `-`, one or more serial digits, `/`, four issue-year
digits, `/`, and `TCDL-GPLHQT` or `SDL-GPLHND` (examples
`79-0123/2026/TCDL-GPLHQT`, `01-0456/2025/SDL-GPLHND`). The serial width was
not specified by the owner. Step 2 blocks malformed values and gives field
feedback before Firebase creation; the domain use case repeats the check,
and BE is authoritative. Do not filter input during Vietnamese IME composition.
The BE codes are `OPERATOR_TAX_CODE_INVALID` and
`OPERATOR_TRAVEL_LICENSE_INVALID`.

- SRS §3.2.2 + `WEB_SCOPE_MATRIX` row UC-02: `SHARED_WEB_MOBILE` — mobile delivers the same
  registration capability as the web. **All fields are identical to the web UC-02**; only the
  layout differs (wizard steps on mobile vs a single scrollable page on web).
- BE contract: `POST /api/v1/auth/register/operator` — multipart/form-data; creates one User
  (role `TourOperator`, status `PendingApproval`) + one OperatorProfile (`PendingApproval`) +
  OperatorDocuments in one database transaction.
- Locked catalog messages MSG01–MSG08/127 follow the BE reconciliation. BE uses
  feature constants **MSG157** (required licence), **MSG158** (invalid document),
  **MSG159** (licence/tax collision) and **MSG160** (duplicate pending application),
  plus `MSG_TOS`. They are not rows in `dbo.Messages`. Do not reuse the SRS's
  incorrect MSG19/22/23/26 references or render arbitrary BE error titles.

## Wizard layout (3 steps on mobile)

Mobile splits the same fields into 3 wizard steps (same fields as web, re-review point: 100%
field parity):

| Step | Fields |
| --- | --- |
| **1 — Account** | Email Address, Password, Confirm Password |
| **2 — Company** | Company Name, Business Licence Number, Tax Code, Contact Person (required — → `Users.full_name`), Business Address (optional), Contact Phone (optional) |
| **3 — Documents + Terms** | Business Licence file (required — `file_picker` PDF/JPG/PNG ≤ 5 MB), Supporting Documents (optional, max 5), Terms checkbox (required), [Submit Application] |

Step navigation: Next/Back buttons per step; a step indicator (1/2/3); the form preserves
values across steps; [Submit Application] on step 3 triggers the full flow. [Back to Sign In]
on step 1 links to `/auth/login`.

After a successful submission, replace the form with a dedicated **Check your email**
screen, following the Traveler registration handoff. Show the masked address,
Pending Approval notice, resend action with a 60-second cooldown after a
successful resend, and **I've verified my email**. This step confirms email
ownership without signing the Operator in or approving the application.
Previous-attempt recovery is not part of the new-account step; an interrupted
registration can resume from the documents step, and a submitted application
can resume email confirmation from Sign In using the same credentials.

## Multipart contract and storage

Client validation checks required values, email/password policy, optional phone,
document extension/MIME/size (5 MiB per file), supporting-file count, and terms
and requires a configured Web verification origin before any Firebase or BE
call. BE validates file signatures and business rules
authoritatively. The exact form keys from `RegisterOperatorRequest` are:

| Field | Submission |
| --- | --- |
| `firebaseIdToken` | Token of the new or recovered Firebase user; the email need not be verified yet |
| `email`, `password`, `confirmPassword` | Required account fields |
| `companyName`, `businessLicenseNo`, `taxCode`, `contactPerson` | Required business fields |
| `businessAddress`, `contactPhone` | Optional; omit if blank |
| `businessLicenseDocument` | One required file |
| `supportingDocuments` | Repeat this exact key for each optional file; no `[]` suffix |
| `acceptTerms` | `true` |

The 201 response is an API envelope with `success: true` and `data` containing
`userId`, `applicationStatus: "PendingApproval"`, and `messageCode: "MSG08"`.
Validate all required fields before reporting success. Mobile sends files to
BE; BE uploads them to Cloudinary and stores URLs in SQL Server. Mobile never
uses Cloudinary credentials or uploads directly to Cloudinary.

## Firebase identity + BE registration flow

1. Create the Firebase email/password identity **after** client validation.
   `registerWithEmail` already returns its ID token. Account creation does not
   prove ownership of the email address. The existing `refreshIdToken()` is
   verified-only and returns `null` before email verification; never use it
   for this initial POST.
2. Send that unverified-user token and the multipart form to BE. BE validates
   the token, hashes the password and creates User (`TourOperator`,
   `PendingApproval`), OperatorProfile and document rows. Do not infer a
   TripMate session from Firebase identity creation or registration success.
3. Only after a valid BE 201, send the Firebase verification email with a
   configured Web continue URL `/verify-email?flow=operator`. Show MSG08 and
   MSG07 guidance. If delivery fails, retain the committed application and
   offer resend with the same Firebase identity; never repeat the BE POST
   merely to resend email.
4. The applicant opens the email link. The Web route applies the Firebase
   action code and, if it has the matching Firebase browser session, calls
   `POST /api/v1/auth/web/verify-email`. Because a Mobile-created user may
   have no Web browser session, the Mobile success/verification state also
   offers **I've verified my email**. It reloads the Firebase user, requires
   `emailVerified`, obtains a fresh ID token, and calls that existing BE
   endpoint with a Firebase Bearer token. The endpoint records
   `EmailVerifiedAtUtc` for `PendingApproval` without issuing a TripMate
   session; calling it again after Web confirmation is safe.
5. The user then signs in through existing Mobile `/auth/login`; BE reports
   `PendingApproval` and keeps Operator workspace actions locked. Do **not**
   use Mobile `/auth/verify-email` for this Operator confirmation: it tries
   to issue a session before that verification marker exists. The current
   `/operator/application` page still contains demo content, so it is not
   evidence of a live application detail view.

If Mobile closes before email verification, the registration Cubit and form are
not restored as a TripMate session. On relaunch the user reaches Sign In and
can use **Tour Operator: finish email verification** to reauthenticate the
same Firebase identity, resend the link or synchronize a verified email with
BE. Do not create another Operator account or repeat the registration POST.

### BE rejection handling

For a **definite non-committing BE rejection**, delete only the Firebase
identity newly created for that attempt, best effort. Never delete an identity
that already existed before the attempt. Preserve and show the BE error even
if Firebase cleanup fails. If cleanup fails, recovery must reuse or
reauthenticate that identity instead of blindly creating another account.

### Unknown POST outcome (network timeout)

For timeout, connection loss after POST, or malformed success response, BE may
already have committed. Keep the Firebase identity and original form; do not
resubmit automatically. Offer an explicit same-identity retry or sign-in and
verification recovery. After app restart, reauthenticate the same Firebase
email/password rather than calling `createUserWithEmailAndPassword` again.
A later 409 may indicate the first attempt committed; it is not itself proof
of success. Never store the password or ID token in insecure storage or logs.

## Error handling

| Situation | Behavior |
| --- | --- |
| Field errors (`400`: MSG01/02/05/06, MSG157/158, MSG_TOS or `auth.request_invalid`) | Read BE `ProblemDetails.errors` field-code arrays and render safe mapped copy under each control; preserve input/files. |
| Email exists (`409` MSG03) | Locked MSG03 text at the email control. |
| Business identity collision (`409` MSG159) | MSG159 text at the company section. |
| Duplicate pending application (`409` MSG160) | MSG160 text at the form level. |
| Storage/system failure (`503` MSG127) | Safe alert; distinguish a definite BE response from an unknown transport outcome; BE-side file compensation is best effort. |
| Firebase unavailable | Alert stating the registration service is unavailable; the flow stops (fail-closed). |
| Network timeout on POST | Keep identity; prompt explicit same-identity retry or verification/sign-in recovery. |
| Verification email delivery failure after 201 | Keep Pending Approval result and offer resend without another registration POST. |
| Unknown BE error code | Show safe generic copy, never the raw server title or exception. |

## Mobile-specific notes

- **`file_picker` ^11.0.3** is wired to the registration wizard for real
  PDF/JPG/PNG selection. Review its dependency/lockfile in the implementation
  PR and verify the Android build at the final head.
- **DioClient** provides the shared Dio instance. Override its JSON content
  type for `FormData` and set `skipAuth: true`; use the multipart boundary Dio
  generates. Tests must assert file bytes and no TripMate Authorization header.
- **Clean Architecture**: Page → Cubit → use case → Domain contracts → Data
  repository/identity adapter → Dio/Firebase. The Cubit owns UI state; the use
  case owns registration order and recovery policy. Do not add empty layers.
- **Route**: `AppRoutes.operatorRegistration` (`/auth/register/operator`) already declared.

## Acceptance and dependencies

- Invalid fields/files make no Firebase or BE call; duplicate taps create at
  most one in-flight submission.
- Tests cover exact multipart keys, repeated supporting files, 201 envelope,
  BE field codes, cleanup on definite failure, ambiguous outcome retention,
  email delivery failure/resend, and verification without a TripMate session.
- Manual E2E requires running UC-02 BE, SQL Server/Cloudinary, Firebase, and
  a reachable Web verification origin. Check documents via the existing
  Admin application **detail** endpoint. The Admin list/review queue is not
  yet available, so SRS PC-03 must remain an explicit external dependency;
  do not claim it passed from this Mobile feature alone.

## Non-goals

New BE verification handlers, Google sign-in for operators, document preview
or direct Cloudinary upload, UC-50/51 approval/rejection, UC-03 resubmission,
automatic sign-in after registration, and a Mobile deep-link verifier.
