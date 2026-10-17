# REVIEW2 (Mobile) — Implementation plan

Spec: `specs/REVIEW2-mobile-spec.md`. Each task is test-first (red → green → refactor).

## Task 1 — Models and price labels (ticket 13)
- `CostKind` (poi domain), `parseCostKind` (poi data), `visitPriceLabel` + `formatVnd` (`lib/shared/formatters/visit_price_format.dart`, also used by the result page).
- `itinerary_detail.dart` / `itinerary_detail_model.dart`: §3.1 fields + `ItineraryLocation`.
- `poi_detail.dart` / `poi_detail_model.dart`: `estimatedVisitCost`, `costKind`; label on
  `poi_detail_page.dart`.
- Detail page: per-stop price, summary "Vé · Ăn uống · Tổng".
- `create_itinerary_page.dart`: radius > 30 km warning; `PoiSearchCubit` /
  `PointOfInterestRepository.search(excludeFoodAndDrink:)` for the mandatory picker.
- Verify: model tests, `visit_price_test.dart`, page tests.

## Task 2 — Stops mutation, leg row, badges, undo (ticket 14)
- Domain: `ItineraryStop`, `itinerary_stops.dart` (current stops, leg mode, insert, replace,
  remove, reorder, arrival shifts); `ItineraryRepository.updateStops` replaces `adjustItems`.
- `StopInfeasibleFailure` + `ErrorMapper` parsing of the 422 extensions.
- `ItineraryDetailCubit`: `changeLegMode`, `updateStops`, `undo`, shift badges.
- Page: leg row widget, mode sheet, motorbike note, walk hint, badges, undo snackbar.
- Verify: domain unit tests, repository Dio-adapter test, cubit tests, page tests.

## Task 3 — Suggestions, item menu, lunch card, Tripadvisor (ticket 15)
- Domain entities `ItinerarySuggestions`, `PoiExternalReviews`; repository methods
  `getSuggestions`, `ExternalReviewRepository` (+ impl, DI).
- Cubits: `ItinerarySuggestionsCubit`, `ExternalReviewsCubit`.
- Widgets: item "⋯" menu, lunch card, suggestions sheet, reviews sheet, regenerate warning.
- `url_launcher` for the Tripadvisor link.
- Verify: model tests, cubit tests, widget tests.

## Task 4 — Itinerary map (ticket 16)
- `trip_map.dart` (generic Mapbox map: markers, polylines, follow-puck or fit camera, marker
  tap); `MapboxNavigationMap` becomes an adapter (active trip unchanged).
- `ItineraryRouteCubit`: per-leg directions with mode profile, straight-line fallback.
- `itinerary_map_canvas.dart`: projected CustomPaint fallback.
- Detail page: map section, marker ↔ row sync, redraw after edits.
- Verify: route cubit tests, marker mapping tests, page test with the fallback canvas,
  existing active-trip tests unchanged.

## Task 5 — Verification
`flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`.
