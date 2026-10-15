# UC-13 Navigate Route — Mobile Implementation Plan

Spec: `specs/UC-13-navigate-route-mobile-spec.md`.

## Tasks

1. **Domain** (`lib/features/traveler/domain/`)
   - `entities/navigation_session.dart`: `NavigationSession`, `NavigationSessionItem`, state,
     completion-reason and item-status enums.
   - `entities/navigation_route.dart`: `NavigationCoordinate`, `NavigationRoute`, `NavigationStep`.
   - `repositories/navigation_session_repository.dart`, `repositories/route_directions_repository.dart`.
   - `services/navigation_location_tracker.dart`: permission + position stream contract.
   - `services/geo_distance.dart`, `services/arrival_detector.dart`,
     `services/route_progress_tracker.dart` (pure Dart).
   - `core/error/failures.dart`: `NavigationFailure` with `NavigationFailureReason`.
   - Verify: unit tests for arrival detector, route progress, geo distance.
2. **Data** (`lib/features/traveler/data/`)
   - `models/navigation_session_model.dart`, `models/mapbox_directions_model.dart`.
   - `repositories/navigation_session_repository_impl.dart` (DioClient, error-code mapping).
   - `repositories/mapbox_directions_repository_impl.dart` (separate Dio, token query parameter).
   - `services/geolocator_navigation_location_tracker.dart`.
   - Verify: model tests + repository tests with a recording `HttpClientAdapter`.
3. **Config & DI**
   - `AppConfig.mapboxAccessToken` (`MAPBOX_ACCESS_TOKEN`, rejects `sk.`), `MapboxOptions.setAccessToken`
     in `bootstrap.dart`, registrations in `service_locator.dart`.
   - Verify: `app_config` tests.
4. **Presentation**
   - Rewrite UC-13 parts of `ActiveTripCubit`/`ActiveTripState` around the session (keep UC-14/15
     demo behaviour); remove `ActiveTripWaypoint` in favour of `NavigationSessionItem`.
   - `demo/demo_navigation_session_repository.dart` (in-memory, DEMO_ONLY).
   - `ActiveTripPage`: start/resume/conflict/error screens, target card, exploring card, stop list
     actions, arrival prompt, skip/finish confirmations, completion summary, feedback snackbars.
   - `widgets/mapbox_navigation_map.dart` + updated `NavigationMapCanvas` fallback.
   - Verify: cubit tests with fake repository/tracker/directions; page widget tests.
5. **Platform**: `pubspec.yaml` (`mapbox_maps_flutter`), iOS `NSLocationWhenInUseUsageDescription`.
6. **Verification**: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`,
   `flutter test`, `flutter build apk --debug` (Android runtime affected).
