# UC-09 Mobile Specification — Update Travel Preferences

**Feature:** UC-09 Update Travel Preferences
**Platform:** Mobile / Flutter
**Status:** Draft — awaiting team approval
**Contract basis:** `Capstone_BE/src/TripMate.Api/Controllers/V1/TravelerPreferencesController.cs` (UC-09, TM-55) and `Capstone_FE/specs/UC-09-spec.md` (Web, Draft v4 — 2026-10-13)

---

## 1. Purpose

UC-09 lets an authenticated Traveler view, replace and clear five optional
travel preferences used as soft constraints by the itinerary planner:
interests, preferred transport mode, travel pace, food preferences, and risk
tolerance.

The existing `/traveler/preferences` screen (`TravelPreferencesPage`,
`TravelPreferencesCubit`) is a **UI-only demo**: it holds in-memory defaults,
never calls the Backend, and its "Save preferences" button shows a
`'Travel preferences saved locally for demo.'` SnackBar. This delivery
replaces that demo with a real integration against the approved Backend
contract. The Backend remains authoritative for option membership, the
ten-interest limit, and `NoRestriction` food exclusivity.

---

## 2. Actor and platform scope

### Supported Mobile actor

- Traveler only (`[Authorize(Roles = nameof(UserRole.Traveler))]` on the
  Backend controller; an inactive/non-Traveler account must receive a safe
  403, never a silently-ignored write).

### Explicit exclusions

- Tour Operator, Staff, Administrator: no UC-09 Mobile screen, route, or
  action.
- Budget/`defaultBudgetVnd`, travel style, and auto-apply-to-plans are **not**
  part of this contract (removed from the Backend schema by
  `20261013_remove_traveler_profile_default_budget.sql`; the current Mobile
  demo's `autoApply` toggle must be removed, not wired up).
- UC-10 scheduling budget remains a separate, request-level optional field;
  UC-09 does not read or prefill it beyond the already-approved supported
  `preferredTransportMode` prefill boundary (Web spec §"UC-10 boundary"),
  which is out of scope for this Mobile delivery unless Mobile already
  implements UC-10 budget prefill today.

---

## 3. User flow

```text
Traveler account/settings page
  ↓
Travel Preferences (/traveler/preferences)
  ↓
GET /api/v1/traveler/preferences/options  → populate selectable options
GET /api/v1/traveler/preferences          → populate current selections
  ↓
Edit interests / transport / pace / food / risk
  ↓
Save
  ├── invalid/error → remain on form with safe feedback, selections kept
  └── success → show saved selections, remain on screen
```

There is no separate "Reset to default" server action; the existing
`Cubit.reset()` is removed because it resets to invented client defaults that
no longer correspond to a canonical server value (an unset preference is
`null`/`[]`, not a pre-selected chip).

---

## 4. Backend API contract

### Options (read on screen entry)

```http
GET /api/v1/traveler/preferences/options
Authorization: Bearer <access-token>
```

```json
{
  "interests": [{ "key": "Beach", "source": "Category" }, { "key": "Hiking", "source": "Tag" }],
  "preferredTransportModes": ["Walking", "Motorbike", "Car", "PublicTransit"],
  "travelPaces": ["Relaxed", "Moderate", "Fast"],
  "foodPreferences": ["NoRestriction", "Vegetarian", "Vegan", "Halal", "NoSeafood"],
  "riskTolerances": ["Low", "Medium", "High"]
}
```

- `interests` is **catalog-driven** (POI categories and tags currently in the
  database) and must never be a hardcoded Mobile enum; the set and its size
  vary over time.
- `preferredTransportModes`, `travelPaces`, `foodPreferences`, and
  `riskTolerances` are the Backend's current enum names (see §9 for exact
  current values); Mobile renders whatever this endpoint returns rather than
  a second hardcoded copy, so a future Backend enum addition/removal needs no
  Mobile code change beyond label text.

### Current preferences (read on screen entry)

```http
GET /api/v1/traveler/preferences
Authorization: Bearer <access-token>
```

```json
{
  "interests": ["Beach", "Hiking"],
  "preferredTransportMode": "Motorbike",
  "travelPace": "Relaxed",
  "riskTolerance": "Medium",
  "foodPreferences": ["Vegetarian"],
  "updatedAtUtc": "2026-10-16T03:00:00Z"
}
```

- Every field may be `null`/`[]` for a Traveler who has never saved
  preferences, or who cleared a selection. The form must render this as "no
  selection", never as a pre-picked default chip.
