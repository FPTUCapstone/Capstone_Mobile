# TripMate Mobile

TripMate Mobile is the Flutter application for Travelers and Tour Operators in
the TripMate Smart Travel Planner & Travel Services Platform. This repository
contains the production-oriented application foundation, several integrated
authentication flows, and remaining local demo screens. UC-02 Tour Operator
registration is wired to Firebase and the BE endpoint; manual end-to-end
verification still requires a configured environment.

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
- **Data** owns DTOs, data sources, mappers, and repository implementations for
  integrated features.
- **Core** contains reusable infrastructure such as Dio, storage, dependency
  injection, errors, and validation. It contains no TripMate business feature.

`AuthSessionCubit` manages the app session. Account data it persists (name,
email, Tour Operator application status) is restored only when it is bound to
the Backend-issued `userId` of the persisted session. The operator application
status page shows the Backend-issued status from that session; the UC-02
registration wizard uses its own Cubit and does not create an authenticated
TripMate session. The app does not use a single global business-state BLoC.

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
|   |       |   |-- auth_session_state.dart
|   |       |   `-- password_demo_cubit.dart
|   |       |-- demo/auth_demo_data.dart
|   |       `-- pages/
|   |           |-- login_page.dart
|   |           |-- traveler_registration_page.dart
|   |           |-- operator_registration_page.dart
|   |           |-- operator_application_page.dart
|   |           |-- reset_password_page.dart
|   |           |-- change_password_page.dart
|   |           |-- demo_screen_index_page.dart
|   |           `-- splash_page.dart
|   |-- tour_operator/presentation/pages/operator_shell_page.dart
|   `-- traveler/presentation/
|       `-- pages/
|           |-- traveler_shell_page.dart
|           |-- traveler_settings_page.dart
|           |-- traveler_profile_page.dart
|           `-- travel_preferences_page.dart
`-- shared/widgets/
    |-- app_button.dart
    |-- app_alert.dart
    |-- app_page_scaffold.dart
    |-- app_password_field.dart
    |-- app_text_field.dart
    |-- error_view.dart
    |-- loading_indicator.dart
    `-- status_badge.dart

test/
|-- app_bootstrap_test.dart
|-- core/utils/validators_test.dart
|-- features/auth/presentation/cubit/auth_session_cubit_test.dart
`-- features/auth/presentation/pages/demo_auth_flows_test.dart
```

Feature `data/` and additional `domain/` directories should be added only when
the feature has real data mapping, repository contracts, and use cases. This
keeps the architecture explicit without accumulating empty abstractions.

## Routing

Routes are centralized in `AppRoutes`:

- `/` — bootstrap redirect
- `/auth/login` — local demo sign-in
- `/auth/register/traveler` — Traveler registration demo
- `/auth/register/operator` — UC-02 Tour Operator registration wizard (requires the UC-02 BE branch and configured Firebase/Web verification)
- `/auth/reset-password` — password reset demo
- `/traveler` — Traveler navigation shell
- `/traveler/settings` — account settings and sign-out confirmation
- `/traveler/profile` — Traveler profile demo
- `/traveler/preferences` — interactive travel preferences
- `/traveler/change-password` — change-password demo
- `/operator` — Tour Operator navigation shell
- `/operator/application` — rejected and pending application states

Debug builds also expose `/demo`, a development-only index for UC-01 through
UC-09. These routes are omitted from release builds.

`RouteGuards` is the extension point for future authenticated session and role
checks. The current Cubit state exists only to demonstrate unauthenticated,
Traveler, and Tour Operator navigation boundaries.

## Configuration

Configuration uses compile-time Dart defines. Defaults are safe for local setup:

```text
APP_ENV=development
API_BASE_URL=https://api.example.invalid
WEB_VERIFICATION_ORIGIN=<web-origin-for-operator-email-verification>
```

Supported environments are `development`, `staging`, and `production`. Supply a
real non-secret base URL per environment at run or build time:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://api.example.invalid \
  --dart-define=WEB_VERIFICATION_ORIGIN=https://your-web-origin.example
```

UC-02 Operator registration uses `WEB_VERIFICATION_ORIGIN` to build the email
continue URL `/verify-email?flow=operator`. Set it to the origin of the Web
application that handles Firebase email verification (scheme, host and optional
port only). Use HTTPS for deployed environments; local HTTP loopback is accepted
only in development or staging. If this value is missing, Operator verification
cannot create a continue URL and must stop safely; no placeholder Web URL is
used. The origin is a public routing value, not a secret. Never put tokens or
credentials in it. The UC-02 wizard selects real PDF/JPG/PNG documents and
sends them to the BE multipart endpoint; the BE stores them in Cloudinary.
If a POST outcome is unknown, the wizard keeps the Firebase identity and
requires explicit same-account recovery. The separate
`/operator/application` page remains demo UI and is not a live status view.

The UC-12 category chips are disabled in production until Backend publishes an approved public category catalogue. `--dart-define=POI_CATEGORY_PREVIEW=true` is only for development preview and cannot enable production category filtering.

Do not place tokens or secrets in Dart defines or source control.

### CI/CD Demo APK Configuration

Automated GitHub Actions CI/CD workflows (PR CI and develop/main CD) build a debug demo APK with the backend endpoint injected at build time. These builds require a GitHub Actions repository variable:

- Variable name: `API_BASE_URL`
- Path in GitHub UI: **Settings** → **Secrets and variables** → **Actions** → **Variables** tab

If `API_BASE_URL` is omitted or empty in GitHub Actions, the workflow fails fast before the build step to prevent distributing an APK with invalid backend routing.

For local Android development without an explicit `API_BASE_URL` define, the app automatically falls back to `http://10.0.2.2:5000` for Android emulator host loopback. When targeting a remote or physical demo backend locally, supply `--dart-define=API_BASE_URL=<backend_url>` explicitly.

## Storage and Networking

- `flutter_secure_storage` is reserved for access and refresh tokens.
- `shared_preferences` is only for non-sensitive user preferences.
- Dio receives its base URL and timeouts from centralized configuration.
- An authorization interceptor is prepared to read a future access token.
- Network logs are enabled outside production, and infrastructure errors can be
  translated to safe `Failure` values.

No API endpoint, OAuth provider, OTP delivery, file upload, or persistent
authentication flow is implemented yet. Demo credentials and transitions are
defined locally in presentation code.

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
  injection, routing foundation, role-separated shells, shared theme/widgets,
  networking/storage abstractions, automated tests, and a UC-02 registration
  wizard wired to Firebase and the BE multipart contract.
- UC-02 integration still requires the BE feature branch, Firebase, a reachable
  Web verification origin, SQL Server, and Cloudinary for manual end-to-end
  evidence; the Admin application collection queue is a separate dependency.
- Prototype only: the separate `/operator/application` status view and some
  screens outside the UC-02 registration flow still use demo data. They are not
  evidence that an application was saved or approved.
- UC-02 sends selected documents to the BE multipart endpoint; the BE owns
  Cloudinary storage. Mobile does not upload directly to Cloudinary.

## Repository

Official repository:
[FPTUCapstone/Capstone_Mobile](https://github.com/FPTUCapstone/Capstone_Mobile)
