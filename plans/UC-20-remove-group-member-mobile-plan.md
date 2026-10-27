# UC-20 Remove Group Member — Mobile implementation plan

**Spec:** `specs/UC-20-remove-group-member-mobile-spec.md`. **Status:** Approved by user for implementation, 2026-10-27.

## Baseline

- Use an isolated `feature/uc20-remove-group-member` Mobile branch/worktree from a clean reviewed baseline. Preserve the current dirty `feature/phuctv-uc10-sync-spatial-exploration-and-quick-chips` tree and untracked files. Read `CONTRIBUTING.md`, `docs/CODEBASE_RULES.md`, existing group code, and tests again in that baseline.
- Record baseline `flutter pub get`, `flutter analyze`, `flutter test`. The Backend UC-20 route and shared inbox endpoints must be deployed in the target environment before enabling the production action. The implementation currently lives in isolated `Capstone_BE_UC20`.
- For each task: failing behavioral test, minimal code, focused verification, spec review, code-quality review. Reuse `DioClient`, `ErrorMapper`, `TravelGroupRepository`, group Cubit/pages/dialog, `go_router`, and the existing `uuid` package.

## Atomic tasks

1. **Removal API.** Extend `lib/features/traveler/domain/repositories/travel_group_repository.dart` and `data/repositories/travel_group_repository_impl.dart`; add a focused result model/entity only if needed to keep JSON out of Domain. Test DELETE path/header/no body, response/UTC mapping, and 400/401/403/404/409/5xx/network outcomes in `test/features/traveler/data/repositories/travel_group_repository_impl_test.dart`. The caller supplies the retry key.
2. **Attempt state.** Extend `TravelGroupMembersCubit`/state or add one small removal Cubit if the load state cannot represent a pending attempt safely. Test UUID once per confirmation, blocked duplicate tap, same-key uncertain retry, new key for a resolved new action, replay followed by refresh, stale Host/target reload, and no optimistic member mutation in `test/features/traveler/presentation/cubit/`.
3. **Host UI.** Wire `travel_group_members_page.dart` and `remove_group_member_dialog.dart` to the attempt state. Replace the `NO_BACKEND` notice only when the target BE environment exposes the endpoint. Preserve authoritative Host visibility, MSG59/MSG60, Cancel, pending/Retry, and refreshed list. Update existing dialog/page widget tests and run focused `flutter test` plus `flutter analyze`.
4. **Inbox data/state.** Add minimal notification Domain/Data pieces under `lib/features/traveler/` for `GET /api/v1/notifications` and retry-safe `POST /api/v1/notifications/{id}/read`. Add Cubit state for loading, cursor, unread filter, read, and retry. Test JSON mapping, recipient-free requests, paging, 401/404, and error recovery in the corresponding `test/features/traveler/` paths.
5. **Inbox UI and access loss.** Add one Traveler inbox page and register it in `service_locator.dart`, `app_routes.dart`, `app_router.dart`, with an entry in the existing Traveler shell. Show the captured group name without a protected detail link. On denied group access, clear only group-specific in-memory state and navigate to a safe Traveler route. Widget/router tests cover loading/empty/error/content, mark-read/pagination, and access denial while personal data remains.
6. **Integration and review.** Against BE with UC-20 migration/API, exercise Host remove → MSG60/list refresh → recipient inbox/read → denied group details, uncertain retry, and rejoin. Run `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` if Android tooling supports it. Report environment limits. Do not commit, push, merge, deploy, or open a PR without a separate request.

## Definition of done

Mobile shows only committed removal success and the current member list, cannot submit twice or re-remove a rejoined member through retry, and lets the removed Traveler read their `InApp` event without regaining group access. Required Mobile checks pass or limitations are reported explicitly.
