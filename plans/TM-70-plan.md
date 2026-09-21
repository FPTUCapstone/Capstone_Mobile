# TM-70 / UC-24 — Mobile Tour Search Implementation Plan

## 1. Overview & Objective
Implement the public tour search screen for TripMate Mobile (TM-70 / UC-24).
Actors: Guest (unauthenticated) and Traveler (authenticated).
The screen allows searching and filtering public tours from the real backend API (`GET /api/v1/tours`) without mock data or hardcoded tour lists.

## 2. Architectural Design & Boundaries
Follow Feature-First Clean Architecture matching existing POI feature conventions:
- **Presentation**: `lib/features/tour_search/presentation/`
  - Cubit for state management (`TourSearchCubit`, `TourSearchState`).
  - Feature theme tokens (`TourSearchPalette`).
  - Widgets: `TourListCard`, `TourSearchFilterSheet`.
  - Pages: `TourSearchPage`.
- **Domain**: `lib/features/tour_search/domain/`
  - Entities: `TourSummary`, `PagedTourResult`, `TourSearchQuery`, `AvailabilityStatus`.
  - Repository contract: `TourSearchRepository`.
  - Use case: `SearchToursUseCase`.
- **Data**: `lib/features/tour_search/data/`
  - DTO & Mappers: `TourSearchPageModel`, `TourSearchItemModel`.
  - Remote Data Source: `DioTourSearchRemoteDataSource` via centralized `DioClient` with `skipAuth: true`.
  - Repository Impl: `TourSearchRepositoryImpl` with `ErrorMapper.toFailure`.

## 3. Strict Scope & Boundaries
### In Scope:
- Public anonymous browsing via `GET /api/v1/tours`.
- Filters: `destination` (max 300 UTF-16 code units), `departureDate` (`yyyy-MM-dd`), `minPrice` & `maxPrice` (`0 <= minPrice <= maxPrice <= 9,999,999,999`).
- Client-side validation: destination length, price range limits, minPrice <= maxPrice.
- Reset filters to initial query and page 1.
- Infinite scroll pagination (trigger load more at 85% scroll extent, deduplicate by `tourId`).
- Correct availability status display: `available`, `soldOut`, `noUpcomingSchedule`, `unknown` ("Tình trạng chỗ chưa xác định").
- Safe currency formatting (display `₫` for VND, currency code for non-VND).
- Full UI states: loading skeleton, success list, empty state, error state with retry, pull-to-refresh, load-more spinner.
- Clear entry point in existing UI navigation.

### Out of Scope:
- TripMatch Persona and recommendation carousel (TM-71 / UC-25).
- Mock images, star ratings, review counts.
- Favorite / save tour actions.
- Verified badges, category chips, sort dropdown.
- Booking flow ("Đặt ngay") and Tour Detail page (TM-72 / UC-26).

## 4. Implementation Tasks & Verification
1. **Domain Layer**:
   - Entities: `AvailabilityStatus`, `TourSummary`, `PagedTourResult`, `TourSearchQuery`.
   - Validation on query bounds: destination <= 300, 0 <= minPrice <= maxPrice <= 9,999,999,999.
   - Tests: `availability_status_test.dart`, `tour_search_query_test.dart`.
2. **Data Layer**:
   - Manual deserialization: `TourSearchPageModel`, `TourSearchItemModel`.
   - Data source with `skipAuth: true`.
   - Repository implementation with failure mapping.
   - Tests: `tour_search_page_model_test.dart`, `tour_search_repository_impl_test.dart`.
3. **Presentation Layer**:
   - Cubit handling initial load, pagination, filters, reset, and errors.
   - Tour card with currency check and Vietnamese departure time (UTC+7).
   - Filter bottom sheet with date picker and price inputs.
   - Tests: `tour_search_cubit_test.dart`, `tour_list_card_test.dart`, `tour_search_filter_sheet_test.dart`, `tour_search_page_test.dart`.
4. **Integration**:
   - DI registration in `service_locator.dart`.
   - Centralized route `AppRoutes.tourSearch = '/explore/tours'`.
   - Navigation entry point from Explore page / Traveler home.
5. **Quality Gates**:
   - `dart format --set-exit-if-changed .`
   - `flutter analyze`
   - `flutter test`
   - `flutter build apk --debug`
