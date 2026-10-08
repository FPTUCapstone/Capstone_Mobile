# 11 — Open PR and Review Register (revision 2026-10-08)

Read-only. Nothing here modifies a PR or branch. GitHub data from `gh` (read-only); code from `git archive` / `git grep` of the cited refs. CodeRabbit posts "review skipped" on every PR in this repository; that is not a review and is not counted.

## R-1 PR #24 — active trip navigation (MERGED 2026-10-04, `bdd1f12`)

Merged; re-evaluated on develop `acfde81`. Not reopened, not modified.

| Concern | Status on develop | Evidence |
|---|---|---|
| Fabricated itinerary names from deep links | Resolved for production (demo-only fallbacks) | `app_router.dart` activeTripLive/offlinePackage builders |
| UC-16 offline metrics without verified data | Resolved for production (truthful pending view) | `offline_trip_package_page.dart`, `offline_trip_package_cubit.dart` |
| Demo copy in Vietnamese and raw `BR-`/`MSG` identifiers | Open, demo-only | audit register A-01 |
| UC-13–UC-15 (#52–#54) | Out of MVP scope; preserved | — |

## R-2 PR #25 — `feat(mobile): harden Batch 1 account and profile MVP screens`

| Field | Value |
|---|---|
| Branch / head | `fix/mobile-production-truthfulness` / `98e4b01` |
| State | OPEN, **CONFLICTING**, REVIEW_REQUIRED |
| Scope | #40, #41, #45, #46 production truthfulness; 23 files |
| Review | PQKhanh294 (COMMENTED, at `98e4b01`): **P1** — the identity snapshot (full name, email) is stored and cleared best-effort; if clearing fails, a later session for another account can restore the previous account's identity. Requested: never ignore clear/replace failures (invalidate the persisted session), or bind the snapshot to `userId`; add a test covering account A → failed clear → account B → restart. |
| MVP UCs | UC-02, UC-03, UC-08, UC-09 |
| Must preserve | Truthful production behaviour for #40/#41/#45/#46; demo gating |
| Design dependency | Specs S-40/S-41/S-45/S-46 in `13-v2-completion-specs.md` assume PR #25 behaviour as the baseline |

## R-3 PR #31 — UC-25 tour recommendations and UC-26 tour details

| Field | Value |
|---|---|
| Branch / head | `feature/mobile-tour-recommendations-details` / `e6a1a94` |
| State | OPEN, MERGEABLE, REVIEW_REQUIRED, 3 behind develop |
| Adds | `tour_recommendations` and `tour_detail` features, routes, shell entry |
| Backend | Calls `/api/v1/tours/{id}` (absent on BE develop); no tour recommendation endpoint → `NO_BACKEND` |
| Truthfulness markers | `PENDING_BE` / pending markers present in `tour_detail_cubit.dart`, `tour_recommendations_cubit.dart` |
| Human review | none yet |
| Must preserve | Production pending states; route names used by the booking branch |

## R-4 PR #32 — UC-30 / UC-31 commercial services

| Field | Value |
|---|---|
| Branch / head | `feature/mobile-commercial-services` / `6739bdf` |
| State | OPEN, **CONFLICTING**, REVIEW_REQUIRED |
| Adds | `commercial_services` feature (search, detail, booking), entry points on POI detail, itinerary detail and the shell |
| Backend | Uses `presentation/demo/demo_commercial_service_store.dart`; BE develop already serves `GET /commercial-services` and `/{id}` → `BE_AVAILABLE_NOT_INTEGRATED` for UC-30 |
| Scope note | UC-31 booking is outside the 25-UC MVP; recorded, not expanded |
| Human review | none yet |

## R-5 PR #33 — UC-32 / UC-33 trip history and reviews (out of MVP scope)

| Field | Value |
|---|---|
| Branch / head | `feature/mobile-trip-history-reviews` / `be66c60` |
| State | OPEN, MERGEABLE, REVIEW_REQUIRED |
| Backend | Demo store (`demo_trip_history_store.dart`); BE PR #30 (submit trip review) open |
| Relevance | Shell entry points overlap with `TravelerShellPage` changes in PR #31 and PR #32 |

## R-6 Unmerged branch without a PR — `feature/mobile-tour-booking-payment-ticket`

| Field | Value |
|---|---|
| Commits | 6 ahead, 3 behind develop (latest `ccf5995 test(traveler): add UC-27 UC-28 UC-29 booking funnel tests`) |
| PR | none |
| Adds | `tour_booking` (booking, `ElectronicPaymentPage`, QR e-ticket) and also `tour_detail` / `tour_recommendations` code (overlaps PR #31) |
| Backend | `presentation/demo/demo_booking_funnel_store.dart`; no booking/payment/ticket endpoint on BE |
| Classification | UC-27/28/29 `NOT_STARTED` on develop; `BRANCH_NO_PR` |
| Action required (owner) | Open a PR after PR #31 merges, or rebase onto it; resolve the duplicated `tour_detail` code |

## R-7 Shared-file conflict risks between open work

| File | Touched by |
|---|---|
| `lib/app/router/app_router.dart`, `app_routes.dart` | PR #25, #31, #32, #33, booking branch |
| `lib/features/traveler/presentation/pages/traveler_shell_page.dart` | PR #31, #32, #33 |
| `lib/features/tour_detail/**` | PR #31 and booking branch |
| `lib/features/poi/presentation/pages/poi_detail_page.dart` | PR #32 |

Recommended merge order: #25 → #31 → booking-branch PR → #32 → #33 (each rebased on the previous).

## R-8 Backend PRs relevant to Mobile (context only)

BE #52 (UC-02 operator registration), BE #44 (UC-38 coupon), BE #30 (UC-33 review). None is merged into BE develop `0075fcb`.
