# UC-32 & UC-33 Mobile Implementation Plan: Trip History & Review

> **Goal:** Remediate reviewer findings for PR #33: decouple detail/review route from `state.extra`, remove unused `DioClient` dependency from repositories, and establish full test coverage for direct navigation and authorization.

**Tech Stack:** Flutter, Dart, flutter_bloc, get_it, go_router.
**Spec Reference:** `specs/UC-32-UC-33-mobile-spec.md` (Screens #73 & #74, Section 3.7.1 View Trip History (UC-32) and Section 3.7.2 Submit Trip Review (UC-33) of `Report3_Software-Requirement-Specification-V2.docx`).

---

## 1. Global Constraints & Clean Architecture

- `Presentation -> Domain -> Data`: UI components and routes depend solely on Cubits and domain contracts.
- Route `:tripId` parameter is authoritative source of truth. `state.extra` is optional in-memory cache only.
- In Demo mode, strict tenant checking (`travelerId == 1`) blocks foreign access (`travelerId == 999`) with `PermissionFailure`.
- In Production mode, truthful `PENDING_BE_INTEGRATION` without fabricating booking mutations.
- Unused `DioClient` removed from `TripHistoryRepositoryImpl` and `TripReviewRepositoryImpl`.
- Self-planned itineraries (`TripType.itinerary`) are non-commercial records and strictly non-reviewable.
- Date range filtering is inclusive of entire calendar days under CR-07 (Asia/Ho_Chi_Minh UTC+7).

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

### Task 4: Enforce Booking Review Eligibility & Exclude Self-Planned Itineraries (P1 Remediation)
- In `TripReviewCubit._applyLoadedTrip`: reject `TripType.itinerary`, set `trip = null`, and emit `noticeSelfPlannedNoReview` with `TripReviewStatus.failure`.
- In `TripReviewCubit.submit`: fail closed if `state.trip == null` or `state.trip.type == TripType.itinerary`, emitting `noticeSelfPlannedNoReview` without calling repository.
- In `DemoTripHistoryStore.submitReview` and `updateReview`: throw `ValidationFailure(noticeSelfPlannedNoReview)` if `item.type == TripType.itinerary`.
- In `TripReviewPage`: ensure `validInitial` suppresses non-commercial itineraries and renders `ErrorView`.

### Task 5: Enforce Inclusive Calendar-Day Date Range Filtering under CR-07 (P2 Remediation)
- Add `TripFormatters.toVietnamCalendarDay(dateTime)` to normalize any `DateTime` to a UTC calendar day with time `00:00:00` under CR-07 (`Asia/Ho_Chi_Minh` UTC+7).
- In `DemoTripHistoryStore.getTrips`: use `!toVietnamCalendarDay(departureDate).isBefore(startDay)` and `!toVietnamCalendarDay(departureDate).isAfter(endDay)` to inclusively capture all trips departing on the end calendar day (e.g. 10:00, 23:59:59).
- Support single-day filters, cross-month, and cross-year ranges.
- In `TripHistoryCubit.setDateRange`: validate using calendar days; emit MSG29 (`validationDateRangeInvalid`) if `endDay.isBefore(startDay)` and preserve current list.

### Task 6: Verification & Build
- Run `dart format --set-exit-if-changed .`
- Run `flutter analyze`
- Run `flutter test` across all suites
- Verify Android debug build
