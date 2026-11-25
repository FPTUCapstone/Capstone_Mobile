# UC-15 Confirm Re-routing — Mobile spec

**Status:** Approved by the developer on 2026-11-25 (design + workflow). Written together with the plan; no further approval step was requested.
**Backend contract:** `Capstone_BE` PR #208, spec `specs/UC-15-confirm-rerouting-spec.md` (section 5), handoff `Handoff/UC-15-confirm-rerouting-be-handoff.md`.
**SRS:** 3.3.6 — BR-25/26/27/31/33, MSG41–MSG44, MSG127.

## Goal

Replace the local-only re-routing state in `ActiveTripCubit` with the real Backend flow: open a proposal from a UC-14 alert that carries `reroutingProposalId`, let the Traveler accept or keep the current route, and continue navigation on the session returned by the Backend.

## Scope

In: domain entity, repository contract + implementation, error mapping (MSG44/MSG127), cubit flow, banner/alerts-sheet entry points, proposal sheet rendering, tests, API contract doc.
Out: Backend changes, Azure seed run, MSG41 dialog (the existing alert banner is the entry point), drawing the proposed path on the map, any demo/fake proposal in production code.

## Contract used

`/api/v1/navigation-sessions/{sessionId}/rerouting-proposals/{proposalId}` (Traveler, session owner):

| Call | Success | Mobile result |
| --- | --- | --- |
| `GET` | 200 detail: `proposalId`, `incidentId`, `status` (`Proposed`/`Accepted`/`Rejected`/`Expired`), `reason{code,strategy,affectedItemId,affectedPoiName}`, `currentStops[]`, `proposedStops[]` (+`change` Kept/Added/Moved), `affectedStops[]`, `removedStops[]`, `travelTimeDiffMinutes`, `arrivalTimeDiffMinutes`, `proposedAtUtc`, `expiresAtUtc`, `decidedAtUtc?` | `RerouteProposal` |
| `PUT .../acceptance` | 200 `NavigationSessionResponse` (new version) | replaces the active session |
| `PUT .../rejection` | 204 | proposal `declined` |

Errors (ProblemDetails `errorCode`): `rerouting.not_found` (404), `rerouting.proposal_expired|proposal_closed|proposal_infeasible` (409) → MSG44; 5xx → MSG127. Accept and reject are idempotent replays.

## Exact copy (SRS message table)

- MSG42 toast: *Your itinerary has been updated. Navigation continues on the new route.*
- MSG43 toast: *Suggestion declined. Continuing on your current route.*
- MSG44 inline: *No re-routing suggestion is available at the moment.*
- MSG127: *TripMate is temporarily unable to process your request. Please check your connection and try again.*

## Behaviour

1. Review button appears on an alert only when `reroutingProposalId != null`; tapping calls `openRerouteProposal(alert)` → `GET`.
2. A proposal that is not effectively `Proposed` (Accepted/Rejected/Expired, or past `expiresAt` by the device clock) is never shown; MSG44 is displayed instead.
3. Accept: `PUT acceptance`; on success the returned session becomes the active session (new item ids, new `itineraryVersion`), route guidance is reset, MSG42 is shown, alerts are refreshed. Reached stops are already preserved by the Backend.
4. Keep Current Route: `PUT rejection`; MSG43; nothing else changes (BR-33).
5. 404/409 `rerouting.*`: close the sheet, discard the proposal, show MSG44, refresh session and alerts. Network/5xx: keep the proposal, show MSG127 with a Retry action; nothing is applied locally. Offline: existing offline message with Retry.
6. Double taps are ignored while a request is in flight (`isSubmitting`). A timer closes the proposal as expired at `expiresAt` (SRS 6.a1) without changing the itinerary.
7. The Traveler never sees a fabricated proposal: production code has no sample data, demo mode has no re-routing entry point.

## Presentation

The proposal sheet keeps its structure (reason, current vs proposed, impact, consent note). Changes: stops are structured (time + name, Added/Moved tags on proposed stops), removed stops are listed, the reason text is derived from `reason.code` + POI name, and the demo-only cost/distance rows are removed because the Backend does not supply them.

Reason copy by code: `trip_alert.severe_weather` → "Severe weather is expected at {poi}."; `trip_alert.poi_closure` → "{poi} is closed."; `trip_alert.schedule_delay` → "Your trip is running behind schedule."; `trip_alert.route_deviation` → "You have left the planned route."; otherwise "Your plan needs a change." (a missing POI name falls back to "your next stop").

## Merge-order note

Merging Backend before Mobile is safe: the current Mobile never loads a proposal, so no Review button appears for alerts that carry `reroutingProposalId`. No feature flag is needed.

## Acceptance criteria

- All behaviours above are covered by Cubit, repository-contract and widget tests; no test relies on a local fake accept.
- `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` pass.
- Known limitation: end-to-end verification needs BE PR #208 deployed and the UAT seed applied; until then this is verified against the documented contract only.
