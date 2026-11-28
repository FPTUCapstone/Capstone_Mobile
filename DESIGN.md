---
version: 1.0.0
name: TripMate Mobile Design System & UI/UX Template Specification
description: Official design system and reusable screen-template specification for TripMate Mobile (Flutter, Material 3, Android & iOS) — unifying Coastal Heritage visual tokens, typography, spacing, shared primitives, 5 canonical mobile screen templates, motion, and accessibility conventions.
platform: Flutter (Android & iOS, Material 3)
brand-palette: Coastal Heritage (aligned with TripMate Web DESIGN.md)
---

# TripMate Mobile — Design System & UI/UX Template Specification

## 1. Design Philosophy & Visual Identity

TripMate Mobile serves **Travelers** and **Tour Operators** exploring and operating journeys across Central Vietnam (Đà Nẵng, Hội An, Cố Đô Huế). Built on Flutter Material 3, its visual language — **Coastal Heritage** — pairs calm editorial clarity with one-handed mobile ergonomics:

1. **Warm Coastal Calm**: A Warm Ivory canvas (`#F7F5EF`) layered with crisp white cards (`#FFFFFF`), 1px hairline borders (`#DCE2DD`), Coastal Deep Teal (`#174B4A`) anchors, Soft Sage (`#E8F0EA`) containers, and Warm Terracotta (`#B96D4C` / accessible `#995436`) accents.
2. **Touch-First, Thumb-Zone Ergonomics**: Primary actions live in the bottom thumb zone (`AppStickyActionBar`, `AppSlidingBottomNav`) with `44dp–48dp` minimum hit targets, while navigation and secondary controls stay lightweight at the top (`AppCoastalAppBar`).
3. **Flat Hairline Hierarchy over Heavy Shadows**: Visual separation uses subtle tonal surfaces (`canvas` → `surfaceCard` → `surfaceElevated`) and `1px` `borderSubtle` dividers rather than thick shadows or heavy gradients.
4. **Adaptive, Inclusive & Offline-Honest**: Every shared primitive and canonical template adapts cleanly to `AppTheme.light` and `AppTheme.dark`, scales to `200%` font size without overflow, honors `MediaQuery.disableAnimationsOf(context)`, and surfaces explicit Loading, Empty, Error, and Offline states.

> [!NOTE]
> This specification governs **visual presentation, tokens, and reusable layout templates** in `trip_mate_mobile`. It does **not** alter backend API contracts, Domain rules, Clean Architecture boundaries, or role routing (`/auth/*`, `/traveler/*`, `/operator/*`) defined in [AGENTS.md](AGENTS.md) and [docs/CODEBASE_RULES.md](docs/CODEBASE_RULES.md).

---

## 2. Canonical Color Token Architecture

### 2.1 Single Source of Truth: `context.tmColors` (`TripMateColors`)

All new and migrated widgets **MUST** read semantic colors from `context.tmColors` (defined in `lib/app/theme/app_colors.dart` as `ThemeExtension<TripMateColors>`).

