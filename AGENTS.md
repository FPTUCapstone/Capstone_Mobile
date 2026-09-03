# TripMate Mobile Agent Instructions

These instructions apply to every AI coding agent working anywhere in this
repository. They are mandatory. Read [CONTRIBUTING.md](CONTRIBUTING.md) and
[docs/CODEBASE_RULES.md](docs/CODEBASE_RULES.md) before changing the project.

## Development Workflow (Superpowers Protocol)

Follow an **Explore → Clarify → Spec → Plan → TDD → Atomic Execution → Verify** workflow for
non-trivial tasks. Never jump directly from a request to implementation code.

1. **Explore & Understand** — Inspect the relevant existing source, related modules, tests, and
   nearby documentation before proposing changes. Do not guess business logic, architecture, or
   requirements when the repository already contains the answer.
2. **Clarify First** — Confirm the assigned task's scope explicitly. Do not implement
   functionality merely because it appears in an SRS, use-case list, or screen inventory. If a
   requirement, contract, or destructive action is materially ambiguous, stop and ask the
   developer instead of inventing it.
3. **Specification** (for non-trivial tasks) — Define scope, acceptance criteria, affected
   modules, and edge cases before implementation begins. Wait for developer approval.
4. **Isolated Workspace** — Once the approach is approved, create or switch to a dedicated
   feature branch (see Git section below) before touching any code. Confirm the required checks
   are green on a clean checkout first — never start implementation on top of an already-broken
   baseline.
5. **Implementation Plan** — Break the spec into small, independently verifiable tasks with the
   exact files to touch and how each will be verified. Wait for developer approval.
6. **Atomic Execution & TDD (Red → Green → Refactor)** — Implement one task at a time; write a
   failing test first where applicable, write the minimal code to pass, refactor, then verify
   before moving to the next task. Do not silently expand scope. When the harness supports
   subagents, dispatch each task to a fresh subagent for a two-stage review (spec compliance,
   then code quality) before integrating it; otherwise perform the equivalent two-pass
   self-review. If implementation code was written before its test, delete it and restart with
   the test first.
7. **Code Review Between Tasks** — After each task passes verification, review it against the
   plan and spec before moving on. Classify findings by severity: a **Critical** finding (breaks
   a requirement, introduces a regression, violates an architecture rule below) blocks moving to
   the next task until fixed; a **Minor** finding may be noted and deferred with the developer's
   agreement.
8. **Verification** — Run this repo's required checks (see below) before reporting completion,
   and report results honestly, including any skipped or environment-limited checks.
9. **Finishing the Branch** — Once every task is complete and verified, do not merge, push, or
   open a Pull Request unprompted. Present the developer with the options — merge, open a PR,
   keep the branch as-is, or discard — and act only on their choice.

Apply YAGNI (build only what the current task needs) and DRY (share logic only when genuinely
duplicated) throughout — this workflow governs *how* work proceeds, it does not replace the
architecture and delivery rules below.

## Before Editing

1. Inspect the current branch, working tree, `pubspec.yaml`, relevant source,
   tests, and nearby documentation.
2. Preserve existing user changes and do not modify unrelated files.
3. Confirm the assigned task's scope. Do not implement functionality merely
   because it appears in the SRS, use-case list, or screen inventory.
4. If an API contract, requirement, role rule, or destructive action is
   materially ambiguous, stop and report the dependency instead of inventing it.

## Architecture and Implementation

- Follow feature-first Clean Architecture and keep dependencies pointing toward
  Domain. Presentation may depend on Domain; Data may implement Domain contracts;
  Domain must not depend on Flutter, Dio, JSON DTOs, or platform storage.
- Put business functionality under `lib/features/<feature>/`. Do not move
  feature logic into `lib/core/` or feature-only widgets into `lib/shared/`.
- Use `flutter_bloc`. Choose Cubit for simple transitions and Bloc for complex,
  event-driven workflows. Do not introduce Provider, Riverpod, GetX, MobX, or
  another primary state-management framework without explicit team approval.
- Do not bypass the intended Page -> Bloc/Cubit -> Use Case -> Repository
  contract -> Repository implementation -> Data Source flow for convenience.
- Pages and BLoCs/Cubits must not issue raw Dio requests. Use the centralized
  client and dependency injection; do not instantiate infrastructure in widgets.
- Use `go_router` and centralized route definitions. Respect `/auth/*`,
  `/traveler/*`, and `/operator/*` role boundaries.
- Never create an Administrator Flutter feature or route. Administration belongs
  to the separate Next.js web system.
- Do not confuse Group Host with Tour Operator. A Group Host remains a Traveler
  participating in Travel Group functionality; a Tour Operator is a commercial
  provider.
- Use the secure-storage abstraction for tokens and credentials. Never store
  sensitive authentication data in SharedPreferences.
- Use Material 3 and existing theme tokens. Account for safe areas, keyboard,
  scrolling, small screens, long text, and data loading/empty/error states.
- Maintain null safety, handle Futures and failures explicitly, and never expose
  raw exceptions, stack traces, internal HTTP details, or secrets to users.
- Add focused tests for new domain rules, BLoCs/Cubits, and meaningful widgets.
  Do not add tests that assert nothing useful.

Do not create empty layers, folders, repositories, DTOs, use cases, or widgets
solely to make the tree look more complete.

## Git and Delivery

- Never develop directly on `main`. Use a lowercase kebab-case branch following
  `<type>/<short-description>` with `feature`, `fix`, `refactor`, `chore`,
  `docs`, or `test`.
- Do not commit, push, open a Pull Request, or modify remote state unless the
  user explicitly requests it.
- Never force push, rewrite shared history, discard unrelated work, or commit
  secrets, generated build output, local environment files, or IDE caches.
- Use Conventional Commits when a commit is explicitly requested.
- Before reporting implementation completion, run:

  ```bash
  flutter pub get
  dart format --set-exit-if-changed .
  flutter analyze
  flutter test
  ```

  Run `flutter build apk --debug` when the task affects Android runtime or build
  configuration and the local environment supports it.
- Report commands and results truthfully. Clearly identify placeholder UI, mock
  data, incomplete integrations, skipped validation, known limitations, and any
  dependency on an unknown backend contract.
