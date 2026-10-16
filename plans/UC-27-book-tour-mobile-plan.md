# UC-27 Mobile Implementation Plan — Book Tour

**Feature:** UC-27 Book Tour
**Platform:** Mobile / Flutter
**Status:** Draft — execute only after specification approval
**Specification:** `specs/UC-27-book-tour-mobile-spec.md`

---

## 1. Delivery Boundary

This plan implements the Traveler booking flow from tour selection through booking creation with Pending Payment status. It does **not** include:
- Payment processing (UC-28 — separate feature)
- E-ticket display (UC-29 — separate feature)
- Tour Operator or Administrator booking management

The Backend is assumed to provide:
- Validated tour schedules and remaining slots
- Participant data validation rules
- Voucher eligibility and discount computation
- Booking creation with auto-generated booking code

---

## 2. Preconditions — BLOCKERS MUST BE RESOLVED FIRST

### ⚠️ CRITICAL BLOCKERS

1. **[P1] Backend API Contract Not Confirmed**
   - `POST /api/v1/traveler/tour-bookings/quote` endpoint (price preview)
   - `POST /api/v1/traveler/tour-bookings` endpoint (create booking)
   - Request/response field names (currently TBD)
   - Error codes mapping to SRS messages (MSG65, MSG77, MSG78, MSG101, MSG102, MSG126, MSG127)
   - **⚠️ DO NOT CODE until Backend confirms.**

2. **[P1] Domain Model Separation**
   - Current plan: `TourBooking` mixes **input** (participant details) with **server-computed response** (bookingId, status, total, expiry)
   - **Fix required:** Separate into:
     - `BookingDraft` (domain entity for form input: tourScheduleId, participants, contactInfo, voucherCode)
     - `TourBooking` (response entity from server: bookingId, bookingCode, status, total, expiry, appliedVoucher)
   - This prevents client from ever submitting or trusting client-computed amounts (BR-63).

3. **[P1] Price Computation BR-63 Violation**
   - Current plan: Cubit computes `subtotal = participants × schedulePrice`, `total = subtotal - discount`
   - **SRS BR-63:** Backend computes unit price, discount, total; **client never computes or trusts client values.**
   - **Fix required:** Add API call to `POST /api/v1/traveler/tour-bookings/quote` whenever participants or voucher changes, receive server-computed amounts (read-only display only).
   - Cubit stores `quoteResponse` with total/discount, never computes them.

4. **[P1] Missing Idempotency-Key**
   - Booking creation holds slots and creates payment obligation (critical operation).
   - Network retry or app relaunch could create duplicate bookings.
   - **Fix required:** Generate UUID on form load (`Idempotency-Key` header), reuse on all retry attempts.
   - Disable [Confirm] button, show "Creating booking..." while in flight.

### Important (P2)

5. **[P2] 401 Session Handling**
   - Plan incorrectly says "Cubit emits `requiresSignIn`" like UC-09 old code.
   - **Actual pattern in UC-09 now:** `AuthInterceptor` + `SessionCoordinator` refresh token once; if fails, sign out.
   - **Fix required:** Don't handle 401 in Cubit—let `AuthInterceptor` do it. Cubit receives `AuthenticationFailure` only on actual failure after refresh, which triggers sign-out via `AuthSessionCubit`.

6. **[P2] Error Code / Message Alignment**
   - Spec lists made-up codes (`TOUR_BOOKING.CAPACITY_INSUFFICIENT`); Backend will use different codes.
   - **Fix required:** After Backend API confirmed, map Backend codes → SRS message keys (MSG65, MSG77, etc.) → localized strings.

7. **[P2] Language (English, not Vietnamese)**
   - Spec incorrectly says "Form labels in Vietnamese"; system UI is all English.
   - **Fix required:** All UI strings in English (follow existing codebase pattern; app has no i18n).

### Prerequisites (if not already done)

