# UC-09 Mobile Implementation Plan — Update Travel Preferences

**Feature:** UC-09 Update Travel Preferences
**Platform:** Mobile / Flutter
**Status:** Draft — execute only after specification approval
**Specification:** `specs/UC-09-update-travel-preferences-mobile-spec.md`

---

## 1. Delivery boundary

This plan replaces the existing demo-only `/traveler/preferences` screen
(`TravelPreferencesPage` + `TravelPreferencesCubit`, pure in-memory state,
no network call) with a real integration against the already-implemented
Backend UC-09 endpoints. It does not touch Tour Operator, Staff, or
Administrator screens, and does not implement UC-10 scheduling-request
budget behavior.

---

## 2. Preconditions

1. Confirm the Backend UC-09 contract from the running code, not from memory:
   `TravelerPreferencesController`, `TravelerPreferencesDto`,
   `TravelerPreferenceOptionsDto`, `UpdateTravelerPreferencesApiRequest`, and
   `TravelerPreferenceErrors` (already read into the spec; re-verify if the
   Backend branch changes before implementation starts).
2. Inspect current Mobile conventions to reuse, not invent:
   - `lib/core/network/dio_client.dart` (centralized Dio, auth interceptor).
   - `lib/core/error/error_mapper.dart` and `lib/core/error/failures.dart`.
   - `lib/core/di/service_locator.dart` (GetIt registration pattern used by
     `ItineraryRepositoryImpl` etc. in `lib/features/traveler/data/repositories`).
   - `lib/app/router/app_router.dart` and `app_routes.dart` (`travelerPreferences`
     route already registered at line ~183/16).
