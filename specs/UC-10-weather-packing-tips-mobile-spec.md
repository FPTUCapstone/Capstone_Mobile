# UC-10 Mobile: weather packing tips on the itinerary detail page

Follows `Capstone_BE/specs/UC-10-weather-packing-tips-spec.md` (BE PR #204) and the Web spec
`Capstone_FE/specs/UC-10-weather-packing-tips-web-spec.md` (FE PR #196). Same contract, same rules, same copy.
Status: approved by the developer on 2026-11-24 (card right after `ItineraryCostSummary`, copy and contract identical to the Web).

## Intent
A traveler who planned a day sees, on the itinerary detail page, what to bring because of that day's weather. Mobile
only shows what the backend sends; it never works out or guesses weather.

## Contract (backend spec section 4)
`GET /api/v1/itineraries/{id}/weather-tips`, Traveler token. Body is `{ "weatherTips": null }` or
`{ "weatherTips": { "date": "2026-11-25", "timeZoneId": "Asia/Ho_Chi_Minh", "forecastAtUtc": "...",
"summary": { "minTempC": 22, "maxTempC": 31, "maxRainProbabilityPercent": 60, "maxUvIndex": 8 },
"tips": [ { "code": "weather_tip.rain", "severity": "Info", "text": "Mang ô hoặc áo mưa" } ] } }`.
`severity` is `Info` or `Warning`; `tips` may be empty. The endpoint is not deployed yet, so Mobile is built and tested
against this contract with fakes, and the product code has no fake fallback.

## Rules
| # | Rule |
|---|---|
| M1 | The detail loads exactly as today. The weather request starts after the itinerary has loaded, is never awaited by the page, and never changes or delays it. |
| M2 | The card shows only for a valid, complete answer. It is hidden while loading, on `weatherTips: null`, on any HTTP or network error, on a timeout and on a body that does not match the contract. No message, skeleton or retry button. |
| M3 | One request per itinerary id per page visit. An edit, an undo, a regenerate or the UC-10 explanation refresh reloads the detail but does not ask for the weather again. Leaving the page drops the answer. |
| M4 | The card shows the backend's `text` unchanged and in the received order; it does not translate by `code`, reorder, or add tips. |
| M5 | The card is read-only: no buttons, no dialogs, nothing stored on the device. |

## What the traveler sees
In `ItineraryDetailPage`, right after `ItineraryCostSummary` (so after the map and the cost line, above the stops):

```
 ┌───────────────────────────────────────────────┐
 │ ☀ Thời tiết ngày 25/11                         │
 │ 22–31°C · Mưa tối đa 60% · UV 8               │
 │ ⚠ Có dông hoặc mưa to, cân nhắc đổi sang ...  │  Warning: warning tokens
 │ • Mang ô hoặc áo mưa                           │
 └───────────────────────────────────────────────┘
```
- Title `Thời tiết ngày dd/MM` from `date` by splitting the string (never through `DateTime`, so the day cannot shift).
  Summary line `22–31°C · Mưa tối đa 60% · UV 8` (en dash). No tips: `Thời tiết thuận lợi, không cần chuẩn bị đặc biệt.`
- A Warning tip has a warning icon and the theme's `tmColors.warning` / `warningContainer`, so it is not told apart by
  colour alone. Info tips use a plain bullet and the default text style. Material 3 `Card`, `AppSpacing` tokens,
  text wraps (long tips, small screens, large font scale), `Semantics` label `Gợi ý theo thời tiết`.

## Scope (feature-first, `lib/features/traveler`)
- Domain: entity `ItineraryWeatherTips` (+ summary, tip, `WeatherTipSeverity { info, warning }`); `ItineraryRepository`
  gets `Future<ItineraryWeatherTips?> getWeatherTips(int itineraryId)`, default `async => null` ("not available").
- Data: `ItineraryWeatherTipsModel.tryParse(Object? json) -> ItineraryWeatherTipsModel?` (strict: wrong type, unknown
  severity, bad date format or missing field gives `null`); `ItineraryRepositoryImpl.getWeatherTips` calls the endpoint
  through the existing `DioClient` and returns `null` for any non-200, `DioException`, timeout or parse failure. It never
  throws and never puts HTTP details in a message.
- Presentation: `ItineraryWeatherTipsCubit` (states: not requested / loaded with tips; `load(id)` is ignored when that id
  was already requested) owned by `_ItineraryDetailPageState`, built from an optional injected repository like the
  page's `_routeCubit` is built from `directionsRepository`, so existing page tests need no change. The page calls it
  once, when `ItineraryDetailCubit` first reports `loaded` for the itinerary. Widget `ItineraryWeatherTipsCard`.
- Tests: model (valid, empty tips, each malformed case, `weatherTips: null`); repository (200, null body, 401/403/404/500,
  timeout, connection error, malformed JSON, path and bearer from the existing client); cubit with `bloc_test` (requests
  once per id, null answer, repository throws -> still no card); card widget (title, summary, order, Warning vs Info,
  empty sentence, text wraps at 2.0 font scale, semantics label); page (card between cost summary and stops; absent on
  `null`, on failure and while pending; page still works and offers edit; the weather call is not repeated after an edit).
- Checks before reporting done: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`,
  `flutter test`. `pubspec.lock` may be rewritten by `pub get`; it is not part of this change and is not committed.

## Not in scope
Per-stop tips; the active-trip page and UC-14 weather alerts (they use their own data); the offline itinerary and
offline package pages; the My Trips list; English text; changing the plan because of weather; the backend flag
(`WeatherTips__Enabled`), which the developer turns on after BE #204 is merged.

## Open points
1. Placement is my proposal: after the cost summary. Tell me if you prefer it above the map.
2. Same copy as the Web (decided 2026-11-24): the empty sentence and the labels above.
3. Until BE #204 is merged and the flag is on, the endpoint gives `null` or 404, so the card never shows on a real
   device; verification is by tests with fakes only.