| Semantic Role | Token (`context.tmColors.*`) | Light Hex | Dark Hex | Primary Usage |
|---|---|---|---|---|
| **Canvas** | `canvas` | `#F7F5EF` | `#0E1716` | Page background (`Scaffold.backgroundColor`). |
| **Card Surface** | `surfaceCard` | `#FFFFFF` | `#152322` | Cards, AppBars, bottom sheets, sticky bottom bars, form inputs. |
| **Elevated Surface** | `surfaceElevated` | `#EDEAE1` | `#1D302E` | Subtle inset containers, neutral status chips, secondary pills. |
| **Overlay Surface** | `surfaceOverlay` | `#F5FFFFFF` | `#EE152322` | Frosted controls over photography or maps. |
| **Hairline Border** | `borderSubtle` | `#DCE2DD` | `#273E3C` | 1px card outlines, AppBar bottom hairlines, dividers, inputs. |
| **Strong Border** | `borderStrong` | `#C4CEC8` | `#3A5754` | Outlined buttons, drag handles, focused outlines. |
| **Brand Primary** | `brandTeal` / `actionPrimary` | `#174B4A` | `#4FB3A7` | Primary buttons, active navigation icons, key prices, focus rings. |
| **Brand Deep** | `brandNavy` / `brandTealDark` | `#103B39` | `#103B39` / `#338C82` | Pressed states, dark hero backdrops, light-mode snackbar surface. |
| **Soft Sage Container** | `tealSoftContainer` | `#E8F0EA` | `#143533` | Selected filter chips, sliding nav pill, soft info callouts, icon badges. |
| **Terracotta Accent** | `brandCoral` / `coralAccessibleText` | `#995436` | `#D89272` / `#E5A486` | Accessible accent text/icons/badges (WCAG AA >= 4.5:1 on light & dark). |
| **Soft Coral Container** | `coralSoftContainer` | `#F6EDE8` | `#3A241B` | Warm highlight callouts, promotional pill containers. |
| **Primary Ink** | `textPrimary` | `#1C2928` | `#F4F3EE` | Headlines, card titles, primary values, input text. |
| **Secondary Ink** | `textSecondary` | `#536560` | `#B6C5C0` | Subtitles, section descriptions, form labels, body metadata. |
| **Muted Ink** | `textMuted` | `#5B6E69` | `#8FA39D` | Hints, timestamps, inactive nav labels, footnotes. |
| **Text on Brand** | `textOnBrand` | `#FFFFFF` | `#071615` | Label and spinner color on filled `actionPrimary` buttons. |
| **Success** | `success` / `successContainer` | `#0E9F6E` / `#E5F6EF` | `#4ADEA0` / `#103428` | Confirmed bookings, paid status, applied vouchers, inclusions. |
| **Warning** | `warning` / `warningContainer` | `#B45309` / `#FEF3E2` | `#FFB74D` / `#3B2810` | Pending payment, ratings, approaching deadlines, manual review. |
| **Error** | `error` / `errorContainer` | `#C8233F` / `#FDECEF` | `#FF7A70` / `#441818` | Validation errors, sold-out/expired notices, destructive actions. |
| **Info** | `info` / `infoContainer` | `#174B4A` / `#E8F0EA` | `#7CB4FF` / `#162A47` | Informational alerts, pending integration banners, refund stages. |
| **Shimmer** | `shimmerBase` / `shimmerHighlight` | `#EBE8DF` / `#F6F4EE` | `#1B2E2C` / `#263E3C` | `AppShimmer` and `SkeletonBox`/`SkeletonText`/`SkeletonCircle`. |

### 2.2 Token Consolidation Policy (Compatibility Shims)

- **Canonical API**: Always use `final c = context.tmColors;` in every new or edited widget.
- **Forbidden in new/edited UI**: Never introduce raw Tailwind/Slate/Blue hex literals (`#0F172A`, `#334155`, `#475569`, `#64748B`, `#94A3B8`, `#CBD5E1`, `#E2E8F0`, `#F1F5F9`, `#F8FAFC`, `#1D4ED8`, `#2563EB`, `#EFF6FF`) or hardcoded `Colors.white` / `Colors.grey` for surfaces and body text.
- **Legacy Aliases Retained for Compilation Compatibility**:
  - `CoastalPalette.of(context)` (`lib/app/theme/coastal_palette.dart`): Thin adapter over `context.tmColors`; safe for Light & Dark, prefer `context.tmColors` directly in new widgets.
  - `AppColors`, `TourSearchPalette`, `PoiPalette`: Static light-only Coastal Heritage constants preserved so un-migrated callers compile cleanly. Replace with `context.tmColors` whenever touching those files.
- **Production Runtime Theme Guard**: `TripMateApp` (`lib/app/app.dart`) currently pins `themeMode: ThemeMode.light` until full-app Dark Mode QA finishes across all remaining screens. All shared widgets and newly migrated screens must still pass Light & Dark widget tests.

---

## 3. Typography & Hierarchy

Bundled SIL OFL 1.1 fonts with verified Vietnamese diacritics and `₫` glyph coverage (`lib/app/theme/app_typography.dart`):

