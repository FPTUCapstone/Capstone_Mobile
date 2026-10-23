# UC-32 Trip History — Mobile integration with the TM-78 API

## 1. Document control

| Field | Value |
| --- | --- |
| Use case | UC-32 View Trip History (Report 3 §3.7.1), Traveler, `SHARED_WEB_MOBILE` |
| Status | **Spec ready — awaiting developer approval.** No code is changed before approval. |
| Date | 2026-10-22 |
| Baseline | `develop` @ `a169dad` (see §10) |
| Branch | `feature/uc32-trip-history-api` (created after approval, AGENTS.md step 4) |
| Backend contract | `Capstone_BE/docs/TM-78-api-contract.md` (BE PR #105) |
| Web counterpart | `Capstone_FE` PR #108, `docs/UC32-API-INTEGRATION.md` (same decisions where they apply) |
| Earlier Mobile work | `specs/UC-32-UC-33-mobile-spec.md`, `plans/UC-32-UC-33-mobile-plan.md` (demo-only UC-32/33, production = pending) |

## 2. Goal

Replace the production `PENDING_BE_INTEGRATION` result behind `/traveler/trips` with the real TM-78 API and make the
screen show only what that contract returns. Production fails safely (error + Retry), never with fabricated data.

## 3. Current state (verified)

- `TripHistoryPage` + `TripHistoryCubit` + `TripHistoryCard` + `TripHistoryFiltersBar` + `RefundStatusDialog` use the
  demo-shaped `TripHistoryItem` (`id` string, `bookingCode`, `TripType {tour, commercialService, itinerary}`,
  `departureDate`, `participantsCount`, `totalAmount`, `hasEticket`, `review` with content/photos, `refundInfo`,
  `providerName`, `location`).
- `TripHistoryRepositoryImpl.getTrips` in production throws `ServerFailure(productionIntegrationPending)`; demo mode
  (`kDebugMode && ?demo=true`) reads `DemoTripHistoryStore`.
- Review actions (Write / Edit / View) navigate to the **legacy** `/traveler/trips/:tripId/review` page by a bare
  `item.id`, and Edit vs View is derived on the client from a 7-day window. The canonical review page
  `/traveler/reviews/:kind/:id` (TM-79, `AppRoutes.canonicalTripReview`) already exists.
- E-ticket shows a SnackBar (`noticeEticketPending`); there is no BE-backed e-ticket screen (UC-29).
- `TripHistoryItem`, `TripHistoryCubit` and `TripHistoryRepository` are **shared** with the Traveler shell's
  "bookings" tab (`TravelerBookingsView`, cancel + demo QR), the legacy review flow (`TripReviewCubit`, `TripReviewPage`,
  `TripReviewRepositoryImpl`, `BookingQrTicketDialog`) and about seven test files.

## 4. Decisions (developer, 2026-10-22)

1. **New model for the history page; legacy stays.** Add contract-shaped entities, repository, use case and cubit for
   `TripHistoryPage` only. `TripHistoryItem`, `TripHistoryCubit`, `TripHistoryRepository`, `DemoTripHistoryStore`, the
   bookings tab and the legacy review flow are not changed (marked `@deprecated` where they are history-specific).
2. **E-ticket:** the action shows when `canViewETicket` is true and, until UC-29 exists, opens the existing
   "e-ticket coming soon" notice. No fake ticket, no new screen.

Defaults taken from the Web decisions (the developer can change any of them): drop what the backend does not return;
keep the demo mode in the new shape; add a detail sheet on the existing screen (no new route); review actions go to
the canonical review page.

## 5. Gaps between the screen and the contract

| Screen today | TM-78 contract | Resolution |
| --- | --- | --- |
| `TripType.commercialService` filter | only `TourBooking`, `SelfPlannedItinerary` | filter offers All / Tour / Itinerary |
| `providerName`, `location`, `hasEticket` from demo data | not returned | removed; e-ticket uses `actions.canViewETicket` + `ticketId` |
| Edit Review (7-day window computed on device) | no edit deadline in the list | **removed**; Write review on `actions.canReview`, View review on `review.exists`, both open the canonical review page (which decides edit or read-only) |
| id is a string, review by bare id | pair `kind` + `id` | route `AppRoutes.canonicalTripReview(kind, id)` with `reviewableRecord` |
| refund dialog from demo `TripRefundInfo` | list has `canViewRefund`; detail has status, amount, channel | refund shown in the detail sheet |
| booking details `AlertDialog` (demo fields) | detail endpoint | detail sheet with lazy `GET …/{kind}/{id}` |
| `pendingIntegration` state | real errors | removed from the new cubit; error + Retry |
| summary / distance | only `totalCompletedTrips`, `totalVisitedPois` on Completed | optional summary line with those two |
| date range as `DateTime` | `fromDate`/`toDate` as `yyyy-MM-dd`, Vietnam days | `TripFormatters.toVietnamCalendarDay` then format |

## 6. Scope

### In scope (new files under `lib/features/trip_history/` unless noted)
1. **Domain:** `trip_record.dart` (sealed `TripRecord`: `BookingTripRecord`, `ItineraryTripRecord`), actions, review
   state, `TripRecordDetail` (booking: tour, schedule, participants, cancellation, refund; itinerary: stops with
   visit status, session), page result and summary. Reuse `ReviewableRecordRef` and `TripStatus`.
2. **Data:** `TripRecordsRepositoryImpl(DioClient)` for `GET /api/v1/traveler/trips` and `/{kind}/{id}` with strict JSON
   parsing (malformed → `ServerFailure('trip_history.invalid_response')`), Dio errors mapped to existing `Failure`
   types (`401`→`AuthenticationFailure`, `403`→`PermissionFailure`, `404`→`NotFoundFailure`,
   `400 invalid_date_range`→`ValidationFailure`, network/timeouts→`NetworkFailure`, else `ServerFailure`). The `Authorization`
   header comes from the existing `AuthInterceptor`; no token handling here.
3. **Demo:** `DemoTripRecordsRepository` + fixtures in the contract shape, selected only by the existing
   `kDebugMode && demo=true` gate; never a fallback after a real failure.
4. **Use case + DI:** `TripRecordsUseCase` (page and detail), registered in `service_locator.dart`, following the
   `CanonicalTripReviewUseCase` precedent.
5. **State:** `TripRecordsCubit` (tab, trip type, date range with MSG29 validation, paging at 20, retry, stale-response
   guard) and a small `TripRecordDetailCubit` (loading / ready / error / not found).
6. **UI:** `TripHistoryPage` switched to the new cubit; `TripHistoryCard` rewritten for `TripRecord`; filters bar
   without Commercial Service; detail bottom sheet replacing the details `AlertDialog` and `RefundStatusDialog`
   on this page. Loading, empty, error (+ Retry), pagination states kept.
7. **Docs:** `docs/mobile-api-contract.md` section for the two endpoints; deprecation notes on legacy history types.
8. **Tests** (bloc_test, fake Dio adapter as in `canonical_trip_review_repository_test.dart`): parser, repository, cubits,
   card, sheet, page, DI; legacy tests stay green and unchanged.

### Out of scope
Service bookings, the e-ticket screen (UC-29), search, cancel / refund actions, `TravelerBookingsView`, the legacy review
flow and `BookingQrTicketDialog`, `DemoTripHistoryStore`, any Administrator feature, BE changes, Android/iOS configuration.

## 7. Behaviour details

- **Pagination:** 20 per page; the backend rejects `page × pageSize > 1000`, so the cubit caps the page count at 50
  and shows an `invalid_paging` answer as the normal error state.
- **Order and totals** come from the server; the client does not sort or recount.
- **Dates:** UTC instants parsed to `DateTime`, shown with `TripFormatters.formatVietnamDate` (`dd/MM/yyyy`, UTC+7).
- **Amounts:** VND whole numbers via `TripFormatters.formatVnd`; a fractional value is rounded only for display.
- **Ids:** Dart `int` (64-bit on device); a non-positive or non-integer id makes the whole response invalid.
- **Actions** (each follows its own flag): Write review ← `actions.canReview`; View review ← `review.exists`; E-ticket ←
  `actions.canViewETicket` and a `ticketId`; View refund ← `actions.canViewRefund`; View details always; itinerary
  cards also offer the existing itinerary view when the route exists (checked in the plan).

## 8. Acceptance criteria

1. In production the history page loads real data through `DioClient`; there is no `pendingIntegration` state.
2. Tab, trip type, date range and page produce exactly the matching query; changing a filter returns to page 1.
3. Cards show only contract fields; no provider, location, edit-review button or commercial-service filter.
4. Review actions use `kind` + `id` and open the canonical review page; the e-ticket action shows the pending notice.
5. The detail sheet shows visited / skipped / not-visited stops and the session for an itinerary, and tour, schedule,
   participants, cancellation and refund for a booking, with loading, error, retry and not-found handling.
6. Demo mode still works behind its gate; a failed real request never shows fixtures.
7. `TravelerBookingsView`, the legacy review flow and all legacy tests are unchanged and green.
8. `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` pass.

## 9. Proposed tasks (detailed plan follows after approval)

| # | Task |
| --- | --- |
| 1 | Domain entities + strict JSON parsing (tests first) |
| 2 | Repository over Dio + failure mapping (fake adapter) |
| 3 | Demo repository + fixtures |
| 4 | Use case + service-locator registration |
| 5 | `TripRecordsCubit` (+ state) |
| 6 | `TripRecordDetailCubit` + detail sheet |
| 7 | Card, filters bar and page rework |
| 8 | Router wiring, docs, deprecations, final verification |

## 10. Baseline on a clean checkout (`develop` @ `a169dad`, 2026-10-22, Flutter 3.44.0 / Dart 3.12.0)

| Check | Result |
| --- | --- |
| `flutter pub get` | pass; it rewrites `pubspec.lock` (analyzer 13.3.0 → 12.1.0 etc.), which is an environment effect and is not committed |
| `dart format --set-exit-if-changed .` | pass (checked with `--output=none`) |
| `flutter analyze` | pass, no issues |
| `flutter test` | pass, 1473 tests |

## 11. Open points

- Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`, as on BE and FE (confirm for Mobile).
- BE PR #105 is not merged; tests mock the transport and do not prove live integration.
- `Stash@{0}` in this repository (create-itinerary POI picker fix) is untouched and unrelated to this task.
