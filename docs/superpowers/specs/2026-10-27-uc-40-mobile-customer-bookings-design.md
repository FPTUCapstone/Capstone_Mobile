# UC-40 View Customer Bookings — Mobile Design Specification

## Status

Approved by the developer on 2026-10-27, with decisions M1–M6 confirmed as recommended (see **Decisions**).
Everything else follows the approved BE contract.

Authority: Report 3 §1 and §2.1 (Tour Operator functions "are available on both platforms"),
`Capstone_FE/docs/WEB_SCOPE_MATRIX.md` (UC-40 = `SHARED_WEB_MOBILE`), mobile screens **#84 Customer Bookings List**
and **#85 Booking Details & Passenger Manifest** (SRS screen list), and the approved BE contract
`Capstone_BE/docs/UC-40-api-contract.md` (BE PR #132, not merged yet). The Web counterpart is FE PR #130.
Report 3 §3.8.4.1 documents only the Next.js screen, so the mobile layout is proposed here, not copied from the SRS.

## Current state

`lib/features/tour_operator/presentation/widgets/operator_bookings_view.dart` (tab "Bookings" of
`OperatorShellPage`) is **presentation-only demo**: hard-coded bookings (Vietnamese text, phone numbers, pickup
locations, free-text totals) and, outside demo mode, an empty state saying "PENDING_BE_INTEGRATION". The
`tour_operator` feature has no domain or data layer. The same widget also carries demo placeholders for
UC-43 (a "Check-in QR" button with the QR scanner dialog) and UC-42 (a "refund" action). The repo already has the
reference pattern to follow: `operator_tours` (remote data source → repository → use cases → Cubit, strict
parsers, `DioClient`, `ErrorMapper`) and `trip_history` (demo repository chosen by `isDemoMode`, detail sheet).

## Scope

Included (read-only):
- **#84 list:** live list of the signed-in operator's customer bookings with status, search, tour and departure
  filters, summary, and paging.
- **#85 detail and passenger manifest:** live booking detail with the participants.
- Domain, data and presentation layers following `operator_tours`; strict JSON parsers; Cubits; DI; routes;
  English resource strings; unit and widget tests; `docs/mobile-api-contract.md` entry.
- Demo mode kept (debug builds only) through a demo repository.

Excluded (unchanged or untouched):
- **UC-41 cancel and UC-42 refund** actions (screens #86, #87) and **UC-43 QR check-in** (#88). This task does
  not call those endpoints.
- Any BE change; Administrator features (never in Flutter); web.

## Contract (mobile calls the BE directly through `DioClient`, no BFF)

Auth: the operator bearer token already handled by `AuthInterceptor`. The BE enforces role, approval and
ownership (BR-105); the app never decides ownership.

### `GET /api/v1/operator/bookings`
Query (all optional): `tourId`, `status` (`PendingPayment`, `Confirmed`, `Cancelled`, `Completed`, `Expired`),
`departureFrom`, `departureTo` (`YYYY-MM-DD`, Vietnam-time days, inclusive), `keyword` (≤ 200 characters: booking
code, booker name or booker e-mail), `pageNumber` (default 1), `pageSize` (default 20, max 100).
Response: `pageNumber`, `pageSize`, `totalCount`, `totalPages`, `summary` (`totalBookings`, `totalParticipants`,
`totalConfirmedAmount`) and `items[]` (`bookingId`, `bookingCode`, `tour{tourId,title}`,
`schedule{scheduleId,startAtUtc,endAtUtc}`, `booker{userId,fullName,email}`, `quantity`, `totalAmount`,
`discountAmount`, `status`, `paymentStatus`, `checkInStatus`, `checkedInAtUtc`, `bookedAtUtc`). Ids are JSON strings.

### `GET /api/v1/operator/bookings/{bookingId}`
Adds `cancelledAtUtc`, `cancelReason`, `schedule.meetingPoint`, `booker.phoneNumber`, `participants[]`
(`fullName`, `participantType` = `Adult`/`Child`/`Infant`; never ID documents, phone or e-mail), `ticket`
(or null), `payment` (or null: `gateway`, `gatewayTransactionRef`, `status`, `amount`, `succeededAtUtc`),
`paidAmount`, `subtotalAmount`, `coupon` (or null), `canCancel`, `cancelBlockedReason`.

### Tour filter options
`GET /api/v1/operator/revenue/tours` → `[{ id, code, title, isActive }]` (every owned tour, including historical
ones). No new BE endpoint.

### Errors
| Condition | Mobile message |
| --- | --- |
| 401/403 (`operator_tour.access_required`, `operator_booking.forbidden`), detail 404 (`operator_booking.not_found`) | access denied (MSG126 text) |
| 400 `operator_booking.invalid_date_range` or inverted range picked in the app | MSG31 text "End date must be on or after the start date." (blocked before the call) |
| 200 with no items | empty state (MSG128 text) |
| network error, 5xx, 400 `operator_booking.invalid_filter`, body that does not match the contract | generic failure with [Retry] (MSG127 text); a malformed body is `ServerFailure('operator_booking.invalid_response')`, never a default-filled record |

## Behaviour

- **List screen** (the existing "Bookings" tab): summary strip from the BE `summary` (never recomputed on the
  device; participants and amount count Confirmed + Completed only), status chips, search field, filter button for
  tour and departure range, card per booking (code, tour, departure `dd/MM/yyyy` in Vietnam time, booker name,
  participants, total in VND, status badge, check-in badge), pull-to-refresh, "Load more" paging (20 per page,
  guarded against duplicate and stale loads), loading / empty / error + Retry states.
- **Detail screen:** opens at once with the card basics and a loading placeholder, then shows tour and meeting
  point, booker contact (tap-to-call is not added: YAGNI), the **passenger manifest** (name + type per participant),
  ticket and check-in time, payment (gateway, reference, amount; read-only), subtotal / discount / total, coupon,
  cancellation info. `ticket` / `payment` / `coupon` null hides that block. A response for a booking the user already
  left is ignored.
- **Actions:** none in this task. `canCancel` / `cancelBlockedReason` are parsed and kept in the entity for the
  UC-41 task but no cancel or refund control is shown.
- **Check-in:** displayed from `checkInStatus`; it is always `NotCheckedIn` until UC-43 exists.
- All strings come from a resource file (English, CR-09), like `trip_history_en.dart`; formatting uses the existing
  `TripFormatters` (Vietnam date, VND).

## Decisions (approved 2026-10-27; the alternatives were not chosen)

- **M1 — which filters on mobile.** The SRS list screen filters by tour, departure range, status and search.
  **Decided:** all four. Search (`keyword`) and the status chips (including `Expired`) sit on the list screen (#84);
  the tour (`tourId`) and the departure range (`departureFrom` / `departureTo`) sit in a filter bottom sheet, and an
  inverted range is rejected with the MSG31 text before any call. Mobile has parity with the approved web behaviour. Alternative: status chips + search only now.
- **M2 — detail as a page or a sheet.** The manifest can be long. **Decided:** a full page route
  `/operator/bookings/:bookingId` (SRS screen #85) pushed from the list; it calls the detail endpoint when it opens. Alternative: a modal bottom sheet like
  `trip_record_detail_sheet`.
- **M3 — existing demo placeholders in the same widget.** The current demo view has a "Check-in QR" button (UC-43),
  a refund action (UC-42) and a pickup-location field the BE does not have. **Decided:** remove them completely from this
  view (no "Check-in QR" button, no fake refund action, no pickup field); the UC-42/UC-43 tasks add real ones. The
  screens show only BE fields: `schedule.meetingPoint`, `participants` (`fullName` + `participantType`), `ticket`,
  `payment`, `coupon`, `checkedInAtUtc`. Alternative: keep them in demo mode only, untouched.
- **M4 — demo mode.** **Decided:** demo only when the demo/debug flag is explicitly on (debug builds, `isDemoMode`), through a
  `DemoOperatorBookingsRepository` shaped like the contract, selected in DI exactly like `trip_history`; it is never a
  fallback for a failed live call and release builds never serve it.
- **M5 — tour filter source.** **Decided:** `GET /api/v1/operator/revenue/tours` through `DioClient` (all owned tours). If it fails,
  the tour filter falls back to a disabled "All tours" and the booking list keeps working. Alternative: the paged `GET /api/v1/operator/tours`
  (needs several pages).
- **M6 — UI language.** The current widget is Vietnamese; `operator_tours` and `trip_history` are English and
  Report 3 CR-09 requires English UI. **Decided:** English for all new strings (CR-09, SRS message catalogue texts).

## Acceptance criteria

1. Outside demo mode the list and detail call only `GET /api/v1/operator/bookings[/{id}]` (and the tour options
   endpoint); no fixture and no "PENDING_BE_INTEGRATION" text.
2. Query mapping is exact; an inverted departure range is blocked in the app with the MSG31 text and sends no call.
3. Every row of the error table above shows the stated message; loading, empty, error and Retry exist for the list
   and the detail; a malformed body becomes the safe failure.
4. The summary and paging come from the BE as returned; "Load more" never duplicates rows or applies a stale page
   after the filter changed.
5. The detail shows participants (name + type) and never any ID-document, phone or e-mail of a participant.
6. No cancel, refund or check-in control exists in this task.
7. Demo mode still works in debug builds and is unreachable in release builds.
8. `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` pass.

## Test plan (TDD)

Parser tests with the BE contract examples and malformed bodies; repository test (Dio adapter fake: query
mapping, error mapping, strict parsing); use-case and Cubit tests (loading → ready, filters reset paging, load more
without duplicates, stale response ignored, failure + retry, date-range guard); widget tests for the list (states,
chips, search, filter sheet, summary) and the detail (states, manifest, null blocks, no action controls);
demo repository test; router test for the new route; shell test updated. `docs/mobile-api-contract.md` gets an
"Operator customer bookings (UC-40)" section.

## Not verified by this task

Live end-to-end against a running BE (BE UC-40 not merged or deployed): verification is against the contract with
fakes. A device or emulator run is made only if the environment supports it and is reported either way.
