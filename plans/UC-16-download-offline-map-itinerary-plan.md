# UC-16 Mobile implementation plan
Status: APPROVED DIRECTION — confirmed 2026-11-22; native feasibility is a blocking execution gate.
Spec: ../specs/UC-16-download-offline-map-itinerary-spec.md
Checks below are planned, not executed for this documentation task.

## Atomic tasks
Every behavior task follows failing test → minimal implementation → refactor → focused verification, followed by spec-compliance and code-quality review.

### 0. Decisions and baseline
Use confirmed M1–M4 and BE B1 in the companion specs. Inspect git status; run flutter pub get, flutter analyze and flutter test. Record baseline failures independently. Preserve user changes.
Done: approved behavior, real contract/nullability and baseline results recorded.

### 1. Native feasibility, before full feature
Proposed files: lib/features/traveler/data/datasources/offline_map_data_source.dart and integration_test/uc16_offline_map_test.dart.
Use pinned Mapbox3.33.0 API. Prove isolated region/map binding, style persistence, actual size, cancel cleanup, shared resource safety and airplane-mode reopen after app restart.
Verify: flutter test integration_test/uc16_offline_map_test.dart -d <android-device>, flutter build apk --debug.
Done: observable native evidence for every gate; if cancellation or budget cannot be satisfied, document findings and obtain approval for plugin/adapter changes before proceeding. Do not add speculative native code or dependencies.

### 2. Domain package lifecycle
Existing: lib/features/traveler/domain/entities/offline_trip_package.dart.
Proposed: domain/entities/offline_trip_manifest.dart; domain/repositories/offline_trip_repository.dart; domain/usecases/download_offline_trip.dart (under same traveler feature).
Test: test/features/traveler/domain/offline_trip_package_test.dart.
Define byte budget, complete/incomplete lifecycle, refresh retention and typed failures. No Flutter, Dio or storage imports.
Verify: flutter test test/features/traveler/domain.
Done: boundary and transition tests pass; no empty abstractions created.

### 3. Durable local storage
Proposed traveler data files: datasources/offline_trip_local_data_source.dart, models/offline_trip_manifest_model.dart.
Tests: test/features/traveler/data/offline_trip_local_data_source_test.dart.
Implement app-private account partitions, staging, integrity verification, atomic publication, recovery and reference-safe removal. Add direct storage/free-space dependency only after checking existing platform infrastructure; update pubspec.yaml/native backup exclusions as necessary and document.
Verify focused test; native restart/crash tests after integration.
Done: failed refresh/cancel/crash cannot destroy committed data or publish partial data.

### 4. Authorized snapshot and version coordination
Proposed: traveler/data/datasources/offline_trip_remote_data_source.dart and data/repositories/offline_trip_repository_impl.dart.
Reuse centralized authenticated Dio and existing itinerary/POI DTOs/mappers. Follow BE A/B version protocol, pin returned ID/version, fetch bounded referenced data and map-service routes; no raw HTTP in Cubit.
Test: test/features/traveler/data/offline_trip_repository_impl_test.dart.
Verify focused test covering race, forbidden/missing data, provider failure and interrupted transfer.
Done: reproducible complete snapshot; documented non-atomic POI boundary matches approval.

### 5. Real storage/download orchestration
Complete repository integration with feasibility-tested Mapbox adapter and device free-space source. Measure all components, handle cancellation/late completion, cleanup, retry, disk growth and temporary refresh capacity.
Extend repository tests; run native gate again only when integration changes justify it.
Done: no fake free-space values, simulated progress or quota-only success check in production.

### 6. Cubit and screen
Modify:
- lib/features/traveler/presentation/cubit/offline_trip_package_cubit.dart
- lib/features/traveler/presentation/pages/offline_trip_package_page.dart
- lib/core/di/service_locator.dart
Tests:
- test/features/traveler/presentation/cubit/offline_trip_package_cubit_test.dart
- test/features/traveler/presentation/pages/offline_trip_package_page_test.dart
Inject use cases/repository. Local-first opening, progress, cancel/remove confirmation, update/retry and localized messages. Retain demo fixtures only under explicit existing demo controls.
Verify both focused tests.
Done: real persisted state drives UI; no raw backend/MSG/BR text.