- Confirm tour detail/schedule pages exist and can pass `tourScheduleId` to booking flow
- Verify Idempotency-Key header is not already present (some HTTP clients add it automatically)
- Check existing `AuthInterceptor` pattern in `DioClient`

### Baseline (safe to run now)

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

**⚠️ DO NOT START TASK 1 UNTIL BLOCKERS 1–4 ARE RESOLVED AND CONFIRMED WITH BACKEND.**

---

## 3. Task 1 — Domain Models & Repository

**Files:**
- `lib/features/traveler/domain/entities/booking_draft.dart` (form input)
  - tourScheduleId, numberOfParticipants, participants, contactInfo, voucherCode
  - **Never contains:** bookingId, status, total, expiry (those come from server only)
- `lib/features/traveler/domain/entities/tour_booking.dart` (server response)
  - bookingId, bookingCode, status, total, subtotal, discount, appliedVoucher, paymentExpiryTime
  - **Read-only; parsed from server response only**
- `lib/features/traveler/domain/entities/tour_participant.dart`
  - fullName, dateOfBirth, identityDocumentNumber, phoneNumber
- `lib/features/traveler/domain/entities/contact_info.dart`
  - fullName, email, phoneNumber
- `lib/features/traveler/domain/entities/booking_quote.dart`
  - subtotal, discount, total, currency (VND) — **returned by quote API only**
- `lib/features/traveler/domain/repositories/tour_booking_repository.dart`
  - `quoteBooking(tourScheduleId, count, voucherCode) → Future<BookingQuote>` (per BR-63)
  - `createBooking(BookingDraft, idempotencyKey) → Future<TourBooking>`

**RED tests:**
- `BookingDraft`, `TourBooking`, `TourParticipant`, `ContactInfo`, `BookingQuote` with equality, copyWith
- Separation: BookingDraft has **no** status/bookingId/total; TourBooking has **no** participant detail fields
- Repository quote method returns read-only quote
- Repository create method accepts draft + UUID, returns booking
- Fields round-trip correctly (dates, phone, amounts VND)

**Implement:** Plain entities, no JSON knowledge; repository interface only.

---

## 4. Task 2 — Data Models & Authenticated Requests

**Files:**
- `lib/features/traveler/data/models/tour_booking_dto.dart`
- `lib/features/traveler/data/models/tour_participant_dto.dart`
- `lib/features/traveler/data/models/contact_info_dto.dart`
- `lib/features/traveler/data/models/create_tour_booking_request.dart`
- `lib/features/traveler/data/datasources/tour_booking_remote_data_source.dart`
- `lib/features/traveler/data/repositories/tour_booking_repository_impl.dart`

**RED tests:**
- `POST /api/v1/traveler/tour-bookings` sends correct request body (no extra fields, amounts omitted)
- Response parsing: bookingCode, status, totalAmount, appliedVoucher round-trip
- Error mapping: `TOUR_BOOKING.CAPACITY_INSUFFICIENT` → field error in bookings section; `TOUR_BOOKING.INVALID_PARTICIPANT` → participant-indexed error; `401`/`403`/network/`5xx` to shared failures

**Implement:**
- Use centralized `DioClient` (no alternate transport)
- DTOs follow UC-09 model (clean, throws `FormatException` on malformed body)
- Repository maps Backend errors to `ValidationFailure` (with `fieldErrors` map for per-participant errors) or shared failures
- No Backend-specific field names leak into domain layer

---

## 5. Task 3 — Cubit & State

**Files:**
- `lib/features/traveler/presentation/cubit/tour_booking_cubit.dart`
- `lib/features/traveler/presentation/cubit/tour_booking_state.dart`

