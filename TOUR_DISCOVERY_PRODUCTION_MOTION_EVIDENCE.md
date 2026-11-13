# TRIPMATE MOBILE — PRODUCTION TOUR DISCOVERY MOTION IMPLEMENTATION EVIDENCE

**Author / Roles:** Senior Flutter Engineer, Motion Design Engineer, QA Engineer, GitHub Release Engineer  
**Date:** 2026-11-13  
**Repository:** `FPTUCapstone/Capstone_Mobile`  
**Feature Branch:** `feature/editorial-tour-discovery-motion`  
**Base Branch:** `feature/editorial-pr1-theme-assets` (Stacked Draft PR on PR #74 HEAD `eb9158732c127df590a11e3b4c0ffc8b0a0daa41`)  
**Status:** **DRAFT PULL REQUEST READY**

---

## 1. Executive Summary

This document presents the implementation, motion engineering, quality assurance evidence, and release readiness for porting **Variant A — Featured + Compact Editorial Feed** into the production codebase of TripMate Mobile.

### Core Objectives Delivered:
1. **Asymmetric Editorial Layout (Variant A):** Replaced repetitive full-width cards with a curated visual hierarchy: 1 primary featured card (16:9 restrained aspect ratio) followed by 2 compact horizontal cards (balanced 116dp image ratio, clear metadata, duration, rating, and price anchors), concluding with an organic Search Continuation strip.
2. **Complete Motion Design System (MOTION-01 to MOTION-05):** Fully implemented native Flutter physics-based animations (scroll reveal with 80ms stagger, native Flow-based photographic parallax, calm tactile touch feedback with 8dp drag cancellation, seamless Hero transition with Frame-0 thumbnail mounting, and smooth feed state transitions).
3. **Screen #65 (Tour Detail) Frame-0 Hero Continuity:** Resolved the Hero blank-popping defect by mounting `_TourDetailLoadingHeroView` on Frame 0 when `initialSummary` is supplied, providing uninterrupted flight transition while details load.
4. **Architectural Isolation:** Cleanly encapsulated discovery logic in `lib/features/tour_discovery/` without mutating existing repositories, business rules, or route guards.
5. **Zero Visual Overflow:** Verified zero RenderFlex overflow across 360dp, 390dp, 412dp widths, and 360dp at 1.3x text scale.
6. **Full Reduced-Motion & A11y Support:** Respects `MediaQuery.disableAnimations` and `reduceMotion` across all components.

---

## 2. Architecture & Domain Mapping

### 2.1 File Map

```
lib/
├── app/
│   └── router/
│       ├── app_router.dart                     [Updated: passes heroTag query parameter to TourDetailPage]
│       └── app_routes.dart                     [Updated: AppRoutes.tourDetail(id, {heroTag}) support]
├── features/
│   ├── tour_detail/
│   │   └── presentation/pages/
│   │       └── tour_detail_page.dart           [Updated: Screen #65 Frame-0 Hero mount for smooth flight]
│   ├── tour_discovery/
│   │   ├── domain/entities/
│   │   │   └── tour_discovery_item.dart        [New: Pure domain entity mapping to/from TourSummary]
│   │   └── presentation/widgets/
│   │       ├── compact_horizontal_tour_card.dart  [New: Variant A compact card with tactile & parallax]
│   │       ├── featured_tour_editorial_card.dart  [New: Variant A featured 16:9 card with tactile & parallax]
│   │       ├── search_continuation_strip.dart     [New: Search continuation banner into Screen #63]
│   │       ├── tour_discovery_feed_states.dart    [New: MOTION-05 Shimmer skeleton, empty & error states]
│   │       ├── tour_discovery_meta_widgets.dart   [New: RatingInline, PriceAnchor, Operator/Duration meta]
│   │       └── traveler_tour_discovery_section.dart [New: Orchestrator section for Traveler Home Screen #44]
│   └── traveler/
│       └── presentation/widgets/
│           └── traveler_home_dashboard_view.dart  [Updated: Replaced legacy card list with TravelerTourDiscoverySection]
└── shared/
    └── widgets/
        └── motion/
            ├── editorial_parallax_image.dart      [New: MOTION-02 Flow/FlowDelegate parallax image]
            ├── editorial_scroll_reveal.dart       [New: MOTION-01 400ms easeOutCubic staggered reveal]
            ├── editorial_tactile_card.dart        [New: MOTION-03 0.985 scale tactile press feedback]
            └── editorial_tour_hero.dart           [New: MOTION-04 Flight shuttle with lerping border radius]

test/features/tour_discovery/
├── domain/entities/tour_discovery_item_test.dart  [Domain entity & mapping tests]
└── presentation/widgets/
    ├── editorial_responsive_and_accessibility_test.dart [Responsive viewports, reduced motion, a11y]
    ├── tactile_and_hero_test.dart                      [Tactile feedback & Hero Frame-0 mount tests]
    ├── tour_discovery_motion_test.dart                 [Scroll reveal, parallax, feed transitions]
    └── variant_a_tour_cards_test.dart                  [Variant A card layout and rendering tests]
```

### 2.2 Domain Separation
The `TourDiscoveryItem` entity acts as a decoupled view-model that preserves full interoperability with production `TourSummary`:
- `TourDiscoveryItem.fromSummary(TourSummary summary)`
- `TourDiscoveryItem.toSummary()`
- Curated fallback default items (`TourDiscoveryItem.curatedDefault`) sourcing verified local destination assets (`danang_dragon_bridge.jpg`, `hue_ngo_mon.jpg`, etc.) bundled in PR #74.

---

## 3. Motion System Verification Matrix

| Motion Token | Purpose | Specs & Parameters | Verification Status | Test Evidence |
| :--- | :--- | :--- | :--- | :--- |
| **MOTION-01: Scroll Reveal** | Staggered entrance animation as cards scroll into viewport | - Duration: `400ms`<br>- Curve: `Curves.easeOutCubic`<br>- Stagger: `80ms` between simultaneous items<br>- Translation: `16dp` -> `0dp` on Y-axis<br>- Opacity: `0.0` -> `1.0`<br>- Reveal guard: Reveals once per key | **VERIFIED** | `tour_discovery_motion_test.dart`<br>`editorial_responsive_and_accessibility_test.dart` |
| **MOTION-02: Photographic Parallax** | Subtle optical depth during scroll | - Native `Flow` + `FlowDelegate`<br>- Featured card: `±10dp` max displacement<br>- Compact card: `±6dp` max displacement<br>- Zero parent widget rebuilds<br>- Zero text / layout displacement | **VERIFIED** | `tour_discovery_motion_test.dart`<br>`editorial_responsive_and_accessibility_test.dart` |
| **MOTION-03: Tactile Card Feedback** | Calm touch feedback on card interaction | - Scale factor: `0.985`<br>- Press duration: `110ms`<br>- Release duration: `180ms`<br>- Curve: `Curves.easeOutCubic`<br>- Drag cancellation threshold: `> 8.0dp`<br>- System haptic click: `HapticFeedback.selectionClick()`<br>- Preserves ink ripple & onTap | **VERIFIED** | `tactile_and_hero_test.dart`<br>`editorial_responsive_and_accessibility_test.dart` |
| **MOTION-04: Seamless Hero Flight** | Fluid shared element transition between Traveler Home (Screen #44) and Tour Detail (Screen #65) | - Custom `flightShuttleBuilder`<br>- Interpolates border radius: `16dp` -> `0dp`<br>- Scoped hero tags: `home_featured_<id>`, `home_compact_<id>`<br>- Frame-0 Thumbnail Mount: `_TourDetailLoadingHeroView` mounts hero instantly on Frame 0 before network completion | **VERIFIED** | `tactile_and_hero_test.dart` |
| **MOTION-05: Feed State Transitions** | Smooth transition between loading skeleton, content, empty, and error states | - `AnimatedSwitcher`<br>- Duration: `300ms`<br>- Curve: `Curves.easeInOut`<br>- Skeleton shimmer sweep duration: `1200ms`<br>- Empty and error states with retry actions | **VERIFIED** | `tour_discovery_motion_test.dart`<br>`editorial_responsive_and_accessibility_test.dart` |

---

## 4. Responsive Viewport Matrix

All layouts were tested across physical viewport constraints to ensure no `RenderFlex` overflow errors:

| Viewport Profile | Width x Height | Text Scale | Result | Visual Behavior |
| :--- | :--- | :--- | :--- | :--- |
| Compact Android / iOS | 360 x 800 dp | 1.0x | **PASS (Zero Overflow)** | Proportional cards, compact metadata alignment, 16:9 featured header |
| Standard Modern Phone | 390 x 844 dp | 1.0x | **PASS (Zero Overflow)** | Ideal editorial density, comfortable margins, clean typography |
| Large Flagship Android | 412 x 915 dp | 1.0x | **PASS (Zero Overflow)** | Restrained image bounds prevent excessive vertical stretching |
| Accessibility Large Text | 360 x 800 dp | **1.3x** | **PASS (Zero Overflow)** | Text wraps cleanly in vertical badges, prices remain anchored without truncating |

---

## 5. Reduced Motion & Accessibility (A11y) Verification

- **Reduced Motion Protocol:** When `MediaQueryData.disableAnimations` is `true` (system setting or widget override):
  - `EditorialScrollReveal`: Renders children immediately with `opacity: 1.0` and `offset: Offset.zero`.
  - `EditorialParallaxImage`: Locks translation offset to `0.0`.
  - `EditorialTactileCard`: Bypasses `ScaleTransition`, preserving instant tap responses.
  - `TourDiscoveryMotionSkeleton`: Static placeholder rendering without continuous ticker looping.
- **Screen Reader Semantics:**
  - `FeaturedTourEditorialCard` announces tour title, location, duration, rating, and formatted VND price with `button: true`.
  - `CompactHorizontalTourCard` announces concise summary metadata with `button: true`.
  - `SearchContinuationStrip` announces remaining tour availability count with actionable search role.
  - `TourDiscoveryEmptyView` & `TourDiscoveryErrorView` provide accessible action buttons ("Thử lại", "Mở tìm kiếm tour").

---

## 6. SRS §4.2.6 & Quality Gate Analysis

### 6.1 SonarQube Status: `SONARQUBE_NOT_VERIFIED`
- **Official SRS Clause:** §4.2.6 requires maintainability and testability with zero Critical or Blocker bugs before release.
- **Investigation Result:**
  - `sonar-project.properties`: **Absent** from repository root.
  - `sonar-scanner` / SonarCloud CLI: **Not installed** in execution environment.
  - GitHub Actions SonarQube workflow: **Not configured** in `.github/workflows/`.
- **Classification:** **`SONARQUBE_NOT_VERIFIED`** (honestly classified without fabricating passing quality gate evidence).
- **Remediation Recommendation:** Add SonarCloud integration to GitHub Actions via `SonarSource/sonarqube-scan-action` configured for Dart LCOV analysis.

### 6.2 Code Quality & Static Analysis: `PASS`
- `dart analyze`: **0 issues found** (Clean across entire codebase).
- `dart format --set-exit-if-changed .`: **0 changed** (100% compliant).
- Strict null safety: 100% compliant, zero force unwraps (`!`).

---

## 7. Performance & Frame Budget Analysis

### 7.1 Status: `PERFORMANCE_NOT_VERIFIED`
- **Technical Root Cause:** The current execution environment is a headless CI/developer workspace without an attached physical GPU profiler or hardware-accelerated device capable of running `flutter run --profile`.
- **Architectural Frame-Budget Compliance (by design):**
  1. **Native Flow Parallax:** Uses Flutter's `FlowDelegate.paintChildren` matrix translation. Bypasses `setState()` and widget tree rebuilds entirely during scroll events.
  2. **Repaint Boundaries:** `EditorialTactileCard` wraps its content in `RepaintBoundary` so that scale transformations do not invalidate the parent scrollable layer.
  3. **Decoded Image Cache Limits:** `cacheWidth` hints (`1080` for featured cards, `360` for compact cards) prevent full-resolution bitmap inflation in GPU memory.

---

## 8. Atomic Commits Summary

| Commit # | SHA | Commit Subject | Key Deliverables |
| :--- | :--- | :--- | :--- |
| **01** | `ed0c688` | `refactor(traveler-home): isolate tour discovery presentation from existing data flow` | Extracted `TravelerTourDiscoverySection` from `traveler_home_dashboard_view.dart`, isolated data flow |
| **02** | `76462cc` | `feat(tour-discovery): integrate featured and compact editorial tour cards` | Created `TourDiscoveryItem`, `FeaturedTourEditorialCard`, `CompactHorizontalTourCard`, meta widgets |
| **03** | `83876b8` | `feat(tour-discovery): add scroll reveal parallax and content transitions` | Implemented `EditorialScrollReveal` (MOTION-01), `EditorialParallaxImage` (MOTION-02), and feed states (MOTION-05) |
| **04** | `2e588ef` | `feat(tour-discovery): add tactile card feedback and safe hero navigation` | Implemented `EditorialTactileCard` (MOTION-03), `EditorialTourHero` (MOTION-04), Screen #65 Frame-0 hero mount |
| **05** | `852a5fb` | `test(tour-discovery): verify responsive motion navigation and accessibility` | Added full responsive matrix (360/390/412dp & 1.3x text scale), reduced motion, and a11y tests |
| **06** | *(Pending)* | `docs(tour-discovery): add visual review motion QA and performance evidence` | Added comprehensive evidence documentation in `TOUR_DISCOVERY_PRODUCTION_MOTION_EVIDENCE.md` |

---

## 9. Next Steps for Merge Readiness

1. Merge or finalize PR #74 (`feature/editorial-pr1-theme-assets`).
2. Retarget or rebase `feature/editorial-tour-discovery-motion` onto `develop` once PR #74 is merged into `develop`.
3. Conduct Human UX Review on physical Android/iOS devices for real-world touch feel.