### 7. Entry points, session isolation and cached readers
Modify relevant existing routes/guards:
- lib/app/router/app_routes.dart
- lib/app/router/app_router.dart
- lib/app/router/route_guards.dart
- lib/features/traveler/presentation/widgets/traveler_home_dashboard_view.dart
- lib/features/traveler/presentation/widgets/traveler_profile_view.dart
- lib/features/traveler/presentation/cubit/active_trip_cubit.dart only for approved read-only cached integration
Remove hardcoded itinerary1. Route Home/Profile shortcuts to the dedicated local package list and add download entry to itinerary details. Connect itinerary/map reader to committed snapshot; restrict offline session exception to approved read-only surfaces. Do not enable offline server mutations or globally relax guards.
Add focused route/account isolation and local reader tests under test/app/router/ and test/features/traveler/.
Done: same-account offline restart works under approved policy; logout/other-account/deep links cannot bypass isolation.

### 8. End-to-end validation and documentation
Run flutter pub get; dart format --set-exit-if-changed .; flutter analyze; flutter test; flutter build apk --debug.
Manual Android: download → airplane mode → force-stop/restart → map/POI/route; refresh success/failure; cancel; remove; low space; logout/account switch; permission denial; reconnect superseded version; small screen/large text.
Update README.md for configuration and measured coverage limitations; revise UC16 status in specs/mobile-active-trip-uc13-uc16-spec.md only for implemented behavior.
Done: all acceptance cases have results; native limitations explicitly disclosed. No generated files, secrets, APK or environment files committed. No commit/push/merge without request.

## Mandatory atomic execution breakdown
The numbered sections above describe workstreams, not single implementation tasks. Execute the following units sequentially. Paths below are relative to lib/features/traveler/ unless prefixed otherwise; test paths are relative to test/features/traveler/. For each row run flutter test with the exact listed test path, then review spec compliance and code quality before proceeding. New files are proposed, not existing implementation claims.

| Unit | Files | Focused test / completion criterion |
| --- | --- | --- |
| 1a Provider coverage | data/datasources/offline_map_data_source.dart | integration_test/uc16_offline_map_test.dart (repository root): 1 km / zoom10–16 real cached style/tiles bound to map after airplane-mode restart |
| 1b Provider lifecycle | same adapter | same native test: cancellation stops work, size includes required resources, removal does not break a second package; stop if unsupported |
| 2a Manifest/budget | domain/entities/offline_trip_manifest.dart; domain/entities/offline_trip_package.dart | domain/offline_trip_package_test.dart: byte boundaries, required components, returned ID/version |
| 2b Operation contract | domain/repositories/offline_trip_repository.dart; domain/usecases/download_offline_trip.dart | domain/download_offline_trip_test.dart: cancellation/failure/refresh outcomes; no platform dependencies |
| 3a Account files | data/datasources/offline_trip_local_data_source.dart; data/models/offline_trip_manifest_model.dart | data/offline_trip_local_data_source_test.dart: isolated account lookup and durable serialization |
| 3b Atomic recovery | same local source | same test: staging crash, corrupt manifest, atomic swap and old-version retention |
| 3c Removal | same local source and map adapter | same local test plus native test: resource references and no cross-package deletion |
| 4a Remote snapshot | data/datasources/offline_trip_remote_data_source.dart | data/offline_trip_remote_data_source_test.dart: authorized reads, missing POI/coordinates, resolved version |
| 4b Version coordination | data/repositories/offline_trip_repository_impl.dart | data/offline_trip_repository_impl_test.dart: itinerary A/B race, POI timestamps, forbidden responses; no mixed-version publication |
| 5a Space reservation | data/datasources/offline_device_storage_data_source.dart; repository implementation | data/offline_device_storage_data_source_test.dart: real free-space adapter mapping; repository test: 150 MB minimum and old+new scratch space |
| 5b Download lifecycle | repository implementation | repository test: duplicate starts, late callbacks, network failure/cancel and final measured budget; no partial Available |
| 5c Refresh | repository implementation | repository test: complete replacement, failed/cancelled replacement preserves old; removal and refresh cannot race |
| 6a Cubit | presentation/cubit/offline_trip_package_cubit.dart | presentation/cubit/offline_trip_package_cubit_test.dart: real repository events, progress, retry, cancellation and no false success |
| 6b Package UI | presentation/pages/offline_trip_package_page.dart | presentation/pages/offline_trip_package_page_test.dart: local-first detail, confirmation controls, failures, progress semantics and large text |
| 7a Local list | presentation/pages/offline_packages_page.dart; presentation/cubit/offline_packages_cubit.dart | presentation/cubit/offline_packages_cubit_test.dart; presentation/pages/offline_packages_page_test.dart: retained packages/empty/error and offline restart discovery with zero HTTP calls |
| 7b Entry routes | lib/app/router/app_routes.dart; lib/app/router/app_router.dart; presentation/widgets/traveler_home_dashboard_view.dart; presentation/widgets/traveler_profile_view.dart; presentation/pages/itinerary_detail_page.dart | test/app/router/offline_package_routes_test.dart (root): real selected IDs, Home/Profile local list, no ID1 fallback |
| 7c Session policy | lib/app/router/route_guards.dart; lib/features/auth/presentation/cubit/auth_session_cubit.dart only if required for retained identity | test/app/router/offline_package_access_test.dart (root): expired offline same-account read, logout denial, switch isolation; online 401 is not itinerary revocation |
| 7d Cached reader | presentation/pages/offline_itinerary_page.dart; presentation/pages/offline_itinerary_map_page.dart | presentation/pages/offline_itinerary_page_test.dart; presentation/pages/offline_itinerary_map_page_test.dart: itinerary/POI/route from local repository and GPS permission state; no network navigation mutations |
| 7e Access revalidation | offline repository implementation; offline_packages_cubit.dart | repository and list Cubit tests: authoritative denial locks affected package, timeout/5xx does not delete or misclassify it |
| 8 Wiring/regression | lib/core/di/service_locator.dart; README.md; relevant feature status documentation | full checks from section8 and native lifecycle matrix; registrations added when each unit first needs them, not postponed until end |

