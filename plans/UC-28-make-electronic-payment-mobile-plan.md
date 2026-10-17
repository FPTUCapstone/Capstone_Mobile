# UC-28 — Make Electronic Payment (Mobile) Plan

## Task 1 — Contract foundation

Add payment entities, datasource/repository/use case and Cubit states matching
the approved Backend DTO. Write mapping and Cubit tests first.

## Task 2 — Booking handoff

After UC-27 booking confirmation supplies a booking ID, create/reuse payment
and show loading/error/retry state. Display only server amount/currency.

## Task 3 — Checkout handling

Implement local Mock checkout actions. Implement external browser launch for
PayOS checkout URLs and an App Link receiver that refreshes canonical status.

## Task 4 — Result screen and tests

Render pending, paid, cancelled and expired states from Backend. Add tests for
return refresh, mock outcomes, failure and retry.

## Task 5 — Verification

Run `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter
analyze`, `flutter test`, and Android debug build. Manually test Mock against
local BE after UC-27 entry integration is available.
