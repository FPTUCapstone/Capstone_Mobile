# UC-75 Respond to Partial Refund Proposal — Mobile Specification

Source: SRS §3.8.6.3, BR-153, screen #97 "Partial Refund Proposal" (web and mobile).
Backend: `Capstone_BE` branch `feature/phuctv-uc75-partial-refund-response`
(spec `specs/UC-75-respond-partial-refund-proposal-spec.md` there).

## Scope

In scope:

- Screen #97 for the Traveler: booking code, Proposed Amount, Response Deadline,
  status, buttons [Accept] and [Decline], each confirmed in a dialog (Normal Flow step 3).
- Route `/traveler/complaints/:complaintId/partial-refund-proposal` (Traveler only, through the
  existing `/traveler/*` guard).

Out of scope (other tickets): the complaint detail screen and the complaint form (UC-68, TM-222),
the Tour Operator response (UC-69), refund progress of the accepted amount (UC-42 / UC-67),
counter-offers, evidence files. The in-app inbox keeps its rule that related entity IDs are not
navigation links, so the entry from the complaint notification or the complaint detail is added
with TM-222.

## API

- `GET /api/v1/traveler/complaints/{complaintId}/partial-refund-proposal` →
  `{ complaintId, bookingId, bookingCode, proposedAmount, responseDeadlineUtc, status, canRespond }`.
- `POST /api/v1/traveler/complaints/{complaintId}/partial-refund-proposal/response`
  with `{ "decision": "Accept" | "Decline" }` →
  `{ complaintId, status, approvedAmount, respondedAtUtc }`.
- `status` is one of `AwaitingOperatorResponse`, `AwaitingTravelerResponse`, `Approved`,
  `Rejected`, `Expired`, `Declined`; an unknown value is treated as an unreadable response.

## Messages

| Case | Display |
|---|---|
| Response recorded | SnackBar MSG164 "Your response has been recorded." (G2) |
| 409 `complaint.partial_refund.response_closed`, or the proposal opens with `canRespond = false` | In line MSG165, buttons hidden, proposal reloaded, no change (G1, G5) |
| 401 / 403 | In line MSG126 |
| 404 | "This partial refund proposal could not be found." |
| Network, 5xx, unreadable body | MSG127, status unchanged, retry allowed |

Dates are shown as `dd/MM/yyyy HH:mm` in Asia/Ho_Chi_Minh (CR-07); amounts as `500,000 VND`.
