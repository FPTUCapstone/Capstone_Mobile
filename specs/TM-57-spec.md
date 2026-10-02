# Specification: TM-57 [UC-11] View Suggested Itinerary

**Feature**: Traveler itinerary detail, acceptance, regeneration, and manual adjustment
**Jira Ticket**: TM-57
**Use Case**: UC-11
**Branch**: `feature/khanhpq-view-suggested-itinerary`
**Repository**: `Capstone_Mobile`
**Status**: Proposed — awaiting developer approval

## Objective

Let a Traveler open a persisted UC-10 itinerary by ID, inspect its current
timeline, and, only when that Traveler owns it, accept, regenerate, or adjust
it. The page must work after app restart and from a group entry point; it must
not depend on a transient `GoRouter.extra` object.

## Scope

- Add a Traveler itinerary-detail route with a positive `itineraryId` path
  parameter.
- Fetch and render the current itinerary version via the UC-11 API contract.
- Render status, version, schedule, estimated total, per-leg travel time,
  visit/rest cards, and inactive-POI warnings in English.
- Show owner-only Accept, Regenerate, and Edit Items actions.
- Give active group members a clear read-only message and hide mutation
  controls.
- Provide a reorder/remove editor for visit items. Rest items are explanatory
  and managed by the backend.
- Change UC-10 success navigation to open the persisted detail route with its
  `itineraryId`.

## Explicitly Out of Scope

- Interactive maps, map provider integration, route polylines, navigation,
  offline download, POI browsing/details, adding POIs, and group-management
  UI.
- Creating scheduling requests or changing UC-10 input/generation behavior.
- A web itinerary screen.

## UX and State Rules

- The detail page initially loads from the route ID and shows loading, loaded,
  not-found, permission, unavailable-POI, and safe retry states.
- All customer-facing copy is English. Technical HTTP messages, exceptions,
  operation keys, and stack traces are never displayed.
- The owner sees `Accept itinerary` only for a Draft version. Regenerate and
  Edit Items are available to the owner of either Draft or Active versions.
- Regenerate/Edit show a blocking progress state and use a new UUID operation
  key. Retrying an unchanged failed network submission reuses that key; a
  changed edit draft creates a new key.
- A successful owner action replaces the displayed detail with the returned
  successor version. A new version remains Draft until explicitly accepted.
- Group members see the same timeline but a `This itinerary is view-only for
  group members.` message and no mutation controls.
- Inactive POIs remain visible with an `Unavailable` marker and a prompt for
  the owner to regenerate. Viewing never changes itinerary data.
- The editor allows drag reordering and removal of visit items, requires at
  least one remaining visit, and submits only the ordered visit POI IDs.

## Mobile Architecture

Use the existing feature-first Clean Architecture under
`lib/features/traveler/`:

```text
presentation page/widget -> itinerary detail cubit -> use case ->
itinerary repository contract -> repository implementation -> Dio data source
```

- Add a persisted `ItineraryDetail` domain entity and item entity rather than
  overloading UC-10's transient `GeneratedItinerary` response entity.
- Extend the existing itinerary repository with get, accept, regenerate, and
  adjust operations; retain JSON/Dio details in Data models/data source.
- Add `ItineraryDetailCubit` with separate loading, loaded, action-in-progress,
  failure, and action-success transitions.
- Register dependencies through the existing `get_it` setup. Pages and Cubits
  must not construct Dio or repositories.
- Add `/traveler/itineraries/:itineraryId` to centralized route definitions.
  Invalid path values render the existing safe error view.

## API Contract Consumed

| Operation | Method and route | Request |
| --- | --- | --- |
| Read current itinerary | `GET /api/v1/itineraries/{id}` | none |
| Accept current draft | `POST /api/v1/itineraries/{id}/accept` | none |
| Regenerate successor | `POST /api/v1/itineraries/{id}/regenerate` | `Idempotency-Key` header |
| Adjust successor | `PUT /api/v1/itineraries/{id}/items` | `Idempotency-Key` and `orderedVisitPoiIds` |

The response exposes `canManage`; Mobile treats it as the server-authoritative
decision. A 403 is handled as permission failure even if stale UI previously
showed owner controls.

## Acceptance Criteria

1. UC-10 navigation opens the detail route by ID and the page can reload the
   itinerary after app restart.
2. The timeline renders ordered visits/rests, version/status, planned times,
   travel minutes, estimated POI costs, total duration/cost, and explanatory
   rest text on reasonable phone widths.
3. Loading, fetch failure, 404, 403, empty item, and unavailable-POI states
   are distinct, safe, and actionable.
4. Group members cannot reach owner actions through the visible UI; a backend
   403 also leaves the page safe and reloadable.
5. Owner can accept a Draft and sees the returned Active status.
6. Owner can regenerate or adjust; success replaces the page with the new
   Draft version without losing the response state.
7. The editor preserves requested visit order, cannot submit duplicates or no
   visits, and retains its draft after a recoverable failure.
8. No map, offline-download, or navigation placeholder control is introduced.

## Testing

- Model/mapper tests for detail JSON, nullable POI fields, item kind, and
  unavailable status.
- Repository/data-source tests for routes, idempotency headers, error mapping,
  and ordered edit JSON.
- Cubit tests for load, owner/group member, accept, network retry, regenerate,
  edit submission, and safe 403/404/422/409 failures.
- Widget tests for timeline, owner/read-only actions, unavailable warning,
  editor reorder/removal validation, loading, error, and retry.
- Final checks: `flutter pub get`, `dart format --set-exit-if-changed .`,
  `flutter analyze`, and `flutter test`.
