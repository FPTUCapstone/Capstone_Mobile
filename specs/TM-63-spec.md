# TM-63 Mobile Spec — UC-17 Create Travel Group

## Scope

Flutter/Mobile implementation only. Backend `POST /api/v1/travel-groups` already exists.
This spec covers: form screen, Cubit state machine, demo route, and the
feature-first Clean Architecture layers needed to support UC-17 in the `traveler` feature.

**Out of scope:** invite member (UC-18), join group (UC-23), leave/remove (UC-20/21),
location sharing (UC-22), production auth-guarded routing (placeholder only at this stage
because the auth token integration is not yet wired).

---

## Use-Case Summary

| Item | Detail |
|---|---|
| Actor | Traveler (authenticated) |
| Pre-condition | Traveler has an active session |
| Main success | Group created → success banner shown → navigate back |
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
  - **Itinerary** — `AppTextField`, read-only + suffix icon (placeholder; no real picker this sprint)
  - **Submit button** — `AppButton` full-width, label "Create Group"
- Overlays:
  - Submitting → `CircularProgressIndicator` overlay, button disabled
  - Success → success `AppAlert` (MSG54) shown briefly, then `context.pop()`
  - Validation error → inline error under field (MSG01)
  - Server error → error `AppAlert` (MSG127)
  - Offline → warning `AppAlert` (MSG126), button disabled

### Messages

| Code | Text |
|---|---|
| MSG01 | "Group name is required and must not exceed 150 characters." |
| MSG54 | "Travel group created successfully." |
| MSG126 | "You appear to be offline. Please check your connection." |
| MSG127 | "Unable to create group. Please try again." |

---

## Acceptance Criteria

| AC | Criterion |
|---|---|
| AC-01 | Submitting empty Group Name shows MSG01 inline without calling the API |
| AC-02 | Submitting a name > 150 chars shows MSG01 inline without calling the API |
| AC-03 | A valid name triggers the API call; loading overlay appears during the call |
| AC-04 | On 201 success the screen shows MSG54 then pops |
| AC-05 | On API failure (non-201) the screen shows MSG127 and remains editable |
| AC-06 | Demo route `/demo/uc-17` opens the screen without auth guard |

---

## Architecture — Files to Create/Modify

### Domain layer (lib/features/traveler/domain/)

| File | Action | Purpose |
|---|---|---|
| `entities/travel_group.dart` | NEW | Immutable value object: id, name, inviteCode |
| `repositories/travel_group_repository.dart` | NEW | Abstract interface createTravelGroup(String name) |

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
| `app_router.dart` | MODIFY | Wire production route + demo route with BlocProvider |

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

Body: { "name": "<string>", "itineraryId": null }

Response 201:
{
  "id": <long>,
  "name": "<string>",
  "inviteCode": "<8-char string>"
}
```

> **Note:** `itineraryId` is optional/nullable. Sent as `null` this sprint.
> Real itinerary picker is deferred.

---

## Tests to Write

| File | Cases |
|---|---|
| `test/features/traveler/cubit/create_travel_group_cubit_test.dart` | (1) empty name → validationFailure, (2) name > 150 chars → validationFailure, (3) valid name + mock success → success state, (4) valid name + mock failure → failure state |

---

## Deferred

- Real itinerary picker (UC-12/13)
- Auth token injection into ApiClient
- Production shell navigation (traveler bottom nav)
