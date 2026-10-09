# UC-03 Resubmit Tour Operator Application — Mobile Implementation Plan

Status: **Revised draft — 2026-10-08; scope `SHARED_WEB_MOBILE` by feature-owner decision**. Follows `specs/UC-03-spec.md` and the shared backend API
contract in `Capstone_BE/specs/UC-03-spec.md`. Branch:
`feature/linhnv-resubmit-tour-operator-application` (based on `origin/develop`, `acfde81`).

The implementation adheres to Clean Architecture:
Page / Widgets → Cubit → Use Cases → Domain Contracts → Data Repositories & DataSources → DioClient.
Tests precede implementation at every task.

## Pre-conditions

- Branch `feature/linhnv-resubmit-tour-operator-application` is checked out on `Capstone_Mobile`.
- `file_picker ^11.0.3` is resolved in `pubspec.yaml` (from UC-02).
- `DioClient` with Bearer token authentication via `AuthSessionCubit` is available.
- Backend UC-03 endpoints (`GET /api/v1/operator/application`, `PUT /api/v1/operator/application/resubmit`)
  are available on the backend feature branch.

## Task 0 — Baseline verification & contract lock

1. Record baseline SHA (`acfde81`), `flutter --version`, `flutter analyze --no-pub`,
   and `flutter test --no-pub --reporter compact` pass/fail numbers.
2. Confirm locked catalog messages in Mobile code/constants:
   `MSG01`, `MSG127`, `MSG157`, `MSG158`, `MSG159`, `MSG161`, `MSG162`.
3. Confirm `DioClient` configuration supports authenticated `PUT` with `multipart/form-data`.

DoD: baseline recorded, no new dependencies required, zero analysis/compilation errors.

## Task 1 — Domain Layer: Entities, Contracts & Use Cases

`lib/features/auth/domain/`:

### Entities (`entities/`)

- **`operator_application.dart`** (`OperatorApplication`):
  - `userId` (`int`)
  - `userStatus` (`String`)
  - `approvalStatus` (`TourOperatorApplicationStatus`)
  - `companyName` (`String`)
  - `businessLicenseNo` (`String`)
  - `taxCode` (`String`)
  - `contactPerson` (`String`)
  - `businessAddress` (`String?`)
  - `contactPhone` (`String?`)
  - `rejectionReason` (`String?`)
  - `reviewedAtUtc` (`DateTime?`)
  - `resubmissionCount` (`int`)
  - `documents` (`List<OperatorApplicationDocument>`)
- **`operator_application_document.dart`** (`OperatorApplicationDocument`):
  - `documentId` (`int`)
  - `documentType` (`String`)
  - `status` (`String`)
  - `uploadedAtUtc` (`DateTime`)
  - `downloadUrl` (`String`)
  - `downloadUrlExpiresAtUtc` (`DateTime`)
- **`resubmit_operator_application.dart`** (`ResubmitOperatorApplication`):
  - `companyName` (`String`)
  - `businessLicenseNo` (`String`)
  - `taxCode` (`String`)
  - `contactPerson` (`String`)
  - `businessAddress` (`String?`)
  - `contactPhone` (`String?`)
  - `businessLicenseDocument` (`OperatorDocumentUpload?`) (reuses upload entity from UC-02)
  - `supportingDocuments` (`List<OperatorDocumentUpload>`)

### Repository contract (`repositories/`)

- **`operator_application_repository.dart`** (abstract):
  ```dart
  abstract interface class OperatorApplicationRepository {
    Future<OperatorApplication> fetchApplication();
    Future<void> resubmitApplication(ResubmitOperatorApplication input);
  }
  ```

### Use Cases (`usecases/`)

- **`fetch_operator_application.dart`** (`FetchOperatorApplication`):
  Calls `repository.fetchApplication()`.
- **`resubmit_operator_application_use_case.dart`** (`ResubmitOperatorApplicationUseCase`):
  - Normalizes text with `trim()`.
  - Validates required fields (`companyName`, `businessLicenseNo`, `taxCode`, `contactPerson`).
  - Validates `businessLicenseNo` regex (UC-02 format).
  - Validates `taxCode` regex (10 digits or 10-3 digits).
  - Validates `contactPhone` if present.
  - Validates file extensions (pdf, jpg, jpeg, png) and max size (≤ 5 MiB).
  - Validates max 5 supporting documents.
  - Calls `repository.resubmitApplication(normalizedInput)`.

Unit tests for domain validation rules, boundary conditions, and repository delegation.

DoD: domain layer is pure Dart, zero Flutter/Dio dependencies, 100% test pass.

## Task 2 — Data Layer: DTOs, DataSource & Repository Impl

`lib/features/auth/data/`:

### Models (`models/`)

- **`operator_application_response_dto.dart`**: maps BE `GET /api/v1/operator/application` JSON.
- **`operator_application_document_dto.dart`**: maps BE document JSON.
- **`resubmit_operator_request.dart`**: constructs `FormData` for `PUT /api/v1/operator/application/resubmit`:
  - `companyName`, `businessLicenseNo`, `taxCode`, `contactPerson`.
  - `businessAddress`, `contactPhone` (omitted if null/empty).
  - `businessLicenseDocument` (MultipartFile with filename and MIME, omitted if null).
  - `supportingDocuments` (repeated key for each supporting file).

### DataSource & Mapper (`datasources/`, `mappers/`)

- Extend `auth_remote_data_source.dart`:
  - `Future<OperatorApplicationResponseDto> fetchOperatorApplication()`
  - `Future<void> resubmitOperatorApplication(FormData formData)`
  - Authenticated via `DioClient` (uses Bearer token interceptor, `skipAuth: false`).
