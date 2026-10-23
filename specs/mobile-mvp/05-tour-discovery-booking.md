# 05 — Tour Discovery, Booking, Payment and E-ticket (Screens #63–#70, UC-24…UC-29)

> **Revision 2026-10-08 (QA) — how to read this file.** The funnel integrity rules and sections S-64…S-70 remain the structural design; `13-v2-completion-specs.md` Part 3 adds the V2 layer (UC-24…UC-29 fields, BR-52…BR-100, MSG64–MSG103) and replaces their status lines and `SRS_TEXT_REQUIRED` placeholders. **Stale statements below:** #64/#65 now exist in open PR #31; #66–#70 exist only on the unmerged branch `feature/mobile-tour-booking-payment-ticket` (no PR). None is on develop; all are `NO_BACKEND`. S-70 says no Traveler cancellation UC exists — V2 Table 4.2 #70 and the UC-28 alternative flow "Cancel the booking instead of paying" provide the basis (`13` S-67). Payment methods are VNPay and PayOS (V2 §3.5.5).

Standards: `C-*` in `01-mobile-shells-and-navigation.md` §1.
**Backend reality (BE develop `d198107`):** the only tour capability is the public list `GET /api/v1/tours` (ToursController, anonymous). There is **no** tour detail, recommendations, booking, payment, ticket or booking list endpoint. Everything from #64 onward is `BACKEND CAPABILITY REQUIRED`.

## Funnel integrity rules (apply to #64–#70)
1. **Preserved context:** `tourId`, `scheduleId`, traveller quantity, **displayed** price, `bookingId`, payment state, ticket state. Passed as route params / `extra` between screens; no new persistence mechanism is invented here.
2. **Displayed price is not authoritative.** The Backend computes the amount; the UI labels it "Estimated" until a Backend-created booking confirms the amount.
3. **Never fake:** booking success, payment success, refund success, ticket validity, Backend-created ids/timestamps.
4. **Payment return ≠ payment success** (UC-28). A deep link/browser return only triggers a **server verification read**; the UI shows *Awaiting verification* until the Backend states paid.
5. **QR payload comes from the Backend** (UC-29). Flutter renders it with `qr_flutter`; it never constructs or signs ticket data.
6. **Idempotency:** booking creation and payment initiation are operations with a client key (rules §14–§15: key reused on retry of the *same* intent, new key when the intent changes; ambiguous timeout must not create a second operation). The exact header/transport is Backend-defined — not invented here.

---

## Part 1 — EXISTING SCREEN PRESERVATION RECORD

### P-63 Search Tours (UC-24) — `MERGED_IMPLEMENTED`, `IMPLEMENTED_BE_INTEGRATED`
- Route `/explore/tours` (public) · `tour_search_page.dart` (605 lines) · `TourSearchCubit` · `SearchToursUseCase` · `TourSearchRepositoryImpl` → `TourSearchRemoteDataSource` · widgets `TourListCard`, `TourSearchFilterSheet` (bottom sheet), `tour_search_palette`.
- Tests: `tour_search_page_test`, `tour_search_cubit_test`, `tour_search_repository_impl_test`, `tour_search_page_model_test`, `tour_search_query_test`, `availability_status_test`, `tour_list_card_test`, `tour_search_filter_sheet_test`. Spec: `specs/TM-70-spec.md`.