- **Display Font (`AppTypography.displayFont`)**: `BricolageGrotesque` (`500`, `600`, `700`, `800`) — used for display headlines, page titles, AppBar titles, and section headers.
- **UI / Body Font (`AppTypography.uiFont`)**: `Manrope` (`400`, `500`, `600`, `700`, `800`) — used for body copy, buttons, chips, form inputs, navigation labels, and tabular currency figures.

| TextTheme Slot | Font | Size | Weight | Line Height | Tracking | Usage |
|---|---|---|---|---|---|---|
| `displayLarge` | BricolageGrotesque | `32sp` | `700` | `1.15` | `-0.6` | Hero welcome / splash headline |
| `headlineMedium` | BricolageGrotesque | `20sp` | `700` | `1.22` | `-0.3` | Prominent confirmation / hero title |
| `titleLarge` | BricolageGrotesque | `17.5sp` | `700` | `1.25` | `-0.2` | AppBar title, major card title |
| `titleMedium` | Manrope | `15sp` | `700` | `1.32` | `-0.1` | Section card title, list item heading |
| `titleSmall` | Manrope | `13.5sp` | `600` | `1.35` | `0` | Subheadings, form section labels |
| `bodyLarge` | Manrope | `14.5sp` | `500` | `1.45` | `0` | Primary body text, list values |
| `bodyMedium` | Manrope | `13.5sp` | `400` | `1.45` | `0` | Descriptions, policy copy, alerts |
| `bodySmall` | Manrope | `12sp` | `500` | `1.38` | `0` | Captions, metadata, helper notes |
| `labelLarge` | Manrope | `13.5sp` | `700` | `1.20` | `+0.05` | Primary & secondary buttons |
| `labelSmall` | Manrope | `11sp` | `600` | `1.25` | `+0.2` | Status badges, nav labels, micro tags |
| `AppTypography.price(...)` | Manrope (`tnum`) | `15.5sp+` | `800` | `1.15` | `-0.2` | Tabular VND amounts, totals, quotes |

---

## 4. Spacing, Radii & Elevation System

Defined in `lib/app/theme/app_spacing.dart`:

- **Spacing Scale (`AppSpacing`)**: `xxs = 4`, `xs = 8`, `sm = 12`, `md = 16`, `lg = 24`, `xl = 32`, `xxl = 48`.
  - Standard screen horizontal margin: `16dp` (`AppSpacing.md`).
  - Vertical gap between cards/sections: `12dp–16dp` (`AppSpacing.sm` / `AppSpacing.md`).
  - Standard card internal padding: `14dp–16dp`.
  - Tablet / Web preview centered max-width for forms & single-column pages: `520dp`.
- **Radii (`TripMateRadius`)**:
  - `sm = 12dp`: Inputs, filled/outlined buttons, alert banners, snackbars.
  - `md = 16dp` (`AppCard` default `14dp`): Cards, section containers, dialogs.
  - `lg = 22dp` / bottom sheet top corners `20dp`: Modal sheets, hero cards.
  - `xl = 28dp`: Feature callout banners.
  - `pill = 999dp`: Filter chips, status badges, segmented pills.
- **Elevation**: Prefer `elevation: 0` + `1px` `borderSubtle`. Subtle directional shadow (`alpha <= 0.08`) is reserved exclusively for floating chrome (`AppSlidingBottomNav`, `AppStickyActionBar`).

---

## 5. Five Canonical Mobile Screen Templates (T1–T5)

Every TripMate Mobile screen maps to one of five canonical layout templates:

### Template T1 — Tabbed Workspace Shell
**Use for**: Primary role hubs (`TravelerShellPage`, `OperatorShellPage`, `GuestLandingPage`).

```text
┌────────────────────────────────────┐
│  Top Brand / Greeting Bar          │ ← Flat surfaceCard or Coastal hero
├────────────────────────────────────┤
│  IndexedStack (lazy tab bodies)    │ ← Preserves scroll & cubit state
│   • AppSectionHeader + AppCard     │
│   • Photo cards / KPI grids        │
├────────────────────────────────────┤
│ [Home] [Trips] [Explore] [..] [Me] │ ← AppSlidingBottomNav (60dp + SafeArea)
└────────────────────────────────────┘
```

