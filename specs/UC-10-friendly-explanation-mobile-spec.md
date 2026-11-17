# UC-10 Mobile: show the AI explanation

Status: design approved by the developer on 2026-11-17 for the Web (`Capstone_FE/specs/UC-10-friendly-explanation-web-spec.md`);
the report of the same day says Mobile follows it, one PR per repo. Follows `Capstone_BE/specs/UC-10-background-explanation-spec.md`
section 6 (BE PR #176, merged). Only the carrier of the "pending" flag differs from the Web (see Approaches).

## Intent

With background mode on, the backend answers a create request at once with template sentences and writes the AI
sentence afterwards (`explanationPending: true`). Mobile shows only `recommendationReason`, so travelers never see the
AI sentence.

## Goals

1. `ItineraryStopCard` shows `friendlyExplanation` where it shows `recommendationReason` today. Never both.
2. After a create that answered `explanationPending: true`, the itinerary detail page loads the itinerary again a few
   times and shows the AI sentences as soon as they arrive.

## Non-goals

- No "AI is rewriting" indicator. No backend change. No refresh for itineraries opened later from My Trips or after
  the app restarted (their stored sentences are already the AI's).
- `ItineraryResultPage` (route `itineraryResult`, nothing in the app navigates to it) is left alone.
- Rest stops keep their current wording (`poiName ?? recommendationReason ?? 'Thời gian nghỉ'`).

## Behavior

### Which sentence a visit stop shows
`friendlyExplanation.trim()` when not empty, else `recommendationReason.trim()` when not empty, else the existing
placeholder `'Địa điểm gợi ý'`. A whitespace-only `friendlyExplanation` must not hide `recommendationReason`.

### Carrying the flag
The create page already pushes the detail route right after a successful create. It now passes a `PendingExplanation`
as the route's `extra`, built from the create result only when `explanationPending == true`:
`{ itineraryId, createdAt, template }`, `template` = trimmed template sentence per `sequenceNo`.
The route builder hands it to the detail page only when `extra.itineraryId` equals the route's `itineraryId`;
anything else is ignored. Nothing is stored globally, so a restart or a later visit has no pending state.

### Refresh schedule (in `ItineraryDetailCubit`)
- `load(id, pendingExplanation: ...)`. After the first load succeeds the cubit schedules attempts at 20, 45, 75 and
  110 seconds after `createdAt`; a delay already passed is skipped. Each attempt calls `repository.getById(id)`.
- The AI sentence has arrived when some item (matched by `sequenceNo`) has a non-empty trimmed `friendlyExplanation`
  that differs from its template text. Then the cubit emits the current state with only the items'
  `friendlyExplanation` replaced, keeping status, edit state, undo and shifted arrivals, and stops.
- Stops when: the AI sentence has arrived, attempts are used up, the cubit closes, or the cubit moves to another
  itinerary id (accept, regenerate or an edit returned a new version). If the first load already has the AI sentence,
  no attempt is made.
- A failed attempt is ignored; later attempts still run. No error is shown.

## Contract changes
- `GeneratedItineraryItem.friendlyExplanation: String?`, `GeneratedItinerary.explanationPending: bool` (default
  false), `ItineraryDetailItem.friendlyExplanation: String?`. Parsing tolerates missing and null. Like
  `recommendationReason`, a non-string value is a malformed payload.

## Approaches considered
1. **`PendingExplanation` in the route `extra`, refresh owned by the cubit** (chosen): idiomatic `go_router`, bound to
   exactly one navigation and one itinerary id, no global state; the cubit already owns every state change of the page.
2. A global in-memory handoff like the Web: works, but adds shared mutable state that `extra` makes unnecessary.
3. A backend pending flag on the detail: contradicts BE spec B6.

## Acceptance criteria
1. A visit stop with `friendlyExplanation` shows it and not `recommendationReason`; null, empty or whitespace-only
   falls back to `recommendationReason`, then to `'Địa điểm gợi ý'`.
2. Create with `explanationPending: true`, detail opens, AI answers at about 40 s: the stop text becomes the AI
   sentence at the 45 s attempt and no further request is made.
3. `explanationPending` false or missing: the detail makes no extra request.
4. A `PendingExplanation` for another itinerary id is ignored.
5. Closing the page cancels pending attempts; accepting, regenerating or editing cancels them too.
6. Opening the detail after 110 s makes no extra request.