Before changing auth/session or native storage files, inspect their existing contracts and document the smallest required change. Provider-dependent Android configuration paths and any new plugin must be identified during unit1 and added to this plan before modifying them. A lack of native support is a blocking finding, not permission to ship demo cancellation.

## Execution record — 2026-11-22 to 2026-11-23
- Initial analyzer found no pre-existing issues; its reported missing files were newly introduced red-test imports. Focused remote snapshot tests verified red before implementation, then 6 passed.
- Independent manifest/local storage tests verified red before implementation, then 9 passed before additional review fixes. Direct crypto dependency was declared for SHA-256 integrity checks.
- BE existing reads remain the contract. A/B checks include essential-field fingerprint because status may change without a version increment. Rest items can have null coordinates; manual itinerary schedulingRequestId may be zero.
- Native cancellation requires an app-owned Android bridge: the pinned Flutter API discards SDK Cancelable handles. Its persisted StylePack conversion also reports resource count in the size field, so the bridge reads native byte values directly.
- Approved native implementation paths: android/app/src/main/kotlin/com/tripmate/trip_mate_mobile/OfflineMapChannel.kt; MainActivity.kt in the same directory; android/app/build.gradle.kts. No installed plugin source or user emulator data is replaced.
- The user supplied public Mapbox configuration; it is stored only in git-ignored config/mapbox.local.json. Build/run uses --dart-define-from-file. Token values must not enter commits or logs.
- Production repository orchestration, local package list/readers, account/route policy and entry points are implemented with focused tests. Existing demo behavior is retained only under the explicit demo path. Final cold-offline rendering, complete regression verification and the main-entry APK remain release gates.
- Real Android online SDK gate passed: 5 tests passed, 1 cold-offline phase skipped, exit 0. Required resources measured 6,012,955 style bytes + 25,042,237 tile bytes = 31,055,192 bytes. Tests verified native download, preflight cancellation protecting an existing region, shared-style preservation and cancellation cleanup. This does not by itself prove cold offline rendering.
- Focused implementation evidence before final review: repository 15 tests, remote/HTTP cancellation 9 tests, UI 17 tests + 49 legacy regressions, auth/guard 118 combined tests; final auth race fixes passed 11 targeted tests. Final review corrections and global checks are recorded below when complete.

### Unit 1 native bridge implementation detail
Inspection of pinned 3.33.0 Android source showed that the Flutter plugin discards native download Cancelable handles and incorrectly maps persisted style-pack byte size to resource count. Implement a small app-owned bridge instead of editing the Pub cache or forking the plugin. Files: android/app/src/main/kotlin/com/tripmate/trip_mate_mobile/OfflineMapChannel.kt, MainActivity.kt (registration only), android/app/build.gradle.kts (explicit same-version Mapbox native dependency), lib/features/traveler/data/datasources/offline_map_data_source.dart, test/features/traveler/data/offline_map_data_source_test.dart and integration_test/uc16_offline_map_test.dart. Use one no-backup app TileStore root, configured before creating maps; serialize download operations and preserve shared styles. Native bridge retains/cancels real SDK handles, reports native style/tile bytes and checks complete region descriptor coverage. This is an app bridge with the pinned SDK, not a plugin upgrade. Actual Android coverage/restart evidence remains a gate.

