# UC-27 Mobile Implementation Plan — Book Tour

**Platform:** Flutter
**Status:** Phase A may begin; quote/create API has implementation evidence, but Mobile integration waits for cross-platform OpenAPI/error-map approval and UC-26 live entry

## Phase A — UI-first, development only

1. Inspect and reuse the Traveler feature, centralized `go_router`, `DioClient`, `flutter_bloc` and `get_it` conventions. Define the entry arguments as string `tourId` and `scheduleId`; map `scheduleId` to the transport field `tourScheduleId`.
2. Define pure domain models for a selected departure, participant with `participantType`, and read-only `BookingQuote` with per-type `priceBreakdown`.
3. Add a development-only fixture repository behind the existing explicit demo guard. It supplies a selected departure and a static quote only.
4. Build the booking form with participant-type selection, voucher input, accessible confirmation and server-quote display.
5. Clearly mark Demo. Disable live confirmation or show that live booking is unavailable; do not write bookings, storage, payment links or local totals.

**Tests:** fixture guard, no mutation in demo, participant-type UI, quote rendering, loading/error/focus states.

## Phase B — contract-first API integration

1. Add DTOs, data source and repository behind the established Page → Cubit → Use Case → Repository → Dio flow.
2. Call quote when derived participant-type counts or voucher changes; cancel stale requests and render the returned breakdown without arithmetic.
3. Submit only `tourScheduleId`, participants with types and optional voucher. Generate and supply `Idempotency-Key`; retain it only for retry of the same intent. After a successful response, clear document inputs from Cubit/form state.
4. Map the approved Backend errors to existing validation/authentication/network failures. Let AuthInterceptor handle refresh.
5. Do not add DOB, age rules, arbitrary participant limits or a contact DTO without a later approved contract change.

**Tests:** JSON request/response mapping, per-type counts, no client calculation, effective-price fallback display from response, idempotent retry, capacity/deadline/voucher errors, authentication behavior.

## Phase C — created-booking handoff

1. Render booking code, PendingPayment status, amount and `paymentExpiresAt` from create response.
2. Provide an explicit **Pay now** navigation handoff to UC-28.
3. Do not implement an expiry status refresh until UC-28 or Booking Details publishes an approved authenticated booking-status endpoint. Until then, show the server expiry and do not set a final status locally.

**Tests:** no automatic payment start, navigation receives booking ID, document inputs clear after success, and no local expiry transition.

## Definition of done

- Mobile transport DTOs match approved BE OpenAPI and Web contract.
- No client price logic, local reservation or production fixture fallback exists.
- Focused domain, Cubit, DTO/repository and widget tests pass.
- `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` and applicable Android build checks pass.
