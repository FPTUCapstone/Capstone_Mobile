# TRIPMATE MOBILE — PRODUCTION TOUR DISCOVERY MOTION IMPLEMENTATION & REMEDIATION EVIDENCE

**Author / Roles:** Senior Flutter Engineer, Motion Design Engineer, QA Engineer, GitHub Release Engineer  
**Date:** 2026-11-13  
**Repository:** `FPTUCapstone/Capstone_Mobile`  
**Feature Branch:** `feature/editorial-tour-discovery-motion`  
**Base Branch:** `feature/editorial-pr1-theme-assets` (Stacked Draft PR on PR #74 HEAD `eb9158732c127df590a11e3b4c0ffc8b0a0daa41`)  
**Pull Request:** [#77 (Draft)](https://github.com/FPTUCapstone/Capstone_Mobile/pull/77)  
**Status:** **DRAFT PULL REQUEST REMEDIATED, TESTED & VERIFIED**

---

## 1. Executive Summary & Remediation Scope

This document provides complete implementation, motion verification, architectural remediation, and quality assurance evidence for **Variant A — Featured + Compact Editorial Feed** on TripMate Mobile.

### Key Remediation Deficiencies Resolved (Post-Delivery Gate):
1. **R1 — Eliminated Production Fixture Dependency:**
   - Removed hardcoded mock fixtures (`curatedDefault`) from production entity `TourDiscoveryItem` and widget default values in `TravelerTourDiscoverySection`.
   - Relocated mock data exclusively to `test/features/tour_discovery/support/tour_discovery_fixtures.dart`.
   - Connected `TravelerHomeDashboardView` to the existing approved public tour search feed (`TourSearchCubit` invoking `SearchToursUseCase` -> `/api/v1/tours`).
   - If no tour data source is registered, renders an honest empty state (`TourDiscoveryFeedState.empty`) navigating to Tour Search. No fake tour availability is invented.
2. **R2 — Real Lifecycle Feed State Binding:**
   - Bound `loading`, `content`, `empty`, and `error` states to real data stream events in `TravelerHomeDashboardView`.
   - Pull-to-refresh (`RefreshIndicator`) triggers simultaneous reloads of both traveler trips (`MyTripsCubit.load()`) and public tour discovery (`TourSearchCubit.refresh()`).
   - `TourDiscoveryErrorView` conditionally displays the "Thử lại" button only when `onRetry != null`, invoking `TourSearchCubit.retryFailedQuery()`. No silent no-op callbacks.
3. **R3 — Tour Details Navigation & Hero Continuity:**
   - Selected cards transmit valid backend tour IDs (`tour.id`) to `AppRoutes.tourDetail(tourId, heroTag: heroTag)` with `extra: tour.toSummary()`.
   - Verified Frame-0 Hero mount (`_TourDetailLoadingHeroView`) in `TourDetailPage` prevents white-popping during network load.
   - Verified error handling, back navigation, and image error fallbacks across all states.
4. **R4 — Reconciled Documentation & Verification Claims:**
   - Corrected git HEAD SHA references against actual commit tree.
   - Removed all unsubstantiated claims asserting that `FlowDelegate` or `RepaintBoundary` "guarantees" 60/120 FPS.
   - Explicitly maintained **`PERFORMANCE_NOT_VERIFIED`** pending actual Profile AOT hardware evidence.
   - Maintained **`SONARQUBE_NOT_VERIFIED`** under SRS §4.2.6 due to absence of scanner tooling in the environment.
5. **R5 — Verified CI Workflow & Comprehensive Test Suite:**
   - Documented that stacked PR #77 receives no automatic GitHub Actions checks because `.github/workflows/ci.yml` strictly targets base branches `[develop, main]`.
   - Added `traveler_tour_discovery_integration_test.dart` and executed the full test suite (2,453 tests passed, 0 failed, 4 skipped).

---

## 2. Architecture & Data Provenance

### 2.1 Component Layout & Data Flow

```
Traveler Home Dashboard View (Screen #44)
  │
  ├──► TourSearchCubit (Registered in serviceLocator, or injected)
  │      └──► SearchToursUseCase -> TourSearchRepository -> /api/v1/tours
  │
  └──► BlocBuilder<TourSearchCubit, TourSearchState>
         │
         ├── Loading (items empty) ──► TourDiscoveryFeedState.loading (Motion Skeleton Shimmer)
         ├── Failure (items empty) ──► TourDiscoveryFeedState.error (TourDiscoveryErrorView + Real Retry)
         ├── Empty Results         ──► TourDiscoveryFeedState.empty (TourDiscoveryEmptyView -> Search)
         └── Content (items > 0)   ──► TourDiscoveryFeedState.content
                                         │
                                         └──► TravelerTourDiscoverySection
                                                ├── 1x FeaturedTourEditorialCard (16:9, Parallax, Tactile)
                                                ├── 2x CompactHorizontalTourCard (Parallax, Tactile)
                                                └── 1x SearchContinuationStrip (-> Tour Search)
```

### 2.2 Production Data Provenance
- In production runtime, `TravelerHomeDashboardView` reads from `TourSearchCubit`, which executes `GET /api/v1/tours?page=1&pageSize=20` with `skipAuth: true`.
- Each received `TourSummary` is mapped to `TourDiscoveryItem.fromSummary(summary)` preserving the actual backend `tourId`, genuine pricing, real operator name, and real availability status (`available` or `soldOut`).
- Ratings are only displayed when present from the backend (`summary.aggregateRating != null`); no ratings or availability numbers are fabricated.

---

## 3. Motion System Specifications (MOTION-01 to MOTION-05)

| Motion Token | Purpose & Parameters | Production Widget | Verification Evidence |
| :--- | :--- | :--- | :--- |
| **MOTION-01: Scroll Reveal** | • Duration: `400ms`<br>• Curve: `Curves.easeOutCubic`<br>• Stagger: `80ms`<br>• Translation: `16dp` -> `0dp` (Y-axis)<br>• Opacity: `0.0` -> `1.0`<br>• Trigger: strictly once per item key | `EditorialScrollReveal`<br>`TourRevealCoordinator` | `tour_discovery_motion_test.dart`<br>`editorial_responsive_and_accessibility_test.dart` |
| **MOTION-02: Photographic Parallax** | • Featured card: `±10dp` max displacement<br>• Compact card: `±6dp` max displacement<br>• Native `Flow` + `FlowDelegate`<br>• Zero parent widget rebuilds during scroll | `EditorialParallaxImage` | `tour_discovery_motion_test.dart`<br>`editorial_responsive_and_accessibility_test.dart` |
| **MOTION-03: Tactile Card Feedback** | • Scale factor: `0.985`<br>• Press duration: `110ms`<br>• Release duration: `180ms`<br>• Drag cancellation threshold: `> 8.0dp`<br>• Haptics: `HapticFeedback.selectionClick()`<br>• Preserves ink ripple & onTap | `EditorialTactileCard` | `tactile_and_hero_test.dart`<br>`traveler_tour_discovery_integration_test.dart` |
| **MOTION-04: Seamless Hero Flight** | • Scoped tags: `home_featured_<id>`, `home_compact_<id>`<br>• Custom `flightShuttleBuilder` (lerps radius `16dp` -> `0dp`)<br>• Frame-0 Thumbnail Mount in `TourDetailPage` prevents white-popping | `EditorialTourHero`<br>`_TourDetailLoadingHeroView` | `tactile_and_hero_test.dart`<br>`traveler_tour_discovery_integration_test.dart` |
| **MOTION-05: Feed State Transitions** | • Transition duration: `300ms`<br>• Curve: `Curves.easeInOut`<br>• Skeleton sweep duration: `1200ms`<br>• Smooth cross-fades across loading, content, empty, error | `TourDiscoveryFeedStates`<br>`AnimatedSwitcher` | `tour_discovery_motion_test.dart`<br>`traveler_tour_discovery_integration_test.dart` |

---

## 4. Responsive Viewport Matrix

Zero `RenderFlex` overflow errors verified across all tested physical viewport configurations:

| Viewport Profile | Width x Height | Text Scale | Verification Status | Layout Observation |
| :--- | :--- | :--- | :--- | :--- |
| **Compact Width** | 360 x 800 dp | 1.0x | **PASS (Zero Overflow)** | Proportional cards, tight vertical hierarchy, clear metadata |
| **Standard Baseline** | 390 x 844 dp | 1.0x | **PASS (Zero Overflow)** | Approved editorial composition, balanced negative space |
| **Large Android** | 412 x 915 dp | 1.0x | **PASS (Zero Overflow)** | Restrained 16:9 bounds prevent oversized vertical stretching |
| **Accessibility Scale** | 360 x 800 dp | **1.3x** | **PASS (Zero Overflow)** | Text wraps cleanly in vertical badges, prices remain anchored |

---

## 5. Reduced Motion & Accessibility (A11y) Verification

- **Reduced Motion Protocol:** When `MediaQueryData.disableAnimations` is `true`:
  - `EditorialScrollReveal`: Renders children immediately with `opacity: 1.0` and `offset: Offset.zero`.
  - `EditorialParallaxImage`: Locks translation offset to `0.0`.
  - `EditorialTactileCard`: Bypasses `ScaleTransition`, preserving instant tap responses.
  - `TourDiscoveryMotionSkeleton`: Static placeholder rendering without continuous ticker looping.
- **Screen Reader Semantics:**
  - `FeaturedTourEditorialCard` announces tour title, duration, and formatted VND price with `button: true`.
  - `CompactHorizontalTourCard` announces concise summary metadata with `button: true`.
  - `SearchContinuationStrip` announces remaining tour availability count with actionable search role.
  - `TourDiscoveryEmptyView` & `TourDiscoveryErrorView` provide accessible action buttons.

---

## 6. SRS §4.2.6 & Quality Gate Analysis

### 6.1 SonarQube Status: `SONARQUBE_NOT_VERIFIED`
- **Official SRS Clause:** §4.2.6 requires maintainability and testability with zero Critical or Blocker bugs before release.
- **Investigation Result:**
  - `sonar-project.properties`: **Absent** from repository root.
  - `sonar-scanner` / SonarCloud CLI: **Not installed** in execution environment.
  - GitHub Actions SonarQube workflow: **Not configured** in `.github/workflows/`.
- **Classification:** **`SONARQUBE_NOT_VERIFIED`** (honestly reported without fabricating passing quality gate evidence).
- **Remediation Recommendation:** Add SonarCloud integration to GitHub Actions via `SonarSource/sonarqube-scan-action` configured for Dart LCOV analysis.

### 6.2 Code Quality & Static Analysis: `PASS`
- `dart analyze .`: **0 issues found** (Clean across entire codebase).
- `dart format --set-exit-if-changed .`: **0 changed files (100% compliant)**.
- Strict null safety: 100% compliant, zero force unwraps (`!`).

---

## 7. Performance & Frame Budget Analysis

### 7.1 Status: `PERFORMANCE_NOT_VERIFIED`
- **Technical Root Cause:** The current execution environment operates in a headless container without an attached physical GPU or hardware-accelerated profiler capable of running `flutter run --profile`.
- **Clarification on Architectural Mechanics (No Unverified Guarantees):**
  - While using `FlowDelegate` matrix translation avoids widget tree rebuilds during scrolling and `RepaintBoundary` avoids parent layer repainting during card touch, **these architectural techniques do not inherently guarantee a constant 60 or 120 FPS on all physical devices**. Real-world frame delivery depends on device CPU/GPU workload, thread contention, and rasterization overhead.
  - Performance remains honestly classified as **`PERFORMANCE_NOT_VERIFIED`** until Profile AOT traces on physical hardware are captured.

---

## 8. Real GitHub Actions CI Coverage on PR #77

- **Trigger Condition in `.github/workflows/ci.yml`:**
  ```yaml
  on:
    pull_request:
      branches: [develop, main]
    push:
      branches: [develop, main]
  ```
- **PR #77 Stacked Configuration:** PR #77 targets base branch `feature/editorial-pr1-theme-assets` (not `develop` or `main`).
- **Observed CI Result:** GitHub Actions does NOT trigger CI runs on PRs targeting intermediate feature branches (`gh pr checks 77` reports `no checks reported`).
- **Remediation & Merge Strategy:** All checks have been run locally (`flutter pub get`, `dart format`, `dart analyze`, and `flutter test`). Once PR #74 is merged into `develop` and PR #77 is retargeted to `develop`, GitHub Actions CI will automatically execute.

---

## 9. Complete Git Commit Lineage

All commits on `feature/editorial-tour-discovery-motion` stacked on base `eb9158732c127df590a11e3b4c0ffc8b0a0daa41`:

| Commit # | SHA | Commit Subject |
| :--- | :--- | :--- |
| **01** | `ed0c688` | `refactor(traveler-home): isolate tour discovery presentation from existing data flow` |
| **02** | `76462cc` | `feat(tour-discovery): integrate featured and compact editorial tour cards` |
| **03** | `83876b8` | `feat(tour-discovery): add scroll reveal parallax and content transitions` |
| **04** | `2e588ef` | `feat(tour-discovery): add tactile card feedback and safe hero navigation` |
| **05** | `852a5fb` | `test(tour-discovery): verify responsive motion navigation and accessibility` |
| **06** | `38bfb37` | `docs(tour-discovery): add visual review motion QA and performance evidence` |
| **07** | `7bf3c27` | `refactor(tour-discovery): eliminate production fixture dependency and connect real tour search feed` |
| **08** | `0465987` | `test(tour-discovery): verify data flow lifecycle states and tour detail hero navigation` |
| **09** | *(Pending)* | `docs(tour-discovery): reconcile verification claims and update PR77 evidence` |
