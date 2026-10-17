# UC-26 View Tour Details — Mobile spec

Status: **PROPOSED — awaiting developer approval.**

SRS: Report 3 §3.5.3 (UC-26), BR-54, BR-56, BR-59, BR-60, BR-96, MSG65, MSG127, MSG128.
Platform: `SHARED_WEB_MOBILE` (`Capstone_FE/docs/WEB_SCOPE_MATRIX.md`, row UC-26); Mobile screen #65 "Tour Details".
Backend contract: `Capstone_BE` PR #93 (`feature/uc26-view-tour-details`), `GET /api/v1/tours/{tourId}`.
Web counterpart: `Capstone_FE` PR #90. **Merge order: Backend PR first.**

## What exists on develop (`b461698`, PR #31 merged)

`features/tour_detail` has the full screen (cubit, state, 1 381-line page, strings, entities), a
`DemoTourDetailDataSource` (debug only, `?demo=true`) and a `PendingTourDetailDataSource` that is what the
service locator registers today. Production therefore always shows the "awaiting Backend integration" view; there is
no real data source. Tour search (UC-24) already opens this page with a `TourSummary` as `extra`.

## Scope

In: a real remote data source and strict model for `GET /api/v1/tours/{id}`, the entity/UI changes needed to show the
real contract, honest not-found / error / retry states, server-driven bookability, tests.
Out: UC-25 recommendations, the UC-27 booking flow itself (Book Now keeps its current handoff), a public review
list (the API returns the aggregate only), any Backend or Web change, removing the debug demo mode.

## Contract consumed

`tourId`, `title`, `description?`, `destination`, `destinations[]`, `durationDays`, `basePrice`, `currency`,
`operator{name, contactPhone?}`, `images[{url, altText, caption?, isPrimary}]`, `inclusions?`, `exclusions?`,
`cancellationPolicy{rules[{daysBeforeDeparture, cancellationFeePercent}]}`,
`itinerary[{dayNo, items[{sequenceNo, poi{poiId,name,address?,latitude,longitude}, plannedTime?, stayDurationMinutes, notes?}]}]`,
`schedules[{scheduleId, startAtUtc, endAtUtc, meetingPoint?, registrationDeadlineAtUtc?, adultPrice, childPrice?, infantPrice?,
remainingSlots?, availabilityStatus (available|soldOut|unknown), bookable}]`, `hasBookableSchedule`,
`rating{average?, count}`, `asOfUtc`. Ids are strings, prices whole VND, times UTC.

## Design (Page → Cubit → Use Case → Repository → Data Source, as the repo requires)

1. **Model** `TourDetailModel.fromJson`: validates every field (type, nullability, closed `availabilityStatus` set) and
   throws `FormatException` on anything else; follows `TourSearchPageModel`. `toEntity()` maps to the domain entity.
2. **Data source** `DioTourDetailRemoteDataSource implements TourDetailDataSource`: `GET /api/v1/tours/{id}` with
   `skipAuth` (public). 404 → `null` (the cubit already turns `null` into the not-found state, MSG65);
   other non-2xx, network errors and malformed bodies throw (cubit → MSG127 + Retry). A non-numeric id returns
   `null` without a request. Registered in `service_locator.dart` instead of `PendingTourDetailDataSource`.
3. **Entities** (additive, keep demo data valid): `TourDetail` gains `destinationSummary`, `cancellationRules`,
   `hasBookableSchedule`, `asOfUtc`; `TourItineraryDay` gains `stops` (`TourItineraryStop`: poiName, address,
   plannedTime, stay minutes, notes); `TourScheduleItem` gains `endAtUtc`, `meetingPoint`, `registrationDeadlineUtc`,
   `childPrice`, `infantPrice`, `bookable` and `totalSlots` becomes optional; `operatorEmail` stays optional (real data: null).
4. **Cubit**: first selectable departure is preselected, where selectable = `bookable ?? !isSoldOut`; selecting a
   non-selectable one shows MSG65. The `pendingIntegration` production state is removed from the real path
   (demo mode untouched). New `failureKind` (`notFound` vs `unavailable`) so Retry is offered only for failures.
5. **UI** (strings stay English like the rest of the app): itinerary stops with time, place, address, stay and notes;
   cancellation rules as a list of notice ranges; destinations; per-departure meeting point and child/infant prices;
   departures listed with their real state (`Registration closed`, `Sold Out`, `Capacity unknown`); Book Now enabled only
   for a bookable departure (BR-60) and, for a Guest, the existing "Sign In Required" dialog; reviews: count 0 → MSG128,
   count > 0 → aggregate only with a note that individual reviews are not listed yet; "slots as of {time}, not a
   reservation" note (BR-59). Departure and return times are shown in Vietnam time (UTC+7), not the device zone.
6. **Accessibility**: schedule cards keep a semantic label with date and slots; error and loading states are announced;
   touch targets ≥ 48 dp.

## Acceptance criteria

1. A real payload renders every section; a malformed payload shows the error state, never a partial screen.
2. 404 → MSG65 state without Retry; network, 5xx or invalid body → MSG127 with a working Retry.
3. Production never uses demo or pending data; `?demo=true` still works only in debug builds.
4. A closed, sold-out or unknown-capacity departure cannot be selected for booking; Book Now is disabled when none is bookable.
5. Rating `count = 0` shows MSG128; `count > 0` shows the aggregate without invented reviews.
6. `flutter analyze` is clean and `flutter test` passes; the screen is verified on an Android emulator against the real
   local Backend (see UAT below).

## UAT on Android (after implementation)

The machine has Flutter but no Android SDK, `adb` or emulator. After the code is done I will walk the developer through
installing Android Studio / SDK command-line tools and creating an AVD, then run the app with
`--dart-define=API_BASE_URL=http://10.0.2.2:5021` against the UC-26 UAT database and Backend. A debug build needs
cleartext HTTP to the local Backend: **decision needed** — either (a) an uncommitted local debug manifest overlay used
only for UAT (recommended, no repo change), or (b) a committed `android/app/src/debug/AndroidManifest.xml` with
`usesCleartextTraffic="true"` (debug builds only).

## Risks / notes

- The release manifest has no `INTERNET` permission (only the debug overlay does; a local uncommitted edit exists in the
  developer's primary checkout). That is outside UC-26 but release builds cannot reach any API until it is fixed.
- Two published versions of the same tour can both be visible until the UC-35 publish flow supersedes the old one.
