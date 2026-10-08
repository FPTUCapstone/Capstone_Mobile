# UC-38 Mobile Screen Specification: Create Coupon

## Scope

An approved Tour Operator creates a coupon for selected approved tours using
the Flutter app. The feature does not apply coupons to a booking, calculate a
booking discount, list/edit/deactivate coupons, or handle redemption.

## Route and role boundary

- Route: `/operator/coupons/create` registered through the centralized
  `GoRouter` configuration.
- The page is only reachable from the Tour Operator area. Backend `403`
  remains the authorization source of truth.

## UX principles

- The normal operator creates a percentage promotion in one pass; optional
  quotas never block that path.
- Every amount is presented as VND with grouping separators and a short human
  explanation, not internal terminology.
- The screen avoids losing work: a failed request leaves valid values and tour
  selection intact.

## Form flow

The form uses Material 3 controls in a vertically scrollable `SafeArea`:

1. Code (canonicalized to uppercase), with an optional editable “Generate”
   action for a readable random code.
2. Discount type: percentage or flat VND.
3. Discount value and, for percentage only, maximum discount amount.
4. Minimum order, optional total limit and optional per-traveler limit.
5. Start/end date and time.
6. Required multi-select of eligible, approved tours; the selected-tour count
   remains visible in the form.
7. Submit.

The form is grouped into **Coupon**, **Discount**, **Availability**, and
**Tours** cards. Usage limits are hidden behind an “Add usage limits” expansion.
A read-only confirmation summary above the submit button shows the discount
example, selected-tour count and local validity window.

Client-side validation mirrors only stable format/range rules. The Cubit calls a
domain use case, which calls a repository contract; the data source owns Dio and
the API JSON contract. Dates are converted to UTC before sending.

## Backend contract

`GET /api/v1/operator/coupons/eligible-tours` returns only the caller's
approved tours for the selector. `POST /api/v1/operator/coupons` creates the
coupon.

The request fields and error semantics match `UC-38-web-spec.md`. The response
returns `couponId` and canonical `code`. The error mapper produces safe
application failures for validation, authentication, permission, duplicate-code
conflict, missing/ineligible tour, connectivity, timeout and unknown failures.

## UX states

- Loading, ready, submitting, success, recoverable error and no-eligible-tour
  states. A progress indicator communicates loading rather than a blank selector.
- Prevent double submission while a request is in flight.
- Validate on submit, avoiding disruptive keystroke-by-keystroke error text.
  Preserve valid form input after a
  server-side error; focus/scroll to the actionable message where feasible.
- Date/time controls reject an end before the start; device-local selections
  are converted to UTC before sending. The bottom submit area remains reachable above system
  navigation and the keyboard.
- Success shows the canonical code plus “Done” and “Create another”; the latter
  keeps tour selection only if the operator elects to reuse it.
- Ensure controls stay usable with keyboard, small screens, long Vietnamese
  labels and enlarged text scale.

## Acceptance criteria

1. Eligible Tour Operators can submit valid percentage and flat coupons.
2. Percentage-specific cap is required only for percentage discount type.
3. A code collision is shown against the code field without clearing the form.
4. The page does not make raw Dio calls, store secrets, or bypass role routing.
5. Cubit, use case/repository mapping and widget interactions have focused
   automated coverage.
