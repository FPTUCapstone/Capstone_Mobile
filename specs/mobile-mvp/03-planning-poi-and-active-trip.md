# 03 — Planning, POI and Active Trip (Screens #47–#54, UC-10…UC-16, UC-72)

> **Revision 2026-10-08.** PR #24 merged on 2026-10-04 (`bdd1f12`); the "OPEN PR" records O-49/O-52/O-53/O-54 now describe code on develop. Within the 25-UC MVP only UC-10 (#47) and UC-16 (#49) apply; UC-11–UC-15 and UC-72 are preserved out-of-scope dependencies. Current UC-16 completion contract: `13` S-49. **QA correction:** P-47 below is labelled `MERGED_IMPLEMENTED`/`IMPLEMENTED_BE_INTEGRATED`; against V2 it is `IMPLEMENTED_PARTIAL` — the BE-integrated one-day model does not implement V2 §3.3.1 (date range ≤ 30 days, travelers, interest tags, pace). V2 is not narrowed; see `00` C-05, `13` S-47, decision D-02. **Historical blockers in Part 2:** "BLOCKER 6 UNRESOLVED" (fabricated trip titles) and "BLOCKER 7 UNRESOLVED" (unguarded package contents) were re-checked on develop `acfde81`: both are resolved for production — fallback titles and package sizes are rendered only in the `kDebugMode && ?demo=true` path (`00` §E). Demo-only CR-09 issues remain (A-01).

Standards: `C-*` in `01-mobile-shells-and-navigation.md` §1.
Business rule numbers (BR-25…BR-40, PC-01…PC-04) are quoted from the PR #24 spec `specs/mobile-active-trip-uc13-uc16-spec.md`, which cites Report 3 §3.3.4–§3.3.7. The full R3 text was not available to this audit → `SRS_TEXT_REQUIRED` for anything not quoted there.

---

## Part 1 — EXISTING SCREEN PRESERVATION RECORDS

### P-47 Trip / Itinerary Planner (UC-10) — `MERGED_IMPLEMENTED`, `IMPLEMENTED_BE_INTEGRATED`
- Route `/traveler/itineraries/create` · page `create_itinerary_page.dart` (741 lines) · Cubits `CreateItineraryCubit`, `PoiSearchCubit` · repositories `ItineraryRepositoryImpl.generate`, `PointOfInterestRepositoryImpl.search` · device: GPS via `geolocator_poi_location_service`.
- Tests: `create_itinerary_page_test`, `create_itinerary_cubit_test`, `itinerary_generation_model_test`, `itinerary_generation_test`, `poi_search_cubit_test`, `selectable_poi_*_test`.