Fresh lifecycle review requires a cancellation latch across Dart initialization and late native success, plus one process-wide native mutation gate across preflight, download, removal and cleanup. Additional exact paths: android/app/src/main/kotlin/com/tripmate/trip_mate_mobile/OfflineMapOperationGate.kt and android/app/src/test/kotlin/com/tripmate/trip_mate_mobile/OfflineMapOperationGateTest.kt. Declare JUnit 4.13.2 as an Android test-only dependency. Tests must prove preflight cancellation cannot own/delete an existing region and asynchronous cleanup prevents a new mutation, including after activity disposal. These focused tests do not replace the token-dependent map gate.

### Final review and Android evidence — 2026-11-23
- Final independent review findings were fixed: publication uses a monotonic per-account sequence rather than wall-clock ordering; delayed authorization failures cannot lock data belonging to a previous session. Local/repository regression tests: 31 passed.
- Cancellation is accepted until the atomic publication boundary. During `publishing`, cancellation is rejected and the UI disables it; an already committed generation is never reported as cancelled.
- Concrete implementation paths supersede proposed names in the task table: `offline_trip_manifest.dart` contains the package model; `live_offline_package_cubit.dart` coordinates the production package page; device space is obtained by `offline_map_data_source.dart` through the Android bridge. Cubits depend on the Domain repository; no empty forwarding use-case wrappers were introduced.
- Fresh native online phase: 6 passed, 1 skipped. Cold offline phase on the same installed APK after force-stop: 3 passed, 4 skipped. Networking was airplane=1, Wi-Fi=0, data=0; retained bytes and MapLoaded assertions passed, and the screenshot showed real streets/buildings/POIs. Original network flags 0/1/1 were restored and verified. These are complementary phase selections, not skipped coverage silently treated as passed.
- Real style/tile resources total 31,055,192 bytes. Native cancellation/shared-style preservation passed in the preceding live phase. Five isolated Kotlin lifecycle tests passed; a complete Gradle JVM test task is not claimed.
- The test harness's old boolean comparison produced incorrect success metadata although actual assertions and `All tests passed!` were green. The source now uses `failureMethodsDetails.isEmpty`; raw logs are preserved and the evidence record distinguishes this metadata correction. Nonfatal plugin event-expiry RangeError logs appeared during rendering; the map loaded and remained visible.
- The initial SDK gate uses a labelled geographic fixture. The subsequent live-account check below verifies the production path against the local backend; automated tests cover the broader failure/account matrix.
- Final global verification: `flutter pub get` passed; `dart format --output=none --set-exit-if-changed .` passed (990 files, zero changes); direct SDK `dart analyze` passed with no issues. The direct analyzer was used after a stale Flutter wrapper process blocked startup; it analyzes the same package and rules. `flutter test --no-pub --concurrency=2` passed: 3,003 tests, 6 skipped, zero failures (3m59s).
- Final `flutter analyze --no-pub` also passed with no issues after the wrapper lock was released. Format verification repeated after the last harness correction: 990 files, zero changes.
- Main application APK: `flutter build apk --debug --no-pub -t lib/main.dart --dart-define-from-file=config/mapbox.local.json` passed (65.3s), using process-local Java memory limits and one Gradle worker. Output is `build/app/outputs/flutter-apk/app-debug.apk`; this final artifact uses the production application entry point, not the integration-test harness. Local public-token configuration stays ignored. No commit or push performed.

### Live local backend acceptance — 2026-11-23
- User authorized backup and synchronization of existing local SQL migrations. Native SQL COPY_ONLY/CHECKSUM backup passed RESTORE VERIFYONLY and was copied to the host before changes. Existing business table row counts were unchanged after migration; the ledger increased from 80 to 88 rows.
- Local schema drift blocked TM-95 safely and rolled back: `Users.status_before_lock` was nullable nvarchar(24), while the checked migration requires varchar(24). Verified there were no non-null values, no dependent checks/indexes, then performed a guarded local conversion and reconciled the rolled-back ledger intent. No application migration file was edited.
- Production app on emulator: authorized `GET /api/v1/itineraries/41420` returned 200; public tour search returned 200. Downloaded itinerary 41420 with live POI and routing reads into a 31.1 MB package.
- Enabled airplane mode and disabled Wi-Fi/mobile data, force-stopped and relaunched the same main APK. Home -> Dữ liệu offline found the retained package. Opened cached itinerary, saved POI opening hours and map with POI markers/planned route; screenshot confirmed visible map while offline. Original network configuration was restored. Package retained for the user's testing; no logout, app-data wipe or uninstall was performed.
