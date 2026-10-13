# UC-32 & UC-33 Mobile Implementation Plan: Trip History & Review

> **Goal:** Remediate reviewer findings for PR #33: decouple detail/review route from `state.extra`, remove unused `DioClient` dependency from repositories, and establish full test coverage for direct navigation and authorization.

**Tech Stack:** Flutter, Dart, flutter_bloc, get_it, go_router.  
**Spec Reference:** `specs/UC-32-UC-33-mobile-spec.md` (Screens #73 & #74).

---

## 1. Global Constraints & Clean Architecture

- `Presentation -> Domain -> Data`: UI components and routes depend solely on Cubits and domain contracts.
- Route `:tripId` parameter is authoritative source of truth. `state.extra` is optional in-memory cache only.
- In Demo mode, strict tenant checking (`travelerId == 1`) blocks foreign access (`travelerId == 999`) with `PermissionFailure`.
- In Production mode, truthful `PENDING_BE_INTEGRATION` without fabricating booking mutations.
- Unused `DioClient` removed from `TripHistoryRepositoryImpl` and `TripReviewRepositoryImpl`.

---

## 2. Tasks

### Task 1: Remove Unused `DioClient` Dependency (P3)
- Remove `dioClient` from `TripHistoryRepositoryImpl` and `TripReviewRepositoryImpl`.
- Update `lib/core/di/service_locator.dart` factory registrations.
- Update repository unit/cubit test constructors.

### Task 2: Route ID as Source of Truth & Ownership Validation (P1)
- Update `DemoTripHistoryStore.getTripById()` to throw `PermissionFailure(TripHistoryStringsEn.permissionDenied)` when foreign traveler records are queried.
- Inject `TripHistoryRepository` into `TripReviewCubit`.
- Add `loadTripAndReview({required String tripId, TripHistoryItem? cachedTrip, int? travelerId, DateTime? referenceTime})` in `TripReviewCubit`.
- Update `TripReviewPage` constructor to accept `tripId` with optional `initialTrip`, resolving data via Cubit.
- Update `app_router.dart` to use `routeTripId` as source of truth and pass `cachedTrip` as optional seed. Add `/traveler/trips/:tripId` direct alias.

### Task 3: Regression & Direct Navigation Tests
- Update `test/app/router/trip_review_route_identity_test.dart` to cover:
  1. Open detail without `state.extra` (deep link / restore).
  2. Open with invalid `tripId` (`tripInformationUnavailable`).
  3. Open unauthorized `tripId` (`permissionDenied`).
  4. Normal navigation with matching `state.extra`.
- Add unit tests in `trip_review_cubit_test.dart` and widget tests in `trip_review_page_test.dart`.

### Task 4: Verification & Build
- Run `dart format --set-exit-if-changed .`
- Run `flutter analyze`
- Run `flutter test` across all suites
- Verify Android debug build
