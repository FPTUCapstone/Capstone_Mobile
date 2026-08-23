# TripMate Mobile Codebase Rules

This document is the engineering source of truth for the TripMate Flutter mobile
codebase. It applies to code written for Travelers and Tour Operators.
Administrator functionality and routes belong exclusively to the separate
Next.js Web Administration System.

## Current Technology and Status

The repository currently uses:

- Flutter and Dart with null safety;
- Material 3;
- feature-first Clean Architecture;
- `flutter_bloc` and Cubit;
- `go_router`;
- `get_it`;
- Dio and `connectivity_plus`;
- `flutter_secure_storage` and `shared_preferences`;
- `equatable`, `json_annotation`, and `json_serializable`;
- `flutter_lints`, `bloc_test`, and Flutter's test framework.

The current login, onboarding, Traveler, and Tour Operator pages are architecture
placeholders. The repository does not yet contain production authentication,
backend endpoints, business DTOs/repositories, or completed TripMate features.
Rules for those components govern future implementation; they do not claim the
components already exist.

## Clean Architecture

The logical layers are Presentation, Domain, and Data. Runtime collaboration
usually follows:

```text
Page -> Bloc/Cubit -> Use Case -> Repository contract
                                      ^
                                      |
                       Repository implementation -> Data Source -> Dio/storage
```

Source dependencies point inward:

```text
Presentation -> Domain <- Data
```

- Presentation may import Domain.
- Data may import Domain and implement its contracts.
- Domain must not import Presentation or Data.
- Domain must remain independent from Flutter widgets, Dio, JSON serialization,
  SharedPreferences, secure-storage plugins, and platform UI.

Do not bypass these boundaries for convenience. UI must not call Dio, and a
BLoC/Cubit must not contain HTTP endpoint implementation or instantiate a data
repository directly.

### Presentation

Presentation owns Pages, feature widgets, BLoCs/Cubits, UI states, and routing
integration. It coordinates user intent and renders loading, success, empty, and
error states. It calls use cases or, for genuinely simple behavior, a Domain
repository abstraction. It does not perform raw infrastructure work.

### Domain

Domain owns entities, repository interfaces, use cases, and framework-independent
business rules or failures. Domain entities express TripMate concepts; they are
not API DTOs merely because their fields currently look similar.

Domain must not import:

- `package:flutter/...`;
- Dio;
- `shared_preferences`;
- `flutter_secure_storage`;
- JSON serialization or platform-specific code.

### Data

Data owns API/local DTOs, remote and local data sources, repository
implementations, and mappers.

- A remote data source communicates with the backend through approved network
  infrastructure.
- A local data source communicates with approved persistence infrastructure.
- A repository implementation coordinates sources, translates infrastructure
  errors, and maps Data models into Domain entities.

Keep the transformation explicit:

```text
API JSON -> DTO/Data Model -> Mapper -> Domain Entity -> Presentation
```

An API contract change should not break Domain unnecessarily. Do not use one
class as JSON payload, persistence model, Domain entity, and UI state.

## Feature-First Organization

Business functionality belongs under `lib/features/<feature>/`. Use this shape
when all responsibilities are needed:

```text
lib/features/<feature>/
|-- data/
|   |-- datasources/
|   |-- models/
|   `-- repositories/
|-- domain/
|   |-- entities/
|   |-- repositories/
|   `-- usecases/
`-- presentation/
    |-- bloc/
    |-- pages/
    `-- widgets/
```

The shape is a guideline, not a file-generation target. Do not create empty
layers, folders, DTOs, repositories, use cases, or abstractions before behavior
requires them. Cubit folders may be named `cubit/` where that is clearer and
consistent with the existing feature.

### `lib/core/`

`core` is reserved for application-wide infrastructure and low-level reusable
abstractions: network, storage, error translation, dependency injection,
configuration, constants, base use-case types, and genuinely cross-feature
utilities.

Feature business logic does not belong in `core`. For example,
`core/tour_booking_service.dart` is forbidden; Tour Booking logic belongs under
`features/tour_booking/`.

### `lib/shared/`

`shared` is for UI components or simple resources genuinely reused across
features. A widget used only by Tour Booking stays in that feature. Move a
component to `shared` after real reuse exists, not in anticipation of reuse.

## Role Boundaries

- Traveler features and screens must remain within Traveler-relevant features.
- Tour Operator features represent commercial travel providers and must remain
  separate from Traveler behavior.
- A Group Host is a Traveler role within Travel Group functionality. A Group
  Host is not a Tour Operator.
- Administrator features, navigation, entities, and authorization paths must not
  be added to Flutter.

Role-aware UI is not backend authorization. Hiding a control never replaces
server-side authorization when APIs are integrated.

## BLoC and Cubit

`flutter_bloc` is the primary state-management framework.

Use Cubit for simple state transitions, straightforward UI/application state,
and low-complexity feature state. Use Bloc when explicit events matter, a
workflow has multiple transitions, async business processing is complex, or
event traceability improves maintenance.

Do not introduce Provider, Riverpod, GetX, MobX, or another competing primary
state framework without explicit team approval. Transitive dependencies do not
make a package an approved application framework.

BLoCs/Cubits coordinate state. They may validate presentation input and invoke
Domain behavior, but they must not:

- call raw Dio or implement endpoints;
- read/write plugin storage directly;
- build widgets or receive `BuildContext`;
- instantiate repositories or infrastructure;
- become a single application-wide container for unrelated feature state;
- swallow exceptions or emit raw technical messages to the UI.

