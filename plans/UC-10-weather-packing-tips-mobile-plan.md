# UC-10 Mobile weather packing tips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Show a read-only "Thời tiết ngày dd/MM" card with the backend's weather tips on the itinerary detail page, hidden whenever the backend has nothing.

**Architecture:** Entity + strict model + a never-throwing repository method (`getWeatherTips`), a small cubit owned by the detail page that asks once per itinerary id after the detail loaded, and a presentational card inserted after `ItineraryCostSummary`.

**Tech Stack:** Flutter, flutter_bloc / bloc_test, Dio (existing `DioClient`), Material 3, `TripMateColors` tokens.

**Spec:** `specs/UC-10-weather-packing-tips-mobile-spec.md` (approved 2026-11-24). Backend contract: `Capstone_BE` PR #204; Web: `Capstone_FE` PR #196.

## Global Constraints
- Feature-first Clean Architecture; pages and cubits never call Dio. No new package, no new route, no storage.
- Run before reporting done, in this order: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. `pubspec.lock` is never committed (restore it with `git checkout -- pubspec.lock` if `pub get` rewrites it).
- Copy (identical to the Web): title `Thời tiết ngày dd/MM`; summary `22–31°C · Mưa tối đa 60% · UV 8` (en dash); empty `Thời tiết thuận lợi, không cần chuẩn bị đặc biệt.`; semantics label `Gợi ý theo thời tiết`.
- The card shows the backend's `text` unchanged, in the received order; it never adds, translates or reorders tips. Date is formatted by splitting `yyyy-MM-dd` (never `DateTime`).
- Warning tip: icon `Icons.warning_amber_rounded` + `context.tmColors.warningContainer` background / `warning` for icon and border; Info tip: bullet, default text style. Decorative icons are excluded from semantics.
- Every failure is silent: the card is hidden, no message, no retry (M2). The repository never throws and never exposes HTTP details.
- Existing page tests must keep passing without edits.

## Review Focus
- A `weatherTips` body with a missing/mistyped field, unknown severity or `date` not `yyyy-MM-dd` must give `null`, not a half card. Task 1 tests.
- Repository must not throw for 401/403/404/500, timeout or connection errors. Task 2 tests.
- The weather request must not repeat after an edit/undo/regenerate/explanation refresh reload the detail (M3). Task 3 and 5 tests.
- Long tip text and font scale 2.0 must wrap, not overflow. Task 4 test.
- The page must still show and allow editing the itinerary when the weather fails or never answers. Task 5 tests.

---

### Task 1: Entity and model

**Files:**
- Create: `lib/features/traveler/domain/entities/itinerary_weather_tips.dart`
- Create: `lib/features/traveler/data/models/itinerary_weather_tips_model.dart`
- Test: `test/features/traveler/data/models/itinerary_weather_tips_model_test.dart`

**Interfaces:**
- Produces (entity, `final class`, `Equatable`, `const` constructors):
  - `enum WeatherTipSeverity { info, warning }`
  - `WeatherTip({required String code, required WeatherTipSeverity severity, required String text})`
  - `WeatherTipsSummary({required int minTempC, required int maxTempC, required int maxRainProbabilityPercent, required int maxUvIndex})`
  - `ItineraryWeatherTips({required String date, required String timeZoneId, required DateTime forecastAtUtc, required WeatherTipsSummary summary, required List<WeatherTip> tips})`
  - getter `String get dayAndMonth` on `ItineraryWeatherTips`: `'25/11'` from `'2026-11-25'` by splitting the string.
- Produces (model): `abstract final class ItineraryWeatherTipsModel { static ItineraryWeatherTips? tryParse(Object? json); }` — takes the whole response body; `null` for `{weatherTips: null}`, a non-map, or anything malformed. Numeric summary fields accept `int` or whole-number `double`; `forecastAtUtc` must parse with `DateTime.tryParse`.

- [ ] **Step 1: Write failing tests**: `parses a full payload`; `parses empty tips`; `accepts whole-number doubles in the summary` (22.0 -> 22); `returns null for weatherTips null / body null / body not a map`; `returns null when summary is missing, a summary field is a string, tips is not a list, a tip lacks text, severity is "Critical", date is "25/11/2026", timeZoneId is not a string, forecastAtUtc is not a date`; `dayAndMonth is 25/11 for 2026-11-25 and 01/12 for 2026-12-01`.
- [ ] **Step 2:** `flutter test test/features/traveler/data/models/itinerary_weather_tips_model_test.dart` — Expected: FAIL (files missing).
- [ ] **Step 3:** Implement entity and `tryParse`.
- [ ] **Step 4:** Same command — Expected: PASS.
- [ ] **Step 5:** Commit `feat(traveler): parse itinerary weather tips (UC-10)`.

