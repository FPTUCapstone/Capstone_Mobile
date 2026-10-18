# UC-44 — View Revenue Report (Mobile Plan)

## Preconditions

- Approve `specs/UC-44-view-revenue-report-mobile-spec.md`.
- Ensure clean branch `feature/linhnv-view-revenue-report` rebased from `develop`.

## Task 1 — Domain & Data Contracts

- Define domain entities (`RevenueReport`, `RevenueSummary`, `RevenueChartPoint`, `TourRevenueDetail`, `OperatorTourOption`).
- Implement data models with JSON serialization parsing Backend `/api/v1/operator/revenue/report` and `/api/v1/operator/revenue/tours`.
- Create `OperatorRevenueRemoteDataSource` and `OperatorRevenueRepositoryImpl`.
- Write unit tests for JSON parsing and failure mapping.

**Done when:** Repository unit tests succeed for successful parsing and error responses.

## Task 2 — State Management (Cubit)

- Implement `OperatorRevenueCubit` and `OperatorRevenueState`:
  - `OperatorRevenueInitial`, `OperatorRevenueLoading`, `OperatorRevenueLoaded`, `OperatorRevenueError`, `OperatorRevenueEmpty`.
- Support actions: `loadRevenueReport({DateTimeRange? dateRange, String? granularity, int? tourId})`, `updateGranularity()`, `selectTour()`.
- Add validation checking `startDate <= endDate` (`MSG29`).

**Done when:** Cubit unit tests verify state transitions (initial -> loading -> loaded / empty / error).

## Task 3 — UI Widgets & Screen Integration

- Build widgets:
  - `RevenueSummaryGrid`: KPI cards for Gross, Net, Commission, Bookings.
  - `RevenueTrendChart`: Custom lightweight bar chart for trend display.
  - `TourRevenueCard`: Expandable card displaying tour package details.
  - `RevenueFilterBar`: Quick range selector and custom date picker.
- Create `OperatorRevenuePage` and hook it into `OperatorShellPage` under the `Revenue` destination.

**Done when:** Widget tests verify rendering of loading shimmer, summary figures, chart bars, and tour list.

## Task 4 — Quality Verification

- Run `dart format --set-exit-if-changed .`
- Run `flutter analyze`
- Run `flutter test`
