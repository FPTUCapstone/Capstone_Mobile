# UC-27 Mobile Specification — Book Tour

**Platform:** Flutter
**Status:** Draft — UI-first delivery allowed; quote/create API exists, while the live entry remains blocked by UC-26 tour detail and cross-platform OpenAPI/error-map approval
**Sources:** SRS §3.5.4 and UC-27 Backend contract

## 1. Scope

An authenticated active Traveler chooses a departure, enters participants, requests a server quote and creates a `PendingPayment` booking. UC-27 ends at the created-booking summary. UC-28 begins only when the Traveler chooses **Pay now**.

Mobile never calculates price, reserves a seat locally, initializes payment, issues a ticket or persists booking/participant data in local storage.

## 2. Entry and identifiers

UC-26 provides the selected `tourId` and navigation argument `scheduleId`. `scheduleId` identifies the dated departure and is sent to Backend as JSON field `tourScheduleId`. The Mobile transport DTO uses string IDs to match the shared contract and preserve SQL Server `BIGINT` values exactly.

Until the UC-26 tour-detail/departure API is available, a development-only labelled Demo fixture may render a departure and read-only quote. It must not create bookings, reserve capacity or open payment.

## 3. Participant and effective-price policy

Each participant includes:

- required `fullName` and `participantType` (`Adult`, `Child`, `Infant`);
- optional `phoneNumber`, `email`, `idDocumentType`, `idDocumentNumber`, `nationality`.

DOB, age limits and a separate contact-information model are not accepted until they are approved in SRS and Backend contract. The first participant is the lead contact for this release.

The quote request sends type counts:

```json
{
  "tourScheduleId": "123",
  "participantCounts": { "adult": 1, "child": 1, "infant": 0 },
  "voucherCode": "SUMMER2026"
}
```

The server returns `priceBreakdown` with every type’s quantity, unit price and line amount, plus subtotal, discount, total, currency and remaining slots. The effective-price policy is server-only:

1. Adult: `schedule.adultPrice ?? tour.basePrice`.
2. Child: `schedule.childPrice ?? effectiveAdultPrice`.
3. Infant: `schedule.infantPrice ?? effectiveAdultPrice`.

`null` Child/Infant price means no override, never “type forbidden”. Mobile displays server values without arithmetic.

## 4. Create booking

```http
POST /api/v1/traveler/tour-bookings
Idempotency-Key: <UUID>
```

The request contains `tourScheduleId`, the participant list with `participantType`, and optional voucher. It contains no price, total, expiry or separate participant count. The app generates one UUID per submission intent and reuses it only for retrying that same request.

On `201 Created` or idempotent `200 OK`, clear `idDocumentNumber` and other document inputs from form state, then show booking code, `PendingPayment`, amounts and `paymentExpiresAt` returned by the server. The Traveler may then choose **Pay now** to navigate to UC-28. UC-27 does not fetch booking status after expiry: that requires an approved booking-detail/status endpoint owned by UC-28 or Booking Details. Until then, it only displays the server-issued expiry and never marks the booking expired locally.

## 5. Errors and availability

Use the approved Backend failure envelope. 401 follows the existing AuthInterceptor/SessionCoordinator refresh flow; only final authentication failure signs the user out. 403 shows a safe Traveler-only message. Capacity, registration-deadline and voucher errors retain form input and let the user request a new quote.

The confirmation dialog, loading state, inline errors, retry and accessibility labels follow the existing Material 3 patterns.

## 6. Acceptance criteria

- Participant type selection produces server quote type counts.
- Price breakdown, total and expiry are displayed only from Backend responses.
- Create includes `Idempotency-Key` and never creates a duplicate after retry.
- A successful create clears document inputs from memory.
- Success stops at PendingPayment; payment is explicitly user initiated in UC-28.
- Demo is explicit, development-only and non-mutating.
