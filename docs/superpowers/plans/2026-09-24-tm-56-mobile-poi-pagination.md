# TM-56 Mobile POI Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the UC-10 POI picker load all API search results as a Traveler scrolls near the end.

**Architecture:** The data result retains items and `totalCount`; repository calls include page information. `PoiSearchCubit` owns query generation, page state, loading-more state and accumulated results. The bottom sheet owns/disposes a scroll controller and asks the Cubit for another page near the end.

**Tech Stack:** Flutter, Dart, flutter_bloc, Dio, bloc_test, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-09-24-tm-56-mobile-poi-pagination-design.md`

## Global Constraints

- JSON stays in Data; Cubit calls the Domain repository; UI does not call Dio.
- Page size is 50; do not request beyond `totalCount` or concurrently for a query.
- Superseded/closed operations cannot emit or append.
- Multi-day is authoritative; one-day UI remains unchanged here.

## Review Focus

- A page-two response after a new search cannot append.
- Repeated near-end scrolling triggers exactly one page request.
- A short page with a larger total cannot duplicate IDs.
- Picker closure during request produces no lifecycle error.
- Selected page-one POIs remain selected after append.

---

### Task 1: Make result/model/repository page-aware

**Files:**
- Modify: `lib/features/traveler/data/models/selectable_poi_search_result_model.dart`
- Modify: `lib/features/traveler/domain/repositories/point_of_interest_repository.dart`
- Modify: `lib/features/traveler/data/repositories/point_of_interest_repository_impl.dart`
- Modify: `test/features/traveler/data/models/selectable_poi_search_result_model_test.dart`
- Modify or create: `test/features/traveler/data/repositories/point_of_interest_repository_impl_test.dart`

**Interfaces:** Produces domain `SelectablePoiSearchResult(items, totalCount)` and `search(..., required int page, int pageSize = 50)`.

- [ ] Write failing tests for `totalCount` parsing, `page=2&pageSize=50` parameters, and malformed/missing totals yielding `FormatException`.
- [ ] Run `flutter test test/features/traveler/data/models/selectable_poi_search_result_model_test.dart test/features/traveler/data/repositories/point_of_interest_repository_impl_test.dart`; expect RED.
- [ ] Implement data-to-domain result mapping and page-aware repository call while preserving existing location validation.
- [ ] Rerun the focused tests; expect GREEN; commit `feat(traveler): page selectable POI search results`.

### Task 2: Add safe page append behavior to PoiSearchCubit

**Files:**
- Modify: `lib/features/traveler/presentation/cubit/poi_search_state.dart`
- Modify: `lib/features/traveler/presentation/cubit/poi_search_cubit.dart`
- Modify: `test/features/traveler/presentation/cubit/poi_search_cubit_test.dart`

**Interfaces:** Consumes page-aware repository search and produces `loadMore()`, `totalCount`, `isLoadingMore`, accumulated unique results.

- [ ] Write failing Cubit tests for append, duplicate-call suppression, exhaustion, stale page suppression after a new search, and closed-Cubit suppression.
- [ ] Run `flutter test test/features/traveler/presentation/cubit/poi_search_cubit_test.dart`; expect RED.
- [ ] Store normalized active parameters, guard with query generation and `isClosed`, and deduplicate POIs by ID before emitting.
- [ ] Rerun focused tests; expect GREEN; commit `feat(traveler): append POI search pages safely`.

### Task 3: Trigger next page from picker scroll position

**Files:**
- Modify: `lib/features/traveler/presentation/pages/create_itinerary_page.dart`
- Modify: `test/features/traveler/presentation/pages/create_itinerary_page_test.dart`

**Interfaces:** Consumes `PoiSearchCubit.loadMore()` and `PoiSearchState.isLoadingMore`; produces automatic load at `extentAfter <= 200`.

- [ ] Write a failing widget test that opens a 50-item picker with a larger total, scrolls near the end, completes page two, and confirms page one/selected items persist.
- [ ] Run `flutter test test/features/traveler/presentation/pages/create_itinerary_page_test.dart`; expect RED.
- [ ] Add and dispose one `ScrollController`, call `loadMore` at threshold, and append a non-interactive Material loading footer during the request.
- [ ] Rerun widget test; expect GREEN; commit `feat(traveler): load more POIs while scrolling`.

### Task 4: Validate and refresh PR #18 evidence

**Files:**
- Modify remotely: PR #18 description.

- [ ] Run `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `git diff --check`.
- [ ] Update PR #18 with final SHA and actual results, replace stale test/APK claims, include the multi-day decision, then push and request exact-SHA re-review.
