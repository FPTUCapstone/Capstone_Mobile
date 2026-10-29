# UC-14 Receive Real-Time Alerts — Tomorrow.io Mobile Revision

## Status and source

**Approved by user on 2026-10-28 for implementation.** The previous Mobile contract is
preserved at [`../../Capstone_Mobile/specs/UC-14-receive-real-time-alerts-mobile-spec.md`](../../Capstone_Mobile/specs/UC-14-receive-real-time-alerts-mobile-spec.md).
Companion Backend specification lives in the `Capstone_BE_UC14` worktree; the
[Mobile implementation plan](../plans/UC-14-receive-real-time-alerts-mobile-plan.md)
tracks this revision.
Implementation is authorized. No commit or push is authorized.
Weather provider: Tomorrow.io (Backend only). Notification policy: `UC14-2026-10-28-v1`.

## Purpose and boundary

During an active UC-13 trip, Mobile presents TripMate alerts in the navigation UI and alert history,
receives FCM notifications, registers the current device and reports route-deviation transitions.

Mobile does not call Tomorrow.io, decide whether a delay/POI/weather incident exists, upload GPS to
Backend, or change the itinerary. UC-15 owns review and application of a reroute proposal.

## Current code to replace or extend

The repository already contains presentation/demo artifacts:

- `lib/features/traveler/domain/entities/trip_alert.dart`
- `lib/features/traveler/presentation/widgets/trip_alert_banner.dart`
- `lib/features/traveler/presentation/widgets/trip_alerts_sheet.dart`
- `lib/features/traveler/presentation/pages/trip_alerts_page.dart`
- demo fixtures under `lib/features/traveler/presentation/demo/`
- UC-13 state and off-route behavior in `active_trip_cubit.dart` and `active_trip_page.dart`

They are not yet the production Backend contract. Preserve the UI where suitable, but replace demo
data with repository/use-case data and map Backend message codes into localized copy.

## User experience

### Active navigation

- Show the newest unread persisted alert as a banner over the active-trip screen.
- Show a moderate-rain advisory banner for an affected Outdoor stop. If Backend promotes it to a
  persisted `Info` preparation alert within one hour of the visit, render the persisted alert and
  suppress the matching transient advisory banner. Never display both copies.
- For heavy rain at an Outdoor stop, clearly advise postponing/skipping that visit. If that stop is
  still `Pending`, expose the existing UC-13 Skip action with Traveler confirmation; never skip it
  automatically. Show the UC-15 adjustment action only when Backend supplies a valid
  `reroutingProposalId`; do not present a fake alternative.
- Closing a banner hides it locally and does not mark the server alert as read.
- Tapping a persisted alert opens its detail, then acknowledges it through Backend.
- If `reroutingProposalId` is present, show “Xem đề xuất điều chỉnh” and navigate to UC-15. Never
  show a fake/disabled proposal action.
- When an incident resolves, stop active reminders but keep its record in alert history.

### Background and reconnect

- FCM received in background displays the platform notification. Opening it routes to the matching
  trip alert.
- Foreground FCM triggers a refresh and displays the normal in-app banner; do not stack a second
  copy of the same `incidentId`.
- On app resume, restored connectivity and active-trip refresh, fetch alert history and current
  weather advisories. Server state wins over push payload.
- Permission denied or failed FCM delivery never blocks the Alerts list.

## Mobile data contract

Persisted alerts come from:

```http
GET /api/v1/navigation-sessions/{sessionId}/alerts
```

Map `incidentId`, `type`, `severity`, `messageCode`, `description?`, structured affected-item/reason
fields, `detectedAtUtc`, `resolvedAtUtc?`, `isRead` and `reroutingProposalId?`. Weather alerts also
carry `weatherBasis = ForecastAtPlannedTime | CurrentAtDestination | OfficialEvent` and the provider's weather time.
Use Backend `canSkipAffectedStop` together with a locally `Pending` affected item to show the
confirmed Skip shortcut. Rain intensity alone cannot prove a POI is Outdoor because thunderstorm
and extreme-rain warnings may affect Indoor POIs too.
Use `weatherCondition` to distinguish moderate/heavy/extreme rain from thunderstorm in display copy;
unknown legacy weather conditions use neutral wording.
Render “dự báo khi bạn đến” only for the first, “hiện tại tại điểm đến” for the second and source
authority wording for an official event; do not conflate these forms of evidence, and
never claim Backend knows the Traveler's actual arrival time from GPS. Known types are
`WeatherAdvisory`, `SevereWeather`, `ScheduleDelay`, `RouteDeviation` and `POIClosure`. Persisted
`WeatherAdvisory` has `Info` severity; the other persisted incident types use `Warning` in this
release. A moderate-rain preparation push is informational, not an emergency or tour cancellation.

Transient moderate-rain advisories come from:

