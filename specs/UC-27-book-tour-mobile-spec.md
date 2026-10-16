# UC-27 Mobile Specification — Book Tour

**Feature:** UC-27 Book Tour  
**Platform:** Mobile / Flutter  
**Status:** Draft — awaiting team approval  
**Contract basis:** SRS 3.5.4 + Backend UC-27 API (to be confirmed)

---

## 1. Purpose

UC-27 lets an authenticated Traveler create a booking for a selected departure schedule of a tour package by entering participant information, optionally applying a voucher, and confirming the total amount computed by TripMate.

---

## 2. Scope & Exclusions

### Supported

- Traveler only (authenticated, Active account)
- Entering participant details (name, DOB, identity doc, phone)
- Contact information (name, email, phone)
- Voucher code application/removal
- Booking creation with Pending Payment status
- 15-minute payment expiry timer

### Out of scope (separate UC)

- **Payment processing** → UC-28 Make Electronic Payment
- **E-ticket display** → UC-29 View QR E-ticket
- Tour Operator or Administrator roles
- Inventory management (Backend only)

---

## 3. User Flow

```text
Tour Search/Details
  ↓
[Book Now] for a Departure Schedule
  ↓
Tour Booking Screen
  ├─ Display: Tour Name, Dates, Price/pax, Remaining Slots
  ├─ Input: Number of Participants (1..)
  ├─ Input: Participant details × N (Name, DOB, ID, Phone)
  ├─ Input: Contact details (Name, Email, Phone)
  ├─ Optional: Voucher code + [Apply]/[Remove]
  └─ Display: Price Breakdown (Subtotal, Discount, Total)
  ↓
[Confirm Booking]
  ├─ Confirmation dialog (per CR-05)
  ├─ Revalidate capacity
  ├─ Check concurrent unpaid bookings limit
  └─ Create booking → Pending Payment
  ↓
Success → MSG79 + Payment Screen (UC-28)
OR Error → Safe feedback, form retained
```

---

## 4. Backend API Contract

### Create Booking Request

```http
POST /api/v1/traveler/tour-bookings
Authorization: Bearer <access-token>
Content-Type: application/json
```

**Request body** (exact field names per Backend spec — TBD):

```json
{
  "tourScheduleId": 123,
  "numberOfParticipants": 2,
  "participants": [
    {
      "fullName": "John Doe",
      "dateOfBirth": "1990-01-15",
      "identityDocumentNumber": "123456789",
      "phoneNumber": "+84912345678"
    },
    {
      "fullName": "Jane Doe",
      "dateOfBirth": "1992-06-20",
      "identityDocumentNumber": "987654321",
      "phoneNumber": "+84987654321"
    }
  ],
  "contactInformation": {
    "fullName": "John Doe",
    "email": "john@example.com",
    "phoneNumber": "+84912345678"
  },
  "voucherCode": "SUMMER2026"
}
```

**Response** (successful booking created):

```json
{
  "bookingId": 456,
  "bookingCode": "BK20261015001",
  "status": "PendingPayment",
  "tourName": "Hanoi City Tour",
  "departureDate": "2026-10-20",
  "returnDate": "2026-10-22",
  "numberOfParticipants": 2,
  "subtotalAmount": 2000000,
  "discountAmount": 200000,
  "totalAmount": 1800000,
  "currency": "VND",
  "paymentExpiryTime": "2026-10-15T10:30:00Z",
  "appliedVoucher": {
    "code": "SUMMER2026",
    "discount": 200000
  }
}
```

### Error Responses (HTTP 400/403/422)

Per SRS §3.5.4 Validation:

| Code | Condition | Safe message | Field-targeted? |
|------|-----------|--------------|-----------------|
| `TOUR_BOOKING.INVALID_FIELD` | Required field empty | "Please fill in all required fields" | Yes (via fieldErrors) |
| `TOUR_BOOKING.INVALID_PARTICIPANT` | DOB/ID format wrong | "Participant information is invalid; check date of birth and ID number" | Yes (participant index in errors) |
| `TOUR_BOOKING.CAPACITY_INSUFFICIENT` | Participants > remaining slots | "Not enough slots available for this departure" | Generic |
| `TOUR_BOOKING.TOUR_UNAVAILABLE` | Schedule no longer available | "This tour departure is no longer available" | Generic |
| `TOUR_BOOKING.VOUCHER_INVALID` | Code invalid, expired, or exhausted | "Voucher code is invalid, expired or fully used" | Generic |
| `TOUR_BOOKING.VOUCHER_MIN_SPEND` | Subtotal < minimum | "This voucher requires a minimum purchase of {amount}" | Generic |
| `TOUR_BOOKING.MAX_CONCURRENT_BOOKINGS` | Too many unpaid bookings | "You have too many pending bookings; please complete payment or cancel one" | Generic |
| `401` | Unauthorized (token expired) | "Please sign in again" | Generic → triggers sign-in |
| `403` | Non-Traveler role | "This action is only available to Traveler accounts" | Generic |
| `5xx` | Server error | "Something went wrong; please try again later" | Generic |