- **Rules**: Max 5 destinations; always visible icons + labels (`Manrope`); sliding highlight capsule adapts via `context.tmColors`; never put destructive 1-tap logout in the AppBar.

### Template T2 — Standard Scroll / Form Page (`AppPageScaffold`)
**Use for**: Forms, settings, profile editing, auth sub-flows, group creation, preferences.

```text
┌────────────────────────────────────┐
│ ←  Title / Optional Subtitle  [Act]│ ← AppCoastalAppBar (52dp + 1px hairline)
├────────────────────────────────────┤
│  SafeArea + Centered maxWidth 520  │
│  ListView (keyboardDismiss: onDrag)│
│   • AppAlert (inline guidance/err) │
│   • AppSectionCard (inputs/fields) │
│   • AppSectionCard (options)       │
├────────────────────────────────────┤
│  Optional AppStickyActionBar       │ ← Pinned primary CTA in thumb zone
└────────────────────────────────────┘
```

- **Widget API**: `AppPageScaffold(title:, subtitle:, actions:, leading:, centerTitle:, onRefresh:, content:, footer:, bottomBar:, floatingActionButton:)`.

### Template T3 — Detail / Checkout + Sticky Action Bar
**Use for**: `TourDetailPage`, `BookTourPage`, `PaymentPage`, `BookingRefundProgressPage`, `PartialRefundProposalPage`, `ItineraryDetailPage`.

```text
┌────────────────────────────────────┐
│ ←  Screen Title                    │ ← AppCoastalAppBar (1px hairline)
├────────────────────────────────────┤
│  Optional Hero / Status Banner     │
│  AppSectionCard (Summary / Form)   │
│   • AppKeyValueRow (tabular price) │
│  AppSectionCard (Policies / Steps) │
├────────────────────────────────────┤
│  Summary (Price)   [ Primary CTA ] │ ← AppStickyActionBar (SafeArea + hairline)
└────────────────────────────────────┘
```

- **Widget APIs**: `AppCoastalAppBar`, `AppSectionCard`, `AppKeyValueRow`, `AppStickyActionBar`.
- **Rules**: On compact widths (`320dp`) or `200%` text scaling, `AppStickyActionBar` gracefully wraps or flexes without `RenderFlex overflow`.

### Template T4 — Discovery / Filtered List Page
**Use for**: `OperatorToursPage`, `TourSearchPage`, `ExplorePoiPage`, `MyTripsPage`, `TripHistoryPage`, `InAppInboxPage`, `OperatorSafetyReviewsPage`.

```text
┌────────────────────────────────────┐
│ ←  List Title             [Action] │ ← AppCoastalAppBar (1px hairline)
├────────────────────────────────────┤
│  [All] [Draft] [Pending] [Live] →  │ ← AppFilterChipBar (horizontal ChoiceChips)
├────────────────────────────────────┤
│  RefreshIndicator + ListView       │
│   • Loading  → AppShimmer skeleton │
│   • Empty    → AppEmptyState       │
│   • Error    → ErrorView + retry   │
│   • Content  → AppCard + StatusBadge
└────────────────────────────────────┘
```

- **Widget APIs**: `AppCoastalAppBar`, `AppFilterChipBar<T>`, `AppCard`, `StatusBadge`, `AppEmptyState`, `ErrorView`, `AppShimmer`.
- **Note**: `AppFilterChipBar` renders styled Material `ChoiceChip` widgets internally so both accessibility semantics and widget tests (`find.byType(ChoiceChip)`) remain consistent.

### Template T5 — Modal Sheet & Action Overlay (`AppBottomSheetScaffold`)
**Use for**: Filters, payment/banking guidance, cancel/refund confirmations, language/support pickers.

```text
┌────────────────────────────────────┐
│          (Dimmed Scrim)            │
├════════════════════════════════════┤ ← 20dp top radius, surfaceCard bg
│             ──────                 │ ← 36×4dp borderStrong drag handle
│  Sheet Title                   [✕] │ ← 44dp close target + optional subtitle
├────────────────────────────────────┤ ← 1px borderSubtle divider
│  Scrollable Sheet Body             │ ← Keyboard viewInsets + SafeArea(top:false)
│  Optional Footer Actions           │
└────────────────────────────────────┘
```

