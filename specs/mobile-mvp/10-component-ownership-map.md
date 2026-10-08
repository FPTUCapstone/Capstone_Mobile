# 10 — Component Ownership Map

## Revision 2026-10-08 (develop `acfde81`) — read this first

Re-measured on develop `acfde81` (files under `lib/features` that construct the widget):
`AppPageScaffold` 14 · `AppButton` 15 · `AppAlert` 14 · `AppTextField` 10 · `AppPasswordField` 5 · `StatusBadge` 4 · `ErrorView` 2 · `LoadingIndicator` **0**.

Changes since the table below was written:

| Item | Change | Effect on ownership |
|---|---|---|
| Confirmation dialogs | **9** feature files now build an ad-hoc `AlertDialog` (operator application, coupon, active trip, invitation regenerate, offline package, settings sign-out, leave group, remove member, QR scanner dialog) | `ConfirmationDialog` (NEW_SHARED_COMPONENT) is now justified by ≥ 6 real consumers. Extract it before #43, #70 and further group flows add more. The QR scanner dialog is not a confirmation and stays separate. |
| `NavigationMapCanvas`, `TripAlertBanner`, `TripAlertsSheet`, `RerouteProposalSheet` | Now on develop (PR #24 merged) | FEATURE_LOCAL_COMPONENT in `traveler`; unchanged |
| `RemoveGroupMemberDialog`, `LeaveTravelGroupDialog` | On develop (PR #26) | FEATURE_LOCAL_COMPONENT; migrate to `ConfirmationDialog` when contracts exist |
| `tour_detail`, `tour_recommendations` features | Only in PR #31 **and** duplicated on the booking branch | One owner: PR #31. The booking branch must consume PR #31 code, not re-add it |
| `commercial_services` feature | Only in PR #32 | FEATURE_LOCAL; `PriceText` and `EmptyState` consumers |
| Localization resources | None exist (CR-09) | **NEW_SHARED infrastructure** (`lib/l10n/*.arb` via `flutter_localizations` + `gen-l10n`) — requires approval because it adds SDK localization dependencies (decision D-03). Every new screen in `13-v2-completion-specs.md` assumes resource-backed copy |

Screen numbers in the table below that refer to Tour Operator screens (#75–#92) are outside the 25-UC MVP and are kept only as future consumers.

---

Original audit (develop `af8daa0`, plus PR #24 for the active-trip widgets). Rule from `AGENTS.md`: **do not move feature logic into `lib/shared/`**, do not create empty layers, apply DRY only when logic is genuinely the same concept. A component is proposed as `NEW_SHARED_COMPONENT` only when at least two real consumers are specified in `02`–`07`; otherwise it stays `FEATURE_LOCAL_COMPONENT`.

Classes: `EXISTING_REUSE` · `EXISTING_EXTEND` · `NEW_SHARED_COMPONENT` · `FEATURE_LOCAL_COMPONENT`.

`lib/shared/widgets/` today: `app_alert`, `app_button`, `app_page_scaffold`, `app_password_field`, `app_text_field`, `error_view`, `loading_indicator`, `status_badge`.
Measured usage in `lib/features` (files referencing the widget): `AppPageScaffold` 14 · `AppButton` 15 · `AppAlert` 12 · `AppTextField` 9 · `AppPasswordField` 4 · `StatusBadge` 3 · `ErrorView` 2 · **`LoadingIndicator` 0** (features use ad-hoc spinners).

| Component | Current owner / evidence | Class | Consumers in this design | Notes |
|---|---|---|---|---|
| AppPageScaffold | `shared/widgets/app_page_scaffold.dart`, 14 feature files | EXISTING_REUSE | all new pages | no change |
| AppButton | `shared/widgets/app_button.dart`, 15 files | EXISTING_REUSE | all | destructive variant needed for confirmations — check existing variants before adding |
| AppAlert | `shared/widgets/app_alert.dart`, 12 files | EXISTING_REUSE | all | `AppAlertType` info/warning/error/success already used by PR #24 |
| StatusBadge | `shared/widgets/status_badge.dart`, 3 files | EXISTING_EXTEND | availability, payment, ticket, booking, tour status, role (Host/Member), application status | extend with icon + semantic type; **never colour-only** |
| Role badge | none (host flag rendered ad hoc) | EXISTING_EXTEND (via `StatusBadge`) | #57, #41 | not a separate widget |
| Search field | `AppTextField` (9 files) + feature-specific fields | EXISTING_EXTEND | #71, #84 | a `SearchField` wrapper only if a third consumer repeats the same behaviour |
| Form fields | `AppTextField`, `AppPasswordField` | EXISTING_REUSE | #40, #43, #45, #66, #78, #82, #92 | |
| Date / time input | three inline implementations: `create_itinerary_page` (date+time), `tour_search_filter_sheet`, `traveler_profile_page` | NEW_SHARED_COMPONENT (`DateTimeField` / `DateRangeField`) | #45, #66, #72, #78, #82, #89, #90 | extract from existing three before adding a fourth |
| Price / currency presentation | **no shared formatter** (no `intl`; prices formatted ad hoc, e.g. tour card) | NEW_SHARED_COMPONENT (`PriceText`) | #65–#69, #72, #85–#87, #89–#92 | currency comes from data (`currency` field); no default currency; no new package assumed |
| Avatar | `CircleAvatar` inline in 2 pages; `avatarUrl` parsed in members model | NEW_SHARED_COMPONENT (`Avatar`) | #45, #57, #76 | graceful fallback when `avatarUrl` null/404 (rules U04) |
| Filter sheet | `TourSearchFilterSheet` (feature-local), POI filters inline | FEATURE_LOCAL_COMPONENT today → NEW_SHARED (`FilterSheet` base) when #71 or #84 starts | #63 (existing), #71, #84 | do not refactor the working tour filter sheet pre-emptively |
| Bottom sheet | `showModalBottomSheet` used in 6 places | EXISTING_REUSE (framework) | #54, #72, #88, #90 | follow C-RESP sheet rules |
| Confirmation dialog | two ad-hoc `AlertDialog`s (`invite_group_members_page` regenerate, `traveler_settings_page` sign-out) | NEW_SHARED_COMPONENT (`ConfirmationDialog`) | #43, #45 discard, #57–#60, #70, #80, #83, #86, #87, #92 | default focus on the non-destructive action; destructive style + icon + text |
| Tour card | `TourListCard` (`tour_search`) | FEATURE_LOCAL_COMPONENT → EXISTING_EXTEND for #64 | #63, #64 | add optional reason/score slot; keep the four availability labels |
| POI card | `PoiListCard` (`poi`) | FEATURE_LOCAL_COMPONENT | #50 | |
| Booking card | none | NEW_SHARED_COMPONENT (`BookingCard`) | #68 (traveler), #84 (operator) | different data shapes → shared shell + feature mappers |
| Timeline | itinerary item list inline in `itinerary_detail_page` / `itinerary_result_page` | FEATURE_LOCAL_COMPONENT | #48, #80 preview | extract only if #80 needs the same widget |
| Map preview / canvas | `PoiMapPreview` + `PoiMapProjection` (poi), `NavigationMapCanvas` (PR #24) — two separate custom canvases | FEATURE_LOCAL_COMPONENT ×2 | #48, #51, #52, #49 | **both are `MAP_INTEGRATION_PENDING`**. A shared `MapView` abstraction is a decision for when the provider is approved — not designed here |
| Loading | `LoadingIndicator` exists but has 0 feature users | EXISTING_REUSE | all | adopt it in new screens; do not add another spinner |
| Empty state | none (only a private `_EmptyMap`) | NEW_SHARED_COMPONENT (`EmptyState`) | #55, #64, #68, #73, #77, #81, #84, #91 | message + optional action; distinct from `ErrorView` |
| Error state | `ErrorView` (2 files) | EXISTING_REUSE | all | map status → safe message (rules: no raw exceptions) |
| QR ticket | none (`qr_flutter` used on #58 invitation) | NEW_SHARED_COMPONENT (`QrTicketCard`) | #69 | renders Backend payload only |
| QR scanner overlay | `QrScannerDialog` (`mobile_scanner`) | EXISTING_EXTEND | #62 (existing), #88 | split into scanning core + overlay; keep #62 behaviour unchanged |
| Revenue / stat card | none | NEW_SHARED_COMPONENT (`StatCard`) | #75, #89 | |
| Payout card | none | FEATURE_LOCAL_COMPONENT (`PayoutCard`) | #91 | |
| Pagination / load-more | per-feature in Cubits (POI, tours) | FEATURE_LOCAL_COMPONENT (pattern) | #55, #68, #73, #77, #84, #91 | introduce a shared footer widget only when a third list repeats it |
| Stepper header | none | NEW_SHARED_COMPONENT (`StepProgressHeader`) | #40, #78 | announced step n of N |
| Schedule picker | none | NEW_SHARED_COMPONENT (`SchedulePicker`) | #65, #72 | data from Backend schedules |
| Rating input | none | NEW_SHARED_COMPONENT (`RatingInput`) | #74 | accessible slider/radio semantics |
| Notification surface | `TripAlertBanner`, `TripAlertsSheet` (PR #24, feature-local) | FEATURE_LOCAL_COMPONENT | #52, #53 | app-level notification surface is blocked by missing push (`DEVICE_INTEGRATION_MISSING`) |
| Quick action tile | none | FEATURE_LOCAL_COMPONENT | #44, #75 | |

## Duplication risks to watch
1. Two custom map canvases (POI preview, navigation) → keep isolated until the provider decision.
2. Ad-hoc confirmation dialogs (2 already) → one `ConfirmationDialog` before the group/booking/operator flows multiply them.
3. Three inline date/time pickers → extract once.
4. No empty-state or price-format helper → define once, then reuse in ≥ 8 screens.
5. `LoadingIndicator` unused → adopt, do not add new spinners.

## Dependency notes (nothing is added by this task)
Chart rendering (#89), file save/download (#90), image/file picker (#40, #76, #78), push notifications, map SDK, URL launcher and deep-link handling are not in `pubspec.yaml`. Each is a separate approved decision (AGENTS.md: no new dependency without approval).
