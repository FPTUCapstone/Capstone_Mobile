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
| MSG54 | "Travel group created successfully! You are the Group Host." |
| MSG125 | "Your session has expired. Please sign in again to continue." |
| MSG126 | "You do not have permission to access this function." |
| MSG127 | "TripMate is temporarily unable to process your request. Please check your connection and try again." |

---

## Acceptance Criteria

| AC | Criterion |
|---|---|
| AC-01 | Submitting empty Group Name shows MSG01 inline without calling the API |
| AC-02 | Submitting a name > 150 chars shows validation failure inline without calling the API |
| AC-03 | A valid name and selected itinerary trigger the API call with an `Idempotency-Key` header; loading overlay appears and repeat submit is guarded |
| AC-04 | On 201 success the screen shows MSG54 as a SnackBar and opens the created group using its returned `groupId` |
| AC-05 | On API failure the screen shows backend message (400 validation / 409 conflict) or MSG125, MSG126, MSG127 and remains editable |
| AC-06 | Production route requires typed `CreateTravelGroupRouteArgs` with a positive `itineraryId` and title |
| AC-07 | Demo route `/demo/uc-17` uses an explicitly labeled development-only fixture |

---

## Architecture — Files to Create/Modify

### Domain layer (lib/features/traveler/domain/)

| File | Action | Purpose |
|---|---|---|
| `entities/travel_group.dart` | NEW | Immutable value object: id, name |
| `repositories/travel_group_repository.dart` | NEW | Abstract interface createTravelGroup({required String name, required int itineraryId, required String idempotencyKey}) |

### Data layer (lib/features/traveler/data/)

| File | Action | Purpose |
|---|---|---|
| `models/travel_group_model.dart` | NEW | JSON DTO, fromJson, toEntity() |
| `repositories/travel_group_repository_impl.dart` | NEW | Calls POST /api/v1/travel-groups with Idempotency-Key header |

### Presentation layer (lib/features/traveler/presentation/)

| File | Action | Purpose |
|---|---|---|
| `cubit/create_travel_group_cubit.dart` | NEW | Cubit: manages submit guard, idempotency key tracking, and state transitions |
| `cubit/create_travel_group_state.dart` | NEW | State with CreateTravelGroupStatus enum (initial, submitting, success, failure, validationFailure) |
| `pages/create_travel_group_page.dart` | NEW | StatefulWidget: form with separate name/itinerary error binding + BlocConsumer |

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
Idempotency-Key: <UUID v4>
Authorization: Bearer <token>

Body: { "groupName": "<string>", "itineraryId": <long> }

Response 201:
{
  "groupId": <long>,
  "groupName": "<string>",
  "itineraryId": <long>
}
```

- **Idempotency**: Client generates a standard UUID v4 `Idempotency-Key` header bound to `(groupName, itineraryId)`. Retries with the identical payload reuse the key; modifying payload resets the key.
- **Error Mapping**:
  - `400 Bad Request`: Mapped to `ValidationFailure` with error details from backend `ProblemDetails`.
  - `401 Unauthorized`: Mapped to `AuthenticationFailure` (MSG125).
  - `403 Forbidden`: Mapped to `PermissionFailure` (MSG126).
  - `409 Conflict`: Mapped to `ConflictFailure` (in-flight request or key mismatch).
  - `>= 500 / Network`: Mapped to `ServerFailure` / `NetworkFailure` (MSG127).

---

## Tests to Write

| File | Cases |
|---|---|
| `test/features/traveler/cubit/create_travel_group_cubit_test.dart` | Itinerary validation, name validation, success, idempotency key reuse, HTTP 400 validation, HTTP 409 conflict, MSG125, MSG126, MSG127 |
| `test/features/traveler/data/models/travel_group_model_test.dart` | Canonical response parsing and malformed response rejection |
| `test/features/traveler/data/repositories/travel_group_repository_impl_test.dart` | Transport assertion: Idempotency-Key header UUID v4 format and payload verification |
| `test/core/error/error_mapper_test.dart` | HTTP 400 (ProblemDetails parsing), 401, 403, 409 (Conflict), and network failures |

---

## Deferred

- Auth token injection into ApiClient
- Loading group details from the backend on direct deep links