---

## 5. Data Model

### Domain Entities

```
TourBooking
├─ bookingId: int
├─ bookingCode: String
├─ status: BookingStatus (enum: PendingPayment, Confirmed, Cancelled, Expired)
├─ tourScheduleId: int
├─ numberOfParticipants: int
├─ participants: List<Participant>
├─ contactInformation: ContactInfo
├─ subtotalAmount: int (VND)
├─ discountAmount: int (VND)
├─ totalAmount: int (VND)
├─ appliedVoucher: Voucher? (null = no voucher)
└─ paymentExpiryTime: DateTime

Participant
├─ fullName: String
├─ dateOfBirth: DateTime
├─ identityDocumentNumber: String
└─ phoneNumber: String

ContactInfo
├─ fullName: String
├─ email: String
└─ phoneNumber: String

Voucher
├─ code: String
├─ discount: int (VND)
```

---

## 6. UI Requirements

### Screen Layout

**Tour Booking Screen** (`TourBookingPage`)

```
┌─────────────────────────────────┐
│ Tour Summary Area               │ (non-editable)
│ ├─ Tour Name                    │
│ ├─ Departure Date               │
│ ├─ Return Date                  │
│ ├─ Price per Participant (VND)  │
│ └─ Remaining Slots              │
├─────────────────────────────────┤
│ Number of Participants: [  1  ] │ (spinner/picker, min 1)
├─────────────────────────────────┤
│ Participant Information         │ (repeat 1..N based on count)
│ ┌─────────────────────────────┐ │
│ │ Participant #1              │ │
│ │ Full Name:        [ input ] │ │
│ │ Date of Birth:    [ picker] │ │
│ │ Identity Doc:     [ input ] │ │
│ │ Phone Number:     [ input ] │ │
│ │ [Remove Participant]        │ │ (if N > 1)
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ Contact Information             │
│ Full Name:        [ input ]     │
│ Email:            [ input ]     │
│ Phone Number:     [ input ]     │
├─────────────────────────────────┤
│ Voucher Code                    │
│ Code:        [ input ] [Apply]  │
│ (if applied) "SUMMER2026" -X    │ (with remove button)
├─────────────────────────────────┤
│ Price Breakdown                 │
│ Subtotal:  {N} × {price}  VND   │
│ Discount:  -{discount}    VND   │
│ ─────────────────────────────   │
│ Total:            {total}  VND  │
├─────────────────────────────────┤
│ [ Confirm Booking ]   [ Cancel] │
└─────────────────────────────────┘
```

### Validation & Feedback

- **Real-time:** DOB picker (constraint: < today), identity doc format
- **On blur:** Phone number format (detect +84/0xxx/+xxx)
- **On Apply Voucher:** Backend validation → field error or success message
- **On Confirm:** Validate all required fields → show errors inline, disable submit while loading
- **Confirmation Dialog:** Standard (per CR-05) before final submission

---

## 7. Accessibility & Localization

- All dates in local timezone (Vietnam)
- Price in VND (no currency symbol elsewhere)
- Form labels in Vietnamese (UI resource strings)
- Keyboard type hints (number pad for phone, date picker for DOB)

---

## 8. Success Criteria

1. ✅ Screen loads with tour details and remaining slots
2. ✅ Participant count drives dynamic form fields (add/remove)
3. ✅ All required fields validated before submission
4. ✅ Voucher code applied/removed with correct discount
5. ✅ Price breakdown recomputed whenever participants or voucher changes
6. ✅ Booking created → MSG79 + payment screen opens (UC-28 entry)
7. ✅ Errors mapped to safe feedback, form retains user input
8. ✅ 401 → sign-in; 403 → role message
9. ✅ No preference data (user details) cached to SharedPreferences