```http
GET /api/v1/navigation-sessions/{sessionId}/weather-advisories
```

Map `advisoryKey`, `severity = Info`, `messageCode = trip_alert.weather_advisory`,
`affectedItemId`, `forecastAtUtc` and `rainIntensityMmPerHour`. These transient entries are
session-only UI data: do not add them to alert history and do not acknowledge them. The matching
persisted `WeatherAdvisory`, when present, comes from the Alerts endpoint, appears in history and
supports the normal acknowledgement route.

Mark a persisted alert read with:

```http
PUT /api/v1/navigation-sessions/{sessionId}/alerts/{incidentId}/acknowledgement
```

Treat `204` as success. Repeating acknowledgement is safe, including after resolution.

## Localization

Mobile owns display copy. Use `messageCode` and structured fields, with `description` only as optional
source context. Required message codes:

- `trip_alert.weather_advisory`
- `trip_alert.severe_weather`
- `trip_alert.schedule_delay`
- `trip_alert.route_deviation`
- `trip_alert.poi_closure`

Delay copy must say that arrival “has not been recorded on time” and provide the existing UC-13
arrival-confirmation action. It must not claim GPS proves the Traveler is late.

## Route deviation reporting

Keep off-route detection on device in the UC-13 location flow. Send only when state transitions from
on-route to off-route:

```http
POST /api/v1/navigation-sessions/{sessionId}/deviations
Content-Type: application/json

{
  "eventId": "UUID",
  "observedAtUtc": "ISO-8601 UTC",
  "targetItemId": 123
}
```

- Generate one UUID for the transition and keep it for transport replay of that submission.
- Never send coordinates, route geometry, client text or severity.
- A successful replay may return the original incident even after the session ended.
- On `429`, honor `Retry-After` for UI/telemetry but do not run an automatic retry loop for the
  rejected event. A future off-route transition uses a new UUID.
- Backend may return an already-open target incident; render/deduplicate by `incidentId`.
- A second deviation to the same target while the first incident remains open produces no new push.

## Push device lifecycle

Add `firebase_messaging` using the existing Firebase project configuration.

- Generate and persist a random installation UUID in secure local storage; it is stable across
  login/logout for that installation.
- After authenticated login and whenever FCM rotates the token, call
  `PUT /api/v1/me/push-devices/{installationId}`.
- Before logout, call `DELETE /api/v1/me/push-devices/{installationId}` on a best-effort basis, then
  clear authenticated local state according to the current session flow.
- Do not log the FCM token or include it in analytics.
- Account switching on one installation registers the new user; Backend atomically removes the old
  ownership.

Push payload is only a refresh/deep-link hint. Load the alert from Backend before presenting detail.
Deduplicate duplicate FCM deliveries by `incidentId`.

## State and architecture

Follow the existing feature-first Clean Architecture flow:

```text
Page/Widget → Cubit → use case → repository → Dio/Firebase data source
```

Extend the traveler feature with production alert models/repository/use cases. Keep network DTOs out
of widgets. `ActiveTripCubit` coordinates active banner/advisory refresh and deviation submission;
alert history can use a focused Cubit if that keeps state transitions smaller. Register services in
`lib/core/di/service_locator.dart` and routes in the existing app router.

UI state must distinguish loading, refresh failure with existing data, empty history, unread/read,
resolved/current, and locally dismissed banner. A failed acknowledgement remains visible and can be
retried by the user or next refresh.

## Acceptance criteria

- Active-trip banner, alert sheet/page and details render all five types from Backend DTOs, newest
  first, with localized text and affected stop information.
- Banner dismissal is local; detail open acknowledges; resolved history remains readable.
- Moderate rain one to three hours before an Outdoor visit appears only as a transient advisory;
  within one hour Backend may persist one `Info` preparation alert, which appears in history and
  replaces its transient banner. Duplicate FCM/advisory payloads do not stack banners.
- Heavy rain copy advises postponing/skipping the affected Outdoor visit; the existing Skip action
  requires a still-Pending item and confirmation, and a UC-15 proposal appears only when supplied
  by Backend. Weather text uses the affected POI/time and forecast/current basis, not a city-wide
  claim, and never says a booked tour was cancelled by UC-14.
- Resume/reconnect refresh recovers missed push alerts.
- Foreground, background and deep-link paths converge on one server-loaded incident and deduplicate
  repeated push payloads.
- Device registration covers first token, rotation, login, logout, permission denial and account
  switch without exposing raw tokens.
- Off-route reporting sends no GPS, reuses the UUID for transport replay and does not loop on `429`.
- The UC-15 action appears only when a valid proposal ID exists.

## Accepted limitations

- Mobile has no traffic/safety provider in this release.
- Push may arrive late or twice; server history is authoritative.
- No local warning for GPS disabled/offline is added by UC-14.
- A newly registered token does not request old push delivery; history refresh still shows old alerts.
