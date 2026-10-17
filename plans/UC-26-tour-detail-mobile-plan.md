# UC-26 Mobile plan

Approved together with `specs/UC-26-tour-detail-mobile-spec.md` (2026-10-17). Work in worktree `Capstone_Mobile_UC26`, branch
`feature/uc26-mobile-tour-detail` from `origin/develop` (`b461698`). Every task is test first; verify with the listed
command before moving on. Baseline on the clean checkout: `flutter analyze` — no issues; `flutter test` — 1257 passed.

## Task 1 — Model and strict parser
`TourDetailModel.fromJson/toEntity` and the additive entity fields (`TourItineraryStop`, schedule and detail extras).
Tests: valid payload; every rejected shape (missing field, wrong type, numeric ids, bad `availabilityStatus`,
non-list collections); null/omitted optionals; mapping of status, prices, rules, stops.
Verify: `flutter test test/features/tour_detail/data/models`.

## Task 2 — Remote data source and repository
`DioTourDetailRemoteDataSource` (public request, 404 → `null`, other failures throw, invalid id → `null` without a
request); register it in `service_locator.dart`; remove `PendingTourDetailDataSource` from the real path.
Tests with a fake Dio adapter: 200, 404, 500, network error, non-JSON, malformed JSON, path for a large id.
Verify: `flutter test test/features/tour_detail/data`.

## Task 3 — Cubit
Selectable-departure rule, `failureKind`, no pending state on the real path, demo mode unchanged.
Tests: first bookable preselected, closed/sold-out/unknown not selectable (MSG65), 404 vs failure, retry reload.
Verify: `flutter test test/features/tour_detail/presentation/cubit`.

## Task 4 — Screen sections
Itinerary stops, cancellation rules, destinations, per-departure details, reviews aggregate/MSG128, "as of" note,
Vietnam-time formatting helper (unit tested across the UTC+7 date boundary).
Widget tests per section with real-shaped data; demo data still renders.
Verify: `flutter test test/features/tour_detail/presentation/pages`.

## Task 5 — Booking bar and states
Bottom bar driven by the selected departure's bookability and the Guest sign-in dialog; not-found view without Retry;
error view with Retry. Tests per state; route test for `/explore/tours/:tourId` with and without `TourSummary` extra.
Verify: page tests and `flutter test test/app/router`.

## Task 6 — Verification
`dart format --set-exit-if-changed .`, `flutter analyze`, full `flutter test`, `flutter build apk --debug` (if the Android
SDK is installed by then). The committed debug manifest overlay (`usesCleartextTraffic`) lands with this work. Two-pass self-review. No push before the developer chooses.

## Task 7 — Android UAT (assisted)
Install Android SDK / AVD with the developer, run against the local UC-26 Backend and the seeded UAT database, and
execute the scenario list (visibility 404 matrix, sections, departure states, Retry after turning the Backend off,
Guest Book Now dialog). Report what ran and what could not.
