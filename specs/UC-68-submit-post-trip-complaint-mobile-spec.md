# UC-68 — Submit Post-Trip Complaint (Mobile)

**Platform:** Flutter Mobile (Traveler)

**Status:** Draft for approval

**Sources:** approved UC-68 product behaviour, the approved UC-68 Web
behaviour, and the current authenticated Backend contract. The checked-in SRS
has a confirmed UC-numbering typo: its current UC-68 number refers to Audit
Logs, while this specification uses the approved post-trip-complaint business
scope.

## 1. Scope and boundaries

An authenticated Traveler can submit one complaint for one eligible booking
after its tour has ended. The mobile app obtains the server-authoritative
context, presents the complaint form, shows an existing complaint read-only,
lets the Traveler download evidence they are authorized to view, and permits
one evidence-only amendment when the Backend says it is allowed.

The flow starts from the Traveler booking detail and also has a **My
Complaints** list under the Traveler account area. A successfully submitted
complaint starts in `AwaitingOperatorResponse` and is forwarded to the Tour
Operator. Operator response is UC-69; Traveler action on a partial proposal is
UC-75. Neither is implemented by this feature.

Out of scope: complaint response, refund calculation/initiation/payment,
settlement, Staff/Admin workflows, evidence deletion/replacement, offline
complaint submission, and persistence of private evidence files or URLs.

## 2. Server-authoritative eligibility and navigation

### 2.1 Entry points

- The authenticated Traveler booking detail displays **Submit complaint** only
  when the UC-68 context says `canSubmit` is true.
- The action opens the named, role-guarded route
  `/traveler/bookings/:bookingId/complaint`; `bookingId` is the server numeric
  booking identifier, never a booking code or ticket number.
- A **My Complaints** account entry opens `/traveler/complaints`. It is a
  read-only list of the signed-in Traveler's own complaints.
- Direct deep links must use the normal Traveler session/role guard. A cancel
  action navigates to the known booking-detail or account route; it must not
  rely on navigator history or create/mutate a complaint.

### 2.2 Context API

Before showing an action state, mobile reads:

```http
GET /api/v1/traveler/bookings/{bookingId}/post-trip-complaint
```

The response is the sole authority for `bookingId`, booking/tour summary,
`endAtUtc`, `submissionDeadlineUtc`, `canSubmit`,
`canAmendEvidence`, nullable `ineligibilityReason`, and nullable `complaint`.
An existing complaint contains only safe evidence metadata:
`evidenceId`, `fileName`, `contentType`, and `sizeBytes`. It must never expose
a storage key or persist a private delivery URL.

The Backend makes the final decision on every read and write. Initial submission
is allowed only for the owning Traveler when the booking is `Confirmed` or
`Completed` and the server-issued `submissionDeadlineUtc` has not passed. The
current Backend derives that deadline as `endAtUtc.AddDays(3)`; Mobile displays
the returned timestamp and must never reinterpret it as a local calendar-day
cutoff. The app must not calculate eligibility, a deadline, booking ownership,
or a refund amount. A stale screen, expired deadline, changed booking state, or
a second complaint is refreshed from the server response.

When `canSubmit` is false because the window has closed, show MSG157 and no
form. When `complaint` exists, show MSG158 and the read-only complaint detail
instead of a second form.

## 3. Submit complaint form

### 3.1 Fields and evidence limits

The form displays server-issued booking/tour/deadline context and contains:

| Field | Required | Submitted value |
| --- | --- | --- |
| Reason category | Yes | `reasonCategory` |
| Reason detail | Yes | trimmed `reasonDetail`, maximum 2,000 characters |
| Evidence files | No | repeated `evidence` multipart parts |

The fixed category mapping is:

| Label | Enum |
| --- | --- |
| Itinerary not as advertised | `ItineraryNotAsAdvertised` |
| Service quality | `ServiceQuality` |
| Guide or staff conduct | `GuideOrStaffConduct` |
| Safety issue | `SafetyIssue` |
| Schedule change/delay | `ScheduleChangeOrDelay` |
| Other | `Other` |

Evidence accepts only JPG/JPEG, PNG, WebP, and PDF. A logical complaint may
contain at most five files, each at most 10 MB, with at most 30 MB total. The
mobile picker validates name/type and size early for usable feedback, shows a
safe filename/size and remove control, and keeps valid chosen files when a new
file is rejected. Backend content-signature and aggregate validation remain
authoritative.

The form never accepts status, response deadline, a refund amount, payment
values, booking owner, Tour Operator data, a storage key, or a delivery URL.

### 3.2 Submit request and idempotency

Mobile sends one authenticated multipart request:

```http
POST /api/v1/traveler/bookings/{bookingId}/post-trip-complaints
Idempotency-Key: <UUID>
Content-Type: multipart/form-data
```

It sends exact part names `reasonCategory`, `reasonDetail`, and repeated
`evidence`. One UUID belongs to one unchanged logical submission and may be
reused only for a transport retry of that exact payload. Editing any form field
or evidence requires a fresh key. The submit control is disabled while pending.

Both `201 Created` and `200 OK` with `isReplay: true` are success. On success,
the app refreshes context and renders the canonical existing complaint; it does
not manufacture another local record.

## 4. Existing complaint, evidence download, and one amendment

