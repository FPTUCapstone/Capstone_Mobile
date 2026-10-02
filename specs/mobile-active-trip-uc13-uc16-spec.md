# Specification: Mobile-Only Active Trip Experience
## UC-13 / UC-14 / UC-15 / UC-16

---

### 1. Scope

- **Target Role**: Traveler only. Commercial Tour Operators and Web Administrators are strictly out of scope.
- **Platform**: Flutter Mobile application (Android / iOS). Web support is excluded per SRS.
- **Functional Scope**:
  - **UC-13 — Navigate Route**: Live route guidance, active waypoint progression, GPS location tracking, maneuver instructions, remaining travel time, and trip completion.
  - **UC-14 — Receive Real-Time Alerts**: Real-time awareness of trip disruptions (weather, delays, closures, deviations) delivered via in-navigation banners and a dedicated trip alerts history list.
  - **UC-15 — Confirm Re-routing**: Interactive comparison of current vs. proposed plans with an explicit, non-automatic Traveler consent gate.
  - **UC-16 — Download Offline Map & Itinerary**: Local device caching of itinerary, POI data, route information, and map tiles subject to a strict 150 MB storage limit.
- **Phase Objective**: Complete architectural and UI/UX specification.

---

### 2. Source of Truth

This specification is grounded strictly in:
1. **Report 3 Software Requirements Specification (SRS)**:
   - §3.3.4 UC-13 Navigate Route (BR-28, BR-31, BR-35, BR-40, PC-01 to PC-04)
   - §3.3.5 UC-14 Receive Real-Time Alerts (BR-29, BR-30, BR-31, BR-32, PC-01 to PC-04)
   - §3.3.6 UC-15 Confirm Re-routing (BR-25, BR-26, BR-27, BR-31, BR-33, PC-01 to PC-04)
   - §3.3.7 UC-16 Download Offline Map & Itinerary (BR-36, BR-37, BR-38, BR-39, BR-40, PC-01 to PC-04)
2. **Current `develop` Baseline**:
   - Integration Commit: `cb483fd8250fd997e7e7f5b050f3a2700af2a3c4`
   - Clean working tree verified.
3. **Repository Rules & Standards**:
   - `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `docs/CODEBASE_RULES.md`
4. **Mobile Design System**:
   - Material 3 tokens defined in `lib/app/theme/` (`AppColors`, `AppSpacing`, `AppTypography`, `AppTheme`) and `lib/shared/widgets/`.
5. **Read-Only Backend Audit**:
   - Architecture and schema evidence in `Capstone_BE` (read-only; no endpoints invented).

---

### 3. Existing Implementation Baseline

The current mobile repository contains the following baseline use cases:
- **UC-10 (Create Scheduling Request)**: Implemented (`CreateItineraryPage`, `CreateItineraryCubit`, `PoiSearchCubit`).
- **UC-11 (View Suggested Itinerary)**: Implemented (`ItineraryResultPage`). Displays timeline, arrival/departure estimates, entry fees, and mandatory POI badges. Currently ends with a single "Create another itinerary" action.
- **UC-12 (Explore Points of Interest)**: Implemented (`ExplorePoiPage`, `PoiDetailPage`, `PoiMapPreview`).
- **UC-17 to UC-19, UC-23 (Travel Groups)**: Implemented for group creation, QR/code invitation, read-only member lists, and group joining.
- **UC-13, UC-14, UC-15**: **NOT_STARTED** across Presentation, Domain, and Data layers.
- **UC-16**: **PLACEHOLDER** visual row in `TravelerSettingsPage` (`Offline downloads: 248 MB`), but underlying business logic, download management, and trip-level packaging are **NOT_STARTED**.

---

### 4. Product Journey

The Active Trip experience links UC-13 through UC-16 into a single cohesive, thumb-friendly mobile journey:

```
Suggested Itinerary (UC-11)
  │
  ├── [Download for Offline Use] ──► Offline Package Manager (UC-16)
  │                                    └─ Local package cached (<150 MB)
  │
  └── [Start Navigation] (Itinerary Active)
        │
        ▼
   ACTIVE TRIP SHELL (UC-13)
   ┌──────────────────────────────────────────────────────────────┐
   │ Top: Maneuver instruction card & connection status badge     │
   │ Center: Map canvas (MAP_INTEGRATION_PENDING preview)         │
   │ Bottom: Contextual waypoint panel & trip progress            │
   └──────────────────────────────────────────────────────────────┘
        │
        ├── Disruption Detected ──► In-Navigation Alert Banner (UC-14)
        │                             │
        │                             ├── Tap [Review] ──┐
        │                             ▼                  │
        │                     Trip Alerts List (UC-14)   │
        │                             │                  │
        │                             └── Tap [Review] ──┤
        │                                                ▼
        └── Deviation >500m / Route Impact ──► Re-routing Proposal Sheet (UC-15)
                                                 │
                                                 ├── [Accept Re-routing]
                                                 │     └─ Version V+1 stored
                                                 │     └─ Route updated in place
                                                 │
                                                 └── [Keep Current Route]
                                                       └─ Proposal declined
                                                       └─ Current plan retained
