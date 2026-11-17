# UC-69 — Respond to Post-Trip Complaint (Mobile)

## Status

Draft for approval. This document plans the Tour Operator mobile client after
the UC-69 Backend contract is available. It does not authorize implementation
of the related Traveler flows (UC-68 and UC-75), refund confirmation (UC-42),
or refund payment (UC-67).

## Scope

An authenticated Tour Operator can use the Flutter app to list post-trip
complaints for tours it owns, view complaint details and time-limited evidence,
then accept a full refund, propose a partial refund or reject the complaint.

The app records a commercial decision only. It never calculates a refund,
creates a payout, calls a payment gateway, confirms a return transfer, or
exposes Staff/Administrator navigation. Accepted outcomes remain subject to
UC-42 and UC-67.

## SRS baseline

| SRS requirement | Mobile behaviour |
| --- | --- |
| UC-69 | Show an owning Tour Operator the complaint and allow one response within seven calendar days. |
| BR-150 / MSG162 | A partial proposal is positive and must not exceed the server-supplied refundable amount. |
| BR-151 / MSG165 | Show the canonical seven-day response deadline; do not offer an action when the server says it has expired or is no longer actionable. |
| BR-152 / MSG163 | Reject requires a non-empty trimmed reason. |
| MSG164 | On success, show confirmation from the canonical response and refresh the complaint state. |
| BR-143 | An accepted result proceeds through the existing UC-42 then UC-67 workflow; UC-69 Mobile has no direct payment action. |

## Required Backend contract

Mobile consumes the approved, authenticated Tour Operator contract under
`/api/v1/operator/post-trip-complaints`:

| Method | Route | Mobile use |
| --- | --- | --- |
| `GET` | `/` | Paginated list, optional `status`, `page` and `pageSize`. |
| `GET` | `/{complaintId}` | Detail, signed evidence links, deadlines and available actions. |
| `POST` | `/{complaintId}/response` | Record one UC-69 response with `Idempotency-Key`. |

The response payload contains only the allowed values:

```json
{
  "action": "AcceptFullRefund | ProposePartialRefund | Reject",
  "proposedRefundAmount": 0,
  "rejectionReason": ""
}
```

The detail/result supplies server-owned `refundableAmount`, `responseDeadline`,
optional `travelerResponseDeadline`, `status`, recorded `response`,
`evidence[]`, `availableActions`, booking/tour summary and safe error envelope.
Mobile must not manufacture deadlines, refund amounts, ownership identifiers,
payment fields, or a refund status from local state.

## Architecture and navigation

- Add a focused `operator_complaints` feature using the repository, DTO/mapper,
  domain entity/use-case and Cubit conventions already used by
  `operator_bookings`.
- Register dependencies through the existing `get_it` service locator and use
  the centralized Dio client and error mapper; no Page or Cubit calls Dio.
- Add named GoRouter routes beneath `/operator/`, for example the list route
  `/operator/post-trip-complaints` and detail route
  `/operator/post-trip-complaints/:complaintId`. Both follow the existing
  operator role guard and deep-link checks.
- Register no `/admin/*` route, Admin entity, or Staff reconciliation UI in
  Flutter.
- Retain a complaint only in feature state. Evidence URLs are time-limited and
  must not be persisted in shared preferences, logs, or screenshots produced by
  the app.

## Screen behaviour

### Complaint list

The list shows the server-provided complaint reference, booking/tour summary,
status, response deadline and a clear empty state. It supports server-backed
status filtering, pagination/load-more, refresh, loading and retry. A list item
opens the detail route; it does not duplicate response controls.

### Complaint detail and evidence

The detail renders the category, submitted reason, booking/tour summary,
`refundableAmount`, current status, response deadline, optional Traveler
deadline, prior response and evidence metadata supplied by Backend. Opening an
evidence link uses the established `url_launcher` external-browser pattern.
Only a non-empty HTTPS URI supplied by the current detail response is launchable;
a failed launch produces a safe localized message and no raw URI/error text.

### Response form

The detail renders controls strictly from `availableActions`.

- **Accept full refund:** confirmation dialog only; it sends no amount.
- **Propose partial refund:** accepts a positive VND amount, validates it
  locally against the current server `refundableAmount` for immediate feedback,
  and relies on Backend as the authority.
- **Reject:** requires a trimmed reason before enabling submission.

Every submit generates one idempotency key for that attempt, disables duplicate
submission while pending, and refreshes the canonical detail/list after success.
The same response is safe to retry only with its original key and payload;
creating a new user action requires a new key. A stale detail, deadline race,
conflict, permission failure or validation error is shown through mapped,
localized UI state, then refreshes canonical data where appropriate.

## States and error handling

List and detail Cubits provide loading, content, empty, submitting, success,
permission-denied and recoverable-error states. The UI must not infer that a
response has succeeded until Backend returns success. It must map MSG162,
MSG163, MSG165 and the standard unauthorized/forbidden/not-found/network
failures to safe localized messages without exposing HTTP status, stack traces,
IDs belonging to another operator, or raw exception text.

## Acceptance criteria

1. A Tour Operator sees only the complaint list/detail routes allowed by the
   normal `/operator/*` role guard; a Traveler cannot reach them through a
   direct deep link.
2. The list has loading, empty, paginated, retry and safe error states.
3. Detail displays server-provided reason, evidence, status, refundable amount
   and deadlines without recomputation or payment data.
4. Each action is available only when returned in `availableActions`; full,
   partial and reject requests match the approved request contract.
5. Full acceptance never sends a client amount; a partial proposal cannot be
   submitted locally at zero/negative or above the latest displayed cap; reject
   cannot be submitted blank.
6. Duplicate taps do not create duplicate requests, and success refreshes the
   canonical complaint state.
7. Evidence opens only a current safe HTTPS link via the approved launcher and
   handles failure without revealing technical details.
8. No Administrator/Staff route, direct refund workflow, payment gateway call,
   server-owned calculation or sensitive evidence persistence is introduced.

## Dependencies and out of scope

Implementation is blocked until Backend exposes the listed authenticated
endpoints, stable DTO/error codes, signed evidence-link representation and
`availableActions`. It is also dependent on the existing mobile authenticated
Tour Operator session/role guard.

Out of scope: UC-68 complaint creation, UC-75 Traveler decision, UC-42 refund
confirmation/return transfer, UC-67 payment execution, Staff dispute handling,
offline response queuing, and evidence upload/download persistence.
