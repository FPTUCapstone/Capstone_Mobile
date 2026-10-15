# UC-03 Resubmit Tour Operator Application — Mobile Specification

## Status and scope

**Revised draft — 2026-10-08. Feature-owner decision: `SHARED_WEB_MOBILE`.** Aligned with SRS §3.2.3 "Resubmit Tour Operator Application",
`Capstone_Docs/ux/screen-specifications/resubmit-tour-operator-application-screen-spec.md`, and
the authoritative backend API contract in `Capstone_BE/specs/UC-03-spec.md`. Companion to
`Capstone_FE/specs/UC-03-spec.md`. Branch:
`feature/linhnv-resubmit-tour-operator-application`, baseline `origin/develop` (`acfde81`).

UC-03 allows an authenticated Tour Operator whose application has been rejected to sign in with
the existing account, review the administrator's rejection reason, correct the company
information and documents, and submit the application again without registering a new account.
After successful resubmission, the application returns to `PendingApproval` status. The account
remains unable to publish tours or receive bookings until an Administrator approves it.

## Related behavior

- UC-02 registers the account, creates `OperatorProfile`, and uploads initial documents.
- UC-04 handles sign-in; role/status routing directs a `PendingApproval` or `Rejected`
  Tour Operator to the application status screen (`/operator/application`).
- UC-51 records rejection metadata (`RejectionReason`, `ReviewedAtUtc`) and sets status to `Rejected`.
- UC-50 requires an existing or newly submitted reviewable Business License document.
- UC-03 transitions the application back to `PendingApproval` and keeps the account locked.

## Locked messages (aligned with BE and FE contracts)

| Code | Text | Use |
| --- | --- | --- |
| **MSG01** | This field is required. | Required input validation |
| **MSG127** | TripMate is temporarily unable to process your request. Please check your connection and try again. | Safe network / infrastructure failure |
| **MSG157** | Please upload the required business licence document. | No existing or new Business License |
| **MSG158** | The uploaded file type is not supported or the file exceeds the size limit. | Invalid file type or > 5 MiB |
| **MSG159** | This business licence number or tax code is already registered. | Duplicate tax code or licence number |
| **MSG161** | Only rejected applications can be resubmitted. | Action attempted when status is not Rejected |
| **MSG162** | Application resubmitted successfully. It is now pending administrator review. | Success banner copy |

The obsolete draft references MSG140–MSG145 and incorrect SRS citations MSG19/22/23/26 are retired.
Mobile must never display raw server exception messages or unmapped `ProblemDetails.title`.

## Business rules and decisions

1. **Authentication and role:** Caller must be an authenticated `TourOperator` (Bearer token
   managed via `AuthSessionCubit` / `DioClient`).
2. **State guard (BR-09):** Resubmission is permitted only when `approvalStatus == Rejected`.
   If status is `PendingApproval` or `Approved`, the resubmit action is blocked.
3. **Single account / profile:** Resubmission updates the existing profile record; it never
   creates a new account or Firebase identity.
4. **Identifier formats & uniqueness (BR-08):**
   - Tax Code: 10 ASCII digits or `10 digits-3 digits` (e.g. `0101234567`, `0315678901-001`).
   - Business Licence Number: `DD-SSSSS/YYYY/TYPE` (e.g. `79-0123/2026/TCDL-GPLHQT`).
   - Phone: valid Vietnamese phone format if provided.
   - Values are trimmed before validation. The operator's own unchanged identifiers are valid.
5. **Documents (BR-07):**
   - Business Licence: optional replacement. If not replaced, server reuses the latest existing
     rejected licence, resetting it to `Submitted`.
   - Supporting documents: optional, max 5 new current-cycle files.
   - Files restricted to PDF, JPG, PNG, each ≤ 5 MiB.
   - BE contract does not return original file names in `GET`; documents are labeled by
     `documentType` and `documentId`. Secure short-lived `downloadUrl` with expiry is used.

## Screen and UI specifications

Per `Capstone_Docs/ux/screen-specifications/resubmit-tour-operator-application-screen-spec.md`
and existing `OperatorApplicationPage` (`/operator/application`):

### Two-screen journey: status then correction form

`OperatorApplicationPage` is the status entry. A rejected application exposes a Resubmit action
that opens `/operator/application/resubmit`; the form route reloads current state and fails closed
if it is no longer rejected.

