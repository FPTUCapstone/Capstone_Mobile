# UC-28 — Make Electronic Payment (Mobile)

## Status

Draft for approval. Mobile adopts the same UC-28 Backend contract as Web only
after UC-27 Mobile is merged into `develop`; UC-28 Mobile then rebases on that
merged baseline.

## Scope

A Traveler opens the checkout URL returned by Backend, returns to the app via
an App Link in PayOS environments, and loads canonical payment status. Local
Mock uses a checkout screen with success/cancel/expire actions.

The scope excludes gateway credentials, raw webhook payloads, payment amount
calculation and administrator payment tools.

## Decisions

- Mobile never treats a deep-link query parameter as proof of payment.
- It uses `GET /api/v1/traveler/bookings/{bookingId}/payment` after returning
  to render canonical state.
- Mock only is available when Backend reports `gateway: Mock`; real PayOS opens
  the returned URL in the external browser.
- Cancellation keeps the booking `PendingPayment` until its normal expiry and
  the Traveler may request payment again.

## Required contract

Mobile consumes the same create/reuse and status endpoints as Web. The mock
completion route is used only for a local mock checkout. The app receives
`bookingId`, `paymentId`, `checkoutUrl`, `amount`, `currency`, `status`,
`paymentLinkExpiresAtUtc` and `bookingPaymentExpiresAtUtc`; it does not
generate references or amounts.

## App links

Production/staging uses a verified HTTPS Android App Link such as
`https://<domain>/payment/return?bookingId={id}`. Until a verified domain is
available, local Mock returns directly inside the app and external PayOS
deep-link testing is deferred to staging.

## Acceptance criteria

- Opening PayOS checkout uses an external browser.
- Returning from payment always refreshes Backend status.
- Mock success/cancel/expire has the same visible status results as Web.
- Network, expired and unauthorized states are handled without showing raw
  errors or declaring payment successful.
- `PAYMENT_BOOKING_NOT_ELIGIBLE`, `PAYMENT_BOOKING_EXPIRED`,
  `PAYMENT_NOT_FOUND`, `PAYMENT_GATEWAY_UNAVAILABLE` and
  `PAYMENT_MOCK_DISABLED` map to clear localized states.