- **Widget APIs**: `AppBottomSheetScaffold` and `showAppModalBottomSheet<T>(context: ..., title: ..., builder: ...)`.

---

## 6. Shared Component Catalog (`lib/shared/widgets/`)

| Widget | File | Role | Theme & A11y Contract |
|---|---|---|---|
| `AppCoastalAppBar` | `app_coastal_app_bar.dart` | Canonical flat AppBar with 1px hairline border & optional subtitle | `tmColors.surfaceCard`, `textPrimary`, `borderSubtle`; `52dp` (or `60dp` with subtitle) |
| `AppPageScaffold` | `app_page_scaffold.dart` | Canonical T2 scroll/form page wrapper | `tmColors.canvas`, `maxWidth: 520`, `onDrag` keyboard dismiss, optional `bottomBar` & `onRefresh` |
| `AppStickyActionBar` | `app_sticky_action_bar.dart` | Canonical T3 pinned thumb-zone footer bar | `tmColors.surfaceCard`, 1px top `borderSubtle`, `SafeArea(top: false)`, `46dp` min button height |
| `AppFilterChipBar` | `app_filter_chip_bar.dart` | Canonical T4 horizontal filter pill strip | `ChoiceChip` styled with `tealSoftContainer` / `brandTeal`, `≥44dp` tap envelope |
| `AppBottomSheetScaffold` | `app_bottom_sheet_scaffold.dart` | Canonical T5 modal bottom sheet wrapper | `20dp` top radius, drag handle, `44dp` close button, `viewInsets.bottom` + `SafeArea` |
| `AppSectionCard` | `app_section_card.dart` | Titled Coastal card with optional icon, subtitle, trailing badge | `AppCard` base (`14dp` radius, `borderSubtle`), `tealSoftContainer` icon pill |
| `AppKeyValueRow` | `app_section_card.dart` | Aligned label + tabular value row for receipts & summaries | `Flexible` wrap-safe layout, `AppTypography.price` option when `isProminent: true` |
| `AppCard` | `app_card.dart` | Base flat surface container with optional `InkWell` ripple | `tmColors.surfaceCard` + `1px borderSubtle` + `14dp` radius |
| `AppSectionHeader` | `app_section_header.dart` | Section heading + optional subtitle + trailing action link | `BricolageGrotesque` `16sp` title + `brandTeal` action |
| `AppButton` | `app_button.dart` | Standard primary / outlined button with loading switcher | `minimumHeight: 46`, spinner uses `tmColors.textOnBrand` / `brandTeal` |
| `AppTextField` / `AppPasswordField` | `app_text_field.dart` / `app_password_field.dart` | Outlined Coastal form inputs | Driven by `AppTheme.inputDecorationTheme` |
| `AppAlert` | `app_alert.dart` | Inline status callout (`info`, `success`, `warning`, `error`) | `Semantics(liveRegion: true)`, `tmColors.*Container` |
| `StatusBadge` | `status_badge.dart` | Compact uppercase pill status tag | `tmColors` light/dark semantic containers |
| `AppEmptyState` | `app_empty_state.dart` | Centered empty state with sage icon badge + optional CTA | `tmColors.tealSoftContainer`, `BricolageGrotesque` title |
| `ErrorView` | `error_view.dart` | Coastal error state with error icon badge + retry `AppButton` | `tmColors.errorContainer` + `error`, optional `title` |
| `AppShimmer` / `Skeleton*` | `app_shimmer.dart` | Hardware-accelerated warm ivory/teal loading shimmer | Defaults to `tmColors.shimmerBase` & `shimmerHighlight`; disables on `disableAnimations` |
| `AppSlidingBottomNav` | `app_sliding_bottom_nav.dart` | Animated capsule bottom navigation bar (T1) | Defaults to `tmColors`, respects `disableAnimations`, circular `InkResponse` |
| `Editorial*` Motion | `motion/editorial_*.dart` | Tactile press (`0.985`), scroll reveal (`400ms`), hero transition | All respect `MediaQuery.disableAnimationsOf(context)` & `RepaintBoundary` |

---

## 7. Mobile Ergonomics, Accessibility & Performance Rules

