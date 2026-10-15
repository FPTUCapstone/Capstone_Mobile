# UC-13 Navigate Route — Mobile Specification

## Status

Draft for developer review, 2026-10-10. Supersedes the UC-13 parts of
`specs/mobile-active-trip-uc13-uc16-spec.md` (sections 7, 13 `ACTIVE_TRIP_SESSION_CONTRACT_MISSING`,
and 14 for UC-13). UC-14, UC-15, and UC-16 remain governed by that document.

Branch: `feature/phuctv-uc13-navigation-mobile` (based on `origin/develop` `acfde81`).

## Sources and priority

1. Backend specification `Capstone_BE/specs/UC-13-navigate-route-spec.md`, revision 2, approved by
   the developer on 2026-10-09 (branch `feature/phuctv-uc13-navigation-backend`).
2. Developer decisions of 2026-10-10:
   - integrate Mapbox in this delivery (map + directions);
   - follow the Backend revision 2 arrival model (GPS detection with confirmation plus a manual
     "I have arrived" action);
   - offline queueing of navigation actions is out of scope; it belongs to the offline sync use case.
3. Existing mobile code (`ActiveTripPage`, `ActiveTripCubit`, demo fixtures, `NavigationMapCanvas`).

## Scope

In scope:

- Start, resume, and finish a server navigation session for an Active itinerary.
- Flexible visit order: any Pending or Skipped stop can be selected as the target and reached.
- Skip a Pending stop (with confirmation, stronger wording for mandatory stops).
- Exploring phase after a reach; depart back to Navigating; Finish replaces Depart when no Pending
  stop remains.
- Continuous GPS tracking, arrival detection (radius + dwell) with a confirmation prompt, and a
  manual "I have arrived" action.
- Mapbox map (route line, stop markers, user location puck, follow/recenter camera) and Mapbox
  Directions turn-by-turn guidance to the selected target, with off-route detection and automatic
  route recalculation to the same target.
- Graceful degradation when no Mapbox token is configured: illustration canvas, straight-line
  distance, no turn-by-turn instructions; the session flow still works.

Out of scope:

- Offline queue and replay of reach/skip/depart (offline sync use case). Mobile sends the device
  event time (`occurredAtUtc`) with each action so a later sync can reuse the same contract.
- UC-14 alerts and UC-15 re-routing backends (existing demo-only UI is kept unchanged).
- Voice guidance, background tracking while the page is closed, a "resume trip" entry outside the
  itinerary screen.

## Backend contract used

| Action | Request | Notes |
| --- | --- | --- |
| Start | `POST /api/v1/itineraries/{itineraryId}/navigation-sessions` + `Idempotency-Key: <uuid>` | `201` session. One key per page instance; retries reuse it. |
| Read | `GET /api/v1/navigation-sessions/{sessionId}` | Used for resume and refresh after `session_completed`. |
| Reach | `PUT /api/v1/navigation-sessions/{id}/reached-items/{itemId}` body `{occurredAtUtc}` | Replays return `200`. |
| Skip | `PUT /api/v1/navigation-sessions/{id}/skipped-items/{itemId}` body `{occurredAtUtc}` | `409 item_already_reached`. |
| Depart | `PUT /api/v1/navigation-sessions/{id}/state` body `{state: "Navigating", occurredAtUtc}` | Idempotent. |
| Finish | `PUT /api/v1/navigation-sessions/{id}/completion` | Idempotent; reason chosen by Backend. |

Error handling (`errorCode` in ProblemDetails):

| Code | Mobile behaviour |
| --- | --- |
| `navigation.active_session_exists` (+ `activeSessionId`) | Load that session. Same itinerary → resume silently. Other itinerary → conflict screen: *Resume that trip* or *End it and start this trip*. |
| `navigation.outside_trip_window` | Start error: trip can only be navigated during its scheduled window. |
| `navigation.itinerary_not_active` | Start error: itinerary must be Active. |
| `navigation.no_navigable_items`, `navigation.itinerary_schedule_incomplete` | Start error with a specific message. |
| `navigation.session_completed` | Reload the session and show the completed summary (covers lazy expiry). |
| `navigation.item_already_reached` | Reload the session; inform the Traveler. |
| `navigation.item_not_navigable`, `navigation.access_denied`, `navigation.session_not_found` | Error message; navigation actions stay available where meaningful. |
| network / 5xx | Error message; the Traveler can retry the action. |

## Session presentation

- Header: itinerary title, `v{itineraryVersion}`, connection pill.
- Target card (Navigating): stop name, order, mandatory badge, distance (route or straight line),
  remaining time from Mapbox, planned arrival, actions **I have arrived**, **Skip**.
- Exploring card: "You are at {stop}", planned departure, primary **Continue to next stop**
  (Depart) or **Finish trip** when no Pending stop remains.
- Stop list: status icon + text (Pending / Skipped / Reached — never colour only), suggested
  next, per-stop actions **Navigate here** (Pending or Skipped) and **Skip** (Pending).
- Finish confirmation: mentions how many stops were not visited. Completion summary shows the
  Backend completion reason (`RouteFinished`, `TravelerStopped`, `Expired`) and reached/skipped
  counts.
- Leaving the page (back) does not end the session; starting navigation again resumes it.

## Arrival detection (mobile settings)

| Setting | Value |
| --- | --- |
| Arrival radius | 50 m + min(GPS accuracy, 30 m) |
| Dwell time | 20 s continuously inside the radius |
| Candidates | Pending and Skipped stops of an open session |
| After *Not yet* | Stop is suppressed until the Traveler leaves 1.5 × radius |
| Off-route threshold | 60 m + min(accuracy, 30 m) for 3 consecutive fixes |
| Route recalculation throttle | 30 s |

The device time of detection (or of the manual tap) is sent as `occurredAtUtc`.

## Mapbox

- Package `mapbox_maps_flutter`; directions through the Mapbox Directions REST API
  (`mapbox/driving`, `geometries=geojson`, `steps=true`, `overview=full`).
- Token: public token (`pk.`) supplied at build time with
  `--dart-define=MAPBOX_ACCESS_TOKEN=pk...`. A secret token (`sk.`) is rejected at startup. The
  token is never committed and never logged; the Directions client is separate from the API client
  so the TripMate JWT is never sent to Mapbox.
- Without a token, the canvas fallback is shown with an explicit "Mapbox not configured" label.

## Acceptance criteria

1. Starting from an Active itinerary creates a session; reopening the page resumes it.
2. An open session of another itinerary offers Resume or End-and-start.
3. Start errors show specific messages for outside window, not active, no navigable stops,
   incomplete schedule.
4. Any Pending/Skipped stop can be targeted and reached; reaching moves to Exploring.
5. GPS dwell inside the radius prompts "Have you arrived at {stop}?"; confirming calls reach with
   the detection time; *Not yet* suppresses the prompt until the Traveler leaves the area.
6. The manual **I have arrived** action asks for confirmation then reaches the target.
7. Skip asks for confirmation (mandatory stops warned) and never changes the session state.
8. Depart returns to Navigating and targets the suggested next stop; with no Pending stop the
   Exploring card offers **Finish trip** instead.
9. Finish asks for confirmation and shows the Backend completion reason.
10. `session_completed` on any action shows the completed (possibly expired) session.
11. With a token: route line, stop markers, user puck, turn-by-turn instruction, remaining distance
    and time; off-route triggers recalculation. Without a token the flow still works.
12. No GPS coordinates are sent to TripMate Backend; the Mapbox token never reaches TripMate logs.
13. Demo mode (debug builds only) keeps working without Backend using an in-memory session.
