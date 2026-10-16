# REVIEW2 (Mobile) — Mentor feedback remediation: prices, legs, edits, suggestions, map

Status: approved by developer 2026-10-16 (cross-repo spec
`.scratch/review2-mentor-feedback/spec.md`, decisions D1, D4–D7, D9 fallback, D11).
Tickets: 13 (models, prices), 14 (leg row), 15 (suggestions), 16 (itinerary map).
Branch: `feature/review2-mentor-feedback` (from `origin/develop` d297e23).

## Scope

The backend contract (§3.1–3.6 of the cross-repo spec) is final but not deployed locally:
Mobile builds against it and is verified with fake repositories / Dio adapters.

### 13 — Models, price labels, cost split, radius warning
- Parse the §3 fields: itinerary `transportMode`, `startLocation`, `endLocation`; item
  `travelDistanceFromPreviousMeters`, `transportModeFromPrevious`, `costKind`, `address`,
  `latitude`, `longitude`; POI detail `estimatedVisitCost`, `costKind`; itinerary `budgetVnd`. Missing fields from
  older backends stay null.
- Price label (D1), per person: `null` → "Chưa có thông tin", `0` → "Miễn phí",
  `AdmissionTicket` → "Giá vé dự kiến: X VNĐ/người", `AverageSpend` → "Mức chi tiêu dự kiến:
  X VNĐ/người". Shown per stop on the itinerary detail page and on the POI detail page.
- Summary card (D11-7): "Vé · Ăn uống · Tổng / ngân sách" computed client-side by `costKind`;
  the budget comes from the detail `budgetVnd` (contract update 2026-10-16), "/ ngân sách" is
  omitted when it is null.
- Create form: warning text when the search radius is above 30 km (default stays 10 km).
- Mandatory-POI picker sends `excludeFoodAndDrink=true` (D2).

### 14 — Leg row, transport change, change badges, undo
- Leg row: "9,4 km · khoảng 22 phút · Xe máy [Đổi]"; km hidden when distance is null;
  metres below 1 km; motorbike note shown once at the top; legs under 1 km that are not
  walked show "Gần, có thể đi bộ ~X phút".
- "Đổi" (owner, not navigating) opens Đi bộ / Xe máy / Ô tô-taxi and sends
  `PUT /itineraries/{id}/items` with `stops` built from the current visit stops and an
  Idempotency-Key.
- 422 `itinerary.stop_infeasible` → message naming the failing stop from the problem-details
  extensions (`poiId`, `reason`, `plannedArrival`, `closesAt`, `overflowMinutes`, `overflowVnd`).
- After an edit, stops whose arrival moved get a badge ("⟲ lùi 25 phút" / "⟲ sớm 10 phút")
  and a snackbar offers "Hoàn tác" (re-sends the previous stops).
- Edit actions stay hidden while `isNavigationInProgress` (`canEdit`).

### 15 — Item menu, lunch card, suggestions, Tripadvisor
- "⋯" per visit stop: Thay địa điểm / Bỏ khỏi lịch / Xem đánh giá (edit entries only for
  `canEdit`); removing a mandatory stop asks for confirmation.
- Lunch card "Bữa trưa? [Chọn quán]" on the stop closest to 12:00 when the trip covers
  11:00–13:30 and has no `AverageSpend` stop; "+ Thêm quán ăn" after the last stop.
- Suggestions sheet (`GET /itineraries/{id}/suggestions?kind=Food&afterItemId=` or
  `kind=Replace&replaceItemId=`): price, distance + detour, closing time, Tripadvisor rating;
  unfit / closed items greyed with the reason and not selectable; empty state names the radius
  and suggests widening it. Choosing sends the full `stops` list.
- Regenerate warns first when the itinerary contains a restaurant.
- The reorder/remove sheet uses the same `stops` call.
- Tripadvisor (§3.6): "Tripadvisor" text + `ratingImageUrl` image + review count + link to
  `url`; hidden when `source` is null; per review "Dịch sang tiếng Việt" (only when
  `translationAvailable`) labelled "Bản dịch tự động · Xem bản gốc". No self-drawn stars.

### 16 — Itinerary-detail map
- The Mapbox widget becomes a generic trip map used by the active-trip page (unchanged
  behaviour) and the itinerary detail page.
- Detail map: numbered markers coloured by type (attraction / food / start / end), polyline per
  leg from the Mapbox Directions repository with the leg's mode (walking vs driving profile),
  straight segment when a leg cannot be routed; marker tap highlights the list row, row tap
  moves the camera; redrawn after edits; CustomPaint fallback without `MAPBOX_ACCESS_TOKEN`.

## Out of scope
Roadmap items (§2), any change to navigation sessions,
device verification of the map (needs the CI APK on a device).

## Acceptance
`flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`
green; new parsing, domain rules, cubits and meaningful widgets covered by tests.