- An interest or food key present in storage but no longer offered by the
  options catalogue is **already excluded by the Backend response** (D-08);
  Mobile does not need to reconcile stale keys itself.

### Save

```http
PUT /api/v1/traveler/preferences
Authorization: Bearer <access-token>
Content-Type: application/json
```

```json
{
  "interests": ["Beach", "Hiking"],
  "preferredTransportMode": "Motorbike",
  "travelPace": "Relaxed",
  "riskTolerance": "Medium",
  "foodPreferences": ["Vegetarian"]
}
```

- Save always sends the **full five-field state**, matching the Web
  contract: an empty collection is `[]`, an empty scalar choice is `null`.
  Mobile must not send a partial/diff payload.
- The body contains no `defaultBudgetVnd`, `travelStyle`, `autoApplyToPlans`,
  user ID, or role.
- On success the Backend returns the same `TravelerPreferencesDto` shape as
  the GET above; Mobile replaces its displayed state from that response only,
  never from the values the user just typed (the Backend is authoritative,
  e.g. it may canonicalize an interest key's casing).

---

## 5. Validation and safe feedback

### Mobile-side validation (early feedback only; Backend remains authoritative)

| Field | Rule |
| --- | --- |
| Interests | At most 10 distinct selections (`TravelerPreferenceKeys.MaxInterests`); selectable values come only from the options response; deselecting every chip is how the user clears this field to `[]`. |
| Preferred transport | Optional; selectable values come only from the options response, **plus an explicit "No preference" chip** that clears the field to `null`. A scalar field has no "tap again to deselect" gesture on a `SegmentedButton`/`ChoiceChip` group, so clearing needs its own selectable option. |
| Travel pace | Optional; selectable values come only from the options response, **plus an explicit "No preference" chip** that clears the field to `null`, for the same reason as transport. |
| Food preferences | Optional, multi-select; selectable values come only from the options response; selecting `NoRestriction` deselects every other food value in the same interaction (and vice versa), mirroring the Backend's exclusivity rule so the user never submits a combination the Backend will reject; deselecting every chip clears this field to `[]`. |
| Risk tolerance | Optional; selectable values come only from the options response, **plus an explicit "No preference" chip** that clears the field to `null`, for the same reason as transport. |

Transport, pace, and risk are rendered as single-choice groups
(`ChoiceChip`/`SegmentedButton`), so — unlike the multi-select Interests and
Food groups, where tapping a selected chip deselects it — these three groups
need one more selectable option standing for "no value", not a second tap
gesture. This mirrors the FE/Backend contract, where an omitted scalar field
is `null`: the GET response can already return `null` for a Traveler who
never set one of these three fields, and the only way to get back to that
state once a chip is selected is to select "No preference" and save.

### Backend result mapping

| Outcome | Mobile behavior |
| --- | --- |
| `200` success (GET options / GET preferences / PUT) | Render/replace state from the response body. |
| `400` `TRAVEL_PREFERENCES.INVALID_OPTION` | Generic "one or more selections are no longer available; please reload" feedback; re-fetch options. |
| `400` `TRAVEL_PREFERENCES.TOO_MANY_INTERESTS` | Inline feedback on the Interests section: "You can select up to 10 interests." |
| `400` `TRAVEL_PREFERENCES.FOOD_NO_RESTRICTION_EXCLUSIVE` | Inline feedback on the Food Preferences section: "No restriction cannot be combined with other food preferences." |
| `400` `TRAVEL_PREFERENCES.VALUE_TOO_LONG` | Generic "one or more selections are too long; please reload and try again" feedback (field named in the error's `field` metadata, per §9.2 wording); re-fetch options. This is a defense-in-depth mapping — the options catalogue already caps key length server-side, so Mobile should not be able to submit an over-length key through normal chip selection. |
| `401` | Clear invalid session using the existing auth flow and redirect to sign-in. |
| `403` `TRAVEL_PREFERENCES.FORBIDDEN` / any 403 | Safe access-denied feedback; preserve whatever was already loaded; never claim success. |
| Network / `5xx` | Generic retry feedback; keep the user's in-progress selections locally for retry; never claim success. |

Mobile must never show raw HTTP bodies, stack traces, or Backend error-code
strings verbatim to the user; each stable error code (`TravelerPreferenceErrors`
in BE) maps to a fixed, human-readable Mobile message per the table above.

---

## 6. Security and session requirements

1. The Traveler identity comes solely from the authenticated session (bearer
   token), never from editable screen state.
2. All three requests (`GET options`, `GET preferences`, `PUT preferences`)
   are authenticated through the existing centralized Dio client exactly like
   every other authenticated Mobile endpoint; no alternate client, no
   hardcoded base URL.
3. Responses are strictly parsed; a malformed response shows the generic
   failure state without inventing plausible fallback data (no silent
   defaulting to `.defaults()`).
4. No preference data is cached in `SharedPreferences` or any unencrypted
   local store; the Cubit's in-memory state is rebuilt from the Backend on
   every screen entry.

---

## 7. Presentation requirements

- Reuse the existing Material 3 section layout (`_Section`, `ChoiceChip`,
  `FilterChip`, `SegmentedButton`) already present in
  `travel_preferences_page.dart`; this is a data-layer and field-set
  correction, not a visual redesign.
- Replace the single-select `ChoiceChip` food UI with a multi-select
  (`FilterChip`, consistent with Interests) to support the Backend's
  `FoodPreferences: string[]` contract and the `NoRestriction` exclusivity
  rule.
- Add a leading "No preference" chip to each of the Preferred Transport,
  Travel Pace, and Risk Tolerance single-choice groups, selected whenever the
  underlying value is `null`; selecting it clears that field to `null` on
  save. Interests and Food Preferences need no such chip because deselecting
  every chip already represents `[]`.
- Remove the `autoApply` `SwitchListTile` and the `reset()` "Reset to
  default" action; neither has a Backend counterpart.
- Add loading (initial GET), validation-error, API-error, and success states;
  disable the Save button while a request is in flight or while initial data
  is still loading.
- Long localized error text must wrap without breaking layout; all states
  remain reachable by keyboard/semantic navigation.

---

## 8. Acceptance criteria

1. Opening `/traveler/preferences` loads the Traveler's real saved
   preferences and the real options catalogue from the Backend; a user who
   has never saved preferences sees no selection, not invented defaults.
2. A valid Save sends exactly the five-field payload (`interests`,
   `preferredTransportMode`, `travelPace`, `riskTolerance`,
   `foodPreferences`) to `PUT /api/v1/traveler/preferences`; no
   `defaultBudgetVnd`, `travelStyle`, or `autoApplyToPlans` field is ever
   sent.
3. Interests and food options render only values returned by
   `GET /api/v1/traveler/preferences/options`; no hardcoded enum list remains
   in the Mobile UI.
4. Food preferences support multi-select, and selecting `NoRestriction`
   clears every other food selection in the same interaction.
5. Preferred Transport, Travel Pace, and Risk Tolerance each expose a
   selectable "No preference" option that clears the field to `null`; a
   Traveler who previously saved a value for one of these fields can return
   it to "no selection" and have that persist after Save.
6. Selecting more than 10 interests is blocked client-side before submission;
   the Backend's `TOO_MANY_INTERESTS` response is also mapped to safe
   feedback for defense in depth.
7. `401`, `403`, validation (including `VALUE_TOO_LONG`), and network/5xx
   failures display safe UX without disclosing technical details, per §5.
8. No preference data is written to `SharedPreferences` or any local
   unencrypted store.
9. The demo SnackBar text ("saved locally for demo") and the `autoApply`
   toggle no longer exist in the shipped screen.

---

## 9. Current Backend enum values (snapshot; Mobile must render from `/options`, not hardcode this list)

- `TransportMode`: `Walking`, `Motorbike`, `Car`, `PublicTransit`.
- `TravelerPace`: `Relaxed`, `Moderate`, `Fast`.
- `RiskToleranceLevel`: `Low`, `Medium`, `High`.
- Food preference keys (`TravelerPreferenceKeys.FoodPreferences`):
  `NoRestriction`, `Vegetarian`, `Vegan`, `Halal`, `NoSeafood`.
- `Interests`: dynamic, sourced from `dbo.PoiCategories` + `dbo.Tags` minus
  commercial-service categories (hotel/restaurant/vehicle/vehicle rental);
  not enumerable in this spec.

This snapshot exists only to help reviewers sanity-check the implementation;
the implementation itself must read these values from the `/options`
response, never from a Mobile-side copy of this list.

---

## 10. Dependencies and non-goals

- Backend UC-09 endpoints already exist and are implemented on `develop`
  (`TravelerPreferencesController`); no Backend change is required for this
  Mobile delivery.
- This document defines only Mobile Traveler behavior. Web Traveler behavior
  is owned by `Capstone_FE/specs/UC-09-spec.md`.
- Does not implement UC-10 scheduling-request budget; that remains a
  separate, already-existing request-level field per the Web spec's "UC-10
  boundary" section.