Prefer feature-scoped providers. Use global providers only for truly
application-wide state such as the current session.

## Dependency Injection

Use the existing `get_it` service locator. Register application infrastructure
centrally and use focused feature registration when a feature gains multiple
dependencies. Respect ownership and lifecycle: prefer factories for short-lived
presentation state and lazy singletons only for genuinely shared services.

Never repeatedly instantiate infrastructure in Pages or widgets. These are
forbidden:

```dart
final dio = Dio();
final repository = TourRepositoryImpl(...);
```

inside UI code.

## Routing and Navigation

Use `go_router` and centralized route constants/names. Do not scatter literal
route strings across Pages. Preserve conceptual scopes:

```text
/auth/*
/traveler/*
/operator/*
```

Navigation and redirect logic must respect session and role boundaries.
Administrator routes must never exist in Flutter. Deep links must pass through
the same checks as in-app navigation. Backend authorization remains
authoritative for protected operations.

Add a new Page only for a separate logical screen. The screen inventory does
not require one Page per entry or one Page per use case; actions, modals,
background processes, and external gateway flows may not be Pages.

## Networking and API Contracts

Use the centralized Dio client, base options, interceptors, and error mapping.
Do not create arbitrary Dio instances across features unless an exceptional
integration is documented and approved.

Base URLs come from centralized environment configuration. Never hard-code
localhost URLs, production endpoints, access tokens, API keys, or credentials in
feature code.

When integrating an API:

1. Obtain and follow the backend contract.
2. Model nullability and error responses accurately.
3. Do not invent fields, silently rename domain concepts, or fake a production
   contract.
4. Keep JSON details in Data and map DTOs to Domain entities.
5. Translate network/server exceptions into application failures and then safe
   UI states.

If the backend contract is unknown, stop and document the dependency. A local
fixture may be used only when the task explicitly calls for a mock and it is
clearly labeled as non-production.

## Storage and Environment

Access tokens, refresh tokens, and security credentials must use the existing
secure-storage abstraction. Never store them in SharedPreferences.
SharedPreferences is limited to non-sensitive preferences such as theme,
onboarding flags, and simple UI choices.

Configuration must remain centralized. Never commit real secrets. Example
environment files may contain placeholders only. When adding a required config
value, update its central definition, placeholder example when present, and
README/setup documentation.

## Failure and Error Handling

Use consistent application failures, including categories such as network,
server, authentication, validation, permission, and unknown failures where the
feature requires them. Extend the common model deliberately rather than passing
raw exceptions through Presentation.

User interfaces must not expose exceptions, stack traces, internal HTTP details,
server implementation information, or sensitive data. Log only appropriate
diagnostics and ensure production logging cannot leak tokens or personal data.

## UI and Responsive Design

Use Material 3 and the centralized TripMate theme. Reuse approved color,
typography, spacing, and shape tokens instead of repeating magic values.

Data-driven screens must deliberately handle loading, success, empty, and error
states. Handle permission and retry states where relevant.

Design for reasonable Android screen sizes rather than one device. Account for:

- safe areas and system insets;
- on-screen keyboard behavior;
- small screens and orientation where applicable;
- long/localized text and text scaling;
- scrolling and content overflow;
- touch targets and accessibility semantics.

Avoid unnecessary fixed widths and heights.

Pages own screen-level composition. Widgets own meaningful smaller UI units.
Avoid large, multi-responsibility Pages, but do not extract every three-line
fragment merely to increase file count. Prefer readable cohesion over artificial
abstraction.

## Dart Style and Safety

- Use `snake_case.dart` filenames, `PascalCase` types, `camelCase` members, and
  `_leadingUnderscore` private identifiers.
- Follow the repository analyzer configuration and use package imports for
  project-level imports. Avoid fragile chains such as `../../../../../../`.
- Keep imports ordered and remove unused imports.
- Preserve null safety. Avoid forced `!` assertions; prove or safely handle
  nullability rather than silencing the analyzer.
- Handle Futures explicitly and do not discard asynchronous errors. Before
  updating UI after async work, account for widget lifecycle or current Bloc
  state as appropriate.
- Do not silently catch exceptions. Translate, recover, or rethrow them at the
  correct boundary.
- Keep classes focused, remove dead code, and avoid duplication where a clear
  reusable abstraction already exists.

Examples:

```text
tour_details_page.dart -> TourDetailsPage
tour_booking_bloc.dart -> TourBookingBloc
```

## Testing

Test behavior at the lowest useful layer:

- Domain rules and use cases: unit tests;
- BLoC/Cubit transitions: bloc tests;
- rendering and user interaction: widget tests;
- critical cross-system flows: integration tests when the integration exists.

New complex business rules should normally have focused tests. Cover important
success, error, empty, and edge cases. Do not write meaningless assertions to
increase test counts, and do not replace behavior tests with implementation
detail tests.

Mirror feature organization under `test/` where practical. Keep helpers focused
and avoid global mutable test state.

## Scope Discipline

Implement only the assigned task. The SRS and screen inventory provide context,
not permission for premature work. A setup task must not silently grow Google
Maps, payment, QR scanning, booking, CSP/FSM, weather, offline synchronization,
or any other unassigned feature.

## Required Validation

Before a Pull Request:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run `flutter build apk --debug` when Android runtime, plugins, native files, or
build configuration are relevant and tooling is available. All applicable checks
must pass. Report environmental limitations exactly.

The Git workflow, review checklist, Pull Request requirements, commit convention,
and Definition of Done are maintained in [CONTRIBUTING.md](../CONTRIBUTING.md).
