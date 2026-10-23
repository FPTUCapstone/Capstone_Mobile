# UC-32 Trip History — Mobile integration plan

Spec: `specs/UC-32-trip-history-api-mobile-spec.md` (approved 2026-10-22).
Backend contract: `Capstone_BE/docs/TM-78-api-contract.md`. Web counterpart: Capstone_FE PR #108.
Branch: `feature/uc32-trip-history-api` from `develop` @ `8310915` (the two commits after `a169dad` only add
`.ai/pr-review-skill/*` and the PR template; no `lib`, `test` or `pubspec` change, so the baseline of 1473 passing tests holds).
Status: **Approved 2026-10-22** (8-task process, isolated new code, legacy kept and marked `@deprecated`, trailer
`Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`).

## 0. Ground rules

- Test first (red, minimal code, refactor). Code written before its test is deleted.
- One task at a time; after each, run its verification and a two-pass self-review (spec compliance, then quality).
  A Critical finding blocks the next task.
- Page -> Cubit -> Use case -> Repository contract -> Repository implementation -> `DioClient` (AGENTS.md); no raw Dio in
  pages or cubits; no new state-management or dependency; `flutter_bloc` Cubit; Material 3 and existing theme tokens.
- Legacy code is not edited except for a `@deprecated` doc comment: `TripHistoryItem`, `TripHistoryCubit`,
  `TripHistoryRepository(+Impl)`, `DemoTripHistoryStore`, `TravelerBookingsView`, the legacy review flow.
- `flutter pub get` rewrites `pubspec.lock` on this machine; it is restored (`git checkout -- pubspec.lock`) and never committed.
- No commit, push or PR unless the developer asks. Tests mock the transport and do not prove live backend integration.

## 1. File map (all under `lib/features/trip_history/` unless noted)

| File | Purpose |
| --- | --- |
| `domain/entities/trip_record.dart` | `TripRecordKind`, actions, review state, sealed `TripRecord` (`BookingTripRecord`, `ItineraryTripRecord`), summary, page |
| `domain/entities/trip_record_detail.dart` | `BookingTripDetail`, `ItineraryTripDetail`, tour, schedule, participants, cancellation, refund, stop, session |
| `domain/repositories/trip_records_repository.dart` | `TripRecordsRepository`, query value object |
| `domain/usecases/trip_records_use_case.dart` | page + detail |
| `data/models/trip_records_json.dart` | strict JSON -> entities (throws `FormatException`) |
| `data/repositories/trip_records_repository_impl.dart` | Dio + failure mapping |
| `data/datasources/demo_trip_records_data.dart` + `data/repositories/demo_trip_records_repository.dart` | contract-shaped demo data (debug + `demo=true` only) |
| `presentation/cubit/trip_records_cubit.dart` + `trip_records_state.dart` | list state |
| `presentation/cubit/trip_record_detail_cubit.dart` + `trip_record_detail_state.dart` | detail sheet state |
| `presentation/widgets/trip_record_detail_sheet.dart` | bottom sheet |
| `lib/core/di/service_locator.dart` | registrations |
| `docs/mobile-api-contract.md` | endpoint notes |

Reworked: `presentation/pages/trip_history_page.dart`, `widgets/trip_history_card.dart`, `widgets/trip_history_filters_bar.dart`,
`resources/trip_history_en.dart` (add strings), `lib/app/router/app_router.dart` (page provider only).
Reused: `ReviewableRecordRef`, `TripStatus`, `TripFormatters`, `AppRoutes.canonicalTripReview`, `Failure` types, `StatusBadge`,
`AppAlert`, `LoadingIndicator`.

## 2. Tasks

Verification for every task: `flutter test <paths>`, `dart format --set-exit-if-changed <paths>`, `flutter analyze`.

### Task 1 — Domain entities and strict JSON parsing
- **Files:** `trip_record.dart`, `trip_record_detail.dart`, `trip_records_json.dart`;
  `test/features/trip_history/data/trip_records_json_test.dart`.
- **Tests first:** a full page (booking + itinerary, summary) parses to entities with positive `int` ids, `TripStatus` tab,
  UTC `DateTime`, whole-VND `int` amounts from `3200000.00`; `summary` absent -> null; reviewed booking
  (`review.exists` with id and rating 1-5); itinerary `visitedCount` optional; unknown fields ignored. Rejected with
  `FormatException`: non-object body, `items` not a list, unknown `kind`, tripType mismatching kind, unknown tab, missing
  bookingCode/totalAmount/stopCount, bad date, missing action flag, non-bool flag, id 0 / negative / string / fractional,
  `reviewableRecord` id or kind mismatch, booking with null review or itinerary with non-null review/reviewableRecord,
  rating outside 1-5, negative counts, `visitedCount > stopCount`, `page`/`pageSize` < 1. Detail: booking
  (tour, schedule with null meeting point, participants, cancellation with null fields, refund with null channel) and
  itinerary (stops with and without visit data, planned times null, session with null end/reason) parse; bad stop
  `visitStatus`, bad `poiId`, missing `stops` rejected.