**BACKEND INTEGRATION CONTRACT**
- API: `GET /api/v1/tours` · Auth: **none** (`skipAuth`)
- Query: `destination` (≤300 chars), `departureDate`, `minPrice`, `maxPrice` (0…9 999 999 999 VND, min ≤ max enforced client-side), `page`, `pageSize` (default 20)
- Response: `{ page, pageSize, totalCount, totalPages, items[] }`; item keys `tourId (string), title, destinations[], operatorName, durationDays, basePrice (int), currency, representativeScheduleId?, departureAtUtc?, availabilityStatus, remainingSlots?`
- Status mapping: `availabilityStatus` ∈ `available | soldOut | noUpcomingSchedule | unknown` (unknown/other → `unknown`). Card labels: "Còn N chỗ" / "Hết chỗ" / "Chưa có lịch khởi hành" / "Tình trạng chỗ chưa xác định" — all four are handled correctly (unlike the Web PR before its fix).
- Pagination: load-more + pull-to-refresh · Upload: none · Deep link: none · Caching: none
- Components: `TourSearchCubit`, `TourSearchRepository`, `TourSearchRemoteDataSource`
- **INTEGRATION CONTRACT: FROZEN.** Safe: card visuals (`kh_m_ph_tour_tripmatch_tripmate_mobile`), filter sheet styling, skeletons. Must not change: query names/limits, status mapping, public access, stale-response handling (see rules U03), `currency` display from data.
- **Forward context to #65:** `tourId` (string), `representativeScheduleId`, `basePrice`, `currency`, `availabilityStatus`. The list does **not** return images (TM-70 out-of-scope); BE branch `feature/datmnt-tour-search-thumbnail` adds a thumbnail — treat as optional/nullable when it lands (C55).

---

## Part 2 — DESIGN SPECIFICATIONS (all `NOT_STARTED`, `FULL` design permission)

### S-64 Tour Recommendations

