# UC-44 — View Revenue Report (Mobile Plan)

## Preconditions

- Approve `specs/UC-44-view-revenue-report-mobile-spec.md`.
- Ensure clean branch `feature/linhnv-view-revenue-report` rebased from `develop`.

## Task 1 — Domain & Data Contracts

- Define domain entities (`RevenueReport`, `RevenueSummary`, `RevenueChartPoint`, `TourRevenueDetail`, `OperatorTourOption`), including payments received, discounts, refunds, commission rate, and active/historical tour-option metadata.
- Implement data models with JSON serialization parsing Backend `/api/v1/operator/revenue/report` and `/api/v1/operator/revenue/tours`.
- Create `OperatorRevenueRemoteDataSource` and `OperatorRevenueRepositoryImpl`.
- Write unit tests for JSON parsing and failure mapping.

**Done when:** Repository unit tests succeed for successful parsing, historical tour options, and error responses.

## Task 2 — State Management (Cubit)

- Implement `OperatorRevenueCubit` and `OperatorRevenueState`:
  - `OperatorRevenueInitial`, `OperatorRevenueLoading`, `OperatorRevenueLoaded`, `OperatorRevenueError`, `OperatorRevenueEmpty`.
- Support actions: `loadRevenueReport({DateTimeRange? dateRange, String? granularity, int? tourId})`, `updateGranularity()`, `selectTour()`.
- Add validation checking `startDate <= endDate` (`MSG29`).

**Done when:** Cubit unit tests verify state transitions (initial -> loading -> loaded / empty / error).

## Task 3 — UI Widgets & Screen Integration

- Build widgets:
  - `RevenueSummaryGrid`: four primary KPI cards for Gross, Net, Commission, and Bookings/Travelers, with an expandable settlement detail for Payments Received, Discounts Given, and Refunded Amount.
  - `RevenueTrendChart`: Custom lightweight bar chart for trend display using server-provided period labels and values without client-side regrouping.
  - `TourRevenueCard`: Expandable card displaying tour package details.
  - `RevenueFilterBar`: Quick range selector and custom date picker.
- Create `OperatorRevenuePage` and hook it into `OperatorShellPage` under the `Revenue` destination.

**Done when:** Widget tests verify rendering of loading shimmer, four primary KPI figures, expandable settlement detail, server-provided chart labels, and tour list.

## Task 4 — Quality Verification

- Run `dart format --set-exit-if-changed .`
- Run `flutter analyze`
- Run `flutter test`