- **DoD:** no `dynamic` leaks past the parser; entities are `Equatable` and immutable.

### Task 2 — Repository over Dio
- **Files:** `trip_records_repository.dart`, `trip_records_repository_impl.dart`;
  `test/features/trip_history/data/trip_records_repository_test.dart` (fake `HttpClientAdapter`, as in
  `canonical_trip_review_repository_test.dart`).
- **Tests first:** the list request is `GET /api/v1/traveler/trips` with `tab`, `tripType` (omitted for All), `fromDate`/`toDate`
  as Vietnam-day `yyyy-MM-dd` (omitted when null), `page`, `pageSize=20`; the detail request is
  `/api/v1/traveler/trips/{kind}/{id}` from the wire kind; responses are parsed; a malformed 200 ->
  `ServerFailure('trip_history.invalid_response')`; `401`->`AuthenticationFailure`, `403`->`PermissionFailure`,
  `404`->`NotFoundFailure`, `400 trip_history.invalid_date_range`->`ValidationFailure`, other 400 and 5xx->`ServerFailure`,
  connection and timeout errors->`NetworkFailure`; no raw exception text or response body in any failure message; a detail
  answer for another (kind,id) is rejected.
- **DoD:** nothing outside the repository imports Dio.

### Task 3 — Demo data and repository
- **Files:** `demo_trip_records_data.dart`, `demo_trip_records_repository.dart` (+ tests).
- **Tests first:** the demo answers the same queries with the same rules as the backend (tab, trip type, Vietnam-day range,
  departure desc then kind then id desc, paging, summary on Completed only); every record has a detail; actions are consistent
  with the record (`canReview` only for a Completed unreviewed booking, itinerary flags all false); the fixtures pass the
  Task 1 parser when serialized to wire JSON (contract guard).
- **DoD:** demo code is reachable only through the factory selected by `isDemoMode`.

### Task 4 — Use case and dependency injection
- **Files:** `trip_records_use_case.dart`; `service_locator.dart`; `test/features/trip_history/trip_records_dependency_injection_test.dart`.
- **Tests first:** the use case delegates page and detail; `serviceLocator<TripRecordsRepository>(param1: false)` is the Dio
  implementation and `(param1: true)` the demo one; the existing `trip_history_dependency_injection_test.dart` stays green.
- **DoD:** the legacy registrations are untouched.

### Task 5 — `TripRecordsCubit`
- **Files:** cubit + state; `test/features/trip_history/presentation/cubit/trip_records_cubit_test.dart` (`bloc_test`).
- **Tests first:** `loadInitial` requests Completed? (default tab = Upcoming, as today), emits loading then success; `switchTab`,
  `setTripType`, `setDateRange`, `clearDateRange`, `goToPage` request exactly those parameters and reset to page 1 (except paging);
  a reversed range emits the MSG29 validation error and sends nothing; the page count is capped at 50; each Failure maps to
  its message (`AuthenticationFailure`/`PermissionFailure` -> permission text, `ValidationFailure(invalid_date_range)` -> MSG29,
  others -> generic) with Retry re-requesting; a stale answer to an older request is ignored; no pending-integration state.
- **DoD:** no `print`, no raw exception text in state.

### Task 6 — Detail cubit and bottom sheet
- **Files:** detail cubit + state, `trip_record_detail_sheet.dart` (+ tests).
- **Tests first:** loading -> ready; `NotFoundFailure` -> not found (no Retry); access failures -> permission text (no Retry);
  other -> generic with Retry; booking sections (tour, schedule, participants, cancellation, refund with `null` channel shown
  as "Not available"); itinerary stops with Visited / Skipped / Not visited and times, `Visited n of m`, session reason
  `RouteFinished` / `TravelerStopped` / `Expired` -> readable text, unknown reason shown raw; refund opened from the refund
  action is highlighted; closing the sheet closes the cubit.
- **DoD:** safe areas, small screens and long text handled (widget tests at 320 dp width and a larger text scale).