- **`operator_application_mapper.dart`**:
  - Maps DTO to Domain entities.
  - Maps BE `ProblemDetails.errors` and status codes to typed domain failures:
    `400` (MSG01, MSG157, MSG158), `409` (MSG159, MSG161), `503` (MSG127).

### Repository Impl (`repositories/`)

- **`operator_application_repository_impl.dart`**:
  Implements `OperatorApplicationRepository` by calling datasource and mapping results/exceptions.

Data layer unit tests: JSON serialization/deserialization, FormData construction with repeated keys,
file omission logic, and error code translation.

DoD: data layer tests pass, exact BE field naming respected.

## Task 3 — Cubit & Presentation State (Wire real API)

File: `lib/features/auth/presentation/cubit/operator_application_cubit.dart`

Replace the existing mock Cubit (`selectDemoLicence`, `Future.delayed`):

1. **`OperatorApplicationState`**:
   - `status`: `TourOperatorApplicationStatus` (`pendingApproval`, `rejected`, `unresolved`, etc.)
   - `application`: `OperatorApplication?`
   - `isLoading`: `bool` (initial fetch in-flight)
   - `isSubmitting`: `bool` (PUT in-flight)
   - `fieldErrors`: `Map<String, String>?`
   - `errorMessage`: `String?`
   - `successMessage`: `String?` (MSG162 copy on successful resubmission)
   - `newLicence`: `OperatorDocumentUpload?`
   - `newSupportingDocuments`: `List<OperatorDocumentUpload>`
2. **Cubit methods**:
   - `Future<void> loadApplication()`: calls `FetchOperatorApplication`, handles loading and state updates.
   - `void selectLicenceDocument(OperatorDocumentUpload document)`: updates selected replacement licence.
   - `void removeLicenceDocument()`: reverts to existing licence.
   - `void addSupportingDocument(OperatorDocumentUpload document)`: appends supporting document (guarded ≤ 5).
   - `void removeSupportingDocument(int index)`: removes supporting document at index.
   - `Future<void> resubmit(ResubmitOperatorApplication input)`: invokes use case, handles loading,
     double-tap guard (`if (state.isSubmitting) return;`), error emission, and success transition.
   - `void dismissError()`: clears error messages.

Cubit unit tests: initial load, rejection reason presentation, document manipulation, validation failure,
submission in-flight guard, success transition to `pendingApproval` with MSG162, and error handling.

DoD: Cubit completely decoupled from UI widgets, zero mock delay/demo code.

## Task 4 — UI Updates: status page and resubmit page

File: `lib/features/auth/presentation/pages/operator_application_page.dart`

Update the screen to consume real Cubit state and wire `file_picker`:

1. **Screen Lifecycle**:
   - Call `cubit.loadApplication()` on init.
   - Display loading skeleton during `state.isLoading`.
2. **Pending Approval View**:
   - Keep existing `_PendingApplicationView` when `status == pendingApproval`.
   - Display real company name and application info.
3. **Rejected status view**:
   - Render top `AppAlert(type: error)` with real `rejectionReason` and formatted `reviewedAtUtc`.
   - Render company summary card with `StatusBadge(Rejected)`, existing documents, and a
     `Resubmit Application` action that opens `/operator/application/resubmit`.
4. **Separate resubmit form route**:
   - Reload the application and redirect to `/operator/application` if it is no longer rejected.
   - Form fields pre-filled from `state.application`:
     - Company Name, Business Licence Number, Tax Code, Contact Person (`AppTextField` with client validators).
     - Business Address, Contact Phone (optional fields).
   - Document Management Section:
     - List existing documents with status badges and download link.
     - `file_picker` integration for replacing Business Licence (shows selected new filename or "Using existing file").
     - `file_picker` integration for optional supporting documents (max 5 chips, tap to remove).
   - Notice alert explaining status transition to `PendingApproval`.
   - Resubmit button: `AppButton(label: 'Resubmit application', isLoading: state.isSubmitting, onPressed: _resubmit)`.
   - Sign Out button with confirmation dialog.
5. **Success / Error Feedback**:
   - After success: state updates to `pendingApproval`, shows MSG162 `AppAlert(type: success)`.
   - Inline field errors under `AppTextField`.
   - Top banner for global errors (MSG159 conflict, MSG161 invalid state, MSG127 network failure).

Widget tests: full rendering of Pending and Rejected states, pre-filling of form controls,
file picker trigger, field error display, loading button state, and success feedback.

DoD: zero mock text/filenames remaining, accessible form with keyboard handling, responsive on small screens.

## Task 5 — Verification & Evidence

1. Run Flutter verification commands:
   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze --no-pub
   flutter test --no-pub --reporter compact
   flutter build apk --debug
   git diff --check
   ```
2. Manual integration verification against BE UC-03 API:
   - Login as a Tour Operator with a Rejected application.
   - Verify rejection reason and previous submission values load correctly.
   - Resubmit without changing documents (verifies existing licence reuse).
   - Resubmit with a new Business Licence (verifies replacement).
   - Verify transition to Pending Approval state and MSG162 banner.
   - Verify locked operator capabilities while pending.
   - Verify error feedback for validation (400), tax/licence collision (409 MSG159),
     and concurrent state change (409 MSG161).
3. Document test evidence and PR summary.

## Non-goals

Modifying UC-02 registration flow, changes to Firebase Auth or Traveler features, direct
Cloudinary upload from mobile, Admin approval/rejection endpoints (UC-50/51).