### Task 2: Repository

**Files:**
- Modify: `lib/features/traveler/domain/repositories/itinerary_repository.dart`
- Modify: `lib/features/traveler/data/repositories/itinerary_repository_impl.dart`
- Test: `test/features/traveler/data/repositories/itinerary_repository_impl_test.dart` (add a `group('getWeatherTips', ...)`, reusing its `respond`, `_RecordingAdapter`)

**Interfaces:**
- Consumes: `ItineraryWeatherTipsModel.tryParse`.
- Produces: in `ItineraryRepository`: `Future<ItineraryWeatherTips?> getWeatherTips(int itineraryId) async => null;` (doc: "null = not available"); in `ItineraryRepositoryImpl`: override doing `GET '$_itineraryPath/$itineraryId/weather-tips'` through `_dioClient.dio`, returning `tryParse(response.data)` for status 200; returns `null` for any `DioException`, non-200 status, `FormatException`, or other error; never rethrows. A non-positive id returns `null` without a request.

- [ ] **Step 1: Write failing tests**: `getWeatherTips calls GET /api/v1/itineraries/42/weather-tips and returns the tips`; `returns null for weatherTips null`; `returns null for 401, 403, 404 and 500` (adapter with that status; Dio throws for >=400 by default); `returns null when the connection fails` (adapter throws `DioException.connectionError`); `returns null for a malformed body`; `returns null for id 0 without a request` (`adapter.request` stays null).
- [ ] **Step 2:** `flutter test test/features/traveler/data/repositories/itinerary_repository_impl_test.dart` — Expected: FAIL.
- [ ] **Step 3:** Add the interface default and the implementation.
- [ ] **Step 4:** Same command — Expected: PASS (the file's existing tests too).
- [ ] **Step 5:** Commit `feat(traveler): read itinerary weather tips from the API (UC-10)`.

### Task 3: Cubit

**Files:**
- Create: `lib/features/traveler/presentation/cubit/itinerary_weather_tips_state.dart`
- Create: `lib/features/traveler/presentation/cubit/itinerary_weather_tips_cubit.dart`
- Test: `test/features/traveler/presentation/cubit/itinerary_weather_tips_cubit_test.dart`

**Interfaces:**
- Consumes: `ItineraryRepository.getWeatherTips`, `ItineraryWeatherTips`.
- Produces: `final class ItineraryWeatherTipsState extends Equatable { const ItineraryWeatherTipsState({this.tips}); final ItineraryWeatherTips? tips; }`; `final class ItineraryWeatherTipsCubit extends Cubit<ItineraryWeatherTipsState> { ItineraryWeatherTipsCubit({required ItineraryRepository? repository}); Future<void> load(int itineraryId); }` — `load` is a no-op when the repository is null or this id was already requested (even if the first answer is still pending or was `null`); a different id replaces the stored tips with a new request and ignores a late answer for the old id; a thrown error is treated as `null`; nothing is emitted after `close`.

- [ ] **Step 1: Write failing tests** (`bloc_test`, hand-written fake repository with a `Completer`): `emits the tips when the repository answers`; `emits nothing when the answer is null` (state stays initial); `emits nothing when the repository throws`; `asks once per id: a second load(10) makes no second call, also while the first is pending`; `does not ask when the repository is null`; `a late answer for the previous id is ignored after load(11)`; `does not emit after close`.
- [ ] **Step 2:** `flutter test test/features/traveler/presentation/cubit/itinerary_weather_tips_cubit_test.dart` — Expected: FAIL.
- [ ] **Step 3:** Implement state and cubit.
- [ ] **Step 4:** Same command — Expected: PASS.
- [ ] **Step 5:** Commit `feat(traveler): load weather tips once per itinerary (UC-10)`.

### Task 4: Card widget

**Files:**
- Create: `lib/features/traveler/presentation/widgets/itinerary_weather_tips_card.dart`
- Test: `test/features/traveler/presentation/widgets/itinerary_weather_tips_card_test.dart`

**Interfaces:**
- Consumes: `ItineraryWeatherTips`, `AppSpacing`, `context.tmColors`.
- Produces: `final class ItineraryWeatherTipsCard extends StatelessWidget { const ItineraryWeatherTipsCard({required this.tips, super.key}); final ItineraryWeatherTips tips; }` — a `Card` wrapped in `Semantics(container: true, label: 'Gợi ý theo thời tiết')`, `Key('itinerary_weather_tips_card')`; title, summary line, then each tip (Warning: `Key('weather_tip_warning')` row with warning icon and `warningContainer`; Info: bullet row), or the empty sentence when `tips.tips` is empty.

- [ ] **Step 1: Write failing tests**: `shows the title with day and month`; `shows the summary line`; `lists the tips in the received order`; `a Warning tip has the warning icon and key, an Info tip does not`; `shows the empty sentence and no tip rows when there are no tips`; `does not show the empty sentence when there are tips`; `wraps a long tip at text scale 2.0 without overflow` (pump in a 320-wide `MediaQuery` with `textScaler: TextScaler.linear(2.0)`, assert `tester.takeException()` is null); `has the semantics label "Gợi ý theo thời tiết"`.
- [ ] **Step 2:** `flutter test test/features/traveler/presentation/widgets/itinerary_weather_tips_card_test.dart` — Expected: FAIL.
- [ ] **Step 3:** Implement the card.
- [ ] **Step 4:** Same command — Expected: PASS.
- [ ] **Step 5:** Commit `feat(traveler): add the itinerary weather tips card (UC-10)`.

### Task 5: Mount on the detail page

**Files:**
- Modify: `lib/features/traveler/presentation/pages/itinerary_detail_page.dart` (constructor, `_ItineraryDetailPageState`, the existing `BlocConsumer` listener ~line 151, `_DetailContent` after `ItineraryCostSummary` ~line 327)
- Test: `test/features/traveler/presentation/pages/itinerary_detail_page_weather_test.dart` (reuse the fake repository and `_pump` style of `itinerary_detail_page_explanation_test.dart`)

**Interfaces:**
- Consumes: `ItineraryWeatherTipsCubit`, `ItineraryWeatherTipsCard`.
- Produces: new optional constructor parameter `ItineraryRepository? weatherTipsRepository` on `ItineraryDetailPage`; the state creates `late final _weatherCubit = ItineraryWeatherTipsCubit(repository: widget.weatherTipsRepository ?? locateOptional<ItineraryRepository>())` and closes it in `dispose`; the existing listener calls `_weatherCubit.load(detail.itineraryId)` whenever the detail cubit state is `loaded` with a detail (the cubit ignores repeats); `_DetailContent` receives the cubit like it receives `routeCubit` and renders `BlocBuilder<ItineraryWeatherTipsCubit, ItineraryWeatherTipsState>(bloc: weatherCubit, ...)` with `SizedBox.shrink()` when `tips == null`, otherwise `const SizedBox(height: AppSpacing.sm)` + the card, right after `ItineraryCostSummary`.

- [ ] **Step 1: Write failing tests**: `shows the weather card after the cost summary and above the first stop` (compare `tester.getTopLeft` y of the card against `ItineraryCostSummary` and the first stop's name); `shows no card when the repository answers null`; `shows no card and still lists the stops when the repository throws`; `shows no card while the weather answer is pending`; `asks for the weather once, with the itinerary id`; `does not ask again after the detail is reloaded` (trigger a second `ItineraryDetailCubit.load(10)` and assert the fake's call count stays 1); `an owner can still open the edit action when the weather failed` (detail with `canManage: true`; the page's existing edit control is present).
- [ ] **Step 2:** `flutter test test/features/traveler/presentation/pages/itinerary_detail_page_weather_test.dart` — Expected: FAIL.
- [ ] **Step 3:** Add the parameter, the cubit, the listener call and the slot.
- [ ] **Step 4:** Run the new test, then `flutter test test/features/traveler` — Expected: PASS, no existing test edited.
- [ ] **Step 5:** Commit `feat(traveler): show weather tips on the itinerary detail page (UC-10)`.

### Task 6: Verification
- [ ] **Step 1:** `flutter pub get`; `dart format --set-exit-if-changed .`; `flutter analyze`; `flutter test`. Expected: all clean; compare the test count with the baseline.
- [ ] **Step 2:** `git checkout -- pubspec.lock` if it changed; `git status` shows only this plan's files.
- [ ] **Step 3:** Hand over: BE #204 not deployed, so verified with fakes only; push / PR only on the developer's go.