### 4.1 Read-only view and secure download

An existing complaint view shows the server-provided category, detail, status,
submitted time, response deadline, and evidence metadata. Each evidence item
has a labeled **Download evidence** action that calls:

```http
GET /api/v1/traveler/bookings/{bookingId}/post-trip-complaint/evidence/{evidenceId}/download
```

The request remains authenticated. The app may hand a response stream or
short-lived backend-issued redirect to the established platform download/open
flow, but must not log, cache in shared preferences, or retain a signed URL.
An unavailable/missing storage object is shown as the safe MSG127-style retry
message, never as raw HTTP details or a blank technical page.

### 4.2 One evidence-only amendment

The app shows **Add evidence** only when the latest context reports
`canAmendEvidence: true`. This means all of the following are still true:

1. a complaint exists;
2. its status is `AwaitingOperatorResponse`;
3. the original UC-68 submission deadline has not closed;
4. no evidence amendment has previously succeeded.

The amendment does not change the reason category, reason detail, submitted
time, deadline, status, or any financial value. It preserves the original
aggregate limits by counting existing evidence plus newly selected files.

```http
POST /api/v1/traveler/bookings/{bookingId}/post-trip-complaint/evidence
Idempotency-Key: <UUID>
Content-Type: multipart/form-data
```

The request contains only repeated `evidence` parts. The app generates one
idempotency key for the unchanged amendment attempt, prevents duplicate taps,
then refreshes the context after success. It removes the amendment action after
the canonical response reports it used. A conflict, expired window, changed
status, or duplicate amendment is a safe error state followed by a context
refresh; it is never represented as a successful local addition.

## 5. My Complaints

The account screen requests the authenticated list:

```http
GET /api/v1/traveler/post-trip-complaints
```

It displays only the signed-in Traveler's complaint reference, booking code,
tour summary, category, status, submitted time, response deadline, and evidence
count. It deliberately has loading, empty, retry, and localized safe-error
states. Selecting an item opens the same booking-scoped complaint detail and
causes a fresh context read; the list does not retain evidence URLs or make a
status/deadline/refund decision locally.

## 6. Mobile architecture and interaction requirements

- Implement under a focused traveler complaint feature using the existing
  Clean Architecture direction: Page -> Cubit/Bloc -> use case -> repository
  contract <- repository implementation -> remote data source.
- Use `flutter_bloc`, the centralized Dio client/error mapper, `get_it`, and
  centralized GoRouter definitions. Pages and Cubits never issue raw Dio calls.
- Use Material 3 theme tokens, safe areas, scroll/keyboard-safe form layout,
  44px touch targets, semantic labels, visible errors, progress state, and
  responsive text for small screens and text scaling.
- Selected evidence names are plain text only. The app must not render remote
  image/PDF previews in this feature.
- Preserve entered form text and valid selected evidence after client validation
  or recoverable server failures. Clear local form state only after success.

## 7. Error and message handling

| Condition | Mobile outcome |
| --- | --- |
| `complaint.window_closed` | MSG157; no submit/amend form. |
| Existing complaint or replay | MSG158 plus canonical read-only view; no duplicate form. |
| `complaint.evidence_limit` | MSG159; retain valid selections where possible. |
| `complaint.evidence_type` | MSG160; reject only the invalid selection. |
| Fresh complaint success | MSG161 then refreshed server context. |
| `complaint.storage_unavailable` or network failure | MSG127; no success state; allow retry. |
| Idempotency payload mismatch | Explain the request changed and create a new key only after explicit retry of the current payload. |
| Unauthorized, forbidden, not found, validation or unknown error | Map through the centralized safe localized error model; reveal neither raw HTTP details nor another Traveler's data. |

## 8. Acceptance criteria

1. Only the owning authenticated Traveler may reach UC-68 routes; the app shows
   a submit form only when the server says `canSubmit`.
2. The form requires an approved category and non-blank detail of at most 2,000
   characters, and enforces client usability limits of five eligible files, 10
   MB each and 30 MB in total.
3. Submission uses the exact authenticated multipart contract and one UUID
   idempotency key per unchanged attempt; it sends no calculated financial or
   private-storage value.
4. Success/replay refreshes and renders the canonical complaint without creating
   a duplicate local record.
5. Existing evidence is visible as metadata and downloadable only through the
   authenticated server route, with no persistent signed URL or private bytes.
6. Add evidence appears exactly once and only when `canAmendEvidence` is true;
   it submits evidence-only multipart data and honors the existing aggregate
   limits.
7. My Complaints has loading, empty, error/retry and list-to-detail behavior,
   showing only data returned for the signed-in Traveler.
8. Automated tests cover mapper/repository contracts, Cubit transitions,
   submission/amendment file boundaries, idempotency/retry behavior, context
   states, safe download failure, list states, route guards, and key widget
   interactions.

## 9. Dependencies and deferrals

Implementation depends on the current UC-68 Backend endpoints and stable DTOs
described above. The mobile API layer must confirm the exact safe error envelope
and authenticated binary/redirect handling before coding a platform downloader.

Deferred: UC-69 operator response, UC-75 traveler response, all refund/payment
flows, Staff/Admin work, editing/removing submitted complaint evidence, offline
queueing, and any Cloudinary/storage credential in the mobile application.
