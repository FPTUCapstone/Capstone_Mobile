# UC-32 & UC-33 Mobile Screen Specification: Trip History and Trip Review

## 1. Context and Authority Disclaimer

This specification defines the mobile application screens, navigation flows, state handling, ownership boundaries, and review submission contracts for:
- **UC-32 — View Trip History** (Screen #73: Trip History)
- **UC-33 — Submit Trip Review** (Screen #74: Trip Review & Rating)

**Authority Source:** Derived from `Report3_Software-Requirement-Specification-V2.docx` (Screens #73 and #74, Sections 3.6.3 and 3.6.4).
> [!NOTE]
> **Status Disclaimer:** This is the authoritative engineering specification and contract reference for Mobile PR #33. Formal stakeholder sign-off is pending live backend integration. Approval is not claimed where contracts remain pending.

---

## 2. Route and Authorization Boundary

### Routes
- **Trip History Screen #73:** `/traveler/trips` (`AppRoutes.tripHistory`)
- **Trip Review Screen #74:** `/traveler/trips/:tripId/review` (`AppRoutes.tripReviewPattern`)
- **Trip Detail Direct Link:** `/traveler/trips/:tripId` (redirects to `/traveler/trips/:tripId/review`)

### Role Guards & Multi-Tenancy
- Both routes are strictly **Traveler-only**.
- Unauthenticated Guests are intercepted by `createAppRouter` and redirected to `/auth/login`.
- Tour Operators attempting access are redirected to `/operator` shell with denied access.
- In Demo mode (`kDebugMode && ?demo=true`), demo tenant data is scoped to `demoTravelerId = 1`. Access to foreign records (`travelerId != 1`, e.g. `trip-tour-999`) is strictly blocked with `permissionDenied` (BR-90).

---

## 3. Screen #73: Trip History Specification (UC-32)

### Functional Requirements
1. **Tabs & Grouping (BR-52):**
   - Three tabs: **Upcoming**, **Completed**, and **Cancelled**.
   - Default active tab: Upcoming.
   - Default sorting: Departure date in descending order.
2. **Filters (CR-01):**
   - Filter by Type: All, Tour, Commercial Service, Self-planned Itinerary.
   - Filter by Date Range: Start Date and End Date.
   - Filter by Status within tabs.
3. **Pagination (CR-01):**
   - Default page size: 20 records per page.
   - Infinite scroll / pagination controls supporting page increments.
4. **Card Information & Actions:**
   - Title, Booking Code, Departure Date, Total Amount, Participant Count, Provider/Location.
   - **View Details Dialog:** displays complete booking metadata.
   - **Refund Info Dialog:** for Cancelled trips, displays refund status, refunded amount, payment channel, and notes.
   - **E-ticket Notice:** displays e-ticket status or information notice.
   - **Review CTA:** displayed exclusively on **Completed** trips (BR-91). Navigates to Screen #74.

### UI States
- **Loading:** skeleton or centered indicator during initial load and tab transitions.
- **Empty:** tab-specific empty messages:
  - Upcoming: *"No upcoming trips found. Explore tours or plan a new itinerary!"*
  - Completed: *"No completed trips yet."*
  - Cancelled: *"No cancelled trips."*
- **Error:** localized error banner with Retry action.

---

## 4. Screen #74: Trip Review & Rating Specification (UC-33)

### Route ID as Source of Truth (P1 Remediation)
- **Primary Source:** Route path parameter `:tripId` is the single source of truth.
- **Cache Optimization:** `state.extra` (passing `TripHistoryItem`) is optional and acts strictly as an in-memory cache/seed.
- **Deep Linking / Restore:** If `state.extra` is missing (direct URL, push notification, deep link, or process restoration), `TripReviewCubit` fetches the trip record by `tripId` via `TripHistoryRepository.getTripById()`.

### Ownership & Authorization Validation (BR-90)
1. Route receives `tripId`.
2. Cubit queries repository `getTripById(tripId: tripId, travelerId: currentTravelerId)`.
3. If trip does not exist: fails closed with `tripInformationUnavailable`.
4. If trip belongs to a different traveler: fails closed with `permissionDenied` without rendering private trip details.
5. If trip status is not `completed` (BR-91): fails closed with `noticeReviewNotCompleted`.

### Review Submission Contract
- **Rating:** Mandatory 1 to 5 integer stars (MSG66 / `validationRatingRequired`).
- **Title:** Mandatory non-empty string (MSG01 / `validationFieldRequired`).
- **Content:** Mandatory non-empty string (MSG01 / `validationFieldRequired`).
- **Attachments:**
  - Maximum 5 photo attachments.
  - Allowed types: JPEG, PNG, WebP.
  - Byte limit boundary: strictly $\le 5,000,000$ bytes per attachment (BR-16).
- **Edit Window (BR-95):**
  - Within 48 hours / 7 days of review creation: editable mode (`reviewEditWindowActive`).
  - Beyond the window: read-only mode (`reviewReadOnlyNotice`) with inputs disabled.
- **Duplicate Prevention (BR-92):** Maximum one review per booking; initial submit rejected if review already exists.

### Production Boundary
- Current merged backend contracts provide review submission endpoints for authoritative commerce bookings, but the aggregate UC-32 mobile contract is pending server integration.
- Production mobile truthfully disables review mutations (`productionReviewMutationDisabled`) to prevent fabricating invalid booking references.

---

## 5. Navigation & State Flow

```
[Deep Link / Router: /traveler/trips/:tripId/review]
                      │
                      ▼
         Does route have tripId?
         ├── No ──► Render ErrorView (tripInformationUnavailable)
         └── Yes ──► Check state.extra
                      ├── Valid & matching ──► Seed cache & validate ownership
                      └── Missing / mismatch ─► Cubit calls getTripById(tripId)
                                                 │
                        ┌────────────────────────┴────────────────────────┐
                        ▼                                                 ▼
               Trip Found & Authorized                           Not Found / Unauthorized
                        │                                                 │
                        ▼                                                 ▼
             Validate status == completed                      Emit Failure (tripInformationUnavailable
             ├── No  ──► Render noticeReviewNotCompleted                      or permissionDenied)
             └── Yes ──► Render TripReviewPage Form
```
