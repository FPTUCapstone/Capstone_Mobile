# UC-16 — Download Offline Map & Itinerary: Mobile
Status: APPROVED DIRECTION — user confirmed 2026-11-22; technical feasibility gates remain. No implementation in this documentation task.
Branch: feature/linhnv-download-offline-map-and-itinerary

## Authority and current state
Source: local SRS_rev10 (5).docx, section 3.3.7, paragraphs 3055–3127; BR36–40; MSG104–107; section 3.10.3 for the separate offline synchronization use case.
SHA256: 5E7110B8130ACDFAE7E69FE6D50BC47DB573BC0E2CBBFFCBAA1CAC2A4DCC1FCC.
This draft supersedes only the UC16 slice of specs/mobile-active-trip-uc13-uc16-spec.md. Older screen references are secondary where they omit Cancel/Remove or use older MSG106 text.
Existing offline page/Cubit is a demo: production reports unavailable, with no durable package or Mapbox download. Home/Profile use hardcoded itinerary 1. Current pinned Mapbox plugin is 3.33.0.

## Scope and SRS traceability
| Requirement | Planned behavior |
| --- | --- |
| Accessible itinerary, before or during trip | Download from a real selected itinerary; follow BE owner/active-group-member access |
| BR36 | Save itinerary, referenced POIs, route information and required maps for itinerary area |
| BR37 / MSG107 | Check device free bytes and package budget; reject oversized package |
| BR38 | Publish only after every required component is durable and verified |
| BR39 | Store resolved itinerary ID/version and downloaded timestamp; detect superseded online |
| BR40 | No offline booking/payment/check-in or server-confirmed navigation writes |
| Refresh alternative | User confirms update; failed/cancelled update preserves previous complete package |
| Required controls | Download, Cancel Download, Remove Offline Data; retry and open when appropriate |
| PC04 | No server offline-package entity |

Separate offline synchronization (UC70 / section 3.10.3 in this SRS) is excluded: no queue/replay of notes, photos, reached/skipped stops or mutation events. Older UC72 references do not change that boundary.

## Screen and entry points
Reuse /traveler/trips/:itineraryId/offline and existing OfflineTripPackagePage.
Show itinerary title/date range, downloaded version/time, status, estimated size with estimate label, 150 MB limit and itinerary/POI/map progress.
- Not downloaded: Download, navigation back.
- Downloading: component progress and Cancel; prevent duplicate operation.
- Available: Open offline itinerary/map, Remove, check version when connected.
- Superseded: old version remains openable; Update after confirmation.
- Failure: safe explanation and Retry; never display fake completion.
- Remove: confirmation and accurate removal state; never claim immediate physical space recovery before measured.
Home/Profile shortcuts open a dedicated local-only “Dữ liệu offline” list, proposed route /traveler/offline-packages. Remove hardcoded itinerary 1. List title, trip dates, measured size, downloaded timestamp, version status and Open / Update / Remove. Update requires connectivity. Empty state explains downloading from itinerary details; browsing existing downloads never requires a remote itinerary list. Add Download for Offline Use to real itinerary details. Retained packages remain discoverable after restart without network.
Local data must load before remote metadata; an airplane-mode restart must not first require an HTTP request.

## Proposed package contract and storage
Use account-partitioned, app-private files with an atomic committed manifest, not SharedPreferences for itinerary content.
Manifest fields: schemaVersion, account identifier from trusted session, requested itinerary ID, resolved current itinerary ID, itinerary version, capturedAtUtc/downloadedAtUtc, component integrity metadata, route fingerprint, provider style/region references, measured component bytes and coverage metadata.
Persist only essential referenced POIs and route data. Credentials/tokens, payment information, unrelated/private member data are excluded.
BE reuse: GET /api/v1/itineraries/{id} and GET /api/v1/pois/{id}; use the companion BE spec consistency protocol, including essential-field fingerprint comparison because Version does not cover every existing mutation. Missing required coordinates/geometry/POIs fail the package rather than fabricate data. Rest items may validly have no coordinates and remain in the saved schedule.
Use a staging generation per operation. Verify files, required SDK resources, coverage and final byte budget before atomic manifest publication. On crash/restart clean abandoned staging; detect damaged/missing resources before reporting availability.
Refresh uses a new generation; never overwrite the old region in place. Swap committed pointer only after new package verifies. Cleanup must not remove resources referenced by another committed package.
Concurrent operations are serialized initially as a technical simplification; late callbacks are ignored through operation identity. Cancel must stop resource work and clean staging, not merely hide UI.

