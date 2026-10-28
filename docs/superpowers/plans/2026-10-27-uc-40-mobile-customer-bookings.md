# UC-40 Mobile Customer Bookings — Implementation Plan

Source of truth: `docs/superpowers/specs/2026-10-27-uc-40-mobile-customer-bookings-design.md` (Approved
2026-10-27, decisions M1–M6) and `Capstone_BE/docs/UC-40-api-contract.md` (BE PR #132, not merged yet).
Branch: `feature/uc40-view-customer-bookings` (from `origin/develop` @ `2dfd89b`). Mobile screens #84 (list) and
#85 (detail and passenger manifest).

## Working rules

- Red → Green → Refactor per task: write the failing test, run it and see it fail for the right reason, write the
  minimal code, re-run, refactor. Code written before its test is deleted and restarted.
- One task at a time; after each task run its command and review the diff against the spec. A Critical finding
  blocks the next task; a Minor one may be deferred with the developer's agreement.
- Follow `AGENTS.md` / `docs/CODEBASE_RULES.md`: feature-first Clean Architecture, `flutter_bloc` only,
  Page → Cubit → Use Case → Repository contract → Repository implementation, no raw Dio in pages or Cubits,
  Material 3 theme tokens, loading/empty/error states, no Administrator code, null safety, user-safe errors only.
- Reference patterns: `operator_tours` (use cases, Cubit, DI) and `trip_history` (`TripRecordsRepositoryImpl`
  strict parsing and own failure mapping, `DemoTripRecordsRepository` chosen by `isDemoMode`, route tests).
- Do not commit, push or open a PR until the developer chooses (Task 10).

Fast per-task check: `flutter test test/features/operator_bookings` (plus the named test files),
`dart format --set-exit-if-changed <touched paths>`, `flutter analyze`.

## Layout of the new feature

```text
lib/features/operator_bookings/
  domain/entities/operator_booking.dart               enums, list item, detail, page, summary, query, tour option
  domain/repositories/operator_bookings_repository.dart
  domain/usecases/operator_bookings_use_cases.dart    list, get detail, load tour options
  data/models/operator_bookings_json.dart             strict parsers (FormatException on any mismatch)
  data/repositories/operator_bookings_repository_impl.dart   DioClient, own failure mapping (like trip_history)
  data/repositories/demo_operator_bookings_repository.dart   + demo data, shaped like the contract
  presentation/cubit/operator_bookings_cubit.dart (+ state)
  presentation/cubit/operator_booking_detail_cubit.dart (+ state)
  presentation/pages/operator_bookings_list_view.dart        the "Bookings" tab body (#84)
  presentation/pages/operator_booking_detail_page.dart       #85
  presentation/widgets/ (booking card, summary strip, filter bottom sheet, status badges)
  resources/operator_bookings_en.dart                 English strings (CR-09)
  utils/operator_booking_formatters.dart              VND, labels, badge types
```
`lib/features/tour_operator/presentation/widgets/operator_bookings_view.dart` is deleted (Task 9).

## Task 0 — Baseline

`flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` on the clean branch.
A run was started on this branch; its result is reported with this plan. The auto-generated `pubspec.lock` diff of
the previous branch was stashed (`git stash list`), not discarded, and is not part of this work.
**DoD:** baseline recorded; any pre-existing failure is listed and agreed before Task 1.

## Task 1 — Domain entities and strict JSON parsers

- **Red:** `test/features/operator_bookings/data/operator_bookings_json_test.dart`: the exact BE contract examples
  (list with `+00:00` timestamps; detail with participants, ticket, payment, coupon) parse into entities; null
  `ticket` / `payment` / `coupon` / `checkedInAtUtc` / `meetingPoint` / phone / e-mail; an empty page; money kept
  as decimals; unknown extra fields ignored and never exposed; rejection (`FormatException`) of: non-object body,
  missing required field, unknown `status` / `paymentStatus` / `checkInStatus` / `participantType` / `gateway` /
  ticket status / blocked reason, numeric ids, non-ISO timestamps, negative or non-finite money, `quantity` < 1,
  `pageNumber` < 1, `items` not a list.
- **Green:** `operator_booking.dart` (Equatable value objects, enums with `wire` names, `OperatorBookingsQuery`
  with defaults `page 1`, `pageSize 20`, `statuses`), `operator_bookings_json.dart`.
- **Verify:** `flutter test test/features/operator_bookings/data/operator_bookings_json_test.dart`.
- **DoD:** contract examples parse; every malformed case is rejected; domain has no Flutter/Dio imports.

## Task 2 — Repository implementation (Dio)

- **Red:** `operator_bookings_repository_test.dart` with a fake `HttpClientAdapter` (pattern of
  `trip_records_repository_test.dart`): `GET /api/v1/operator/bookings` query mapping is exact (`tourId`, `status`,
  `departureFrom`, `departureTo` as `yyyy-MM-dd`, `keyword` trimmed and omitted when empty, `pageNumber`,
  `pageSize`); detail path `/api/v1/operator/bookings/{id}`; tour options from
  `GET /api/v1/operator/revenue/tours` (id + title only); error mapping: 401 → `AuthenticationFailure`, 403 and
  detail 404 → `PermissionFailure` carrying the MSG126 text, 400 `operator_booking.invalid_date_range` →
  `ValidationFailure` with the MSG31 text, 400 `invalid_filter`, 5xx and any other answer → `ServerFailure`,
  connection errors → `NetworkFailure`; a malformed body → `ServerFailure('operator_booking.invalid_response')`;
  a detail whose `bookingId` differs from the requested id is rejected; no server text reaches the failure message.
- **Green:** `operator_bookings_repository.dart` (contract), `operator_bookings_repository_impl.dart`.
- **Verify:** that test file.
- **DoD:** each row of the spec's error table has a test.

## Task 3 — Use cases and the list Cubit

- **Red:** `operator_bookings_cubit_test.dart` (`bloc_test`): `loadInitial` (loading → success with items and
  BE summary, never recomputed); status chip and keyword change reset to page 1 and reload; `loadMore` appends the
  next page without duplicates and is ignored while loading, when no more pages exist, or after a filter change
  (stale page dropped by request id); filters (tour, departure range) apply together; an inverted range emits the
  MSG31 validation message, keeps the previous list and sends no call; `clearFilters` resets in one request;
  empty result → empty state (MSG128); failures map to canonical copy only (access MSG126, MSG127) with `retry`;
  closed Cubit ignores late answers; tour options: success fills them, failure leaves `tourOptionsFailed = true`
  with no options and does not fail the list.
- **Green:** `operator_bookings_use_cases.dart`, `operator_bookings_cubit.dart`, `operator_bookings_state.dart`.
- **Verify:** that test file.
- **DoD:** spec acceptance criteria 2 (date guard) and 4 (paging, no stale/duplicate rows) covered.

## Task 4 — Detail Cubit

- **Red:** `operator_booking_detail_cubit_test.dart`: loading → success; access failure (MSG126) and generic failure
  (MSG127) with `retry`; a late answer after `close` or after a newer request is ignored; the entity keeps
  `canCancel` / `cancelBlockedReason` (no control uses them in this task).
- **Green:** `operator_booking_detail_cubit.dart`, `operator_booking_detail_state.dart`.
- **Verify:** that test file.
- **DoD:** acceptance criterion 3 for the detail covered.

## Task 5 — Demo repository and dependency injection

- **Red:** `demo_operator_bookings_repository_test.dart` (contract-shaped fixtures, filters, paging, summary on
  Confirmed + Completed only, detail by id, unknown id → `NotFoundFailure`) and
  `test/app/router/operator_bookings_di_test.dart`: `registerFactoryParam<OperatorBookingsRepository, bool, void>`
  returns the demo repository only for `isDemoMode == true` and the Dio repository otherwise; the live path never
  falls back to demo data when a call fails.
- **Green:** `demo_operator_bookings_repository.dart`, registrations in `lib/core/di/service_locator.dart`
  (repository, use cases, both Cubits with the `bool isDemoMode` parameter like `TripRecordsCubit`).
- **Verify:** those tests.
- **DoD:** demo isolated by an explicit flag; release/live wiring contains no fixture reference.

## Task 6 — Resources and formatters

- **Red:** `operator_booking_formatters_test.dart`: VND from decimals (`2400000.00` → `2,400,000 VND`, **`0` stays
  `0 VND`**, not "Free" as `TripFormatters.formatVnd` would print); Vietnam-time dates reuse
  `TripFormatters.formatVietnamDate` / `formatVietnamDateTime` (boundary at UTC 17:00); status → label and
  `StatusBadgeType` for all five statuses (incl. `Expired`), payment status, check-in status, participant type,
  gateway names.
- **Green:** `operator_bookings_en.dart` (every user string incl. MSG126, MSG127, MSG128, MSG31 texts; internal
  MSG ids are not rendered), `operator_booking_formatters.dart`.
- **Verify:** that test file.
- **DoD:** no user-facing string is hard-coded in widgets afterwards.

## Task 7 — List UI (#84)

- **Red:** `operator_bookings_list_view_test.dart` (widget): loading shimmer/indicator; cards show code, tour,
  departure date, booker name, participants, total, status badge and check-in badge; summary strip from the BE
  values; status chips including **Expired**; keyword submit via the keyboard search action; filter button opens the
  bottom sheet with tour dropdown (disabled "All tours" and a hint when options failed) and departure range
  picker, inverted range shows the MSG31 text and does not apply, Apply/Reset; empty state (MSG128); MSG126 view
  without Retry; MSG127 with Retry that reloads; "Load more" button and its loading state; tap opens
  `/operator/bookings/{id}`; small-screen and long-text layout (no overflow at width 320, large text scale);
  demo banner only when `isDemoMode`; **no** Check-in QR, refund or pickup control.
- **Green:** `operator_bookings_list_view.dart`, widgets, filter bottom sheet.
- **Verify:** that test file.
- **DoD:** acceptance criteria 1, 2, 3 (list), 4, 6 covered.

## Task 8 — Detail page (#85) and route

- **Red:** `operator_booking_detail_page_test.dart` and route test
  `test/app/router/operator_booking_route_test.dart`: the page shows the list-card basics at once, then the detail
  (tour, meeting point, booker contact incl. phone, passenger manifest as name + type, ticket and check-in time,
  payment gateway/reference/amount/time read-only, subtotal / discount / total / paid amount, coupon,
  cancellation info); null `ticket` / `payment` / `coupon` hide their blocks; failure states with Retry (MSG127) and
  MSG126; **no** cancel, refund or check-in control; the DOM/widget tree never shows participant phone, e-mail,
  nationality or ID document (the parser drops them: verified with a body that carries them); the route
  `/operator/bookings/:bookingId` resolves for an approved operator, redirects a Traveler and a non-approved
  operator (existing `RouteGuards` operator scope), rejects a non-numeric id.
- **Green:** `operator_booking_detail_page.dart`; `AppRoutes.operatorBooking` (+ path helper) and
  `AppRouteNames.operatorBooking`; the `GoRoute` in `app_router.dart` with a `BlocProvider` for the detail Cubit.
- **Verify:** those tests.
- **DoD:** acceptance criteria 3 (detail), 5, 6 covered.

## Task 9 — Shell integration and demo gating

- **Red:** update `operator_shell_page_test.dart`: the Bookings tab builds the new list view lazily (no request
  before the tab is first selected); production mode no longer shows "PENDING_BE_INTEGRATION" or any fixture;
  demo mode shows demo data and the demo badge. New router test: the operator route honours `demo=true` **only in
  debug builds** (today `/operator` reads the flag without `kDebugMode`, so a release build could serve fixtures;
  it is gated like the other routes).
- **Green:** `operator_shell_page.dart` (lazy `BlocProvider` for the bookings tab), delete
  `operator_bookings_view.dart`, add `kDebugMode &&` to the `/operator` route's demo flag.
- **Verify:** `flutter test test/features/tour_operator test/app`.
- **DoD:** acceptance criterion 7 covered; no remaining reference to the removed widget.

## Task 10 — Contract doc, full verification, finish

1. `docs/mobile-api-contract.md`: new sections for `GET /api/v1/operator/bookings`,
   `GET /api/v1/operator/bookings/{bookingId}` and the tour-options call (auth, query, fields, errors, mobile usage,
   "BE PR #132 not merged; no live call verified"); remove "bookings" from the "Explicitly Unavailable Contracts"
   list.
2. `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` (AGENTS gate);
   compare with the Task 0 baseline. `flutter build apk --debug` only if the environment supports it, reported
   either way (no Android config change is planned).
3. Review the whole diff against acceptance criteria 1–8; confirm no secrets, no generated output, `pubspec.lock`
   untouched.
4. Report and stop: merge / open a PR / keep the branch / discard, on the developer's choice only.

## Risks

| Risk | Handling |
| --- | --- |
| BE not merged/deployed: no live check | Strict parsers fail closed with a safe failure; contract doc says so; PR text will say so |
| `TripFormatters.formatVnd(0)` prints "Free" | Own VND formatter for bookings (tested), `TripFormatters` only for dates |
| Decimal money from the BE (`2400000.00`) | Entities keep `double`; display rounds to whole dong; a test pins it |
| Demo gate on `/operator` missing `kDebugMode` | Fixed and tested in Task 9 |
| Existing shell test asserts the old pending text | Updated in Task 9 as part of the behaviour change, not deleted |
| Load-more races (filter change mid-request) | Request-id guard in the Cubit, covered by tests |
| Platform: Android-only run may not be possible | Widget tests carry the behaviour; device run reported as done or not done |