- **Screen Index:** 64 · **UC:** UC-25 · **Name:** Tour Recommendations · **Domain:** Commerce · **Role:** Traveler · **Platform:** SHARED
- **Presentation Type:** EMBEDDED_SECTION on Khám phá tab (+ optional FULL_PAGE "See all") · **Route:** `/traveler/tours/recommendations` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Nature:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Backend Contract Status:** `TOUR_RECOMMENDATION_CONTRACT_MISSING`. (Only `POST /api/v1/recommendation-feedback` exists — a feedback capture, not a recommendation source.)
- **Previous:** Khám phá · **Next:** #65 · **Alternatives:** #63 search
- **Entry Points:** Khám phá tab, Traveler Home · **Entry Conditions:** Traveler, preferences (BE-owned) · **Exit:** open tour
- **User Goal:** see tours that match my preferences
- **Page Header:** "Recommended for you" · **Layout:** vertical cards with reason line. Visual reference: `kh_m_ph_tour_tripmatch_tripmate_mobile`
- **Sections:** recommendation cards · "why this tour" · refresh · link to Preferences (#46)
- **Components:** reuse `TourListCard` (EXISTING_EXTEND with an optional score/reason slot), `StatusBadge`, `ErrorView`
- **Primary Action:** open tour · **Secondary:** refresh, edit preferences
- **Displayed Data (semantic needs):** tour identity, title, similarity score, availability, schedule summary, price. `DESIGN_ONLY_FIELD`: match percentage presentation — shown only if Backend provides a score; **never computed or invented on the client**
- **Form Inputs / Validation:** none
- **Loading:** skeleton · **Empty:** "No recommendations yet" + link to preferences (distinct from error) · **Error:** retry read · **Success:** list
- **Dialogs / Sheets:** none · **Offline:** show nothing fabricated; message
- **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y (score not colour-only)
- **Reusable / Unique:** `TourListCard` · none
- **Visual Tokens:** C-TOKENS
- **Context In:** none · **Context Out:** `tourId`, `scheduleId?`
- **Backend Readiness (C-BE):** A user from token · B recommended tours · C optional feedback (existing capture endpoint, separate decision) · D Backend · E page/limit (BE) · F none · G none · H score (BE) · I 401/5xx · J JWT · K Traveler · L none · M none · N none · O NO · P **recommendation source** · Q score, reason · R retry reads · S pull-to-refresh · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TOUR_RECOMMENDATION_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep Link:** none
- **Demo / Production Boundary:** production → `PENDING_INTEGRATION_STATE` ("Personalised tours are not available yet"); demo cards only in explicit `DEMO_ONLY` (Web PR #41 followed this rule)
- **Design-only Assumptions:** card composition · **Implementation Notes:** keep search (#63) independent
- **Non-goals:** ranking logic on device
- **Acceptance Criteria:** AC1 no fabricated scores/tours; AC2 pending state truthful; AC3 reuses the tour card; AC4 empty ≠ error.

### S-65 Tour Details

- **Screen Index:** 65 · **UC:** UC-26 · **Name:** Tour Details · **Domain:** Commerce · **Role:** Guest / Traveler · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/explore/tours/:tourId` PROPOSED (public) · **Parent Shell:** Public
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Backend Contract Status:** `TOUR_DETAIL_CONTRACT_MISSING` (no `GET /tours/{id}`)
- **Previous:** #63 / #64 · **Next:** #66 Book · **Alternatives:** share, back to results
- **Entry Points:** list card, recommendation, deep link · **Entry Conditions:** any user can view; **booking requires sign-in** · **Exit:** Book / back
- **User Goal:** decide whether to book this tour
- **Page Header:** gallery + title + operator · **Layout:** gallery, price/rating strip, tabs/sections, sticky booking bar. Visual reference: `chi_ti_t_tour_hanoi_old_quarter_cycling_tripmate`
- **Sections (semantic):** gallery · overview/description · destinations · day-by-day itinerary · inclusions/exclusions · cancellation policy · meeting point · schedules (date, price, remaining capacity) · reviews summary · operator
- **Components:** gallery carousel (feature-local), `StatusBadge` (availability), schedule picker (NEW_SHARED `SchedulePicker`), `AppButton`, price text (NEW_SHARED `PriceText`)
- **Primary Action:** Select schedule → Book · **Secondary:** share, view operator
- **Navigation:** Book → #66 with `tourId`, `scheduleId`, quantity, price (guard → login with `from` if unauthenticated)
- **Displayed Data:** all `BACKEND_SUPPORT_REQUIRED`; Web PR #41 lists the *expected* DTO (`tourId, title, description, destinations, operatorName, durationDays, basePrice, currency, aggregateRating, reviewCount, images, inclusions, exclusions, cancellationPolicy, meetingPoint, schedules, itinerary, reviews`) — a **design reference only, not a contract**
- **Form Inputs:** schedule selection, quantity stepper (bounds = remaining capacity from Backend)
- **Validation:** quantity ≥ 1 and ≤ remaining slots; selected schedule must be bookable
- **Loading:** skeleton · **Empty:** sections with no data are hidden, not filled (rules U04: optional fields null/empty) · **Error:** 404 "Tour not found" (no retry), 5xx retry
- **Success:** n/a · **Dialogs / Sheets:** schedule picker sheet · **Offline:** error state
- **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y; gallery images have alt text from data; image 404 → neutral placeholder, no stock image
- **Reusable / Unique:** NEW_SHARED `PriceText`, `SchedulePicker`; unique gallery
- **Visual Tokens:** C-TOKENS
- **Context In:** `tourId` (+ optional list hints, display-only) · **Context Out:** `tourId`, `scheduleId`, quantity, displayed price
- **Backend Readiness (C-BE):** A `tourId` · B detail + schedules + reviews summary · C none · D Backend · E reviews page (BE) · F none · G none · H none · I 404/5xx · J public read · K none · L none · M `/explore/tours/:id` · N none · O NO · P **detail endpoint** · Q every field above · R retry reads · S refresh · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TOUR_DETAIL_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep Link:** public tour URL `DEVICE_INTEGRATION_MISSING` (no app-link handling)
- **Demo / Production Boundary:** no demo tour in production; `PENDING_INTEGRATION_STATE` until BE exists
- **Design-only Assumptions:** section order · **Implementation Notes:** nullable-safe parsing from day one (C55)
- **Non-goals:** reviews authoring (UC-33), compare tours
- **Acceptance Criteria:** AC1 detail data only from Backend; AC2 missing optional fields don't break the page; AC3 Book requires auth; AC4 sold-out/no-schedule disables Book with reason; AC5 image failure shows placeholder.

### S-66 Tour Booking Confirmation

- **Screen Index:** 66 · **UC:** UC-27 · **Name:** Tour Booking Confirmation · **Domain:** Commerce · **Role:** Traveler · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE · **Route:** `/traveler/bookings/new` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Backend Contract Status:** `BOOKING_CREATION_CONTRACT_MISSING`
- **Previous:** #65 · **Next:** #67 · **Alternatives:** back to #65, edit quantity
- **Entry Points:** Book on #65 · **Entry Conditions:** Traveler, bookable schedule · **Exit:** booking created (pending payment) → #67; or cancel
- **User Goal:** review and confirm what I am booking
- **Page Header:** "Confirm booking" · **Layout:** summary card, traveller details form, price breakdown, terms, confirm bar. Visual reference: `x_c_nh_n_t_tour_tripmate_mobile`
- **Sections:** tour + schedule summary · quantity · contact/traveller details (fields `SRS_TEXT_REQUIRED`) · price summary labelled **Estimated** · policy/terms acknowledgement · Confirm
- **Components:** `AppTextField`, `PriceText`, `AppButton`, `AppAlert`
- **Primary Action:** Confirm booking · **Secondary:** Edit, Cancel
- **Displayed Data:** tour/schedule snapshot passed from #65 (display), **final amount only from the Backend response**
- **Form Inputs / Validation:** quantity within capacity, required traveller details per SRS, terms accepted
- **Loading:** confirm in progress, controls disabled; **never** double submit (single in-flight operation key)
- **Empty:** n/a · **Error:** 409 capacity/price changed → show updated Backend data and require re-confirmation; 400 field errors on fields; timeout → *unknown outcome*: "Check My Bookings before booking again", no new operation
- **Success State:** booking exists only once the Backend returns a booking identity → go to #67 (payment) with `bookingId`; status shown as the Backend states (e.g. pending payment) — never "Booked" locally
- **Dialogs / Sheets:** discard confirm · **Offline:** confirm disabled
- **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y; keyboard doesn't hide confirm bar
- **Reusable / Unique:** reuse · none
- **Visual Tokens:** C-TOKENS
- **Context In:** `tourId`, `scheduleId`, quantity, displayed price · **Context Out:** `bookingId`, Backend amount/currency, status
- **Backend Readiness (C-BE):** A tourId, scheduleId, user from token · B none (snapshot) · C create booking (idempotent) · D Backend · E–H none · I 400/401/403/409/5xx · J JWT Traveler · K server validates ownership/capacity · L none · M none · N none · O **NO** · P **booking creation + capacity hold semantics** · Q traveller fields, promo/coupon (UC-38 consumer side `SRS_TEXT_REQUIRED`) · R same key for same intent, new key if quantity/schedule changes · S none · T traveller PII · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `BOOKING_CREATION_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep Link:** none
- **Demo / Production Boundary:** Confirm hidden/disabled until BE exists; no local booking id
- **Design-only Assumptions:** breakdown lines · **Implementation Notes:** identifier for idempotency per `01`/rules §15
- **Non-goals:** group booking splits, add-ons
- **Acceptance Criteria:** AC1 no success without Backend identity; AC2 exactly one operation per intent; AC3 changed price/capacity requires re-confirm; AC4 timeout leaves "unknown outcome" guidance; AC5 amount shown is Backend's.

### S-67 Electronic Payment

- **Screen Index:** 67 · **UC:** UC-28 · **Name:** Electronic Payment · **Domain:** Commerce/Payment · **Role:** Traveler · **Platform:** SHARED (Mobile uses external gateway + deep-link return per R3 Table 3)
- **Presentation Type:** FULL_PAGE + STATE (payment result) · **Route:** `/traveler/bookings/:bookingId/payment` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Backend Contract Status:** `PAYMENT_INITIATION_AND_RECONCILIATION_CONTRACT_MISSING`
- **Previous:** #66 · **Next:** #69 · **Alternatives:** retry payment, back to #68
- **Entry Points:** after booking creation, from a pending-payment booking in #68/#69 · **Entry Conditions:** booking awaiting payment · **Exit:** verified paid → #69; failed/expired → retry or #68
- **User Goal:** pay for the booking securely and know the real outcome
- **Page Header:** "Payment" + amount (Backend) · **Layout:** summary, payment method, secure note, pay button; result states. Visual reference: `thanh_to_n_an_to_n_tripmate_mobile`
- **Sections:** amount due (Backend) · method selection (methods `SRS_TEXT_REQUIRED`) · hand-off explanation · result panel
- **Components:** `PriceText`, `StatusBadge` (payment state), `AppButton`, `AppAlert`, `LoadingIndicator`
- **Primary Action:** Pay now (opens gateway) · **Secondary:** Cancel, Check payment status
- **States (all Backend-owned):** `Not started` → `Redirecting` → `Awaiting verification` → `Paid` | `Failed` | `Cancelled by user` | `Expired` | `Unknown`. **App return/deep link only moves to `Awaiting verification`**, then the screen performs a server read; `Paid` is shown only when that read says so.
- **Form Inputs / Validation:** method selection only
- **Loading:** redirecting / verifying with explicit text · **Empty:** n/a
- **Error State:** gateway cancelled (neutral, not an error), verification failed, still pending after N checks → "We are still confirming your payment; check My Bookings" (never "Paid", never "Failed" while unknown)
- **Success State:** `Paid` from Backend → #69 with ticket state as the Backend reports it
- **Dialogs / Sheets:** leave-payment confirm while awaiting · **Offline:** verification read deferred; banner
- **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y; state changes announced
- **Reusable / Unique:** reuse · unique `PaymentStatusPanel`
- **Visual Tokens:** C-TOKENS (success/warning/error + icon + text)
- **Context In:** `bookingId`, Backend amount/currency · **Context Out:** `bookingId`, payment state
- **Backend Readiness (C-BE):** A `bookingId` · B payment state/amount · C initiate payment (idempotent) · D **Backend gateway reconciliation** · E–H none · I gateway errors, 409 already paid, 410 expired · J JWT · K owner · L **URL launch / in-app browser + deep-link return** (none present) · M **return deep link** · N none · O **NO** · P **initiation, gateway callback reconciliation, status read** · Q method list · R poll with backoff + manual "check status"; never create a second payment while one is unresolved · S status read · T payment data never on device, no card data handled by app · U Backend
- **Authoritative State Owner:** Backend (gateway reconciliation)
- **Required Backend Capability:** `PAYMENT_INITIATION_AND_RECONCILIATION_CONTRACT_MISSING`
- **Device Dependencies:** `DEVICE_INTEGRATION_MISSING`: URL launcher/in-app browser, app/deep links
- **Deep-Link Behavior:** return link → opens this screen with `bookingId`, then verifies server-side; an unknown/forged link shows no state change
- **Demo / Production Boundary:** no simulated gateway in production
- **Design-only Assumptions:** method presentation
- **Implementation Notes:** the previously-stated rule "deep link ≠ payment success" is a hard acceptance criterion
- **Non-goals:** storing cards, wallet management
- **Acceptance Criteria:** AC1 `Paid` only from a Backend read; AC2 return link triggers verification only; AC3 no second payment while unresolved; AC4 clear text for pending/unknown; AC5 no payment data in logs.

### S-68 My Tour Bookings

- **Screen Index:** 68 · **UC:** UC-29 (entry list); outcome surface for UC-70/71 · **Name:** My Tour Bookings · **Role:** Traveler · **Platform:** SHARED
- **Presentation Type:** FULL_PAGE (tab root "Đặt chỗ") · **Route:** `/traveler/bookings` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED (tab body is a placeholder) · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `BOOKING_LIST_CONTRACT_MISSING`
- **Previous:** tab · **Next:** #69 · **Alternatives:** resume payment, search tours
- **Entry Points:** Đặt chỗ tab · **Entry Conditions:** Traveler · **Exit:** open booking
- **User Goal:** find a booking and its state
- **Page Header:** "My bookings" + status filter · **Layout:** list of booking cards
- **Sections:** filter chips (status set is Backend-defined `SRS_TEXT_REQUIRED`) · cards (tour title, date, quantity, status, amount)
- **Components:** NEW_SHARED `BookingCard`, `StatusBadge`, `ErrorView`
- **Primary Action:** open booking · **Secondary:** filter, pull-to-refresh, resume payment (pending payment)
- **Displayed Data:** `BACKEND_SUPPORT_REQUIRED`; automatic cancellation/refund results (UC-70/71) appear as the booking's status/message, not as a separate page
- **Form Inputs:** none · **Validation:** none
- **Loading:** skeleton · **Empty:** "No bookings yet" + Search tours · **Error:** retry
- **Success:** n/a · **Dialogs:** none · **Offline:** last list labelled stale only if caching is approved; none invented
- **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y; status = icon + text
- **Reusable / Unique:** NEW_SHARED `BookingCard` (reused by Operator #84 with a different data shape)
- **Visual Tokens:** C-TOKENS
- **Context In:** none · **Context Out:** `bookingId`
- **Backend Readiness (C-BE):** A user from token · B bookings · C none · D Backend · E page/limit · F none · G status · H newest first (BE) · I 401/5xx · J JWT · K own bookings · L none · M `/traveler/bookings` · N none · O NO · P **list endpoint** · Q all · R retry reads · S pull-to-refresh · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `BOOKING_LIST_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep Link:** none
- **Demo / Production Boundary:** `PENDING_INTEGRATION_STATE` until BE exists
- **Design-only Assumptions:** filter set · **Implementation Notes:** keep tab placeholder honest meanwhile
- **Non-goals:** invoices export
- **Acceptance Criteria:** AC1 no fabricated bookings; AC2 empty ≠ error; AC3 status never colour-only; AC4 pending-payment items offer resume.

### S-69 Booking Details & QR E-ticket

- **Screen Index:** 69 · **UC:** UC-29 (+ UC-70/71 outcome surface, UC-33 entry) · **Name:** Booking Details & QR E-ticket · **Role:** Traveler · **Platform:** SHARED (display on both; scanning is Operator-only)
- **Presentation Type:** FULL_PAGE · **Route:** `/traveler/bookings/:bookingId` PROPOSED · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL · **Contract:** `BOOKING_DETAIL_AND_TICKET_CONTRACT_MISSING`
- **Previous:** #68/#67 · **Next:** #70 cancel · **Alternatives:** review (#74 after trip), payment (#67)
- **Entry Points:** list, payment result, notification · **Entry Conditions:** owner · **Exit:** back
- **User Goal:** see my booking and show my ticket at check-in
- **Page Header:** tour title + booking reference (Backend) · **Layout:** status banner, ticket card with QR, trip info, price, actions. Visual reference: `v_i_n_t_dynamic_qr_tripmate_mobile`
- **Sections:** status banner · **QR ticket** · schedule/meeting point · travellers · payment summary · cancellation/refund state · actions
- **Components:** NEW_SHARED `QrTicketCard` (renders Backend payload with `qr_flutter`), `StatusBadge`, `PriceText`, `AppAlert`
- **Ticket states (Backend-owned):** `Not issued` (e.g. awaiting payment) · `Valid` · `Used` · `Cancelled/Refunded` · `Expired` · `Unknown`. The QR is shown **only** in `Valid` with a Backend-provided payload; otherwise an explanatory panel. **Dynamic/rotating QR behaviour (Stitch shows "dynamic QR") is a Backend decision `SRS_TEXT_REQUIRED`; the client may only re-fetch the payload, never generate one**
- **Primary Action:** show QR / pay now (pending) · **Secondary:** Cancel booking (#70, if allowed), Write review (after trip)
- **Displayed Data:** all `BACKEND_SUPPORT_REQUIRED`; refund progress for UC-71 appears here as status text
- **Form Inputs / Validation:** none
- **Loading:** skeleton · **Empty:** n/a · **Error:** 403/404 non-retry; ticket fetch failure → retry, QR hidden
- **Success:** n/a · **Dialogs:** #70
- **Offline State:** whether a ticket may be shown offline is `SRS_TEXT_REQUIRED`; until decided, offline shows last Backend payload only if caching is approved (none invented), else "Connect to load your ticket"
- **Permission State:** none (screen brightness helpers are an optional enhancement, not required)
- **Responsive / Accessibility:** C-RESP, C-A11Y; QR has a text alternative (booking reference); not colour-only status
- **Reusable / Unique:** NEW_SHARED `QrTicketCard`, `BookingCard` style
- **Visual Tokens:** C-TOKENS
- **Context In:** `bookingId` · **Context Out:** `bookingId`, tourId for review
- **Backend Readiness (C-BE):** A `bookingId` · B booking, payment state, ticket payload/state, refund state · C cancel (via #70) · D Backend · E–H none · I 401/403/404/5xx · J JWT · K owner · L none · M `/traveler/bookings/:id` · N offline ticket policy undefined · O NO · P **detail + ticket + refund-state read** · Q ticket state names · R retry reads · S pull-to-refresh re-reads ticket · T **ticket payload is sensitive**: not logged, not screenshot-cached by the app · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `BOOKING_DETAIL_AND_TICKET_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep Link:** `/traveler/bookings/:id` (payment return, push) once link handling exists
- **Demo / Production Boundary:** no sample QR in production
- **Design-only Assumptions:** ticket card layout
- **Implementation Notes:** UC-70/71 results show here (see `06` §UC-70/71)
- **Non-goals:** transferring tickets
- **Acceptance Criteria:** AC1 QR only from Backend payload in `Valid`; AC2 no local ticket construction; AC3 refund/cancel state shown from Backend; AC4 status not colour-only; AC5 payload never logged.

### S-70 Confirm Cancellation Modal

- **Screen Index:** 70 · **UC:** **no Traveler "cancel booking" UC exists in the catalogue** (UC-41 = Operator cancels; UC-70 = automatic). `SRS_TEXT_REQUIRED` / conflict C-6 in `00` · **Name:** Confirm Cancellation Modal · **Role:** Traveler · **Platform:** SHARED
- **Presentation Type:** MODAL on #69 · **Route:** none · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **Permission:** FULL (conditional on SRS) · **Contract:** `TRAVELER_BOOKING_CANCELLATION_CONTRACT_MISSING`
- **Previous:** #69 · **Next:** #69 refreshed · **Alternatives:** keep booking
- **Entry Points:** Cancel on a cancellable booking · **Entry Conditions:** Backend marks it cancellable · **Exit:** cancelled/kept
- **User Goal:** cancel knowing the refund consequence
- **Page Header:** "Cancel this booking?" · **Layout:** dialog with policy + refund preview + buttons
- **Sections:** cancellation policy (Backend), **refund amount preview from Backend** (never computed on device), reason (if SRS requires)
- **Components:** `ConfirmationDialog`, `PriceText`
- **Primary Action:** Confirm cancellation (destructive) · **Secondary:** Keep booking
- **Loading/Error/Success:** C-STATE; success only after Backend confirms; refund is a *process*, shown as pending until Backend states otherwise
- **Offline:** disabled · **Permission:** none · **Responsive / Accessibility:** C-RESP, C-A11Y
- **Context In:** `bookingId` · **Context Out:** none
- **Backend Readiness (C-BE):** A `bookingId` · B policy + refund preview · C cancel · D Backend · I 401/403/409 (not cancellable)/5xx · J JWT · K owner · O **NO** · P **whole capability** · R no auto-retry; re-read before retry · T none · U Backend; E–H, L, M, N, Q, S: none
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRAVELER_BOOKING_CANCELLATION_CONTRACT_MISSING`
- **Demo / Production Boundary:** hidden until capability and SRS rule exist
- **Non-goals:** partial cancellation (unspecified)
- **Acceptance Criteria:** AC1 refund preview from Backend only; AC2 success only after Backend; AC3 hidden when not cancellable; AC4 destructive action labelled.