3. Run and record baseline:

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
```

---

## 3. Task 1 — Domain models and repository contract

**Files:** `lib/features/traveler/domain/entities/travel_preferences.dart`,
`lib/features/traveler/domain/entities/travel_preference_options.dart`,
`lib/features/traveler/domain/repositories/travel_preferences_repository.dart`.

**RED tests:** entity equality/copyWith for the five-field preferences model
(`interests`, `preferredTransportMode`, `travelPace`, `riskTolerance`,
`foodPreferences`), and for the options model (`interestOptions`,
`preferredTransportModes`, `travelPaces`, `foodPreferences`,
`riskTolerances`); a repository interface exposing `getOptions()`,
`getPreferences()`, and `updatePreferences(TravelPreferences)`.

**Implement:** plain domain entities (no BE-shaped JSON knowledge); repository
interface only, no implementation yet. All values are `String?`/`List<String>`
keys exactly as the Backend sends them — Mobile does not re-encode them into
a Dart enum, so a Backend-side catalogue change needs no Mobile code change.

**Verify:** focused domain tests pass.

---

## 4. Task 2 — Data contract and authenticated requests

**Files:** `lib/features/traveler/data/models/travel_preferences_model.dart`,
`lib/features/traveler/data/models/travel_preference_options_model.dart`,
`lib/features/traveler/data/datasources/travel_preferences_remote_data_source.dart`,
`lib/features/traveler/data/repositories/travel_preferences_repository_impl.dart`.

**RED tests:**

- `GET /api/v1/traveler/preferences/options` parses
  `interests[].key`/`interests[].source`, `preferredTransportModes`,
  `travelPaces`, `foodPreferences`, `riskTolerances`.
- `GET /api/v1/traveler/preferences` parses the five fields plus
  `updatedAtUtc`; a `null` scalar or empty list round-trips as "no selection",
  never as a default.
- `PUT /api/v1/traveler/preferences` sends exactly
  `{interests, preferredTransportMode, travelPace, riskTolerance, foodPreferences}`
  — an empty collection serializes as `[]`, an unset scalar as `null`; no
  extra field (`defaultBudgetVnd`, `travelStyle`, `autoApplyToPlans`, user ID,
  role) is ever present.
- A malformed/incomplete success body throws without producing plausible
  fallback data. **Unlike `ChangePasswordRemoteDataSource`, UC-09 responses
  are not wrapped in a `{ success, data }` envelope** —
  `TravelerPreferencesController` returns `Ok(result.Value)` directly, so the
  three data-source methods parse `TravelerPreferenceOptionsModel.fromJson`/
  `TravelerPreferencesModel.fromJson` straight off the response body; do not
  add an envelope-unwrap step that does not exist on this controller.
- Error mapping: `400 TRAVEL_PREFERENCES.INVALID_OPTION`,
  `400 TRAVEL_PREFERENCES.TOO_MANY_INTERESTS`,
  `400 TRAVEL_PREFERENCES.FOOD_NO_RESTRICTION_EXCLUSIVE`,
  `400 TRAVEL_PREFERENCES.VALUE_TOO_LONG`, `401`, `403`
  (`TRAVEL_PREFERENCES.FORBIDDEN` and any other 403), network, `5xx`.

**Implement:** use the centralized `DioClient` exactly as
`ChangePasswordRemoteDataSource` does (no `skipAuth`, no alternate client, no
hardcoded base URL, same auth-interceptor reuse) but parse the response body
directly as the DTO with no envelope unwrap; map DTOs to domain
entities/failures in the repository impl, following
`ChangePasswordRepositoryImpl`'s precedent of dedicated Failure types for the
UC-specific codes (now including `VALUE_TOO_LONG`) ahead of the shared
`ErrorMapper` fallback.

**Verify:** focused data-source/repository tests pass.

---

## 5. Task 3 — Cubit rewrite (remove demo state, add real state machine)

**Files:** `lib/features/traveler/presentation/cubit/travel_preferences_cubit.dart`,
`lib/features/traveler/presentation/cubit/travel_preferences_state.dart` (new,
replacing the in-file `TravelPreferencesState` in the current cubit file).

**RED tests:**

- Initial `load()` calls both `getOptions()` and `getPreferences()`, and
  emits a loading → loaded (or loading → error) sequence; options and current
  selections populate independently of each other's success/failure where
  reasonable.
- Toggling an interest past 10 distinct selections is rejected client-side
  without emitting a Backend call.
- Selecting `NoRestriction` in food preferences clears every other food
  selection in the same emission, and vice versa.
- Selecting "No preference" on transport/pace/risk sets that field to `null`
  in state; selecting any real option after "No preference" was selected
  clears `null` in favor of the chosen value. A Traveler whose loaded state
  already has `null` for one of these fields starts with "No preference"
  selected, not with no chip selected at all.
- `save()` calls `updatePreferences` exactly once per tap, sends the current
  full five-field state, disables re-entrant submission while in flight, and
  on success replaces local state from the response (not from the
  pre-submission local state).
- Each Backend failure code from the spec's §5 table maps to the matching
  safe UI message/section-targeted error.
- `401` triggers the existing invalid-session sign-out/redirect behavior
  (reuse the same mechanism `ChangePasswordCubit`/`AuthSessionCubit` already
  use elsewhere; do not invent a second one).

**Implement:** remove `TravelPreferencesState.defaults()`, `reset()`, and the
`autoApply` field entirely; replace the single `TravelPreferencesState` with
a state carrying `options`, `selected preferences`, `status` (loading/loaded/
saving/error), and field-targeted error messages. Inject the repository
through `service_locator.dart` instead of the current no-arg constructor.

**Verify:** focused Cubit tests pass.

---

## 6. Task 4 — Page rewrite

**Files:** `lib/features/traveler/presentation/pages/travel_preferences_page.dart`.

**RED tests (widget):**

- Initial loading state shows a loading indicator, not stale/default chips.
- Interests and food options render only from the loaded options response
  (verify with a fake repository returning a distinctive option set that
  does not match the old hardcoded enum values).
- Food preferences render as multi-select (`FilterChip`), not the current
  single-select `ChoiceChip`; selecting `NoRestriction` visually deselects
  other food chips.
- Transport, Travel Pace, and Risk Tolerance each render a leading "No
  preference" chip alongside the Backend-supplied options; it is selected
  when the loaded value is `null`, and tapping it clears the field.
- Selecting an 11th interest is blocked and shows the "up to 10" message.
- Save button disabled while loading/saving; success shows confirmation
  without the old "...saved locally for demo." text; failure shows the
  mapped safe message without clearing user selections.
- No `autoApply` switch and no "Reset to default" button remain on the page.

**Implement:** wire the page to the rewritten Cubit; keep the existing
`AppPageScaffold`/`_Section` visual structure; replace the food section's
`ChoiceChip` loop with `FilterChip` multi-select; remove the `autoApply`
`Card`/`SwitchListTile` and the `reset` `TextButton`.

**Verify:** focused widget tests and manual Android/iOS emulator smoke test
against a real Traveler account with and without previously saved
preferences.

---

## 7. Task 5 — DI wiring and router cleanup

**Files:** `lib/core/di/service_locator.dart`, `lib/app/router/app_router.dart`.

**Implement:** register `TravelPreferencesRemoteDataSource` and
`TravelPreferencesRepositoryImpl` in the service locator following the
existing registration pattern for sibling Traveler repositories; update the
router's `/traveler/preferences` route builder (currently
`create: (_) => TravelPreferencesCubit()` at
`lib/app/router/app_router.dart:183`) to resolve the Cubit through the
service locator instead of a bare constructor, and trigger the initial
`load()` call on creation.

**Verify:** `flutter analyze` clean; route smoke test confirms the screen
still opens from the Traveler account/settings entry point.

---

## 8. Task 6 — Security and regression verification

Review the final diff for:

- no hardcoded interest/transport/pace/food/risk enum list remaining in the
  Mobile UI layer;
- no preference data in `SharedPreferences`, logs, or analytics;
- no `autoApply`, `defaultBudgetVnd`, or `travelStyle` field anywhere in the
  new code;
- Save always sends the full five-field state, never a partial diff.

Run:

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Document any unavailable backend/emulator validation honestly. Do not
commit, push, or open a PR until the user requests it.

---

## 9. Delivery gate

The feature is ready for review only when:

1. The screen loads real options and real current preferences from the
   Backend on entry, with no invented default selection.
2. Save sends and receives the exact five-field contract; no legacy field
   remains.
3. Food preferences are multi-select with working `NoRestriction`
   exclusivity on both the client (early feedback) and via Backend error
   mapping (authoritative).
4. The 10-interest limit is enforced client-side and the Backend's
   `TOO_MANY_INTERESTS` response is also mapped safely.
5. Transport, Travel Pace, and Risk Tolerance each support clearing back to
   `null` via an explicit "No preference" chip, and that clear persists
   after Save.
6. `401`/`403`/validation (including `VALUE_TOO_LONG`)/network/`5xx` all show
   safe feedback without false success.
7. No demo-only code (`.defaults()`, `reset()`, `autoApply`, the "saved
   locally for demo" SnackBar) remains.