### Task 7 — Card, filters bar, page
- **Files:** `trip_history_card.dart`, `trip_history_filters_bar.dart`, `trip_history_page.dart`, strings (+ rewritten page/card tests).
- **Tests first** (one per row):
  - booking card shows title, `dd/MM/yyyy` (UTC+7), code, participants, VND, status; itinerary shows stops and `Visited n of m` only
    when `visitedCount` exists; nothing from the removed fields;
  - **Write review** only when `canReview`; **View review** only when `review.exists`; each opens
    `AppRoutes.canonicalTripReview('commerceBooking', reviewableRecord.id)`; flags that disagree show both; no Edit button;
  - **E-ticket** only when `canViewETicket` and a `ticketId`, tapping shows the existing pending notice and navigates nowhere;
  - **View refund** only when `canViewRefund` and opens the sheet on the refund; **View details** always;
  - filter offers All / Tour / Itinerary only; the page shows loading, empty, error + Retry, pagination, MSG29; tabs
    keep their state; production has no pending state.
- **DoD:** accessible labels (`Semantics`/tooltips) on icon-only controls; legacy `TravelerBookingsView` tests untouched.

### Task 8 — Router wiring, docs, deprecations, final verification
- **Files:** `app_router.dart` (page provider uses `TripRecordsCubit` through DI with `isDemo`), `docs/mobile-api-contract.md`,
  `@deprecated` comments on the legacy history types, leftover unused strings.
- **Tests first:** a router test that `/traveler/trips` builds the page with the new cubit and that `?demo=true` is honoured only in debug.
- **Verify (in order):** `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` (all 1473 legacy
  tests still pass plus the new ones); restore `pubspec.lock`; `git status` shows no generated files.
- **DoD:** report skipped or environment-limited checks honestly (no device run, no `flutter build apk` since no Android config changed).

## 3. Traceability

| Spec | Task |
| --- | --- |
| §6.1 domain | 1 |
| §6.2 data and failures | 2 |
| §6.3 demo | 3 |
| §6.4 use case and DI | 4 |
| §6.5 state | 5, 6 |
| §6.6 UI | 6, 7 |
| §6.7 docs | 8 |
| Acceptance 1-8 | 2, 5, 7, 6, 3, 8 |

## 4. Risks

- BE PR #105 is not merged: nothing proves live integration until it is deployed.
- Two history models coexist (legacy and TM-78) until the bookings tab and legacy review are migrated in their own tasks.
- The bookings tab in production still shows its pending state; it is out of scope.
- No device or emulator run in the authoring session; widget tests stand in and are reported as such.

## 5. Finishing

When all tasks pass and are reviewed, stop and ask: merge, open a PR, keep the branch, or discard. Nothing is committed or pushed unprompted.

## 5. Execution log (2026-10-22)

All 8 tasks done on `feature/uc32-trip-history-api`; nothing committed, pushed or opened as a PR.

| Task | Result |
| --- | --- |
| 1-4 | Domain, strict JSON, Dio repository, demo repository, use case and DI, each with tests. |
| 5-6 | `TripRecordsCubit`, `TripRecordDetailCubit`, `TripRecordDetailSheet`. |
| 7 | `TripHistoryCard`, `TripHistoryFiltersBar`, `TripHistoryPage` reworked; page tests rewritten (19). |
| 8 | Router uses `TripRecordsCubit`; `docs/mobile-api-contract.md` has the two endpoints; `@deprecated` doc comments on the legacy types; three unused strings removed. |

Verification: `flutter pub get`, `dart format --set-exit-if-changed .` (0 changed), `flutter analyze` (no issues), `flutter test` (1670 passed). `pubspec.lock` restored; `git status` shows only intended files.

Deviations:
- The sheet title moved into the scrollable area (close button stays pinned): a long title at 2x text on a 320 dp screen overflowed by 8 px.
- Added `TripRecordsCubit.clearFilters()` so Reset is one request (its test was written after the code).
- `TripHistoryPage` no longer takes `initialTab` or `referenceTime`; the tab comes from the cubit.
- Legacy page tests for the old page were replaced, as planned; `TravelerBookingsView` and legacy review tests are unchanged.

Not verified: no device or emulator run; `kDebugMode == false` behaviour of the demo gate is by code reading only (a const); live integration waits on BE PR #105.

Update 2026-10-23: develop gained the refund progress screen (`/bookings/:bookingId/refund`, PR #58). After merging develop, View refund opens it for the real booking id (`reviewableRecord.id`); demo mode keeps the detail sheet so a demo id never reaches the refund API. This replaces the earlier "View refund opens the sheet" decision outside demo mode.