1. **Touch Targets**: All interactive controls MUST provide at least `44dp × 44dp` (iOS) / `48dp × 48dp` (Android) hit area with `>= 8dp` spacing between adjacent targets.
2. **Text Scaling & Small Phones**: Every screen and template MUST render without `RenderFlex overflow` at `320×568` and `textScaler = TextScaler.linear(2.0)`. Never wrap text rows in fixed-height `SizedBox` containers when wrapping is possible.
3. **Reduced Motion**: Every animated component MUST check `MediaQuery.maybeDisableAnimationsOf(context) ?? false` and snap immediately when enabled.
4. **Performance**:
   - Prefer `const` constructors and `const` leaf widgets.
   - Use `ListView.builder` / `ListView.separated` for unbounded or paginated lists (never `SingleChildScrollView` + `Column` for long feeds).
   - Wrap independently animating chrome (`AppSlidingBottomNav`, `EditorialTactileCard`) in `RepaintBoundary`.
   - Dispose every `AnimationController`, `TextEditingController`, `Timer`, and `StreamSubscription`.

---

## 8. Template Adoption Matrix (Completed App-Wide)

### Completed on Coastal Heritage + Canonical Templates (Waves 1–3)
- **Core Theme & Shared Templates**: `lib/app/theme/*`, `lib/shared/widgets/*` (Light + Dark verified with `coastal_shared_primitives_test.dart` & `coastal_templates_test.dart`).
- **Wave 1 & 2 (PR #106, #107, #109, #110)**: Splash, Login, Traveler Registration, Guest Landing, Tour Search, Explore POI, POI Detail, Traveler Shell/Home/Profile, Active Trip Navigation (UC-13), Trip History & Review (UC-32/33), E-Ticket, Travel Group Details/Members/Invite, Notifications Inbox, Support Chat, Messenger, Operator Shell/Dashboard/Finance/Profile (UC-34).
- **Template System Pilot (Track A & B)**: `TourDetailPage` (+ `DepartureScheduleCard`, `ItineraryStopTile`), `BookTourPage`, `PaymentPage`, `TourDiscoveryMotionSkeleton`, `OperatorToursPage`, `BookingRefundProgressPage`, `PartialRefundProposalPage`.
- **Wave 3 Full App-Wide Unification (Completed)**:
  - **Template T2 (`AppPageScaffold` / `AppCoastalAppBar` + `AppSectionCard`)**:
    - Auth sub-flows: `change_password_page`, `password_recovery_page`, `verify_email_page`, `operator_application_page`, `operator_email_recovery_page`, `resubmit_operator_application_page`.
    - Traveler settings/forms: `travel_preferences_page`, `traveler_profile_page`, `traveler_settings_page`, `create_travel_group_page`, `join_travel_group_page`, `post_trip_complaint_page`.
    - Operator forms: `create_coupon_page`, `create_tour_package_page`, `edit_tour_package_page`, `emergency_decision_page`.
  - **Template T3 (`AppCoastalAppBar` + `AppSectionCard` + `AppStickyActionBar`)**:
    - `operator_registration_page`, `operator_booking_detail_page`, `operator_contract_page`, `operator_safety_review_detail_page`, `itinerary_result_page`, `commercial_booking_page`.
  - **Template T4 (`AppCoastalAppBar` + `AppFilterChipBar` + `AppCard` + State Views)**:
    - `trip_alerts_page`, `my_post_trip_complaints_page`, `offline_packages_page`, `live_offline_package_page`, `offline_itinerary_page`, `offline_trip_package_page`, `operator_settlement_history_page`, `operator_safety_reviews_page`, `commercial_booking_requests_page`, `traveler_emergency_page`, `tour_recommendations_page`.
  - **Specialized Camera / Map Workspaces (Domain canvas + `AppCoastalAppBar` + `context.tmColors` chrome)**:
    - `operator_check_in_page`, `group_location_sharing_page`, `offline_itinerary_map_page`.
  - **Discovery / Shared Card Token Cleanup**:
    - `guest_landing_page`, `tour_list_card`, `poi_image`, `compact_horizontal_tour_card`, `featured_tour_editorial_card`, `operator_coupons_view`.