| State | Display |
| --- | --- |
| **Loading** | Centered progress indicator; no stale data. |
| **Pending Approval** | Hourglass icon, `StatusBadge(Pending Approval)`, application submitted heading, locked-workspace guidance, [Sign Out]. No edit controls. |
| **Rejected status page** | **Rejection banner** (`AppAlert(type: error)` with `rejectionReason` and formatted `reviewedAtUtc`), company summary card with `StatusBadge(Rejected)`, existing documents, and a **Resubmit Application** action that opens the separate form route. |
| **Resubmit form route** | `/operator/application/resubmit` reloads the current application, redirects back if it is no longer rejected, and renders the editable pre-filled form: |
| | - Company Name (required, pre-filled) |
| | - Business Licence Number (required, pre-filled) |
| | - Tax Code (required, pre-filled) |
| | - Contact Person (required, pre-filled, maps to `Users.full_name`) |
| | - Business Address (optional, pre-filled) |
| | - Contact Phone (optional, pre-filled) |
| | - **Document Section**: cards showing existing documents (by type and ID) with status badge and authorized view/download link. Option to `[Replace Business Licence]` and `[Add Supporting Documents]` via `file_picker`. |
| | - Notice: "After resubmission the application returns to Pending Approval." |
| | - **[Resubmit Application]** button (loading state + double-tap guard) |
| | - **[Sign Out]** button with confirmation dialog. |
| **Unresolved / Error** | Safe error banner (`AppAlert(type: warning)`), [Sign Out]. |

## API Contracts (DioClient, authenticated)

### GET `/api/v1/operator/application`
- Headers: `Authorization: Bearer <token>`
- Response `200 OK`:
  ```json
  {
    "userId": 12,
    "userStatus": "Rejected",
    "approvalStatus": "Rejected",
    "companyName": "Sapa Trekking Co.",
    "businessLicenseNo": "79-0123/2026/TCDL-GPLHQT",
    "taxCode": "0101234567",
    "businessAddress": "123 Muong Hoa, Sa Pa",
    "contactPerson": "Nguyen Van A",
    "contactPhone": "0987654321",
    "rejectionReason": "The scan is unreadable.",
    "reviewedAtUtc": "2026-10-05T08:30:00Z",
    "resubmissionCount": 0,
    "documents": [
      {
        "documentId": 101,
        "documentType": "BusinessLicense",
        "status": "Rejected",
        "uploadedAtUtc": "2026-10-01T10:00:00Z",
        "downloadUrl": "https://signed-url...",
        "downloadUrlExpiresAtUtc": "2026-10-08T10:10:00Z"
      }
    ]
  }
  ```

### PUT `/api/v1/operator/application/resubmit`
- Headers: `Authorization: Bearer <token>`, `Content-Type: multipart/form-data`
- Body fields:
  - `companyName` (string, required)
  - `businessLicenseNo` (string, required)
  - `taxCode` (string, required)
  - `contactPerson` (string, required)
  - `businessAddress` (string, optional)
  - `contactPhone` (string, optional)
  - `businessLicenseDocument` (file bytes, optional replacement)
  - `supportingDocuments` (repeated file keys, optional, max 5)
- Response `200 OK`:
  ```json
  {
    "userId": 12,
    "userStatus": "PendingApproval",
    "approvalStatus": "PendingApproval",
    "updatedAtUtc": "2026-10-08T10:00:00Z",
    "messageCode": "MSG162",
    "message": "Application resubmitted successfully. It is now pending administrator review.",
    "resubmissionCount": 1
  }
  ```

## Acceptance criteria

1. Real API data replaces the prototype mock in `OperatorApplicationPage` and `OperatorApplicationCubit`.
2. A `Rejected` application displays the real `rejectionReason` and `reviewedAtUtc`.
3. Form fields pre-fill from the loaded `OperatorApplication` entity.
4. Input validation blocks submission locally and renders inline errors for missing required
   fields or malformed tax code / licence number / phone without firing network calls.
5. `file_picker` validates file extension (.pdf, .jpg, .jpeg, .png) and file size (≤ 5 MiB).
6. Omitting a new licence file is supported; the existing licence is retained and resubmitted.
7. Successful resubmission transitions status to `PendingApproval`, displays MSG162 banner,
   and locks the form.
8. Error handling maps `400` (field/file errors), `409` MSG159 (identifier conflict),
   `409` MSG161 (state conflict), and `503` MSG127 (network/server error) to safe user-facing
   alerts while preserving user input for correction and retry.
9. Double-tap on submit is prevented while submission is in-flight.
10. Automated tests cover Cubit states, entity mapping, validation rules, multipart request
    construction, and error scenarios.

## Non-goals

New account creation, Firebase registration/email verification modifications, direct Cloudinary
upload, Admin review operations (UC-50/51), and Traveler flow modifications.