**RED tests:**
- `load(tourScheduleId)` fetches schedule details and populates state
- `setNumberOfParticipants(int)` dynamically creates/removes participant slots
- `updateParticipant(index, field, value)` updates individual participant data
- `setContactInfo(ContactInfo)` or field-by-field setters
- `applyVoucher(String code)` calls repo, updates `appliedVoucher` and recomputes total
- `removeVoucher()` clears applied voucher and recomputes
- Price breakdown auto-updates whenever participants or voucher changes
- `submit()` validates all fields client-side, calls repo, emits success/error
- Field-targeted errors (e.g., participant[0].name, participant[0].dateOfBirth, contactInfo.email) preserved in state
- `401` → emits state with `requiresSignIn` flag (same as UC-09 pattern)

**Implement:**
- State carries tour schedule, list of participants, contact info, applied voucher, total/subtotal/discount, validation errors, submission status
- Price recalculation logic: `subtotal = participants.length × schedulePrice`, `total = subtotal - discount`, discount from `appliedVoucher?.discount ?? 0`
- Cubit injects through service locator, not constructor

---

## 6. Task 4 — Page & Widgets

**Files:**
- `lib/features/traveler/presentation/pages/tour_booking_page.dart`
- `lib/features/traveler/presentation/widgets/participant_form_section.dart` (or inline)
- `lib/features/traveler/presentation/widgets/contact_info_section.dart` (or inline)
- `lib/features/traveler/presentation/widgets/voucher_section.dart` (or inline)
- `lib/features/traveler/presentation/widgets/price_breakdown_section.dart` (or inline)

**RED tests (widget):**
- Tour summary renders without editable state
- Participant count field allows 1..N input
- Adding N participants renders N form groups with remove buttons (if > 1)
- Date picker for DOB, number pad for phone
- Voucher section shows [Apply]/[Remove] buttons, applied code with discount shown
- Price breakdown updates when participant count or voucher changes
- Required field errors shown inline (per field)
- Participant-specific errors (e.g., "Participant 2: invalid date of birth") shown near that participant's form
- Confirm button disabled while loading, shows loading spinner
- Success shows MSG79 + opens payment screen (or navigates per UC-28 entry)
- Cancel → confirmation dialog, dismisses form
- 401 → triggers sign-in; 403 → shows role message

**Implement:**
- Use `AppPageScaffold` for consistent layout (or `Scaffold` + existing Material 3 theme)
- Keep form state in Cubit, not local widget state (single source of truth)
- Date picker: `showDatePicker()`, validate max-age constraint
- Phone input: format +84xxx... on blur, show error if malformed
- Participant management: dynamic list with add/remove buttons
- Price breakdown section always visible at bottom, updates reactively

---

## 7. Task 5 — DI & Router

**Files:**
- `lib/core/di/service_locator.dart`
- `lib/app/router/app_router.dart`

**Implement:**
- Register `TourBookingRemoteDataSource`, `TourBookingRepositoryImpl`, `TourBookingCubit` in service locator (pattern: existing Traveler repos)
- Router: `/traveler/tours/{scheduleId}/booking` route, create Cubit with `..load(scheduleId)` on entry
- On successful booking, navigate to payment screen (`/traveler/bookings/{bookingId}/payment` for UC-28)

---

## 8. Task 6 — Security & Regression

**Review for:**
- No participant data cached to `SharedPreferences` or logs
- Tour schedule price never trusted from client; always use Backend-computed total
- Voucher discount always from Backend, never client-computed discount
- Booking creation only on explicit [Confirm], after revalidation by Backend
- 401 sign-out behavior consistent with UC-07/UC-09 pattern
- No demo mode; integration is real from start

**Run:**

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

---

## 9. Delivery Gate

Feature ready for review when:

1. ✅ Participant count drives dynamic form fields (add/remove works)
2. ✅ All required fields validated (name, DOB, identity, phone, contact email)
3. ✅ Voucher applied/removed correctly, discount shown
4. ✅ Price breakdown recomputes on participant or voucher change
5. ✅ Booking created → MSG79 + payment screen opens
6. ✅ Field-targeted errors (participant-indexed) shown inline
7. ✅ 401/403/validation/network/5xx errors show safe feedback
8. ✅ No participant data in logs or local storage
9. ✅ Backend always revalidates capacity and computes amounts
