# TripMate Mobile

TripMate Mobile is the Flutter application for Travelers and Tour Operators in
the TripMate Smart Travel Planner & Travel Services Platform. This repository
currently contains the production-oriented application foundation and
intentionally does not contain real business features or backend integrations.

## Mobile Scope

Planned Traveler functionality includes:

- Smart trip planning and navigation
- Travel groups
- Tour discovery and booking
- Trip history and reviews

Planned Tour Operator functionality includes:

- Business onboarding
- Tour and customer-booking management
- QR participant check-in
- Revenue and payout

These capabilities describe the planned mobile product scope; they are not
implemented by the current architecture setup. Administrator functions are
implemented separately in the Next.js Web Administration System.

## Tech Stack

- Flutter and Dart
- Material 3
- Feature-first Clean Architecture
- `flutter_bloc` for BLoC/Cubit state management
- `go_router` for navigation
- `get_it` for dependency injection
- Dio and `connectivity_plus` for the networking foundation
- `flutter_secure_storage` and `shared_preferences` for local storage
- `equatable`, `json_annotation`, and `json_serializable`

## Architecture

The project uses Flutter with Material 3, feature-first Clean Architecture,
and BLoC/Cubit state management.

Dependencies point inward:

```text
Presentation -> Domain <- Data
```

- **Presentation** owns pages, widgets, Cubits/BLoCs, UI state, and routing
  integration. Presentation code depends on domain contracts or use cases when
  business behavior is introduced.
- **Domain** owns framework-independent entities, repository contracts, use
  cases, and failures. It does not depend on Flutter UI or JSON DTOs.
- **Data** will own DTOs, data sources, mappers, and repository implementations.
  It is intentionally not populated until real feature behavior is added.
- **Core** contains reusable infrastructure such as Dio, storage, dependency
  injection, errors, and validation. It contains no TripMate business feature.

`AuthSessionCubit` is a deliberately small routing preview, not authentication.
Future business flows should receive feature-specific BLoCs/Cubits and use cases;
the app must not grow a single global business-state BLoC.

## Project Structure

```text
lib/
|-- main.dart
|-- app/
|   |-- app.dart
|   |-- bootstrap.dart
|   |-- config/
|   |   |-- app_config.dart
|   |   `-- environment.dart
|   |-- router/
|   |   |-- app_router.dart
|   |   |-- app_routes.dart
|   |   `-- route_guards.dart
|   `-- theme/
|       |-- app_colors.dart
|       |-- app_spacing.dart
|       |-- app_theme.dart
|       `-- app_typography.dart
|-- core/
|   |-- constants/
|   |   |-- api_constants.dart
|   |   `-- app_constants.dart
|   |-- di/service_locator.dart
|   |-- error/
|   |   |-- error_mapper.dart
|   |   |-- exceptions.dart
|   |   `-- failures.dart
|   |-- network/
|   |   |-- dio_client.dart
|   |   |-- network_info.dart
|   |   `-- interceptors/
|   |       |-- auth_interceptor.dart
|   |       `-- logging_interceptor.dart
|   |-- storage/
|   |   |-- preferences_service.dart
|   |   `-- secure_storage_service.dart
|   |-- usecase/usecase.dart
|   `-- utils/validators.dart
|-- features/
|   |-- auth/
|   |   |-- domain/entities/user_role.dart
|   |   `-- presentation/
|   |       |-- cubit/
|   |       |   |-- auth_session_cubit.dart
|   |       |   `-- auth_session_state.dart
|   |       `-- pages/
|   |           |-- login_page.dart
|   |           |-- registration_page.dart
|   |           `-- splash_page.dart
|   |-- tour_operator/presentation/pages/operator_shell_page.dart
|   `-- traveler/presentation/pages/traveler_shell_page.dart
`-- shared/widgets/
    |-- app_button.dart
    |-- app_text_field.dart
    |-- error_view.dart
    `-- loading_indicator.dart

test/
|-- app_bootstrap_test.dart
|-- core/utils/validators_test.dart
`-- features/auth/presentation/cubit/auth_session_cubit_test.dart
```

Feature `data/` and additional `domain/` directories should be added only when
the feature has real data mapping, repository contracts, and use cases. This
keeps the architecture explicit without accumulating empty abstractions.

## Routing

Routes are centralized in `AppRoutes`:

- `/` — splash/bootstrap placeholder
- `/auth/login` — sign-in placeholder and role-shell preview
- `/auth/register/traveler` — Traveler registration placeholder
- `/auth/register/operator` — Tour Operator onboarding placeholder
- `/traveler` — Traveler navigation shell
- `/operator` — Tour Operator navigation shell

`RouteGuards` is the extension point for future authenticated session and role
checks. The current Cubit state exists only to demonstrate unauthenticated,
Traveler, and Tour Operator navigation boundaries.

## Configuration

Configuration uses compile-time Dart defines. Defaults are safe for local setup:

```text
APP_ENV=development
API_BASE_URL=https://api.example.invalid
```

Supported environments are `development`, `staging`, and `production`. Supply a
real non-secret base URL per environment at run or build time:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://api.example.invalid
```

Do not place tokens or secrets in Dart defines or source control.

## Storage and Networking

- `flutter_secure_storage` is reserved for access and refresh tokens.
- `shared_preferences` is only for non-sensitive user preferences.
- Dio receives its base URL and timeouts from centralized configuration.
- An authorization interceptor is prepared to read a future access token.
- Network logs are enabled outside production, and infrastructure errors can be
  translated to safe `Failure` values.

No API endpoint or authentication flow is implemented yet.

## Getting Started

```bash
flutter pub get
flutter run
```

## Code Quality

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

For Android debug verification:

```bash
flutter build apk --debug
```

## Development Status

- Implemented: application bootstrap, architecture boundaries, dependency
  injection, routing foundation, role-separated placeholder shells, shared
  theme/widgets, networking/storage abstractions, and automated tests.
- Placeholder only: login, registration/onboarding, Traveler navigation, and
  Tour Operator navigation UI.
- Not present: mock business data, production authentication, backend API
  endpoints, or completed TripMate business features.
- Planned: repository/use-case implementations, DTO mapping, session
  restoration, backend integration, and feature-specific BLoCs/Cubits.

## Repository

Official repository:
[FPTUCapstone/Capstone_Mobile](https://github.com/FPTUCapstone/Capstone_Mobile)
