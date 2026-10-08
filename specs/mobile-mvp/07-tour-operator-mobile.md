# 07 — Tour Operator Mobile (Screens #75–#92, UC-34…UC-46)

> **Revision 2026-10-08 — outside the 25-UC MVP.** No screen in this file belongs to the current Mobile MVP (UC-01…UC-10, UC-16…UC-30). The only Tour Operator MVP items are UC-02 (#40) and UC-03 (#41), specified in `13` Part 1. Since this file was written, #82 Create Coupon (UC-38) was merged in PR #29 (BE PR #44 still open). Keep this file as future design input; do not schedule it without explicit scope approval.

Standards: `C-*` in `01-mobile-shells-and-navigation.md` §1.
Platform: UC-34…UC-42 and UC-44…UC-46 are `SHARED_WEB_MOBILE`; **UC-43 is `MOBILE_ONLY` with `SRS_CONFLICT`** (conflict C-3). R3 §§3.8.x document the Next.js management screens; the Mobile layouts below follow the Screen Index and the catalogue.

## Backend reality (BE develop `d198107`, TourOperator role)
The **only** Operator capability that exists is tour media management on an **already existing** `tourId`:

| Capability | Verified contract (read-only) |
|---|---|
| List media | `GET /api/v1/operator/tours/{tourId}/media` → list of media DTOs |
| Upload | `POST /api/v1/operator/tours/{tourId}/media` · `multipart/form-data` (file + caption + alt text + primary flag) · **required header `Idempotency-Key` = GUID** · request limit ≈ 11 MB · 201 on success; 400/401/403/404/409/413/503 ProblemDetails |
| Update metadata | `PATCH …/media/{mediaId}` body caption/alt text |
| Reorder | `PUT …/media/order` body ordered media ids + primary media id |
| Delete | `DELETE …/media/{mediaId}` → 204 |

There is **no** endpoint to create/update/submit tour packages, coupons, bookings, refunds, QR check-in, revenue or payouts, and no operator profile endpoint. Operator application status is read through the login/session response (see #41). All screens below are `NOT_STARTED` unless noted and carry `BACKEND CAPABILITY REQUIRED`.

## C-OP — Operator common standards (referenced as `C-OP`)
- **Shell:** `OperatorShellPage` (`/operator`, approved operators only). One app bar `Operator · <tab>`; bottom navigation Dashboard · Tours · Bookings · Revenue · Profile; coupons reachable from Dashboard/Profile; **Scan QR** primary action on Bookings and Dashboard.
- **Auth/role:** TourOperator JWT; server enforces ownership of every resource; a non-approved operator never reaches these screens (guard). Never an Administrator feature.
- **Money:** every amount, fee, balance, commission and refund comes from the Backend. The client formats (`PriceText`) but does not compute authoritative totals.
- **Mutations:** `Optimistic update: NO`. Lists re-read after any mutation. Writes that create a resource use a client operation key (rules §14–§15). Destructive/approval actions use the shared `ConfirmationDialog`.
- **Offline:** read-only labelled "offline" only if caching is approved (none invented); mutations disabled; unknown outcome after a timeout never reports success.
- **Demo/production:** `C-DEMO`. Until a capability exists the screen shows `PENDING_INTEGRATION_STATE` or the entry is hidden; no fake bookings, revenue, coupons or QR results.
- **PII:** passenger names/contacts and revenue data are sensitive: never logged, not placed in route paths beyond ids.
- **Stitch references:** operator mobile visuals `t_o_g_i_tour_m_i_tripmate_operator`, `qu_n_l_khuy_n_m_i_coupon_tripmate_partner`, `qu_n_l_t_tour_ho_n_ti_n_tripmate_operator`, `qr_scanner_check_in_tour_tripmate_operator`; the "partner desktop 1440px finance dashboard" is desktop-only and is a hint, not a Mobile layout.

Each screen below uses the exact template (§23 of the task brief). Fields that are identical for all operator screens are given by `C-OP` and not repeated.

---

### S-75 Tour Operator Dashboard
- **Screen Index:** 75 · **UC:** none owns it (entry to UC-34…46) · **Domain:** Operator · **Role:** Tour Operator · **Platform:** Mobile
- **Presentation Type:** FULL_PAGE (tab root) · **Route:** `/operator` · **Parent Shell:** Operator
- **Implementation Status:** PLACEHOLDER (`_OperatorSection`) · **Nature:** IMPLEMENTED_UI_ONLY · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** summary read `OPERATOR_DASHBOARD_SUMMARY_CONTRACT_MISSING`
- **Previous:** login/guard · **Next:** any tab/action · **Alternatives:** #88 scan
- **Entry Points:** approved operator login · **Entry Conditions:** approved · **Exit:** navigation
- **User Goal:** see what needs attention today
- **Page Header:** business name (profile source missing → session `fullName` until then) · **Layout:** summary cards + quick actions
- **Sections:** today's departures, pending bookings, revenue snapshot (all `DESIGN_ONLY_FIELD` + `BACKEND_SUPPORT_REQUIRED`) · quick actions: Scan QR, Create tour, Bookings
- **Components:** NEW_SHARED `RevenueCard`/`StatCard`, `QuickActionTile`, `StatusBadge`
- **Primary Action:** Scan QR · **Secondary:** Create tour, view bookings
- **Displayed Data:** nothing fabricated; cards show "Not available yet" until the contract exists
- **Loading/Empty/Error/Success:** C-STATE; empty = zero from Backend, distinct from unavailable
- **Dialogs:** none · **Offline:** unavailable text · **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y
- **Reusable / Unique:** `StatCard` NEW_SHARED (also #89)
- **Visual Tokens:** C-TOKENS · **Context In:** session · **Context Out:** none
- **Backend Readiness (C-BE):** A operator from token · B summary figures · C none · D Backend · E–H none · I 401/403/5xx · J JWT TourOperator · K own · L none · M none · N none · O NO · P **summary capability** · Q all cards · R retry reads · S pull-to-refresh · T revenue · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_DASHBOARD_SUMMARY_CONTRACT_MISSING` · **Device:** none · **Deep Link:** `/operator`
- **Demo / Production Boundary:** no sample numbers · **Design-only Assumptions:** card set · **Implementation Notes:** keep tabs/IndexedStack
- **Non-goals:** charts here (see #89) · **Acceptance Criteria:** AC1 no fabricated figures; AC2 Scan QR reachable in one tap; AC3 only approved operators reach it.

### S-76 Tour Operator Profile
- **Screen Index:** 76 · **UC:** UC-34 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (+ edit) · **Route:** `/operator/profile` PROPOSED · **Parent Shell:** Operator (Profile tab)
- **Implementation Status:** PLACEHOLDER · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_PROFILE_CONTRACT_MISSING`
- **Previous:** tab · **Next:** edit · **Alternatives:** coupons entry, security (#43), sign out
- **Entry Points:** Profile tab · **Entry Conditions:** approved · **Exit:** pop
- **User Goal:** keep business information accurate
- **Page Header:** business name · **Layout:** profile card + sections
- **Sections:** business identity, contact, description, logo (`SRS_TEXT_REQUIRED`), account actions
- **Components:** `AppTextField`, `Avatar`, `AppButton`
- **Primary Action:** Save (disabled until BE) · **Secondary:** Cancel, Sign out
- **Displayed Data/Form Inputs:** all `BACKEND_SUPPORT_REQUIRED`; validation per SRS (`SRS_TEXT_REQUIRED`)
- **Loading/Empty/Error/Success:** C-STATE; success only after Backend confirms
- **Dialogs:** discard confirm · **Offline:** read-only · **Permission:** photo access if logo upload exists
- **Responsive / Accessibility:** C-RESP, C-A11Y
- **Reusable / Unique:** `Avatar`; none
- **Visual Tokens:** C-TOKENS · **Context In/Out:** session / none
- **Backend Readiness (C-BE):** A operator from token · B profile · C update profile · D Backend · I 400/401/403/409 · J JWT TourOperator · K own · L image picker (optional) · O NO · P **read/update** · Q all · R network retry · S refresh · T business PII · U Backend; E–H, M, N: none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_PROFILE_CONTRACT_MISSING` · **Device:** image picker (optional, missing) · **Deep Link:** none
- **Demo / Production Boundary:** no hard-coded business data (see the Traveler profile leak, `02` S-45) · **Non-goals:** KYC re-verification
- **Acceptance Criteria:** AC1 no success without Backend; AC2 no constants shown as real data; AC3 field errors preserved.

### S-77 Tour Packages List
- **Screen Index:** 77 · **UC:** UC-35/UC-36 (entry) · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (tab root "Tours") · **Route:** `/operator/tours` PROPOSED · **Parent Shell:** Operator
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE (media only, no listing) · **Permission:** FULL · **Contract:** `OPERATOR_TOUR_LIST_CONTRACT_MISSING`
- **Previous:** tab · **Next:** #79 / #80 · **Alternatives:** #78 create
- **Entry Points:** Tours tab · **Entry Conditions:** approved · **Exit:** open/create
- **User Goal:** see my tour packages and their approval state
- **Page Header:** "My tours" + Create (FAB) · **Layout:** status filter + list of tour cards
- **Sections:** filter by status (statuses Backend-owned; draft/pending approval/approved/rejected/inactive are `DESIGN_ONLY_FIELD`) · cards (title, destinations, price, next schedule, status)
- **Components:** NEW_SHARED `TourPackageCard` (EXISTING_EXTEND of `TourListCard` is possible but the data shape differs → FEATURE_LOCAL), `StatusBadge`
- **Primary Action:** Create tour · **Secondary:** open, filter, refresh
- **Displayed Data/Pagination/Filter/Sort:** Backend-defined; `BACKEND_SUPPORT_REQUIRED`
- **Loading/Empty/Error:** C-STATE; empty → "Create your first tour" · **Success:** list
- **Dialogs:** none · **Offline:** unavailable · **Permission:** none
- **Responsive / Accessibility:** C-RESP, C-A11Y (status = icon + text)
- **Reusable / Unique:** `StatusBadge`; `TourPackageCard` feature-local
- **Visual Tokens:** C-TOKENS · **Context Out:** `tourId`
- **Backend Readiness (C-BE):** A operator from token · B own tours · C none · D Backend · E page/limit · F title search (`SRS_TEXT_REQUIRED`) · G status · H updated desc · I 401/403/5xx · J JWT · K own · M none · O NO · P **list capability** · R retry reads · S pull-to-refresh · T none · U Backend; L, N, Q: none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_TOUR_LIST_CONTRACT_MISSING` · **Device:** none · **Deep Link:** none
- **Demo / Production Boundary:** no sample tours · **Non-goals:** bulk actions
- **Acceptance Criteria:** AC1 only own tours; AC2 status from Backend; AC3 empty ≠ error.

### S-78 Create Tour Package
- **Screen Index:** 78 · **UC:** UC-35 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (multi-section/stepper) · **Route:** `/operator/tours/new` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE for the package; **media upload contract exists** (table above) but needs an existing `tourId` · **Permission:** FULL · **Contract:** `OPERATOR_TOUR_CREATE_CONTRACT_MISSING`
- **Previous:** #77 · **Next:** #80 · **Alternatives:** save draft (`SRS_TEXT_REQUIRED`)
- **Entry Points:** Create on #77, Dashboard · **Entry Conditions:** approved · **Exit:** created → #80 / #77
- **User Goal:** define a bookable tour package
- **Page Header:** "Create tour" + step indicator · **Layout:** stepper. Visual reference: `t_o_g_i_tour_m_i_tripmate_operator`
- **Sections (semantic, exact fields `SRS_TEXT_REQUIRED`):** basic info · destinations (POIs/destinations from an authoritative catalogue) · day-by-day itinerary · schedules (dates, capacity, price) · inclusions/exclusions · policies (cancellation) · media (cover + gallery, uses verified media contract after the tour exists)
- **Components:** `AppTextField`, `StepProgressHeader` (NEW_SHARED, shared with #40), schedule editor (feature-local), media manager (feature-local)
- **Primary Action:** Continue / Create · **Secondary:** Back, Save draft (only if Backend supports)
- **Form Inputs / Validation:** per SRS; client mirrors Backend bounds only after they are documented; field errors from ProblemDetails mapped onto fields
- **Loading:** step save/submit progress · **Empty:** n/a · **Error:** field errors, 409 conflicts, 413 media too large, 503 media service unavailable (verified media statuses)
- **Success State:** created only after Backend returns the tour identity; media upload begins after that
- **Dialogs:** discard confirm · **Offline:** disabled · **Permission:** photo/gallery access (`DEVICE_INTEGRATION_MISSING`)
- **Responsive / Accessibility:** C-RESP, C-A11Y; stepper announced; keyboard never hides action bar
- **Reusable / Unique:** `StepProgressHeader`; schedule editor, media manager
- **Visual Tokens:** C-TOKENS · **Context In:** none · **Context Out:** `tourId`
- **Backend Readiness (C-BE):** A client operation key; Backend `tourId` · B destination catalogue · C create tour (idempotent), then upload media (verified, `Idempotency-Key` GUID) · D Backend · I 400/401/403/409/413/503 · J JWT · K own · L image picker, multipart upload · M none · N no draft persistence invented · O NO · P **tour creation + destination catalogue** · Q all non-media fields · R media upload retry reuses the same key for the same file · S none · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_TOUR_CREATE_CONTRACT_MISSING`, `DESTINATION_CATALOGUE_CONTRACT_MISSING`
- **Device:** image picker/camera (missing) · **Deep Link:** none
- **Demo / Production Boundary:** no local "created" tour · **Non-goals:** pricing rules engine
- **Acceptance Criteria:** AC1 creation only after Backend identity; AC2 media upload follows the verified contract; AC3 destinations from an authoritative source; AC4 field errors kept.

### S-79 Update Tour Package
- **Screen Index:** 79 · **UC:** UC-36 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/operator/tours/:tourId/edit` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE (media endpoints PATCH/PUT order/DELETE exist) · **Permission:** FULL · **Contract:** `OPERATOR_TOUR_UPDATE_CONTRACT_MISSING`
- **Previous:** #77 / #80 · **Next:** #80 · **Alternatives:** cancel
- **Entry Points:** tour card, preview · **Entry Conditions:** own tour, editable state (`SRS_TEXT_REQUIRED`: effect of editing an approved tour on approval) · **Exit:** saved/cancelled
- **User Goal:** change a tour package
- **Page Header:** tour title · **Layout:** same sections as #78, pre-filled from a Backend read
- **Components / Sections:** as #78; media manager uses verified list/PATCH/reorder/delete
- **Primary Action:** Save changes · **Secondary:** Cancel, Preview
- **Validation/Loading/Error/Success:** as #78; 409 when the tour changed (concurrent edit) → reload prompt; success only after Backend confirms
- **Dialogs:** discard confirm, warn if edit re-triggers approval · **Offline:** disabled · **Permission:** as #78
- **Responsive / Accessibility:** C-RESP, C-A11Y · **Visual Tokens:** C-TOKENS
- **Context In:** `tourId` · **Context Out:** `tourId`
- **Backend Readiness (C-BE):** A `tourId` · B tour detail · C update tour; media metadata/reorder/delete (verified) · D Backend · I 400/401/403/404/409/5xx · J JWT · K owner · L image picker · O NO · P **detail read + update** · Q all non-media · R no blind retry of writes · S re-read after save · T none · U Backend; E–H, M, N: none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_TOUR_UPDATE_CONTRACT_MISSING` · **Device:** image picker · **Deep Link:** `/operator/tours/:id/edit`
- **Demo / Production Boundary:** none · **Non-goals:** version history UI
- **Acceptance Criteria:** AC1 pre-fill from Backend; AC2 concurrent edit handled; AC3 media ops use verified contract; AC4 no success without Backend.

### S-80 Tour Preview & Submit for Approval
- **Screen Index:** 80 · **UC:** UC-37 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE + MODAL (confirm) · **Route:** `/operator/tours/:tourId/preview` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_TOUR_SUBMIT_CONTRACT_MISSING`
- **Previous:** #78/#79 · **Next:** #77 (status pending) · **Alternatives:** back to edit
- **Entry Points:** after create/update · **Entry Conditions:** tour is submittable (Backend decides) · **Exit:** submitted / back
- **User Goal:** review how travellers will see the tour and submit it
- **Page Header:** "Preview" · **Layout:** traveller-style preview (reuse #65 presentation components), readiness checklist, Submit
- **Sections:** preview · checklist (missing required items, from Backend validation result) · Submit
- **Components:** reuse #65 components (EXISTING_REUSE once built), `ConfirmationDialog`, `StatusBadge`
- **Primary Action:** Submit for approval · **Secondary:** Edit, Cancel
- **Dialogs:** confirm submit · **Loading:** submit progress · **Error:** 409 not submittable (shows reasons), 5xx retry only after re-read · **Success State:** status becomes whatever Backend reports (e.g. *Pending approval*); the UI never marks "Approved" (that is Admin Web, UC-60)
- **Offline:** disabled · **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y
- **Visual Tokens:** C-TOKENS · **Context In:** `tourId` · **Context Out:** none
- **Backend Readiness (C-BE):** A `tourId` · B tour + validation result · C submit for approval · D Backend/Admin approval flow · I 400/401/403/409/5xx · J JWT · K owner · O NO · P **submit + validation** · R re-read before retry · S refresh · T none · U Backend; E–H, L, M, N: none
- **Authoritative State Owner:** Backend (approval by Administrator on Web) · **Required Backend Capability:** `OPERATOR_TOUR_SUBMIT_CONTRACT_MISSING`
- **Device:** none · **Deep Link:** none · **Demo / Production Boundary:** no local approval state
- **Non-goals:** approving/rejecting (Admin Web) · **Acceptance Criteria:** AC1 status only from Backend; AC2 readiness reasons from Backend; AC3 destructive-style confirm; AC4 never shows Approved locally.

### S-81 Promotional Coupons List
- **Screen Index:** 81 · **UC:** UC-38/UC-39 (entry) · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/operator/coupons` PROPOSED · **Parent Shell:** Operator (via Dashboard/Profile)
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_COUPON_LIST_CONTRACT_MISSING`
- **Previous:** Dashboard/Profile · **Next:** #83 · **Alternatives:** #82
- **Entry Points:** Dashboard, Profile · **User Goal:** manage promotions. Visual reference: `qu_n_l_khuy_n_m_i_coupon_tripmate_partner`
- **Layout / Sections:** status filter (active/expired/deactivated — Backend-owned) · coupon cards (code, discount, validity, usage)
- **Components:** feature-local `CouponCard`, `StatusBadge` · **Primary Action:** Create coupon · **Secondary:** open, filter
- **Displayed Data:** `BACKEND_SUPPORT_REQUIRED` · **Loading/Empty/Error:** C-STATE; empty → "No coupons yet"
- **Dialogs:** none · **Offline:** unavailable · **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y
- **Visual Tokens:** C-TOKENS · **Context Out:** `couponId`
- **Backend Readiness (C-BE):** A operator from token · B own coupons · C none · D Backend · E page/limit · G status · I 401/403/5xx · J JWT · K own · O NO · P **list** · R retry reads · S refresh · T none · U Backend; F, H, L, M, N, Q: none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_COUPON_LIST_CONTRACT_MISSING` · **Device:** none · **Deep Link:** none
- **Demo / Production Boundary:** no fake coupons · **Non-goals:** traveller-side redemption UI (not in this index)
- **Acceptance Criteria:** AC1 only Backend coupons; AC2 empty ≠ error; AC3 status icon + text.

### S-82 Create Coupon
- **Screen Index:** 82 · **UC:** UC-38 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (form) · **Route:** `/operator/coupons/new` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_COUPON_CREATE_CONTRACT_MISSING`
- **Previous:** #81 · **Next:** #81 · **Alternatives:** cancel
- **User Goal:** create a promotion
- **Sections (semantic, fields `SRS_TEXT_REQUIRED`):** code, discount type/value, validity period, usage limit, applicable tours
- **Components:** `AppTextField`, date pickers (NEW_SHARED `DateRangeField`), tour multi-select (data from #77 source) · **Primary Action:** Create · **Secondary:** Cancel
- **Validation:** per SRS; code uniqueness is Backend-validated (409 → field error "Code already used")
- **Loading/Error/Success:** C-STATE; success only after Backend returns the coupon identity (coupon persistence is on the truthfulness list)
- **Dialogs:** discard confirm · **Offline:** disabled · **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y
- **Context In:** none · **Context Out:** `couponId`
- **Backend Readiness (C-BE):** A client operation key; `couponId` from Backend · B own tours for selection · C create coupon (idempotent) · D Backend · I 400/401/403/409/5xx · J JWT · K own · O NO · P **create** · Q all · R same key for same intent · T none · U Backend; E–H, L, M, N, S: none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_COUPON_CREATE_CONTRACT_MISSING` · **Device:** none · **Deep Link:** none
- **Demo / Production Boundary:** no local coupon · **Acceptance Criteria:** AC1 duplicate code reported on field; AC2 success only after Backend; AC3 no double submit.

### S-83 Update Coupon
- **Screen Index:** 83 · **UC:** UC-39 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (edit/deactivate) · **Route:** `/operator/coupons/:couponId` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_COUPON_UPDATE_CONTRACT_MISSING`
- **Previous:** #81 · **Next:** #81 · **Alternatives:** deactivate
- **Sections:** same fields as #82; fields locked once redeemed (`SRS_TEXT_REQUIRED`); Deactivate action with `ConfirmationDialog`
- **Primary Action:** Save · **Secondary:** Deactivate, Cancel
- **Error:** 409 coupon already used/changed → reload; **Success:** only after Backend confirms; deactivation reflected from Backend status
- **Offline:** disabled · **Responsive / Accessibility:** C-RESP, C-A11Y · **Context In:** `couponId` · **Context Out:** none
- **Backend Readiness (C-BE):** A `couponId` · B coupon · C update/deactivate · D Backend · I 400/401/403/404/409/5xx · J JWT · K owner · O NO · P **update** · R re-read before retry · U Backend; others none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_COUPON_UPDATE_CONTRACT_MISSING`
- **Demo / Production Boundary:** none · **Acceptance Criteria:** AC1 pre-fill from Backend; AC2 deactivation confirmed first; AC3 no local-only state.

### S-84 Customer Bookings List
- **Screen Index:** 84 · **UC:** UC-40 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (tab root "Bookings") · **Route:** `/operator/bookings` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_BOOKING_LIST_CONTRACT_MISSING`
- **Previous:** tab · **Next:** #85 · **Alternatives:** #88 Scan QR (primary action)
- **User Goal:** find bookings for my tours. Visual reference: `qu_n_l_t_tour_ho_n_ti_n_tripmate_operator`
- **Sections:** filters (tour, departure date, status) · search (by booking ref/name `SRS_TEXT_REQUIRED`) · booking cards
- **Components:** `BookingCard` (NEW_SHARED, operator data shape), `StatusBadge`, filter sheet (NEW_SHARED base)
- **Primary Action:** open booking · **Secondary:** Scan QR, filter
- **Displayed Data:** `BACKEND_SUPPORT_REQUIRED`; automatic cancellation/refund outcomes (UC-70/71) appear as booking status
- **Loading/Empty/Error:** C-STATE · **Dialogs:** filter sheet · **Offline:** unavailable · **Permission:** none
- **Responsive / Accessibility:** C-RESP, C-A11Y · **Context Out:** `bookingId`
- **Backend Readiness (C-BE):** A operator from token · B own bookings · C none · D Backend · E page/limit · F text · G tour/date/status · H date · I 401/403/5xx · J JWT · K own tours only · O NO · P **list** · R retry reads · S pull-to-refresh · T traveller PII · U Backend; L, M, N, Q: none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_BOOKING_LIST_CONTRACT_MISSING` · **Device:** none · **Deep Link:** none
- **Demo / Production Boundary:** no fake bookings · **Acceptance Criteria:** AC1 only own bookings; AC2 status not colour-only; AC3 empty ≠ error.

### S-85 Booking Details & Passenger Manifest
- **Screen Index:** 85 · **UC:** UC-40 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/operator/bookings/:bookingId` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_BOOKING_DETAIL_AND_MANIFEST_CONTRACT_MISSING`
- **Previous:** #84 · **Next:** #86 / #87 · **Alternatives:** #88
- **Sections:** booking summary · payment status · passenger manifest (names, count, contact, check-in status) · actions (Cancel, Refund — shown only when Backend allows)
- **Components:** `StatusBadge`, `PriceText`, manifest list (feature-local), `ConfirmationDialog`
- **Primary Action:** depends on state (Scan/verify, Cancel) · **Secondary:** Refund, contact (system dialer only if SRS; `DEVICE_INTEGRATION_MISSING`)
- **Displayed Data:** `BACKEND_SUPPORT_REQUIRED`; check-in status is **Backend-owned**; never updated locally
- **Loading/Empty/Error:** C-STATE; 403/404 non-retry · **Offline:** unavailable · **Permission:** none
- **Responsive / Accessibility:** C-RESP, C-A11Y · **Context In:** `bookingId` · **Context Out:** `bookingId`
- **Backend Readiness (C-BE):** A `bookingId` · B booking + manifest + payment + check-in status · C via #86/#87 · D Backend · I 401/403/404/5xx · J JWT · K own tour bookings · O NO · P **detail + manifest** · R retry reads · S refresh · T **passenger PII** (no logging, no screenshots cache) · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_BOOKING_DETAIL_AND_MANIFEST_CONTRACT_MISSING` · **Device:** none · **Deep Link:** `/operator/bookings/:id`
- **Demo / Production Boundary:** no sample passengers · **Acceptance Criteria:** AC1 manifest from Backend only; AC2 actions gated by Backend flags; AC3 PII not logged.

### S-86 Cancel Customer Booking
- **Screen Index:** 86 · **UC:** UC-41 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** MODAL on #85 · **Route:** none
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_BOOKING_CANCEL_CONTRACT_MISSING`
- **Previous:** #85 · **Next:** #85 refreshed · **Alternatives:** keep booking
- **Sections:** consequence text (traveller is notified, refund follows policy — wording `SRS_TEXT_REQUIRED`), **reason** (required if SRS says so)
- **Components:** `ConfirmationDialog`, `AppTextField` (reason) · **Primary Action:** Confirm cancellation (destructive) · **Secondary:** Keep
- **Validation:** reason bounds per SRS · **Loading/Error/Success:** C-STATE; 409 not cancellable → show reason and refresh; success only after Backend confirms; refund is a separate process shown on #85
- **Offline:** disabled · **Responsive / Accessibility:** C-RESP, C-A11Y · **Context In:** `bookingId` · **Context Out:** none
- **Backend Readiness (C-BE):** A `bookingId` · C cancel (idempotent) · D Backend · I 400/401/403/404/409/5xx · J JWT · K owner · O **NO** · P **cancel** · R re-read before retry · T none · U Backend; B, E–H, L–N, Q, S: none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_BOOKING_CANCEL_CONTRACT_MISSING` · **Demo / Production Boundary:** hidden until capability exists
- **Acceptance Criteria:** AC1 no success without Backend; AC2 reason captured per SRS; AC3 destructive confirm default-focus on Keep.

### S-87 Initiate Booking Refund
- **Screen Index:** 87 · **UC:** UC-42 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** MODAL / action within #85 · **Route:** none
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_REFUND_INITIATION_CONTRACT_MISSING`
- **Previous:** #85 · **Next:** #85 refreshed
- **Sections:** refund amount (**Backend-computed; operator input only if SRS allows**, `SRS_TEXT_REQUIRED`), reason, consequence text
- **Components:** `ConfirmationDialog`, `PriceText`, `AppTextField` · **Primary Action:** Initiate refund · **Secondary:** Cancel
- **Loading/Error/Success:** C-STATE; **refund success is never asserted by the client**: after the Backend accepts, show "Refund requested/pending" and let #85 show progress; completion is Backend/gateway-owned (`refund success` is on the truthfulness list)
- **Offline:** disabled · **Responsive / Accessibility:** C-RESP, C-A11Y · **Context In:** `bookingId` · **Context Out:** none
- **Backend Readiness (C-BE):** A `bookingId` · B refundable amount · C initiate refund (idempotent) · D Backend/payment gateway · I 400/401/403/404/409/5xx · J JWT · K owner · O **NO** · P **refund initiation + status** · R same key for same intent; ambiguous timeout → re-read refund state first · T financial data · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_REFUND_INITIATION_CONTRACT_MISSING` · **Demo / Production Boundary:** hidden until capability exists
- **Acceptance Criteria:** AC1 amount from Backend; AC2 status shown as pending until Backend says otherwise; AC3 no duplicate refunds on retry.

### S-88 Tour Participant QR Check-in Scanner
- **Screen Index:** 88 · **UC:** UC-43 (`MOBILE_ONLY`, `SRS_CONFLICT` C-3) · **Role:** Tour Operator · **Platform:** Mobile
- **Presentation Type:** FULL_PAGE (camera) with result BOTTOM_SHEET · **Route:** `/operator/checkin` PROPOSED · **Parent Shell:** Operator
- **Implementation Status:** NOT_STARTED · **Nature:** NOT_STARTED, **but the camera capability already exists** (`mobile_scanner` is used by Traveler #62 `qr_scanner_dialog.dart`) · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_CHECKIN_VALIDATION_CONTRACT_MISSING`
- **Previous:** Bookings/Dashboard · **Next:** result then scan again · **Alternatives:** #85 (manual lookup if SRS allows)
- **Entry Points:** Scan QR action · **Entry Conditions:** approved operator · **Exit:** close scanner
- **User Goal:** check a traveller in quickly and trust the result
- **Page Header:** tour/departure selector + counter (from Backend) · **Layout:** full-screen camera preview with overlay frame, flashlight toggle, result sheet. Visual reference: `qr_scanner_check_in_tour_tripmate_operator`
- **Sections / Components:** EXISTING_EXTEND `QrScannerDialog` scanning core into a full-page scanner; NEW_SHARED `ScannerOverlay`; result sheet; `StatusBadge`
- **Camera permission states:** not determined → rationale + request · denied → explanation + retry · denied forever → "Open settings" · restricted/unavailable → manual alternative if SRS allows
- **Scanner states:** `Scanning` → `Processing` (payload sent for validation) → one of `Valid` | `Invalid` | `Already used` | `Not for this tour/departure` | `Network error` | `Server error`. **Local decoding is not check-in success**: `Valid` appears **only** after the Backend validates and records the check-in. Each result: icon + text + (optional) haptic/sound, never colour only; auto-resume scanning after dismissal; one in-flight validation per payload (debounce duplicates)
- **Primary Action:** scan · **Secondary:** toggle flash, change departure, view manifest
- **Loading:** `Processing` indicator; **Empty:** n/a · **Error:** per states above; network error → retry the **same payload** safely only because validation is server-idempotent — idempotency semantics are Backend-defined (`SRS_TEXT_REQUIRED`)
- **Offline State:** online required; any buffered/offline check-in (UC-72 schema `trip.OfflineSyncBatches`) is **not designed here** and must never be displayed as valid before Backend acknowledgement
- **Responsive / Accessibility:** C-RESP, C-A11Y; result announced as a live region; large result text; flashlight control labelled
- **Reusable / Unique:** reuse scanning core; unique `ScannerOverlay`
- **Visual Tokens:** C-TOKENS · **Context In:** departure/tour selection · **Context Out:** `bookingId`/passenger result (display only)
- **Backend Readiness (C-BE):** A scanned ticket payload (opaque), operator from token · B validation result (valid/invalid/used/wrong tour), passenger/booking summary · C validate-and-check-in (single atomic Backend operation) · D **Backend** · E–H none · I 400/401/403/404/409/5xx · J JWT TourOperator · K only own tours' tickets · L camera, flashlight · M none · N none · O **NO** · P **validation + check-in endpoint** · Q counters · R retry only on network failure, never auto-repeat after a definitive answer · S none · T **ticket payload sensitive**: not logged, not stored · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_CHECKIN_VALIDATION_CONTRACT_MISSING`
- **Device:** camera + flashlight (**present**), haptics · **Deep Link:** none
- **Demo / Production Boundary:** **no local fake check-in success in production**; a demo scanner may exist only in explicit `DEMO_ONLY`
- **Design-only Assumptions:** counters, departure selector · **Implementation Notes:** blocked by SRS conflict C-3 for approval; scanning core reuse avoids a second camera integration
- **Non-goals:** issuing tickets, offline validation
- **Acceptance Criteria:** AC1 `Valid` only after Backend confirmation; AC2 all six failure states distinct and announced; AC3 permission states complete; AC4 payload never logged; AC5 duplicate scans don't double check-in.

### S-89 Revenue & Analytics
- **Screen Index:** 89 · **UC:** UC-44 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (tab root "Revenue") · **Route:** `/operator/revenue` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_REVENUE_REPORT_CONTRACT_MISSING`
- **Previous:** tab · **Next:** #90 / #91 · **Alternatives:** #92
- **User Goal:** understand earnings over time. (Stitch's partner finance dashboard is desktop 1440 px → layout designed independently for Mobile.)
- **Sections:** period selector · KPI cards (gross, commission, net, bookings) · trend chart · per-tour breakdown · links to export/payout
- **Components:** `StatCard`, chart (feature-local, **no chart package added by this task**), `StatusBadge`
- **Primary Action:** change period · **Secondary:** Export (#90), Payouts (#91)
- **Displayed Data:** Backend-computed only (`DESIGN_ONLY_FIELD`/`BACKEND_SUPPORT_REQUIRED` for every figure); no client-side sums of partial data
- **Loading/Empty/Error:** C-STATE; zero revenue (Backend zero) ≠ unavailable · **Offline:** unavailable
- **Responsive / Accessibility:** C-RESP, C-A11Y; chart has a data-table alternative; values never colour-only
- **Context Out:** period
- **Backend Readiness (C-BE):** A operator from token · B aggregates by period/tour · C none · D Backend · E none · G period, tour · H date · I 401/403/5xx · J JWT · K own · O NO · P **report** · R retry reads · S refresh · T financial data · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_REVENUE_REPORT_CONTRACT_MISSING` · **Device:** none · **Deep Link:** none
- **Demo / Production Boundary:** no sample figures · **Acceptance Criteria:** AC1 only Backend figures; AC2 period change re-reads; AC3 chart has text alternative.

### S-90 Export Revenue Report
- **Screen Index:** 90 · **UC:** UC-45 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** BOTTOM_SHEET / dialog on #89 · **Route:** none
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_REVENUE_EXPORT_CONTRACT_MISSING`
- **Sections:** period, format (`SRS_TEXT_REQUIRED`), Generate · result: file ready / failed
- **Primary Action:** Export · **Secondary:** Cancel
- **Loading/Error/Success:** C-STATE; the file is **generated by the Backend**; success only when a Backend result exists; delivery to the user (save/share) is a device concern (`share_plus` present; file download/save missing → `DEVICE_INTEGRATION_MISSING`)
- **Offline:** disabled · **Permission:** storage only if saving locally · **Responsive / Accessibility:** C-RESP, C-A11Y
- **Context In:** period · **Context Out:** none
- **Backend Readiness (C-BE):** A operator, period · B generated report · C generate export · D Backend · I 400/401/403/5xx, too large · J JWT · K own · L file save/share · O NO · P **export** · R retry only generation request after state check · T financial data (do not log, do not cache beyond delivery) · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_REVENUE_EXPORT_CONTRACT_MISSING` · **Demo / Production Boundary:** hidden until capability exists
- **Acceptance Criteria:** AC1 no fake file; AC2 success only after Backend result; AC3 delivery errors distinct from generation errors.

### S-91 Payout Settlement History
- **Screen Index:** 91 · **UC:** UC-46 (history/detail; Admin confirms via UC-65 on Web) · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (list + detail) · **Route:** `/operator/payouts` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_PAYOUT_HISTORY_CONTRACT_MISSING`
- **Previous:** #89 · **Next:** #92 · **Alternatives:** payout detail
- **Sections:** available balance (Backend), payout list (period, amount, status, dates), detail
- **Components:** NEW_SHARED `PayoutCard`, `PriceText`, `StatusBadge` · **Primary Action:** Request payout (#92) · **Secondary:** open detail
- **Displayed Data:** Backend-only; statuses Backend-owned (`SRS_TEXT_REQUIRED`: requested/approved/paid/rejected is `DESIGN_ONLY_FIELD`)
- **Loading/Empty/Error:** C-STATE · **Offline:** unavailable · **Responsive / Accessibility:** C-RESP, C-A11Y (status icon + text)
- **Backend Readiness (C-BE):** A operator from token · B balance + payouts · C none · D Backend (Admin confirms settlement) · E page/limit · H newest first · I 401/403/5xx · J JWT · K own · O NO · P **history** · R retry reads · S refresh · T financial data · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_PAYOUT_HISTORY_CONTRACT_MISSING` · **Demo / Production Boundary:** no sample payouts (`payout success` is on the truthfulness list)
- **Acceptance Criteria:** AC1 amounts only from Backend; AC2 status never colour-only; AC3 empty ≠ error.

### S-92 Payout Request
- **Screen Index:** 92 · **UC:** UC-46 · **Role:** Tour Operator · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (form) · **Route:** `/operator/payouts/request` PROPOSED
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `OPERATOR_PAYOUT_REQUEST_CONTRACT_MISSING`
- **Previous:** #91 · **Next:** #91 · **Alternatives:** cancel
- **Sections:** available balance (Backend), amount, payout destination details (fields `SRS_TEXT_REQUIRED`), summary, Submit
- **Components:** `AppTextField` (currency), `PriceText`, `ConfirmationDialog`
- **Validation:** amount > 0 and ≤ Backend-reported available balance; destination fields per SRS; server re-validates
- **Loading/Error/Success:** C-STATE; submit uses an operation key; success shows **"Requested"** status from Backend — settlement is confirmed later by an Administrator (Web) and is never shown as paid by the client; 409 balance changed → refresh balance
- **Offline:** disabled · **Responsive / Accessibility:** C-RESP, C-A11Y
- **Context In:** balance snapshot (display) · **Context Out:** `payoutId`
- **Backend Readiness (C-BE):** A operation key; `payoutId` from Backend · B available balance, destination info · C request payout (idempotent) · D Backend/Admin · I 400/401/403/409/5xx · J JWT · K own · O **NO** · P **request + balance** · R same key for same intent · T bank/financial PII (never logged) · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `OPERATOR_PAYOUT_REQUEST_CONTRACT_MISSING` · **Demo / Production Boundary:** hidden until capability exists
- **Acceptance Criteria:** AC1 amount bounded by Backend balance; AC2 no duplicate request on retry; AC3 never shows "paid" locally; AC4 financial inputs not logged.