## Size and Mapbox feasibility gate
The SRS specifies a maximum 150 MB package and MSG107 requires at least 150 MB free. These are distinct checks. Refresh also requires temporary space for old + replacement; insufficient scratch space preserves old.
Proposed M1 unit: 150,000,000 bytes. Use integer byte accounting, not rounded MB or demo constants.
Installed SDK supports tile/style download and completedResourceSize. Estimates and TileStore quota do not prove total package size (JSON + routes + style + tiles). Shared resources and deferred native eviction complicate physical size.
Before implementation completion prove on Android:
- map view actually uses isolated downloaded resources after restart in airplane mode;
- cancellation terminates native work safely;
- actual required resources can be accounted for and oversized staging rejected;
- removing/updating one package cannot break another.
The Dart download APIs return Future without a public cancellation handle; native adapter/plugin change may be necessary. If the pinned SDK cannot satisfy cancellation/storage requirements, stop for an approved technical change, not a simulated success.
Official references: [Flutter offline example](https://docs.mapbox.com/flutter/maps/examples/offline/), [offline resource management](https://docs.mapbox.com/android/maps/guides/offline/manage-offline-data/). Validate behavior against pinned 3.33.0 source, not latest documentation alone.

## Offline reading and navigation proposal
Persist planned geometry/available steps from the existing map integration. Offer cached itinerary, POI details, planned route and GPS position within downloaded coverage.
GPS permission denial does not prevent reading itinerary. Show permission state for position display.
Do not promise new offline Directions requests, rerouting or full dynamic turn-by-turn from map tiles alone. Do not start/complete a server navigation session offline.
Approved target: cover every itinerary POI and the complete saved route geometry, buffered by 1 km, zoom 10–16, using the existing configured Mapbox style. Handle longitude wrapping rather than accidentally requesting a world-sized bounding box. Verify provider descriptor coverage and offline rendering at sampled POIs, route segments and zoom boundaries after restart. These are approved product defaults, not original SRS numbers; feasibility must confirm resource size and provider behavior before release. Do not silently reduce zoom, omit POIs or truncate the route to fit the budget. First release downloads the whole itinerary; oversized packages fail with the storage-limit explanation. Download by day is excluded and requires separate approval.

## Account/session proposal
Retain downloaded files on logout, consistent with existing Settings copy, but deny viewing until the same account signs in; switching account never exposes the previous account's content.
For offline restart, proposed M3: permit local read-only access for the last securely retained account if not explicitly logged out; do not treat this as valid online authentication or bypass HTTP authorization.
This requires a narrowly scoped route policy; current route guards require authenticated session for every Traveler route. Do not globally disable guards. Approved: offline-expired sessions may read only their retained local package list/detail/map. Reconnection revalidates access; an authoritative itinerary access denial locks that package and offers deletion. A 401, timeout, connectivity event or 5xx alone is not proof of revoked itinerary access: request sign-in/retry without misclassifying or deleting data. No account switch or logout permits another account to read retained files. Do not store credentials in manifests.

## Messages and failure states
Use localized application resources; never expose raw MSG/BR codes or exceptions.
| SRS ID | Canonical English content / mapping |
| --- | --- |
| MSG104 | Downloading offline trip package (itinerary, POIs, map tiles)… |
| MSG105 | Trip package downloaded! Itinerary is now available offline without internet. |
| MSG106 | Connection lost. The transfer was interrupted and nothing partial was kept. Please retry. |
| MSG107 | Insufficient storage space. At least 150MB free space required for offline map data. |
Explicit cancellation is not connection loss. For failed refresh, explain that previous complete data is retained. Missing/inaccessible itinerary follows MSG32/MSG126 semantics with existing API failure mapping.
Corruption, missing SDK resources, provider failure and write failure remain unavailable/incomplete with safe retry; do not mislabel every error as network failure.

## Acceptance / test matrix
1. Authorized download persists all components; restart airplane mode opens real itinerary, POIs and cached map/route.
2. Below/exactly/above budget; below/exactly 150 MB free; mid-download growth and refresh temporary-space failure.
3. Network interruption, explicit cancel and process death discard incomplete generation; no success notification.
4. Refresh success swaps atomically; failure/cancel retains old usable version; obsolete response cannot publish.
5. Changed returned ID/version and itinerary race handled; POI consistency limitation follows approved BE decision.
6. Logout/account switch/deep link cannot leak retained content; approved offline restart policy tested.
7. Removed/corrupt style, tiles or JSON cannot appear Available. Shared resource removal does not break another package.
8. Reconnection checks version without auto-download/upload; repeated reconnect events do not duplicate operations.
9. Small screen, long text, screen reader labels, progress semantics and large text remain usable.
10. Booking/payment/check-in and navigation mutations remain online-only.

## Decision record — confirmed 2026-11-22
- M1: Interpret 150 MB as 150,000,000 bytes per complete package; free-device minimum is a separate check. No invented global package count. Account for style, tiles, JSON and routes conservatively, including resources shared with other packages; do not count only newly transferred bytes. Physical scratch usage and cleanup are measured separately.
- M2: Whole itinerary, 1 km buffer, zoom 10–16; cached route/map/POI reading and GPS position. No offline rerouting, dynamic turn-by-turn or download-by-day in first release.
- M3: Same-account local read after offline restart/token expiry, locked after explicit logout; authoritative online loss of itinerary access locks the affected package. List is local-first.
- M4 / B1: Reuse current itinerary/POI reads with version recheck and individual POI capture timestamps. No atomic expanded BE endpoint unless feasibility demonstrates a required gap and a revised contract is approved.
Native Android gates were verified on 2026-11-23: actual style/tile download, cancellation, shared-resource preservation and visible map rendering after a same-APK cold process restart with networking disabled. See the plan execution record for exact evidence and remaining validation limits. This does not authorize silently weakening approved behavior or creating a new backend contract.
