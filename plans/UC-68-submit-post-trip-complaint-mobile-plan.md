# UC-68 Submit Post-Trip Complaint Mobile Plan

## Baseline and delivery boundaries

Implement only the authenticated Traveler UC-68 flow defined in
`specs/UC-68-submit-post-trip-complaint-mobile-spec.md`. The Backend is
authoritative for ownership, eligibility, status, timestamps, evidence limits,
the one-amendment decision and all private storage operations. No mobile code
will calculate a refund, persist evidence URLs/bytes, create Tour Operator or
Administrator UI, or start UC-69/UC-75.

The implementation must use the existing Flutter feature-first Clean
Architecture, centralized `DioClient`, `ErrorMapper`, `get_it`, `go_router`,
`flutter_bloc`, Material 3 theme and the existing `file_picker` dependency.

## Task 0 — Lock the mobile evidence-download handoff

The existing `url_launcher` pattern cannot attach the Traveler bearer token to
the protected download endpoint, so it is not sufficient for UC-68 evidence.
Before feature code, verify that the authenticated Dio request follows the
Backend's private-storage redirect or receives the local binary response. Add a
focused platform download/open adapter: it requests the file through Dio with
`ResponseType.bytes`, writes only a short-lived cache file, hands that file to
the platform save/open/share UI, and deletes the app-managed temporary copy
after handoff whenever possible. Do not use a signed URL directly in a page or
persist it.

If the current dependencies cannot provide the platform handoff safely, add the
smallest approved file-save/open dependency and include its Android setup in
the change. The adapter owns the temporary-file lifecycle; Domain, Cubits and
widgets see only a safe success/failure result.

**Verify:** Android/device or emulator validation covers both a direct local
binary response and a production-style redirect. Confirm no authorization
header, signed URL, bytes or filesystem path enters logs, preferences, state
serialization or user-facing errors.

## Task 1 — Establish API models and safe error mapping

Create `lib/features/post_trip_complaints/` with focused Domain contracts and
Data DTOs/mappers for the following server-owned resources:

- context and existing complaint:
  `GET /api/v1/traveler/bookings/{bookingId}/post-trip-complaint`;
- initial multipart submission:
  `POST /api/v1/traveler/bookings/{bookingId}/post-trip-complaints`;
- one evidence-only multipart amendment:
  `POST /api/v1/traveler/bookings/{bookingId}/post-trip-complaint/evidence`;
- authenticated evidence download:
  `GET /api/v1/traveler/bookings/{bookingId}/post-trip-complaint/evidence/{evidenceId}/download`;
- authenticated My Complaints list:
  `GET /api/v1/traveler/post-trip-complaints`.

Model `canSubmit`, `canAmendEvidence`, all safe evidence metadata, canonical
deadlines, `isReplay`, complaint/list data and the approved reason-category
enum explicitly. Preserve server timestamps as UTC at the data boundary and
format only in Presentation. Map `complaint.*`, HTTP/auth/network failures to
safe feature failures, without exposing technical error text.

**Verify:** mapper/DTO tests cover valid and malformed data, enum mapping,
nullable existing complaint, safe error envelopes and no storage key/private URL
in any Domain entity.

## Task 2 — Repository, use cases and evidence selection rules

Add the `PostTripComplaintRepository` contract, repository implementation and
use cases for context read, submit, amend evidence, list mine and download.
Use the centralized authenticated Dio client; multipart construction lives in a
remote data source, never a page or Cubit.

Add a framework-independent selected-evidence validation helper/rule set for
the fixed six categories, non-blank trimmed detail up to 2,000 characters, five
files maximum, 10 MB each and 30 MB total. The evidence amendment accepts only
new files but validates them against the size/count of existing safe metadata.
The server remains authoritative for file signatures and races.

Generate a UUID for a single unchanged submit/amend attempt. Retain it only for
a transport retry of that exact payload; invalidate it when fields/evidence
change. Keep binary response/temporary redirect handling in the data/download
boundary and do not save private evidence bytes or URLs in preferences.

**Verify:** repository and use-case tests assert paths, multipart keys,
idempotency header behavior, file-boundary rules, response mapping and safe
failure mapping.