```

- **Entry**: Traveler views an approved/active itinerary from UC-11 or "My Trips" and initiates either offline preparation (UC-16) or live navigation (UC-13).
- **In-Trip Alerts (UC-14)**: Non-intrusive alert banners appear during live execution. Tapping an alert opens the full alerts history list.
- **Re-routing (UC-15)**: Triggered by route deviation (>500m) or route-affecting alerts. Renders as a modal sheet over the navigation canvas without tearing down the active navigation session.
- **Consent Gate**: Route adjustments require explicit Traveler acceptance. An unaccepted or expired proposal leaves the active plan intact.
- **Completion / Exit**: Reaching the final waypoint or explicitly tapping "Stop Navigation" triggers a confirmation dialog, logs arrival, and displays the trip summary.

---

### 5. Screen Inventory

| Presentation Unit | Presentation Type | Primary Role | Scope & Responsibility |
| :--- | :--- | :--- | :--- |
| **`ActiveTripPage`** | Full Page | Traveler | Core live navigation canvas, turn-by-turn guidance banner, GPS status indicator, map controls, next waypoint card, and in-navigation alert banner host. |
| **`TripAlertsSheet` / `TripAlertsPage`** | Modal Bottom Sheet or Full Sub-page | Traveler | Reverse-chronological history of all trip alerts (weather, delays, closures, deviations) with read/acknowledgment status and re-routing action triggers. |
| **`RerouteProposalSheet`** | Modal Bottom Sheet | Traveler | In-context comparison sheet presenting current vs. proposed plans, travel-time delta, arrival-time delta, affected stops, and explicit Accept / Decline buttons. |
| **`OfflineTripPackagePage`** | Full Page | Traveler | Trip offline package inspector: size estimation, 150 MB ceiling verification, component progress indicator, and download/delete/refresh controls. |

---

### 6. Provisional Route Architecture

> **[PROVISIONAL_ROUTE_IDENTITY]**  
> The routes below use `itineraryId` to integrate naturally with the existing UC-11 navigation context (`ItineraryResultPage`). This identifier strategy is provisional for Mobile UI delivery. It does not assert that `itineraryId` will be the final server-side navigation session token once backend contracts are established.

Proposed route constants for `AppRoutes`:
- `AppRoutes.activeTripLive`: `/traveler/trips/:itineraryId/live` (Name: `active-trip-live`)
- `AppRoutes.tripAlerts`: `/traveler/trips/:itineraryId/alerts` (Name: `trip-alerts`)
- `AppRoutes.offlinePackage`: `/traveler/trips/:itineraryId/offline` (Name: `offline-package`)

**Presentation Placement for Re-routing**:
- `RerouteProposalSheet` is designed as an **in-context modal bottom sheet** presented directly over `ActiveTripPage`. It will not have a standalone route path during initial UI delivery to prevent disruptive full-page navigation context loss.

**Route Guard Rules**:
- Scoped under `/traveler/*`. Non-authenticated users redirect to `/auth/login?from=...`.
- Authenticated Tour Operators redirect safely to `/operator` or `/operator/application`.

---

### 7. UC-13 Specification — Navigate Route

- **Actor**: Traveler, System.
- **Trigger**: Traveler selects *Start Navigation* on an Active itinerary.
- **Preconditions**: Itinerary is in `Active` status; device location permission is granted.
- **Interface**: `ActiveTripPage`.
- **System Behavior & Arrival Detection**:
  - Continuous GPS sampling tracks user progress along the active polyline segment.
  - **Arrival Behavior**: When GPS coordinates enter the configured proximity threshold of the scheduled stop, the **SYSTEM automatically marks the item as reached and advances navigation to the next scheduled stop**.
  - **No Manual Arrival Button**: The production interface **must not** contain a manual `[Arrived at this stop]` business action.
  - **Debug / Demo Simulation**: A clearly labeled development fixture control (`[Simulate Arrival at Next Stop]`) will be provided strictly in `DEMO_ONLY` mode to facilitate manual UI verification.
- **Stop Navigation Flow**:
  - Traveler taps the exit/stop control.
  - A confirmation dialog appears requesting confirmation before ending the session.
  - Upon confirmation, navigation stops, the session ends, and the final completion state is surfaced.
- **Business Rules**:
  - `BR-28`: Navigation requires an active itinerary and granted location permissions.
  - `BR-31`: Deviation beyond threshold raises a re-routing suggestion (UC-15); never applied automatically.
  - `BR-35`: Turn-by-turn guidance is supplied by the integrated map service; TripMate does not calculate road-level routing natively.
  - `BR-40`: While offline, navigation falls back to downloaded data (UC-16). Server-confirmed actions remain disabled.

---

### 8. UC-14 Specification — Receive Real-Time Alerts

- **Actor**: Traveler, System.
- **Trigger**: System detects a disruption event relevant to the active itinerary or the Traveler's current position.
- **Interface**:
  - Primary: In-navigation alert banner (`TripAlertBanner`) anchored below the maneuver card on `ActiveTripPage`.
  - Secondary: Full trip alerts history sheet/page (`TripAlertsSheet` / `TripAlertsPage`).
- **Information Architecture**:
  - Alert type indicator (icon + text).
  - Severity level (High, Medium, Info) signaled via icon and text, **never by color alone**.
  - Short description and affected stop/segment.
  - Detection timestamp.
  - Re-routing availability indicator (with direct trigger to UC-15 if applicable).
- **Banner Lifecycle**:
  - Appears smoothly upon alert arrival.
  - Can be dismissed from the navigation view by the user.
  - **Retention Rule (`BR-32`)**: Dismissing the banner does not discard the alert. All delivered alerts are retained in the trip's Alerts list until the trip is completed.

---

### 9. UC-15 Specification — Confirm Re-routing

- **Actor**: Traveler.
- **Trigger**: System offers a re-routing suggestion following a route deviation (>500m) or a severe real-time alert, and the Traveler selects *Review Proposal*.
- **Interface**: `RerouteProposalSheet` (Modal bottom sheet over `ActiveTripPage`).
- **Authoritative Comparison Data (SRS Core)**:
  - **Reason for Suggestion**: Explicit cause (e.g., severe weather alert, route deviation, closed POI).
  - **Current Plan vs. Proposed Plan**: Visual route representation and affected stop sequence.
  - **Estimated Travel-Time Difference**: Delta in travel duration (e.g., `-15 min` or `+10 min`).
  - **Estimated Arrival-Time Difference**: Updated estimated time of arrival at subsequent stops.
  - **Affected Scheduled Items**: List of stops modified, replaced, or reordered.
- **Optional / Exploratory Metrics (`DEMO_ONLY`)**:
  - Cost delta, distance delta, or "stops kept count" may be included in demo fixtures for UI richness, but are **not** treated as required production contracts.
- **Consent Semantics & Business Rules**:
  - `BR-25`: Proposed plan must respect POI opening hours and travel times.
  - `BR-26`: Accepting re-routing stores the proposed plan as a new itinerary version with an incremented version number ($V+1$).
  - `BR-27`: The previous itinerary version is retained in history and never overwritten.
  - `BR-31` & `BR-33`: **A re-routing is NEVER applied automatically.** Traveler confirmation must be explicit.
  - **Declining or Expiration**: Tapping *[Keep Current Route]* or allowing the proposal to expire closes the suggestion as declined. The current route remains active without modification.

---

### 10. UC-16 Specification — Download Offline Map & Itinerary

- **Actor**: Traveler.
- **Trigger**: Traveler opens an accessible itinerary and taps *Download for Offline Use*.
- **Interface**: `OfflineTripPackagePage`.
- **Authoritative Core Behavior & Data**:
  - Itinerary identity, date range, and stops summary.
  - Downloaded itinerary version and local download timestamp.
  - Offline availability state (Not Downloaded, Downloading, Available Offline, Superseded).
  - Estimated package size validated against the **configured 150 MB limit (`BR-37`)**.
  - Free device storage validation prior to download.
  - Granular download progress (Itinerary data, POI data, Map data).
  - Actions: *[Download for Offline Use]*, *[Cancel Download]*, *[Remove Offline Data]*.
  - **Refresh Flow (Alternative Flow)**: When an itinerary available offline has been updated on the server ($V_{\text{server}} > V_{\text{local}}$), the UI offers to refresh. The superseded local copy remains functional until the new download completes successfully.
  - **Integrity Rule (`BR-38`)**: A partially downloaded package is **never** marked as available offline. If aborted or interrupted, incomplete data is discarded.
- **Optional Controls (`OPTIONAL_UX_ENHANCEMENT` / `DEMO_ONLY`)**:
  - Wi-Fi-only toggle, automatic background refresh toggle, specific zoom level selections, and individual component MB breakdowns are classified as optional UI enhancements and are not required production contracts.

---

### 11. UI State Models (Semantic)

To eliminate coupling with conflicting numeric SRS message IDs, domain and presentation layers will use **semantic state representations**:

#### A. Active Navigation States (`ActiveTripState`)
- `navigationInitial`: Preparing session.
- `navigationAcquiringPosition`: Awaiting valid GPS fix.
- `navigationActive`: Live tracking in progress with valid position, active maneuver, and ETA.
- `navigationOffRouteDeviation`: Current position deviates >500m; re-routing suggestion raised.
- `navigationPausedBattery`: Position updates suspended due to device power-saving mode.
- `navigationArrivedAtWaypoint`: System detected arrival; advances active item.
- `navigationTripCompleted`: Final scheduled stop reached or session terminated by user.
- `navigationPermissionDenied`: Location permission not granted.
- `navigationPositionUnavailable`: GPS signal lost or hardware unavailable.

#### B. Trip Alert Feed States (`TripAlertState`)
- `alertFeedInitial`: Uninitialized.
- `alertFeedLoading`: Retrieving active alert log.
- `alertFeedActive`: Displays current list of alerts; banner active if unread/unacknowledged items exist.
- `alertFeedEmpty`: No alerts active for the current trip.
- `alertFeedError`: Failure retrieving alert updates.

#### C. Re-routing Proposal States (`RerouteProposalState`)
- `rerouteNone`: No active proposal.
- `reroutePendingReview`: Valid proposal available for Traveler review.
- `rerouteApplying`: User accepted; persisting version $V+1$ and updating route segment.
- `rerouteAccepted`: Transition successful; navigation resumed on new route.
- `rerouteDeclined`: User rejected proposal; continuing on current plan.
- `rerouteExpired`: Proposal response window lapsed without decision; discarded.
- `rerouteError`: Failure persisting accepted version.

#### D. Offline Package States (`OfflinePackageState`)
- `offlineNotDownloaded`: Package not stored on device.
- `offlineCheckingStorage`: Validating local space against package size and 150 MB ceiling.
- `offlineDownloading`: Download stream in progress with percentage completion.
- `offlineAvailable`: Fully stored and ready for offline execution.
- `offlineSuperseded`: Server version has incremented; refresh available.
- `offlineInsufficientStorage`: Device free space is below the required 150 MB threshold.
- `offlineNetworkInterrupted`: Connection dropped mid-download; partial data discarded.
- `offlineError`: Local disk write failure or general persistence error.

---

### 12. Device Dependencies

| Device Capability | Supporting Package | Current Status | Usage in Active Trip Experience |
| :--- | :--- | :--- | :--- |
| **GPS Position Stream** | `geolocator: ^14.0.2` | **PARTIAL** | One-shot location exists. Continuous streaming via `getPositionStream()` is required for UC-13. |
| **Location Permission** | `geolocator: ^14.0.2` | **AVAILABLE** | Permission queries and settings navigation support exist. |
| **Network State Monitoring** | `connectivity_plus: ^7.0.0` | **AVAILABLE** | Connectivity listener exists; binds to offline indicators and download safety checks. |
| **Local File System** | Native / `path_provider` | **MISSING** | Required for UC-16 to persist offline trip JSON, POI text data, and tile archives. Kept demo-scoped for initial preview. |
| **Map Rendering Engine** | Google Maps / Mapbox / OSM | **MISSING** | Marked **`MAP_INTEGRATION_PENDING`**. Decoupled canvas widget used for development preview. |
| **Push Notification Receiver** | Firebase Cloud Messaging | **MISSING** | Required for background alert delivery. In foreground UI preview, simulated via Cubit streams. |

---

### 13. Backend Capability Dependencies

All backend capabilities for UC-13 through UC-16 are currently absent from `Capstone_BE`. No speculative HTTP endpoints are defined. Requirements are cataloged as conceptual backend contracts:

- **`ACTIVE_TRIP_SESSION_CONTRACT_MISSING`**: Backend capability required to start a trip session, record reached waypoints, evaluate itinerary active status, and conclude sessions.
- **`REAL_TIME_ALERT_CONTRACT_MISSING`**: Backend capability required to broadcast or query weather disruptions, traffic events, POI closures, and route deviation events for an active itinerary.
- **`REROUTING_CONTRACT_MISSING`**: Backend capability required to calculate feasible alternative routes/shelters respecting opening hours and persist version increments ($V+1$) upon explicit user acceptance.
- **`OFFLINE_SOURCE_DATA_CONTRACT_MISSING`**: Backend capability required to bundle an itinerary, its POIs, route polylines, and bounding-box map tile assets into a downloadable payload under 150 MB.
- **`UC72_SYNC_CONTRACT_PARTIAL`**: Backend database schema contains `trip.OfflineSyncBatches` and `trip.OfflineSyncItems` for uploading buffered offline check-ins, but API controllers are missing. (Independent background process; not part of UC-16 download flow).

---

### 14. Map Integration Policy

> **[MAP_INTEGRATION_PENDING]**

- **Strict Dependency Ban**: Neither `google_maps_flutter`, `mapbox_maps_flutter`, nor `flutter_map` will be added to `pubspec.yaml` in this delivery batch.
- **Development Canvas**:
  - The map area in `ActiveTripPage` and `RerouteProposalSheet` will render using an isolated vector-projection canvas widget patterned after the approved `PoiMapPreview`.
  - The canvas will render polyline paths, waypoint pins, and user GPS position using local coordinate transforms.
  - A persistent, prominent development banner reading **"MAP INTEGRATION PENDING — Illustration Preview Only"** will be displayed across the map area.
  - All navigation business rules, waypoint sequencing, and BLoC states must remain completely decoupled from any specific map rendering package.

---

### 15. Demo Fixture Policy

- **Development / Demo Scope Only (`DEMO_ONLY`)**:
  - All mock data, GPS position streams, arrival simulations, synthetic weather alerts, and offline package downloads must reside strictly in an isolated demo location (e.g., `lib/features/traveler/presentation/demo/`).
  - Fixtures will allow reviewers to exercise the interactive UI without a live backend or physical movement.
- **Safety Prohibitions**:
  - No fake production HTTP clients or interceptors pretending to talk to real backend services.
  - No DTOs or entities named after hypothetical backend contracts.
  - Fixture controls (e.g., "Simulate Stop Arrival", "Trigger Weather Alert") must be segregated from production widgets and visually tagged as debug tools.

---

### 16. Accessibility

- **Semantics & Screen Readers**:
  - Turn-by-turn instruction updates must be wrapped in `Semantics(liveRegion: true)`.
  - All icons must have meaningful semantic labels or be marked decorative where redundant with text.
- **Non-Color Severity Signals**:
  - Alert severities and route statuses must always combine an explicit icon and text label with color (e.g., Warning Icon + "Delay: +25 min", Error Icon + "Severe Weather Alert").
- **Touch Targets & Sizing**:
  - All interactive touch targets will measure $\ge 48\times 48$ logical pixels.
  - Layouts must support large system text scaling (up to 200%) without vertical clipping or horizontal overflow.
- **One-Handed Navigation Ergonomics**:
  - Key interactive controls (Recenter, Dismiss, Review Reroute, Stop Navigation) must be positioned in the bottom 40% of the screen.

---

### 17. SRS Message Conflict Register

> **[SRS_MESSAGE_ID_CONFLICT]**  
> Conflicting numeric message IDs across Report 3 SRS sections are formally cataloged below. **Implementation rule**: Use semantic UI states; defer hard-coded numeric message IDs until the specification is authoritatively harmonized.

| Conflicted ID | Use Case & Detailed Flow Context | Global Message Catalog Context | Conflict Description | Implementation Decision |
| :--- | :--- | :--- | :--- | :--- |
| **MSG35** | **UC-13 Flow Step 6**: Navigation session starts successfully. | **Catalog**: "CSP execution exceeded 2,500ms SLA, fallback heuristic applied." | Step 6 expects a navigation start confirmation, but catalog defines CSP algorithm fallback. | **Semantic UI state only** (`navigationActive`). Numeric ID deferred. |
| **MSG36** | **UC-13 Validation / Flow**: Current GPS position cannot be acquired / GPS lost. | **Catalog**: "Itinerary saved to user account ('Itinerary saved to My Trips')." | Flow uses MSG36 as GPS error; catalog uses MSG36 as successful itinerary save toast. | **Semantic UI state only** (`navigationPositionUnavailable`). Numeric ID deferred. |
| **MSG37** | **UC-13 Flow Step 7.b1**: Off-route deviation detected beyond threshold. | **Catalog**: "User confirms deletion of an itinerary ('Are you sure you want to delete...?')." | Flow uses MSG37 for off-route deviation; catalog uses MSG37 for itinerary deletion modal. | **Semantic UI state only** (`navigationOffRouteDeviation`). Numeric ID deferred. |
| **MSG41** | **UC-13 Step 8 / UC-14 Step 7**: System offers re-routing suggestion or announces POI arrival. | **Catalog**: "Push notification: Traveler arrived at scheduled POI location." | Catalog aligns with POI arrival, but UC-14 Step 7 references MSG41 as raising a re-routing suggestion. | **Semantic UI state only** (`reroutePendingReview` / `waypointReached`). Numeric ID deferred. |
| **MSG42** | **UC-15 Flow Step 8**: Navigation session updated with new route. | **Catalog**: "Toast message: Automatic check-in recorded at POI." | Flow treats MSG42 as route update success; catalog treats MSG42 as POI check-in confirmation. | **Semantic UI state only** (`rerouteAccepted`). Numeric ID deferred. |
| **MSG43** | **UC-15 Flow Step 9**: Proposal declined; continuing on current route. | **Catalog**: "Alert pop-up: Schedule delay detected (>30 mins behind timeline)." | Flow treats MSG43 as reroute decline notice; catalog treats MSG43 as timeline delay warning. | **Semantic UI state only** (`rerouteDeclined`). Numeric ID deferred. |
| **MSG44** | **UC-15 Abnormal Cases**: Suggestion expired or alternative route unavailable. | **Catalog**: "Confirmation pop-up: User attempts to end or complete the trip." | Flow uses MSG44 for expired proposal; catalog uses MSG44 for trip completion confirmation modal. | **Semantic UI state only** (`rerouteExpired`). Numeric ID deferred. |
| **MSG47** | **UC-13 Validation**: Map data of active segment unavailable. | **Catalog**: "Alert pop-up: Severe weather threshold exceeded along active itinerary." | Flow uses MSG47 for map tile failure; catalog uses MSG47 for severe weather warning. | **Semantic UI state only** (`mapDataUnavailable` / `severeWeatherAlert`). Numeric ID deferred. |
| **MSG48** | **UC-13 Step 10**: Navigation session ends. | **Catalog**: "Modal dialog: System proposes emergency indoor shelter rerouting." | Flow uses MSG48 for trip end; catalog uses MSG48 for emergency shelter rerouting dialog. | **Semantic UI state only** (`navigationTripCompleted`). Numeric ID deferred. |
| **MSG49 / MSG50** | **UC-15 Normal / Alternative Flow**: Implicitly mapped to Accept / Decline in Catalog. | **Catalog**: MSG49 = "Traveler accepted dynamic reroute", MSG50 = "Traveler rejected dynamic reroute". | Flow text omits explicit references to MSG49/MSG50 while catalog explicitly assigns them. | **Semantic UI state only** (`rerouteAccepted`, `rerouteDeclined`). Numeric ID deferred. |

---

### 18. SRS Alert Taxonomy Conflict

> **[SRS_ALERT_TAXONOMY_CONFLICT]**

The SRS contains two overlapping but distinct disruption categorizations:
1. **UC-14 BR-29 (Formal Alert Types)**:
   - Weather
   - Traffic
   - Point-of-Interest Closure
   - Safety Notice
2. **Real-Time Navigation / Incident Trigger Rules**:
   - Severe Weather (triggers indoor shelter proposal)
   - Schedule Delay (>30 minutes behind timeline)
   - Route Deviation (>500 meters off planned polyline)
   - Unavailable / Closed POI (catalog status change)

**Architectural Decision**:
- The UI layer will conceptually distinguish between **Advisory Alerts** (general environmental notices) and **Operational Navigation Incidents** (events impacting route execution).
- Production enum values will **not be frozen** in this mobile delivery batch.
- Presentation widgets will render data polymorphically via a flexible `TripAlert` presentation model capable of displaying both advisory notices and operational incidents without cementing an unapproved backend schema.

---

### 19. Explicit Non-Goals

The following items are explicitly excluded from this mobile delivery batch:
1. **Voice / Turn-by-Turn Spoken Audio**: No audio engine, speech synthesis, or background voice guidance.
2. **Proprietary Advanced Map Features**: No 3D buildings, live traffic heatmaps, lane guidance, or speed camera warnings.
3. **Silent / Automatic Rerouting**: No automatic path changes without explicit user interaction.
4. **Native Map SDK Integration**: No installation or configuration of Google Maps, Mapbox, or MapLibre.
5. **Broad UC-11 Redesign**: `ItineraryResultPage` will be updated only as needed to expose entry points to UC-13 and UC-16.
6. **UC-72 Standalone Implementation**: Background offline check-in upload synchronization is not part of this task.

---

### 20. Acceptance Criteria

- [ ] **Unified Journey**: Traveler can seamlessly navigate from `ItineraryResultPage` (UC-11) into `OfflineTripPackagePage` (UC-16) and `ActiveTripPage` (UC-13).
- [ ] **Arrival Automation (UC-13)**: Stop arrival in production logic is triggered exclusively by position detection. Manual arrival is restricted to `DEMO_ONLY` test fixtures.
- [ ] **Stop Navigation Confirmation (UC-13)**: Exiting navigation requires explicit confirmation via modal dialog before closing the session.
- [ ] **Alert Persistence (UC-14)**: Dismissing a top alert banner removes it from the navigation canvas but retains it in `TripAlertsSheet` for the trip's duration.
- [ ] **Explicit Consent Gate (UC-15)**: Re-routing proposals are presented via `RerouteProposalSheet`. Accepting creates version $V+1$; keeping current route dismisses without modification. Automatic rerouting is strictly prevented.
- [ ] **Authoritative Reroute Diffing (UC-15)**: Proposal sheet displays disruption reason, current vs. proposed stop sequence, travel-time delta, arrival-time delta, and affected items.
- [ ] **Offline Storage Ceiling (UC-16)**: Offline package estimator strictly verifies package size $\le 150\text{ MB}$. Incomplete downloads are purged and never marked available.
- [ ] **Superseded Offline Refresh (UC-16)**: Refreshing an outdated offline package retains the existing local copy until the new download succeeds.
- [ ] **Decoupled Map Canvas**: Map displays the `MAP_INTEGRATION_PENDING` indicator with vector mock projection; zero map SDK dependencies in `pubspec.yaml`.
- [ ] **Semantic Code Contracts**: Domain and presentation logic use semantic state identifiers without referencing conflicting numeric MSG codes.
- [ ] **Accessibility & Design Tokens**: 100% adherence to Material 3 tokens, non-color severity cues, semantics labels, and $\ge 48\text{px}$ touch targets.

---

### 21. Open Dependencies

The following external dependencies remain open for resolution by the broader engineering team:
1. **Map Engine Selection**: Final architecture sign-off on the production mapping provider (Google Maps vs. Mapbox vs. MapLibre/vector tiles).
2. **Backend API Contracts**: Formalization of endpoints and DTO schemas for `ACTIVE_TRIP_SESSION`, `REAL_TIME_ALERTS`, `REROUTING`, and `OFFLINE_PACKAGE`.
3. **Push Notification Infrastructure**: Provisioning of Firebase Cloud Messaging for out-of-app alert delivery.
4. **Authoritative Message Catalog Harmonization**: Alignment of SRS detailed-flow references with the global Message Catalog by the requirements team.
