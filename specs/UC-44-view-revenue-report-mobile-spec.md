# UC-44 — View Revenue Report (Mobile Specification)

## Status

Draft for approval. This specification defines the Flutter Mobile architecture, UI components, state management, and backend consumption for Tour Operator Revenue Reporting (UC-44).

## Scope

Allows a signed-in Tour Operator on the mobile application to view financial summaries, revenue trends, and per-tour breakdowns directly from the Operator Shell's **Revenue** tab.

Included in scope:
- Destination integration in `OperatorShellPage` (replacing the placeholder under the `Revenue` destination).
- State management via `OperatorRevenueCubit` and `OperatorRevenueState`.
- Filter controls: Period quick chips (This Month, Last Month, Last 30 Days, Custom Range), Granularity chips (Daily, Weekly, Monthly), and Tour Package filter picker.
- Financial Summary cards: Gross Revenue, Payments Received, Discounts Given, Platform Commission (with rate), and Net Payout Due.
- Mobile-optimized Trend Chart: Bar/indicator visualizer showing Gross vs Net earnings across periods.
- Tour Breakdown list: Touch-friendly card items displaying tour code, name, bookings, travelers, gross amount, and net amount.
- Empty, loading, and error states conforming to SRS messages (MSG29, MSG126, MSG127, MSG128).

Excluded from scope:
- Direct PDF/Excel file generation (UC-45: Handled via Web or external export link).
- Submitting payout settlement requests (UC-46).

## User Experience & Screen Design

1. **Top Bar**:
   - Title: `Revenue Report`
   - Active period badge & quick filter icon.
2. **Filters Section**:
   - Quick range chips: `This Month`, `Last 30 Days`, `Last Month`.
   - Date picker sheet for custom start/end dates.
   - Granularity segmented toggle: `Day`, `Week`, `Month`.
   - Tour selector modal or dropdown (All Tours / Specific Tour).
3. **Summary KPI Section**:
   - 2x2 grid of responsive cards:
     - **Gross Revenue** (Primary brand text, total sales volume).
     - **Net Payout** (Highlighted in success color, net earnings after commission & discounts).
     - **Platform Commission** (Deduction display with commission rate e.g. 10%).
     - **Total Bookings / Travelers** (Operational volume).
4. **Trend Chart**:
   - Visual bar chart displaying weekly/monthly comparisons between Gross and Net.
5. **Tour Breakdown List**:
   - List of expandable cards for each tour package showing booking volume, discount deduction, commission deduction, and final net amount.

## Technical Architecture

```
lib/features/tour_operator/
├── data/
│   ├── datasources/
│   │   └── operator_revenue_remote_data_source.dart
│   ├── models/
│   │   ├── revenue_report_model.dart
│   │   ├── revenue_summary_model.dart
│   │   ├── revenue_chart_point_model.dart
│   │   └── tour_revenue_detail_model.dart
│   └── repositories/
│       └── operator_revenue_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── revenue_report.dart
│   │   ├── revenue_summary.dart
│   │   ├── revenue_chart_point.dart
│   │   └── tour_revenue_detail.dart
│   └── repositories/
│       └── operator_revenue_repository.dart
└── presentation/
    ├── cubit/
    │   ├── operator_revenue_cubit.dart
    │   └── operator_revenue_state.dart
    ├── pages/
    │   └── operator_revenue_page.dart
    └── widgets/
        ├── revenue_filter_bar.dart
        ├── revenue_summary_grid.dart
        ├── revenue_trend_chart.dart
        └── tour_revenue_card.dart
```

## Business Rules & Client Validation

- **BR-105**: Authenticated Operator context. Token injected automatically via `DioClient` / secure storage.
- **BR-109 / BR-112**: All computations and aggregations originate authoritatively from the server.
- **CR-07**: Dates formatted using `dd/MM/yyyy` in Asia/Ho_Chi_Minh. Currencies formatted with Vietnamese Dong symbol (`₫`).
- **Validation**:
  - `startDate > endDate` triggers inline error snackbar or indicator with `MSG29`.
  - Empty results trigger an empty-state illustration with `MSG128` ("No records found matching your criteria.").
  - Network failure triggers `MSG127` with a [Retry] button.
