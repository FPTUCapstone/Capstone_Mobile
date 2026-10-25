# UC-29 View QR E-ticket — Mobile specification

**Status:** Approved 2026-10-25 (developer).
**Platform:** Traveler, Flutter app (SRS §3.5.6: shown on both platforms; on Mobile it is presented to the
Tour Operator for scanning at the meeting point).
**Backend contract:** `Capstone_BE/docs/UC-29-api-contract.md` (BE PR #126), decisions D1–D7.

## 1. Scope

| Entry | Route | Backend call |
| --- | --- | --- |
| Trip History → [View E-ticket] (`actions.ticketId`) | `/traveler/tickets/:ticketId` | `GET /api/v1/traveler/tickets/{ticketId}` |
| Payment success view (`bookingId`) | `/traveler/bookings/:bookingId/ticket` | `GET /api/v1/traveler/bookings/{bookingId}/ticket` |
| [Refresh QR Code] | — | `POST /api/v1/traveler/tickets/{ticketId}/qr-code/refresh` |

Out of scope: UC-43 scanning, persisting the ticket to disk, screen brightness or wake-lock, the demo
Bookings tab beyond M3.

## 2. Confirmed decisions (developer, 2026-10-25)

| ID | Decision |
| --- | --- |
| M1 | QR rendered with the existing `qr_flutter` from the server's `qr.content` only. The app never builds or parses QR content. |
| M2 | The payment success view no longer returns home by itself. Its primary action becomes **[Xem vé điện tử]** (booking route); the existing Trip History and Home actions stay. |
| M3 | `BookingQrTicketDialog` (client-built `TRIPMATE_TICKET:{bookingCode}`) and the "Vé điện tử QR" button of the demo Bookings tab are deleted. The rest of that tab is unchanged. |

## 3. Architecture

New feature `lib/features/e_ticket/` following Page → Cubit → Use case → Repository contract → Repository
implementation (`DioClient`), as `trip_history` does:

- Domain: `ETicket` entity (contract fields; ids `int`, `TicketDisplayStatus`, nullable `qr`), `ETicketRepository`,
  use cases `GetETicket` (by ticket or by booking) and `RefreshETicketQr`, typed failures
  (`signIn`, `forbidden`, `notFound`, `notConfirmed`, `notIssued`, `notRefreshable(status)`, `system`).
- Data: `ETicketJson` parser (strict: unknown status, missing required field or non-object `qr` → invalid
  response), `ETicketRepositoryImpl` mapping `errorCode` to failures.
- Presentation: `ETicketCubit` (load, refresh, connectivity from `NetworkInfo.onConnectivityChanged`) and
  `ETicketPage`; strings in `resources/e_ticket_en.dart` like `trip_history`.
- Registration in `service_locator.dart`; routes in `AppRoutes` / `app_router.dart` under `/traveler/*`.

## 4. Screen

| Area | Content |
| --- | --- |
| Status chip | Not Yet Active / Valid / Used / Cancelled / Expired |
| QR | `QrImageView` of `qr.content`, white background, large enough to scan (≥ 240 dp, scales on small screens); only when `qr` is not null |
| Info | ticket code, booking code, tour, operator, departure (`dd/MM/yyyy HH:mm`, Asia/Ho_Chi_Minh), meeting point (or "Not provided yet"), participants |
| Validity note | departure date from `validity.departureDate` (MSG98 wording) |
| Used | check-in time (MSG95) |
| Message | `Valid` MSG93, `NotYetActive` MSG98, `Used` MSG95, `Cancelled` MSG139, `Expired` MSG140 |

Refresh (contract client rules): confirmation dialog first; button disabled while offline; on success the
QR is replaced; on `ticket.not_refreshable` the ticket is re-read; on other failures the ticket is re-read and,
if that fails too, MSG127 plus a warning that the displayed QR may no longer be valid. The last successful
ticket stays in the Cubit state (memory only) so the QR stays on screen when the connection drops.

Errors: 401 → existing session-expired handling; 403 → MSG126; 404 → not found + back; 409
`booking_not_confirmed` → MSG138; `not_issued`, 5xx, network, invalid response → MSG127 + [Retry].
Safe areas, small screens, long text and loading/error states per `AGENTS.md`.

## 5. Acceptance criteria

1. Trip History [View E-ticket] opens the ticket by `actions.ticketId` (the "pending" SnackBar is gone).
2. The payment success view stays and [Xem vé điện tử] opens the ticket by booking id.
3. The QR encodes exactly `qr.content`; no code in the app builds QR content.
4. Each status shows its chip and message; the QR is hidden for Used / Cancelled / Expired.
5. Refresh follows §4, including offline disabling and the failure path.
6. `BookingQrTicketDialog` and its button no longer exist.
7. `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` pass.
