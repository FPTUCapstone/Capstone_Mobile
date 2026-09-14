# TM-63 Mobile Spec — UC-17 Create Travel Group

## Scope

Flutter/Mobile implementation only. Backend `POST /api/v1/travel-groups` already exists.
This spec covers: form screen, Cubit state machine, typed itinerary route argument,
success navigation, demo route, and the feature-first Clean Architecture layers needed
to support UC-17 in the `traveler` feature.

**Out of scope:** invite member (UC-18), join group (UC-23), leave/remove (UC-20/21),
location sharing (UC-22), production auth-guarded routing (placeholder only at this stage
because the auth token integration is not yet wired).

---

## Use-Case Summary

| Item | Detail |
|---|---|
| Actor | Traveler (authenticated) |
| Pre-condition | Traveler has an active session |
| Main success | Group created → MSG54 shown → open the new Travel Group Details screen |
| Alt: validation | Inline field error before submit |
| Alt: server error | Error banner shown; form remains editable |
| Alt: offline | Offline banner shown; submit disabled |

---

## Screen Reference

Based on `Capstone_Docs/ux/screen-specifications/create-travel-group-screen-spec.md`.

### Layout (Material 3)

- `AppBar`: title "Create Travel Group", leading back arrow
- `Body` (scrollable):
  - **Group Name** — `AppTextField`, required, max 150 chars
  - **Itinerary** — read-only selected itinerary association; received from the eligible itinerary entry point
  - **Submit button** — `AppButton` full-width, label "Create Group"
- Overlays:
  - Submitting → `CircularProgressIndicator` overlay, button disabled
  - Success → MSG54 shown as a `SnackBar`, then open the created Travel Group Details screen
  - Validation error → inline error under field (MSG01)
  - Server error → error `AppAlert` (MSG127)
  - Offline → warning `AppAlert` (MSG126), button disabled

### Messages

| Code | Text |
|---|---|
| MSG01 | "This field is required." |
| MSG54 | "Travel group created! You are the Group Host. Share the invite code to add members." |
| MSG125 | "Your session has expired. Please sign in again to continue." |
| MSG126 | "You do not have permission to access this function." |
| MSG127 | "TripMate is temporarily unable to process your request. Please check your connection and try again." |

---

## Acceptance Criteria

| AC | Criterion |
|---|---|
| AC-01 | Submitting empty Group Name shows MSG01 inline without calling the API |
| AC-02 | Submitting a name > 150 chars shows MSG01 inline without calling the API |
| AC-03 | A valid name and selected itinerary trigger the API call; loading overlay appears and repeat submit is disabled |
| AC-04 | On 201 success the screen shows MSG54 and opens the created group using its returned `groupId` |
| AC-05 | On API failure (non-201) the screen shows MSG125, MSG126, or MSG127 as applicable and remains editable |
| AC-06 | Production route requires typed `CreateTravelGroupRouteArgs` with a positive `itineraryId` and title |
| AC-07 | Demo route `/demo/uc-17` uses an explicitly labeled development-only fixture |

---

## Architecture — Files to Create/Modify

### Domain layer (lib/features/traveler/domain/)

| File | Action | Purpose |
|---|---|---|
| `entities/travel_group.dart` | NEW | Immutable value object: id, name, inviteCode |
| `repositories/travel_group_repository.dart` | NEW | Abstract interface createTravelGroup({required String name, required int itineraryId}) |

### Data layer (lib/features/traveler/data/)

| File | Action | Purpose |
|---|---|---|
| `models/travel_group_model.dart` | NEW | JSON DTO, fromJson, toEntity() |
| `repositories/travel_group_repository_impl.dart` | NEW | Calls POST /api/v1/travel-groups via ApiClient |

### Presentation layer (lib/features/traveler/presentation/)

| File | Action | Purpose |
|---|---|---|
| `cubit/create_travel_group_cubit.dart` | NEW | Cubit: initial / submitting / success / failure |
| `cubit/create_travel_group_state.dart` | NEW | Sealed-like state with CreateTravelGroupStatus enum |
| `pages/create_travel_group_page.dart` | NEW | StatefulWidget: form + BlocConsumer |

### Router (lib/app/router/)

| File | Action | Purpose |
|---|---|---|
| `app_routes.dart` | MODIFY | Add createTravelGroup + demoUc17 constants |
| `app_router.dart` | MODIFY | Wire typed production route, group details success route, and demo route with BlocProvider |

### Demo index (lib/features/auth/presentation/pages/)

| File | Action | Purpose |
|---|---|---|
| `demo_screen_index_page.dart` | MODIFY | Add UC-17 entry to _screens list |

---

## State Machine (CreateTravelGroupStatus)

```
initial
  ├─[submit invalid]─► validationFailure(message)   (returns to initial after showing error)
  └─[submit valid]──► submitting
                        ├─[201 Created]──► success(TravelGroup)
                        └─[error]────────► failure(message)
```

### State class fields

```dart
enum CreateTravelGroupStatus { initial, submitting, success, failure, validationFailure }

final class CreateTravelGroupState extends Equatable {
  final CreateTravelGroupStatus status;
  final String? errorMessage;
  final TravelGroup? result;   // non-null on success
}
```

---

## API Contract

```
POST /api/v1/travel-groups
Content-Type: application/json
Authorization: Bearer <token>

Body: { "groupName": "<string>", "itineraryId": <long> }

Response 201:
{
  "groupId": <long>,
  "groupName": "<string>",
  "itineraryId": <long>,
  "hostUserId": <long>,
  "inviteCode": "<8-char string>"
}
```

The response must contain valid `groupId`, `groupName`, and `inviteCode`; malformed
responses are treated as failures rather than converted into fabricated values.

---

## Tests to Write

| File | Cases |
|---|---|
| `test/features/traveler/cubit/create_travel_group_cubit_test.dart` | Required itinerary validation, empty/too-long name validation, success, MSG125, MSG126, and MSG127 |
| `test/features/traveler/data/models/travel_group_model_test.dart` | Canonical response parsing and malformed response rejection |
| `test/core/error/error_mapper_test.dart` | HTTP 401 and 403 failure mapping |

---

## Deferred

- Auth token injection into ApiClient
- Loading group details from the backend on direct deep links
