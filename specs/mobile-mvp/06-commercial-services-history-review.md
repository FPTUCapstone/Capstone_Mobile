# 06 — Commercial Services, Trip History, Review, and System Outcomes (Screens #71–#74, UC-30…UC-33, UC-70/71)

> **Revision 2026-10-08 (QA) — scope note and stale statements.** Only UC-30 (View Commercial Service) is in the 25-UC MVP. UC-31 (booking, PR #32), UC-32/UC-33 (PR #33) and the system UCs are preserved as out-of-scope dependencies. S-71/S-72 remain the structural design for #71/#72; `13-v2-completion-specs.md` Part 4 adds the V2 layer (BR-87/BR-34/BR-88/BR-55) and replaces the status lines. **Stale statements below:** the "Backend reality" line says no commercial-service endpoint exists — BE develop `0075fcb` serves `GET /api/v1/commercial-services` and `/{id}` (anonymous). The categories are confirmed by V2 BR-87 (Hotel, Vehicle Rental, Restaurant). #71/#72 exist in PR #32 (conflicting) using a demo store. The "SRS blocking note"/C-3 below was re-checked in V2: §1 and Table 1 say commercial service booking is mobile-only while §3.6.1/§3.6.2 Interface name both platforms (`00` C-12). Mobile is in scope under either reading, so UC-30 on Mobile is **not** blocked by it; S-71/S-72 acceptance criterion "blocked until C-3 closed" no longer applies to the Mobile UC-30 detail.

Standards: `C-*` in `01-mobile-shells-and-navigation.md` §1. Funnel rules for payments/tickets: `05-…` "Funnel integrity rules".
**Backend reality (BE develop `d198107`):** no commercial-service, trip-history or review endpoint exists. All screens here are `NOT_STARTED` and `BACKEND CAPABILITY REQUIRED`.
**SRS blocking note:** UC-30 and UC-31 are `SRS_CONFLICT` / `BLOCKED_BY_SRS_CONFLICT` in `WEB_SCOPE_MATRIX` (R3 catalogue says Mobile-only, detailed sections mention Next.js). Design below follows the Mobile-only catalogue statement; **implementation needs the conflict closed first** (conflict C-3).

---

## Journey G — Commercial services

Itinerary / POI → Commercial service discovery (#71) → Service detail (#72) → choose bookable option → Service booking → resulting **Backend** booking state.
Categories per requirements: **Hotel, Vehicle Rental, Restaurant** (exact SRS text `SRS_TEXT_REQUIRED`; Stitch only shows vehicle rental). TripMate models these internally; **no external provider integration is invented**.

### S-71 Commercial Services Search & List

- **Screen Index:** 71 · **UC:** UC-30 · **Name:** Commercial Services Search & List · **Domain:** Commerce · **Role:** Traveler · **Platform:** MOBILE_ONLY (`SRS_CONFLICT`)
- **Presentation Type:** FULL_PAGE · **Route:** `/traveler/services` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Nature:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `COMMERCIAL_SERVICE_LIST_CONTRACT_MISSING`
- **Previous:** #48 / #51 / tab · **Next:** #72 · **Alternatives:** change category, change location
- **Entry Points:** from an itinerary stop or POI ("services near here"), Khám phá · **Entry Conditions:** Traveler · **Exit:** open a service
- **User Goal:** find a hotel, vehicle or restaurant near my trip
- **Page Header:** "Services" + category tabs · **Layout:** category tabs, search + filter, result list. Visual reference: `d_ch_v_du_l_ch_tripmate_mobile`
- **Sections:** category tabs (Hotel / Vehicle / Restaurant) · location context chip (from POI/itinerary) · filter sheet · results
- **Components:** search field (EXISTING_EXTEND), NEW_SHARED `FilterSheet` base (the tour/poi sheets exist but are feature-local), `ServiceCard` (feature-local), `StatusBadge`, `PriceText`
- **Primary Action:** open service · **Secondary:** filter, change location
- **Displayed Data (semantic):** service identity, category, name, location/distance, price indicator, availability, rating. `BACKEND_SUPPORT_REQUIRED`
- **Form Inputs / Validation:** search text, filters (set `SRS_TEXT_REQUIRED`) · limits like tour search (bounds enforced client-side to match BE once defined)
- **Loading:** skeleton · **Empty:** "No services found near this place" · **Error:** retry reads · **Success:** list
- **Dialogs / Sheets:** filter bottom sheet · **Offline:** error state · **Permission:** location permission only if "near me" is offered
- **Responsive / Accessibility:** C-RESP, C-A11Y
- **Reusable / Unique:** reuse search/filter patterns; unique `ServiceCard`
- **Visual Tokens:** C-TOKENS
- **Context In:** POI id / itinerary id / coordinates (as the contract allows) · **Context Out:** `serviceId`, category
- **Backend Readiness (C-BE):** A service ids · B services by category/location · C none · D Backend · E page/limit · F text · G category, price, availability · H distance/price/rating (BE) · I 5xx/validation · J JWT (SRS: Traveler) · K none · L GPS (optional) · M none · N none · O NO · P **list capability + category catalogue** · Q all · R retry reads · S refresh · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `COMMERCIAL_SERVICE_LIST_CONTRACT_MISSING`
- **Device Dependencies:** GPS (optional) · **Deep Link:** none
- **Demo / Production Boundary:** no fixture services in production; category IDs must not be hard-coded per client (rules §34 / L20)
- **Design-only Assumptions:** category tab set · **Implementation Notes:** blocked by SRS conflict C-3
- **Non-goals:** external provider aggregation
- **Acceptance Criteria:** AC1 only Backend data; AC2 categories from an authoritative source; AC3 empty ≠ error; AC4 blocked until C-3 closed.

### S-72 Commercial Service Details & Booking

- **Screen Index:** 72 · **UC:** UC-30 (detail), UC-31 (booking) · **Name:** Commercial Service Details & Booking · **Role:** Traveler · **Platform:** MOBILE_ONLY (`SRS_CONFLICT`)
- **Presentation Type:** FULL_PAGE + BOTTOM_SHEET (booking options) · **Route:** `/traveler/services/:serviceId` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `COMMERCIAL_SERVICE_DETAIL_AND_BOOKING_CONTRACT_MISSING`
- **Previous:** #71 · **Next:** resulting booking state · **Alternatives:** back, other options
- **Entry Points:** #71, deep link · **Entry Conditions:** Traveler · **Exit:** booking created / back
- **User Goal:** understand a service and book a bookable option
- **Page Header:** service name + category · **Layout:** gallery, key facts, options list, sticky "Book" bar. Visual reference: `t_d_ch_v_xe_t_l_i_tripmate_modal` (vehicle rental modal)
- **Sections:** overview · options (room/vehicle/table; fields differ per category `SRS_TEXT_REQUIRED`) · availability for chosen dates · price · policies · booking sheet (dates/time, quantity, contact)
- **Components:** `PriceText`, `SchedulePicker` (EXISTING after #65), `AppTextField`, `ConfirmationDialog`
- **Primary Action:** Book selected option · **Secondary:** change option/dates
- **Displayed Data:** all `BACKEND_SUPPORT_REQUIRED`; price shown **Estimated** until Backend confirms
- **Validation:** dates/quantity within availability from Backend; required contact fields per SRS
- **Loading/Empty/Error:** C-STATE; 409 availability changed → refreshed options, re-confirm; timeout → *unknown outcome*, check booking state before re-submitting
- **Success State:** only once Backend returns the booking identity/status; no local confirmation
- **Dialogs / Sheets:** booking bottom sheet, discard confirm · **Offline:** disabled
- **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y; bottom sheet reachable at 200 % text
- **Reusable / Unique:** reuse `PriceText`, `SchedulePicker`; unique option cards
- **Visual Tokens:** C-TOKENS
- **Context In:** `serviceId` (+ POI/itinerary context) · **Context Out:** resulting booking id/status
- **Backend Readiness (C-BE):** A `serviceId`, option id · B detail/availability · C create service booking (idempotent) · D Backend · E–H none · I 400/401/403/404/409/5xx · J JWT · K owner · L none · M `/traveler/services/:id` · N none · O **NO** · P **detail + availability + booking** · Q per-category fields · R same key for same intent · S refresh availability · T contact PII · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `COMMERCIAL_SERVICE_DETAIL_AND_BOOKING_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep Link:** none
- **Demo / Production Boundary:** no local booking; `PENDING_INTEGRATION_STATE`
- **Design-only Assumptions:** option card fields · **Implementation Notes:** how a service booking appears in #68 vs a separate list is `SRS_TEXT_REQUIRED`
- **Non-goals:** external supplier checkout
- **Acceptance Criteria:** AC1 no success without Backend identity; AC2 availability from Backend; AC3 single operation per intent; AC4 blocked until C-3 closed.

---

## Post-trip

### S-73 Trip History

- **Screen Index:** 73 · **UC:** UC-32 · **Name:** Trip History · **Role:** Traveler · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (+ detail) · **Route:** `/traveler/history` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `TRIP_HISTORY_CONTRACT_MISSING` (what counts as a "trip": completed itinerary and/or completed tour booking is `SRS_TEXT_REQUIRED`)
- **Previous:** Chuyến đi / Hồ sơ · **Next:** #74 · **Alternatives:** open itinerary (#48), open booking (#69)
- **Entry Points:** Chuyến đi tab, Hồ sơ · **Entry Conditions:** Traveler · **Exit:** open trip / review
- **User Goal:** look back at completed trips and review them
- **Page Header:** "Trip history" · **Layout:** chronological list (grouped by month), detail page. Visual reference: `l_ch_s_chuy_n_i_tripmate_mobile_uc_32`
- **Sections:** list cards (title, dates, destinations, reviewed state) · detail (itinerary summary, tour info)
- **Components:** FEATURE_LOCAL `TripHistoryCard`, `StatusBadge`, `ErrorView`
- **Primary Action:** open trip · **Secondary:** Write/Edit review (#74)
- **Displayed Data:** `BACKEND_SUPPORT_REQUIRED` (all); the planner's own itineraries are not listed anywhere today (no list endpoint)
- **Loading:** skeleton · **Empty:** "No completed trips yet" · **Error:** retry · **Success:** list
- **Pagination:** page/limit (BE) · **Filter/Sort:** by date (BE-defined)
- **Dialogs / Sheets:** none · **Offline:** error · **Permission:** none
- **Responsive / Accessibility:** C-RESP, C-A11Y
- **Reusable / Unique:** reuse list/empty/error
- **Visual Tokens:** C-TOKENS
- **Context In:** none · **Context Out:** `tripId` / `bookingId` as defined by Backend
- **Backend Readiness (C-BE):** A user from token · B completed trips · C none · D Backend · E yes · F none · G date range (`SRS_TEXT_REQUIRED`) · H newest first · I 401/5xx · J JWT · K own · L none · M none · N none · O NO · P **history read** · Q all · R retry reads · S refresh · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRIP_HISTORY_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep Link:** none
- **Demo / Production Boundary:** no fabricated trips
- **Design-only Assumptions:** grouping
- **Non-goals:** exports, sharing
- **Acceptance Criteria:** AC1 only Backend trips; AC2 empty ≠ error; AC3 "reviewed" flag from Backend; AC4 navigation to #48/#69 uses real ids.

### S-74 Trip Review & Rating

- **Screen Index:** 74 · **UC:** UC-33 · **Name:** Trip Review & Rating · **Role:** Traveler · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (form) or BOTTOM_SHEET · **Route:** `/traveler/history/:tripId/review` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `TRIP_REVIEW_CONTRACT_MISSING`. (Only a recommendation-feedback endpoint exists; it is **not** a trip review.)
- **Previous:** #73 / #69 · **Next:** #73 · **Alternatives:** cancel
- **Entry Points:** history item, booking detail after the trip · **Entry Conditions:** Backend marks the trip reviewable (eligibility is server-owned) · **Exit:** submitted/cancelled
- **User Goal:** rate and comment on a completed trip
- **Page Header:** "Rate your trip" · **Layout:** star rating, optional comment, submit. Visual reference: `g_i_nh_gi_ph_n_h_i_tripmate_mobile_uc_33`
- **Sections:** rating (1–5; scale `SRS_TEXT_REQUIRED`) · comment (length `SRS_TEXT_REQUIRED`) · optional photos (`SRS_TEXT_REQUIRED`, `DEVICE_INTEGRATION_MISSING`)
- **Components:** NEW_SHARED `RatingInput`, `AppTextField`, `AppButton`, `AppAlert`
- **Primary Action:** Submit review · **Secondary:** Cancel
- **Validation:** rating required; comment bounds per SRS; keep input on failure
- **Loading:** submit progress, no double submit · **Empty:** n/a
- **Error:** 403 not eligible, 409 already reviewed (show existing review per SRS), validation on fields, timeout → *unknown outcome* (re-read before retry)
- **Success State:** only after Backend accepts; review then shown from Backend
- **Dialogs / Sheets:** discard confirm · **Offline:** submit disabled; draft held in memory only
- **Permission:** photo access if photos exist · **Responsive / Accessibility:** C-RESP, C-A11Y; stars are a labelled slider/radio group ("4 of 5 stars")
- **Reusable / Unique:** NEW_SHARED `RatingInput` (also reused by display-only rating rows)
- **Visual Tokens:** C-TOKENS
- **Context In:** `tripId`/`bookingId`, tour/trip title · **Context Out:** none
- **Backend Readiness (C-BE):** A trip id · B existing review (if any) · C submit review (idempotent) · D Backend · E–H none · I 400/401/403/404/409/5xx · J JWT · K owner, eligible only · L photo picker (optional) · M none · N none · O **NO** · P **review endpoint** · Q photos, moderation state · R same key for same intent · S none · T free text PII · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRIP_REVIEW_CONTRACT_MISSING`
- **Device Dependencies:** photo picker (none present) · **Deep Link:** none
- **Demo / Production Boundary:** no fake submitted review
- **Design-only Assumptions:** star scale
- **Non-goals:** review moderation (Admin), replies by operator
- **Acceptance Criteria:** AC1 server decides eligibility; AC2 success only after Backend; AC3 input retained on error; AC4 rating control accessible.

---

## System / background outcomes (no standalone pages)

Per `WEB_SCOPE_MATRIX`: UC-70 and UC-71 are `NON_SCREEN`; UC-72 is Mobile `NON_SCREEN / background` (see `03` Part 3). **No full page is created.**

| UC | Trigger | Where the Traveler sees the result | Error result | Retry | Authoritative owner |
|---|---|---|---|---|---|
| UC-70 Handle Emergency Tour Cancellation | automatic (e.g. weather; `SRS_CONFLICT` whether an operator can also trigger it) | (1) status + message on **Booking Details #69** and the card in **#68** ("Cancelled by TripMate/operator – reason"); (2) a notification — the notification channel **does not exist** (`DEVICE_INTEGRATION_MISSING`, no push package, no BE source), so #69/#68 are the only reliable surface; (3) if the tour is linked to an itinerary, an alert in #53 only when a real alert source exists | status unknown → "We could not load the latest booking status" with refresh | pull-to-refresh / re-open | Backend |
| UC-71 Process Automatic Refund | follows cancellation/failed fulfilment (actor ownership `SRS_CONFLICT`) | refund **progress as booking/payment state** inside #69 ("Refund pending", "Refunded"); amount from Backend | stuck/failed refund → state text + support route (SRS) | none by user (no client-initiated refund for travellers) | Backend |
| UC-72 Synchronize Offline Trip Data | connectivity restored with buffered offline actions | non-blocking sync indicator (see `03` Part 3) | per-item failure shown as pending | automatic bounded + manual | Backend |

Stitch's full-screen "emergency cancellation & refund notice" (`th_ng_b_o_h_y_tour_ho_n_ti_n_kh_n_c_p_…_mobile`) and "emergency confirm dialog" are **not adopted as pages/dialogs** (see `00` §O).
