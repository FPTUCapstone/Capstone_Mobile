# Contributing to TripMate Mobile

Thank you for contributing to the Flutter application for TripMate Travelers
and Tour Operators. Administrator functionality is outside this repository and
is implemented by the separate Next.js Web Administration System.

The detailed architecture and coding standard is
[docs/CODEBASE_RULES.md](docs/CODEBASE_RULES.md). Human contributors and coding
agents must follow it.

## Prerequisites and Setup

Use a stable Flutter SDK compatible with the constraints in `pubspec.yaml`.

```bash
flutter --version
dart --version
flutter pub get
flutter run
```

Configuration is supplied through the project's centralized configuration and
Dart defines. Never commit real tokens, API keys, credentials, or environment
files. When introducing a required configuration value, document it and add
only a placeholder to an example file if one exists.

## Work from an Assigned Task

Before writing code:

1. Read the task, acceptance criteria, relevant requirements, existing code,
   and tests.
2. Confirm which role and feature own the behavior.
3. Identify the affected Presentation, Domain, and Data responsibilities.
4. Stop and document the dependency if a required backend contract is unknown.
5. Keep the change focused. Do not bundle unrelated backlog work or premature
   SRS/screen-inventory implementation into the same task.

The screen inventory is a planning baseline, not a requirement for one Page per
screen entry or use case. A use case may be an action, modal, background process,
or external-gateway flow. Create a Page only for a separate logical screen.

## Branch Workflow

Do not develop directly on `main`. Start from an up-to-date `main` and create a
focused branch:

```bash
git switch main
git pull --ff-only
git switch -c feature/auth-login
```

Branch format is `<type>/<short-description>` using lowercase kebab-case.
Approved common types are:

- `feature`
- `fix`
- `refactor`
- `chore`
- `docs`
- `test`

Examples include `feature/traveler-itinerary`,
`feature/operator-tour-management`, `fix/booking-validation`,
`refactor/navigation-shell`, and `chore/update-dependencies`.

Never force push shared work or bypass repository protections. Keep generated
artifacts, IDE state, local configuration, and secrets out of Git.

## Development Expectations

- Place business code in `lib/features/<feature>/` and create only the layers
  the behavior requires.
- Preserve Clean Architecture boundaries and use feature-specific BLoCs/Cubits.
- Use existing routing, dependency-injection, network, storage, error, and theme
  infrastructure.
- Keep Traveler and Tour Operator concepts separate. Group Host is a Traveler,
  not a Tour Operator.
- Add focused tests with the change. Complex business rules normally require
  unit tests; BLoCs/Cubits require state-transition tests when behavior changes;
  meaningful UI behavior requires widget tests.
- Update setup, configuration, architecture, or feature-status documentation
  when the change makes it inaccurate.

## Required Validation

Before opening a Pull Request, run:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

When the task affects Android runtime behavior, plugins, native configuration,
or build setup, also run when supported:

```bash
flutter build apk --debug
```

All applicable checks must pass. If an environmental limitation prevents a
check, state the exact limitation in the Pull Request; do not imply it passed.

## Commit Convention

Use Conventional Commits:

```text
<type>(<scope>): <imperative summary>
```

Examples:

- `feat(auth): add traveler login flow`
- `feat(operator): add tour package editor`
- `fix(booking): prevent duplicate cancellation`
- `refactor(navigation): simplify traveler shell`
- `test(auth): add auth cubit tests`
- `docs(readme): update mobile setup`

Avoid messages such as `update`, `done`, `fix`, `final`, `commit`, or `abc`.
Commits should be focused and must not contain secrets or generated build files.

## Pull Requests

Every normal feature or fix goes through a Pull Request. Complete
[the PR template](.github/pull_request_template.md), including:

- what changed and why;
- the related task ID, such as `TM-29` or `TM-xx`;
- affected features, screens, and roles;
- exact tests and manual checks performed;
- screenshots or recordings for UI changes;
- known limitations, placeholders, mocks, and unfinished integration.

Keep a Pull Request small enough to review as one coherent task. Resolve review
comments and rerun affected validation after changes.

## Review Expectations

Authors and reviewers must check:

- requirement and task scope;
- feature ownership and role boundaries;
- Clean Architecture dependency direction;
- BLoC/Cubit responsibilities;
- Domain entity, DTO, mapper, repository, and data-source separation;
- dependency injection and centralized infrastructure usage;
- routing and authorization boundaries;
- error handling, null safety, and async lifecycle safety;
- Material 3 consistency and responsive UI behavior;
- test relevance and coverage of new rules;
- naming, imports, readability, duplication, and dead code;
- secret handling and staged-file safety;
- documentation accuracy.

Approval means the reviewer has assessed the change, not merely that automated
checks are green.

## Definition of Done

A task is Done only when all applicable conditions are satisfied:

- the assigned requirement and acceptance criteria are complete;
- code is in the correct feature and follows Clean Architecture;
- approved BLoC/Cubit state management and routing are correct;
- loading, success, empty, error, and permission states were considered;
- formatting, analyzer, and tests pass;
- relevant Android build validation passes or a real environment limitation is
  documented;
- no sensitive data, generated artifacts, dead code, or unrelated changes are
  included;
- documentation is current;
- a focused Pull Request is created;
- review comments are resolved and required approvals are obtained.
