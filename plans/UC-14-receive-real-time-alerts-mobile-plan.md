# UC-14 Receive Real-Time Alerts — Mobile Implementation Plan

## Status

Approved by the user on 2026-10-22. It implements
[`../specs/UC-14-receive-real-time-alerts-mobile-spec.md`](../specs/UC-14-receive-real-time-alerts-mobile-spec.md),
which is derived from the approved cross-repository contract.

Repository: `Capstone_Mobile`. Start after Backend OpenAPI for list, acknowledgement, advisories,
deviation and device registration is stable. Do not commit, push, open a PR or deploy without an
explicit request.

## Dependency order

`M0 → M1 → M2 → M3 → M4 → M5`. M1–M3 can be integrated against fixture DTOs while Backend is under
development; replace fixtures only after the OpenAPI contract is accepted.

## Tasks

### M0 — Baseline and production seam

Inspect and baseline:

- `lib/features/traveler/domain/entities/trip_alert.dart`
- `lib/features/traveler/presentation/cubit/active_trip_cubit.dart`
- `lib/features/traveler/presentation/cubit/active_trip_state.dart`
- alert banner/sheet/page and demo fixtures
- `lib/features/traveler/data/repositories/navigation_session_repository_impl.dart`
- `lib/core/di/service_locator.dart`, router and authentication logout flow

Record the current off-route transition seam and verify demo alerts do not leak into production.
Run `flutter analyze` and `flutter test` for a clean baseline.

### M1 — Alert and advisory data layer

Add focused DTOs/data source/repository/use cases under `lib/features/traveler/` for list,
acknowledgement, current advisories and deviation submission. Extend `TripAlert` with server identity,
message code, read/resolved state and optional proposal ID. Keep advisory as a separate domain type so
it cannot enter persisted history accidentally.

Add mapping tests for every type, nullable description/proposal/resolution, UTC parsing, unknown enum
failure/fallback policy and Backend error mapping. Use OpenAPI fixture JSON.

### M2 — Production alert state and UI

Connect `ActiveTripCubit` to alert/advisory use cases and replace production demo fallback. Update:

- `active_trip_page.dart`
- `trip_alert_banner.dart`
- `trip_alerts_sheet.dart`
- `trip_alerts_page.dart`
- `app_router.dart` as needed for alert detail/deep links

Implement newest unread banner, local dismissal, server acknowledgement on detail open, resolved
history, empty/loading/error states, once-per-session advisory keys and conditional UC-15 action.
Add Cubit/widget tests for the state transitions rather than snapshots of static markup.

### M3 — Refresh and deviation integration

Refresh alerts/advisories when the active session loads, app resumes and connectivity returns. Wire
the existing UC-13 on-route → off-route transition to one deviation submission with UUID and UTC
timestamp. Reuse the UUID only for transport replay; on `429`, stop automatic retry and respect the
response for user feedback/telemetry. Test duplicate incidents, reconnect and no-coordinate payloads.

### M4 — Firebase Messaging and device lifecycle

Add `firebase_messaging` to `pubspec.yaml` and configure platform files using the existing Firebase
project. Add a messaging service/data source, installation-ID storage through the current secure
storage service, and Backend register/remove calls. Register dependencies in
`lib/core/di/service_locator.dart` and connect login/logout/token-refresh lifecycle.

Implement foreground refresh/banner, background notification tap and cold-start deep link. Treat push
payload as a hint, then load server state. Test service logic with fakes; verify operating-system
delivery on a real Android device. Never log tokens.

### M5 — Verification and review

Run:

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

Complete a cross-module check with Backend fixtures for all four incident types, moderate-rain
advisory, read/resolved history, duplicate push, permission denial, token rotation/logout, missed-push
recovery, deviation replay and `429`. Review the diff against both repository specs.

## Delivery slices

1. Server-backed list, detail and acknowledgement.
2. Active banner and transient weather advisory.
3. Deviation submission from the existing UC-13 detector.
4. Device registration and Firebase Messaging.

The first slice remains useful without FCM because the server Alerts list is the recovery path.
