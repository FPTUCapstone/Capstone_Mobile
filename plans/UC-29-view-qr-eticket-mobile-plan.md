# UC-29 View QR E-ticket — Mobile implementation plan

Spec: `specs/UC-29-view-qr-eticket-mobile-spec.md` (M1–M3). Contract: `Capstone_BE/docs/UC-29-api-contract.md`.
Branch: `feature/uc29-view-qr-eticket` from `develop` @ `deda8e6`.
Status: **Approved 2026-10-25; in progress.**

## 0. Ground rules

- TDD per `AGENTS.md`; one task at a time with a spec and a quality self-review between tasks.
- Mirror `lib/features/trip_history` (repository over `DioClient`, Cubit, `serviceLocator`, English resource
  strings). No new package: `qr_flutter`, `connectivity_plus` (`NetworkInfo`), `flutter_bloc`, `go_router` exist.
- Baseline `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` before Task 1.

## 1. Tasks

### Task 1 — Domain and JSON parser
- Files: `lib/features/e_ticket/domain/entities/e_ticket.dart`, `.../domain/entities/e_ticket_failure.dart`,
  `.../data/models/e_ticket_json.dart`; tests `test/features/e_ticket/data/e_ticket_json_test.dart`.
- Tests first: the contract example parses; `qr: null`, missing meeting point and `checkedInAtUtc` accepted;
  unknown status, missing required field, non-object `qr` rejected; dates parsed as UTC.

### Task 2 — Repository and use cases
- Files: `.../domain/repositories/e_ticket_repository.dart`, `.../domain/usecases/get_e_ticket_use_case.dart`,
  `.../domain/usecases/refresh_e_ticket_qr_use_case.dart`, `.../data/repositories/e_ticket_repository_impl.dart`;
  tests `test/features/e_ticket/data/e_ticket_repository_impl_test.dart`.
- Tests first: exact paths and verbs for the three calls; each `errorCode`/status maps to its failure,
  `not_refreshable` carries `ticketStatus`; network and invalid body → `system`.

### Task 3 — Cubit
- Files: `.../presentation/cubit/e_ticket_cubit.dart`, `e_ticket_state.dart`; tests `test/features/e_ticket/presentation/e_ticket_cubit_test.dart`.
- Tests first: load success / each failure; refresh success replaces the ticket; `not_refreshable` re-reads;
  other failure re-reads and, if that fails, keeps the previous ticket with a stale-QR warning and MSG127;
  connectivity changes toggle `canRefresh`; the cubit never persists anything.

### Task 4 — Page, strings and routes
- Files: `.../presentation/pages/e_ticket_page.dart`, `.../resources/e_ticket_en.dart`, `lib/app/router/app_routes.dart`,
  `lib/app/router/app_router.dart`, `lib/core/di/service_locator.dart`; widget tests
  `test/features/e_ticket/presentation/e_ticket_page_test.dart`.
- Tests first: each status shows chip, message and QR visibility; `QrImageView` gets exactly `qr.content`;
  refresh asks for confirmation and is disabled offline; error views per spec §4; small-screen layout does not overflow.

### Task 5 — Entry points and removal of the client-built QR
- Files: `lib/features/trip_history/presentation/pages/trip_history_page.dart` (open the ticket route, drop
  `_showEticketNotice` and its string), `lib/features/payment/presentation/pages/payment_page.dart` (M2),
  `lib/features/traveler/presentation/widgets/traveler_bookings_view.dart` and delete
  `lib/features/traveler/presentation/widgets/booking_qr_ticket_dialog.dart` (M3); update affected tests.
- Tests first: Trip History [View E-ticket] navigates to `/traveler/tickets/{ticketId}`; the paid view shows
  [Xem vé điện tử] to `/traveler/bookings/{bookingId}/ticket` and does not navigate home after the old countdown;
  no `TRIPMATE_TICKET` string remains (`grep` check).

### Task 6 — Full validation
- `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`;
  `flutter build apk --debug` if the environment allows. Manual run against the BE branch on an emulator,
  scanning the QR with a phone camera.

## 2. Risks

| Risk | Mitigation |
| --- | --- |
| Countdown removal changes UC-28 behaviour reviewers expect | Approved as M2; called out in the PR. |
| Emulator cannot reach the local BE | Use the existing `API_BASE_URL` dart-define documented in the README. |

## 3. Implementation notes (2026-10-25)

Tasks 1–5 implemented test-first; each task's tests, `dart format` and `flutter analyze` were clean before the next.

| # | Deviation | Reason |
| --- | --- | --- |
| N1 | Failures use a feature type `ETicketFailure(kind, ticketStatus)`, not the core `Failure`. | The core `Failure` hierarchy is `sealed`, so a feature cannot extend it. |
| N2 | The QR is drawn by a small `ETicketQrCode` widget around `QrImageView`. | `QrImageView` keeps its data private; the widget's public `content` lets tests prove the QR gets exactly `qr.content`. |
| N3 | `ETicketCubit.start()` loads the ticket and checks connectivity in parallel; a failed check counts as online. | The route test showed a hanging connectivity check (no plugin) kept the screen loading forever; connectivity only gates Refresh. |
| N4 | In demo mode Trip History shows a notice instead of opening the ticket (`noticeEticketDemo` replaces `noticeEticketPending`). | Demo records carry made-up ticket ids that must never reach the ticket API, as `_openRefund` already does. |
| N5 | The payment success view shows [Xem vé điện tử] only for a positive numeric booking id; [Quản lý chuyến đi] became an outlined secondary action. | The route takes an `int`; one primary action per screen. |
| N6 | The ticket page uses `SingleChildScrollView` + `Column`. | `ListView` built off-screen rows lazily; the page is short. |
| N7 | `pubspec.lock` is not part of the change. | `flutter pub get` on this machine resolves older dev packages (local SDK); unrelated to UC-29. |