## Task 3 — Complaint context, submit state and list state

Create a feature-scoped `PostTripComplaintCubit` and immutable state for:
initial/context loading, eligible form, ineligible/closed, existing complaint,
file-picker validation, submitting, replay/fresh success and recoverable error.
The Cubit loads context from `bookingId`, owns draft text/category/selected
files, refreshes context after success or conflict, and prevents concurrent
submit/amend taps. Create a separate `MyPostTripComplaintsCubit` for list
loading/empty/retry state so entering the account list cannot discard or mutate
an in-progress booking-scoped form.

Register the remote source, repository, use cases, parameterized complaint
Cubit and list Cubit in
`lib/core/di/service_locator.dart`, following the existing
`BookingCancellationCubit`/`TravelerEmergencyCubit` factory pattern.

**Verify:** bloc tests cover eligibility states, form validation, one
idempotency key per unchanged retry, new key after edit, fresh/replay success,
window close, duplicate complaint, conflict refresh and disposed/in-flight
protection.

## Task 4 — Traveler complaint page, localization and evidence amendment UI

Create a keyboard-safe, scrollable Material 3 page beneath
`lib/features/post_trip_complaints/presentation/pages/`.

- Render booking/tour/deadline context only from the loaded server model.
- Render the form only for `canSubmit`; otherwise render MSG157 or a read-only
  existing complaint view with MSG158.
- Use `file_picker` multi-select for allowed formats and display each selected
  safe file name/size with a remove action; preserve valid selection after an
  invalid add or recoverable request failure.
- In existing complaint state, list server evidence metadata with accessible
  download actions. Surface storage/network failures as a safe localized retry
  state, never a raw error page.
- Show **Add evidence** only when `canAmendEvidence` is true. It submits
  evidence-only data exactly once, then refreshes and removes the action after
  canonical success.

Add all labels and mapped MSG127/MSG157–MSG161 feedback to a focused complaint
resource catalogue; do not hard-code user-visible business copy in Pages or
Cubits. Use existing theme spacing/colour/typography and accessible labels,
focus and minimum touch targets. Do not preview remote images/PDFs in-app.

**Verify:** widget tests cover form, existing, closed, loading and error states;
field/file boundary feedback; add/remove file controls; submit/amend progress;
download failure; long text and narrow-screen scrolling.

## Task 5 — My Complaints and application routing

Add centralized `AppRoutes`/`AppRouteNames` constants and guarded `GoRoute`s
for:

- `/traveler/bookings/:bookingId/complaint`;
- `/traveler/complaints`.

Use the existing authenticated Traveler route-guard convention and validate
positive numeric booking IDs before creating a Cubit. Add **Submit complaint**
to the authenticated Traveler booking-detail action area in
`lib/features/trip_history/presentation/widgets/trip_record_detail_sheet.dart`.
It must first obtain the authoritative context and be absent/disabled unless
`canSubmit` is true. Add **My Complaints** to the existing Traveler account/trip
history navigation surface, and do not introduce an Admin or Operator
destination.

Build `MyPostTripComplaintsPage` with loading, empty, error/retry and list
states. Selecting a list item navigates to the booking-scoped complaint route,
which always performs a fresh context read.

**Verify:** route/deep-link tests reject bad IDs and unauthorized role access;
widget tests cover list loading, empty, retry, content navigation and no local
deadline/refund calculation.

## Task 6 — Integration review and final validation

Review every module against the spec and Backend contract. Run the feature tests
against the local API with a Traveler booking that is eligible under the
server-issued deadline. Manually confirm:

1. submit new complaint with/without evidence;
2. fresh success and idempotent replay do not duplicate records;
3. existing evidence downloads through the authenticated API;
4. one permitted evidence amendment updates the read-only view and cannot be
   repeated;
5. My Complaints lists only current Traveler records;
6. expired/ineligible and service-unavailable outcomes retain safe UI state.

Before handing off, run:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run `flutter build apk --debug` if the local Android toolchain is available and
the evidence-download integration requires a new platform plugin/configuration.
Report any tooling or backend-contract limitation explicitly.
