# Operator dashboard metrics

Approved by the user on 2026-11-19. Scope: four metrics only; leave the header,
today's departures and recent bookings unchanged. No APK build/install or push.

- Active tours: distinct published packages with a future scheduled departure
  still accepting bookings (deadline open and remaining capacity).
- Monthly bookings: created within the current Vietnam calendar month,
  successfully paid and not pending, expired or cancelled. Count bookings, not guests.
- Monthly net: exact existing operator revenue report Summary.NetAmount for that
  month; do not reproduce financial calculations on Mobile.
  Authority: Backend `specs/UC-44-view-revenue-report-be-spec.md` and
  `OperatorRevenueAggregator`, plus FE `specs/UC-44-settled-payout-revenue-fe-spec.md`.
  Display as **Thực nhận trong tháng** (Settled Payout): settled Advance/Final/
  Cancellation payouts less operator returns confirmed received by Staff.
  A newly paid order contributes zero until settlement. The reporting cohort uses
  successful-payment timestamps in the selected Vietnam month, not departure,
  booking creation or payout dates. Do not label it as projected net sales or
  compute it from gross less commission/refunds on Mobile.
- Active coupons: enabled, within validity and below any usage quota now.
- Only the authenticated approved active operator's data. Backend clock and UTC+7
  define the month; device clock must not define this reporting period.

GET /api/v1/operator/dashboard/metrics returns activeTourCount,
monthlyBookingCount, monthlyNetAmount, activeCouponCount, asOfUtc, monthStart,
monthEndExclusive. Counts are integers; net amount may be negative.

Mobile uses the central authenticated Dio client, a domain repository and Cubit.
Render loading, genuine zero values, safe error and retry; never show sample or
zero values on a failed live request. Reload on home activation/foreground and
manual refresh. Explicit demo mode remains separate and makes no API request.

Acceptance: contract mapping, failure/retry, loading/zero values, narrow layouts,
tab navigation and existing shell behavior have focused automated coverage.