**BACKEND INTEGRATION CONTRACT**
- Screen/Route: #47 `/traveler/itineraries/create`
- API 1: `POST /api/v1/scheduling-requests` · Auth: Traveler JWT · Header `Idempotency-Key` (client-generated, **reused on retry**, new key when the intent changes — rules §15, tests `I01–I05`)
- Request: `startAt, timeZoneId, startLatitude, startLongitude, explorationLatitude, explorationLongitude, endPoiId, returnToStart, availableMinutes, transportMode, searchRadiusKm, budgetVnd, mandatoryPoiIds, restPreference`
- Response (keys parsed): `schedulingRequestId, itineraryId, title, status, totalEstimatedCost, totalDurationMinutes, items[]` with item keys `sequenceNo, poiId, poiName, itemKind, plannedArrival, plannedDeparture, stayDurationMinutes, travelDurationToNextMinutes, estimatedCost, isMandatory, recommendationReason`
- Status mapping: HTTP `429` → `RoutingProviderFailure` (routing provider busy); other failures through `ErrorMapper`
- API 2 (mandatory-POI picker): `GET /api/v1/points-of-interest/search` · Auth Traveler · Query `page` (≥1), `pageSize` (default 50), optional `query`; location search requires **all** of `latitude, longitude, radiusKm` or none (client enforces) · Response `items[]` + `totalCount` (item keys: `id, name, address, latitude, longitude, averageVisitDurationMinutes, estimatedVisitCost, openingHoursKnown, hasShelter, categoryName`)
- Pagination: page/pageSize · Upload: none · Deep link: none · Caching: none
- Device: GPS permission for "use my location"
- Components: `CreateItineraryCubit`, `PoiSearchCubit`, `ItineraryRepository`, `PointOfInterestRepository`, `DioClient`
- **INTEGRATION CONTRACT: FROZEN**
- Safe to change: layout, step grouping, field presentation, validation message styling, visuals (`l_p_k_ho_ch_chuy_n_i_csp_engine_tripmate`, `s_th_ch_du_l_ch_tripmate`).
- MUST NOT change: request field names/units, idempotency-key lifecycle, 429 mapping, location-search all-or-none rule, route + `extra` hand-off to #48.
- Known limitation (not a regression): preferences (#46) are local-only, so the Planner must not claim to use saved preferences until BE owns them.

### P-48 Suggested Itinerary (UC-11) — `MERGED_IMPLEMENTED`, `IMPLEMENTED_BE_INTEGRATED`
- Routes: `/traveler/itineraries/result` (extra = `GeneratedItinerary` from #47; any other extra → "Your itinerary is unavailable.") and `/traveler/itineraries/:itineraryId` (persisted detail). Pages `itinerary_result_page.dart`, `itinerary_detail_page.dart`; Cubit `ItineraryDetailCubit`; repository `ItineraryRepositoryImpl`.
- Tests: `itinerary_detail_page_test`, `itinerary_detail_cubit_test`, `itinerary_detail_model_test`, `itinerary_result_page_test`.

**BACKEND INTEGRATION CONTRACT**
- API read: `GET /api/v1/itineraries/{itineraryId}` · Auth Traveler JWT (owner only; `canManage` is Backend-derived)
- Response keys: `itineraryId, schedulingRequestId, title, version, status, validFrom, validTo, canManage, totalEstimatedCost, totalDurationMinutes, items[]`; item keys `itemId, sequenceNo, poiId, poiName, category, kind, plannedArrival, plannedDeparture, travelDurationFromPreviousMinutes, stayDurationMinutes, estimatedCost, isMandatory, recommendationReason, isUnavailable`
  - **Note:** the persisted detail uses `kind` / `travelDurationFromPreviousMinutes` while the creation response uses `itemKind` / `travelDurationToNextMinutes`. Both are real and must stay separate models.
  - **Note:** the detail items carry **no coordinates**. This matters for #52 (see below).
- Mutations: `POST /api/v1/itineraries/{id}/accept` (no body) · `POST /api/v1/itineraries/{id}/regenerate` (header `Idempotency-Key`) · `PUT /api/v1/itineraries/{id}/items` body `{ orderedVisitPoiIds: [int] }` (header `Idempotency-Key`). All return the updated detail.
- Status mapping: status string compared case-insensitively; PR #24 gates navigation on `active`.
- Route params: `itineraryId` (int > 0, otherwise error view) · Deep link: `/traveler/itineraries/:id` valid after guard + login · Caching: none
- Components: `ItineraryDetailCubit`, `ItineraryRepository`
- **INTEGRATION CONTRACT: FROZEN**
- Safe to change: timeline visuals, stop cards, summary header, action bar layout (`chi_ti_t_l_ch_tr_nh_timeline_tripmate`), map preview slot (`MAP_INTEGRATION_PENDING`).
- MUST NOT change: field names above, accept/regenerate/adjust semantics and idempotency keys, ownership enforcement (server decides), error view for invalid id.
- SRS note: UC-11 is a "Timeline/map result view". The timeline exists; a real map does not (`MAP_INTEGRATION_PENDING`, no provider approved).

**MISSING PART (specification only)** for #48
- **Entry points to Active Trip:** "Start Navigation" (#52) and "Download for Offline Use" (#49) are added by PR #24 on the result page; they are absent from develop. Do not duplicate them; review them in PR #24.
- **Group creation entry:** exists (`CreateTravelGroupRouteArgs`).
- **Itinerary list:** no list of the user's itineraries (no BE endpoint) → "Chuyến đi" tab cannot show saved trips. `TRAVELER_TRIP_LIST_CONTRACT_MISSING`.
- **Version history / BR-26/27** (re-route creates version V+1, old version retained) is Backend-owned; the screen only displays `version`.

### P-50 POI Explore / List (UC-12) — `MERGED_IMPLEMENTED`, `IMPLEMENTED_BE_INTEGRATED`
- Route `/explore` (public) · `explore_poi_page.dart` (659 lines) · `PoiListCubit` · `GetPoisUseCase` · `PoiRepositoryImpl` → `PoiRemoteDataSource` · device GPS (`GetPoiLocationUseCase`).
- Tests: `explore_poi_page_test`, `poi_list_cubit_test`, `poi_repository_impl_test`, `poi_models_test`, `poi_query_test`, `poi_map_projection_test`.

**BACKEND INTEGRATION CONTRACT**
- API: `GET /api/v1/pois` · Auth: **none** (`skipAuth`) · public
- Query: `page, pageSize, search, sort (name|distance|rating), openNow, originLatitude, originLongitude`, plus category filter (`categoryId`) held in the query state
- Response: `{ page, pageSize, totalCount, totalPages, items[] }`; item keys `id, name, address, latitude, longitude, categoryId, categoryName, averageRating, reviewCount, distanceKm, thumbnailUrl, isOpenNow, hasShelter, indoorOutdoor, averageVisitDurationMinutes`
- Pagination: page-based with `totalPages`. Empty vs failed distinguished by the cubit.
- Category chips: **`poiCategoryPreviewFixtures` is DEMO_ONLY** — rendered only when the build flag `POI_CATEGORY_PREVIEW` is true (default off) because no authoritative category catalogue endpoint exists (rules §34 / L20). Do not hard-code category IDs in production.
- Device: GPS permission (optional; sort by distance requires origin)
- **INTEGRATION CONTRACT: FROZEN.** Safe: card layout, filters presentation, map preview styling. Must not change: query names, `sort` values, `skipAuth`, the category-fixture gating, empty/error distinction.

### P-51 POI Details (UC-12) — `MERGED_IMPLEMENTED`
- Route `/explore/poi/:id` (public) · `poi_detail_page.dart` · `PoiDetailCubit` · `GetPoiDetailUseCase`.
- API: `GET /api/v1/pois/{id}` · Auth none · Response keys: `id, name, description, address, latitude, longitude, categoryId, categoryName, averageRating, reviewCount, averageVisitDurationMinutes, hasShelter, indoorOutdoor, scenicScore, status, tags, openingHours[] (dayOfWeek, openTime, closeTime, isClosed), photos[] (url, caption, sortOrder, photoRating), isOpenNow, createdAtUtc, updatedAtUtc`. Nullable/optional fields (e.g. description, photos) must stay accepted (rules §34 nullability row; known earlier regression).
- Map: `poi_map_preview.dart` + `poi_map_projection.dart` are a custom projection, **`MAP_INTEGRATION_PENDING`**.
- **FROZEN.** Safe: gallery, hours table, sticky action. Must not change: nullable handling, public access, route id typing.

---

## Part 2 — OPEN PR PRESERVATION RECORDS (PR #24, head `31990be`) — do not duplicate, do not redesign

Common record: PR #24 `feat(traveler): implement active trip navigation experience`, branch `feature/mobile-active-trip`, OPEN, `REVIEW_REQUIRED`, CI green, human review by `PQKhanh294` (two COMMENTED reviews: P1 findings at `fdfe1cb`, BLOCKERs at `31990be`). Author reply claims fixes in `31990be`. Details: `11-open-pr-and-review-register.md`.

### O-52 Live Trip Navigation (UC-13) — `OPEN_PR_REVIEW_REQUIRED`
| Item | Record |
|---|---|
| Current design | `ActiveTripPage` (937 lines), `NavigationMapCanvas` (custom vector preview), `ActiveTripCubit`; upcoming-maneuver banner, waypoint progress, GPS pill (Signal Lost / Acquiring / Normal / Arrived), deviation detection, arrival advancement |
| Implementation nature | `DEVICE_ONLY` + UI; **no Backend integration** (no network DTO) |
| Review blocker | **BLOCKER 6 UNRESOLVED:** `app_router.dart:271` falls back to `'Đà Nẵng Day Trip'` when `state.extra` is not a `String`; default `title` also hard-coded in `active_trip_page.dart:19`. A deep link or restored route shows an invented trip name. |
| Resolved earlier | demo opt-in only (`isDemoMode` default false, `kDebugMode`), Start Navigation gated on Active, single-decision reroute, longitude 0.0 valid |
| Missing requirement | (a) itinerary identity: resolve title/status from `itineraryId` via the **existing** `ItineraryRepository.getById` → states loading / real metadata / error (not found, forbidden, not Active) (b) **waypoint coordinates:** persisted itinerary items have no latitude/longitude (see P-48). Real navigation needs coordinates from a Backend-owned source — either an itinerary representation that includes them or per-POI reads of `GET /api/v1/pois/{id}`; decision is BE/Mobile joint, `ITINERARY_ITEM_COORDINATES_REQUIRED` (c) BR-28 permission gate visible when location denied (d) BR-40 offline fallback needs #49 package |
| Integration boundary | GPS device service ↔ domain waypoint progress. Arrival must be position-driven (manual arrival is `DEMO_ONLY`). Map rendering = `MAP_INTEGRATION_PENDING`. Route guidance (BR-35) belongs to the map service, not TripMate |
| Future Backend dependency | `ACTIVE_TRIP_SESSION_CONTRACT_MISSING` (start session, record reached waypoints, conclude) |
| Design permission | NONE for redesign; MISSING_PART_ONLY for the metadata/permission states above |

### O-53 Real-Time Trip Alert (UC-14) — `OPEN_PR_PARTIAL`
| Item | Record |
|---|---|
| Current design | `TripAlertBanner` (dismissible), `TripAlertsSheet`, `TripAlertsPage` (`/traveler/trips/:id/alerts`), severity Info/Warning/Critical |
| Nature | UI only; production alert list is empty (truthful) — no alert source |
| Review blocker | none specific; inherits blocker 6 only through the title |
| Missing requirement | BR-32 retention (dismissing the banner keeps the alert in the list until the trip completes) is implemented in the cubit per PR spec; **alert source is absent** |
| Boundary | no notification source is invented. Push notifications need a device integration that does not exist (`DEVICE_INTEGRATION_MISSING`). Severity must stay icon + text + colour |
| Future Backend dependency | `REAL_TIME_ALERT_CONTRACT_MISSING` |
| SRS note | `SRS_ALERT_TAXONOMY_CONFLICT` (BR-29 formal types vs catalogue categories) — recorded in the PR spec; keep semantic types |

### O-54 Re-routing Proposal (UC-15) — `OPEN_PR_PARTIAL`
| Item | Record |
|---|---|
| Current design | `RerouteProposalSheet` with reason, ETA diff, stop-count diff, optional cost/distance, explicit Accept / Decline |
| Nature | UI + cubit state machine; proposals exist only in demo; **no proposal source and no persistence** |
| Resolved | single decision: accept/decline/expire all require `RerouteStatus.pending` (terminal afterwards); no auto-apply (BR-31/BR-33) |
| Missing requirement | persistence of accepted plan as version V+1 and retention of old version (BR-26/BR-27) is Backend-owned; the client must not show "route updated" as persisted until Backend confirms (`reroute persistence` is on the truthfulness list) |
| Boundary | optimistic update **NO**: acceptance outcome is displayed from Backend response only once a contract exists; until then production never shows a proposal |
| Future Backend dependency | `REROUTING_CONTRACT_MISSING` |

### O-49 Offline Map & Itinerary (UC-16) — `OPEN_PR_REVIEW_REQUIRED`
| Item | Record |
|---|---|
| Current design | `OfflineTripPackagePage` (518 lines), `OfflineTripPackageCubit`; states notDownloaded, checkingStorage, downloading (progress), available, insufficientStorage, networkInterrupted, superseded, error |
| Nature | UI + simulated state machine; **no download service, no filesystem, no Backend** |
| Review blocker | **BLOCKER 7 UNRESOLVED:** `offline_trip_package_page.dart:172-181` always renders a "Package Contents" card with hard-coded rows (`Map area tiles 85.0 MB`, `18 km radius`, `Itinerary schedule & route geometry 2.5 MB`, `POI descriptions 31.0 MB`) outside any `isDemoMode` guard. Also blocker 6 default title `'Đà Nẵng City Explorer'` (`app_router.dart:308`, cubit, page). |
| Production behaviour already correct | `download()` in non-demo emits `error: 'Offline download service is currently unavailable.'` (truthful) |
| Required correction (future, not done here) | production → capability-unavailable state: no package breakdown, no sizes, no radius; storage ceiling card (BR-37, 150 MB) shown only when a Backend-provided package size exists; breakdown/progress simulation allowed only in explicit `DEMO_ONLY` |
| Missing requirement | BR-38 integrity (partial package never "available"), local persistence boundary, supersede handling (server version increments), UC-72 sync status indicator (below) |
| Device boundary | offline filesystem and connectivity are separate device services (not generic repositories); `DEVICE_INTEGRATION_MISSING` |
| Future Backend dependency | `OFFLINE_SOURCE_DATA_CONTRACT_MISSING`, `UC72_SYNC_CONTRACT_PARTIAL` |

---

## Part 3 — UC-72 Synchronize Offline Trip Data (`BACKGROUND_PROCESS`, no page)

- **Trigger:** connectivity restored while buffered offline actions exist (e.g. check-ins made offline).
- **Visible result:** a non-blocking indicator on the Active Trip shell / trip detail ("Syncing…", "Synced", "Some items could not sync — retry") and, when relevant, in notification surface. No standalone screen unless R3 defines one.
- **Error result:** failed items stay visible as pending; user can retry; nothing is shown as synced until Backend acknowledges.
- **Retry:** automatic on connectivity change with bounded backoff; manual retry affordance.
- **Authoritative owner:** Backend. The BE schema contains `trip.OfflineSyncBatches` / `trip.OfflineSyncItems`, but no API controller exists (per PR #24 spec; BE controllers on develop confirm none) → `UC72_SYNC_CONTRACT_PARTIAL`.
- **Optimistic update:** NO.

## Part 4 — Cross-checks against the Dev & Cross-Review Checklist v2.2

| Check | Where it applies here |
|---|---|
| C57 / L20 no hard-coded catalogue IDs | #50 category chips (already gated) |
| C55 / L18 nullable fields accepted | #51 detail, #48 detail (`title`, `validFrom/To`, `category`) |
| C58 / U03 no-op and stale response states | #50 search/filter, #47 POI picker |
| U04 empty/404 image | #50/#51 images and photos (fallback placeholder, no fabricated image) |
| V04 map real vs preview | #48, #51, #52, #49 stay `MAP_INTEGRATION_PENDING` — must not be reported as "map delivered" |
| I01–I05 idempotency | #47 generate, #48 regenerate/adjust (already in keys) |
