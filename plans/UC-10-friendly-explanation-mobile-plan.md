# UC-10 Mobile: show the AI explanation. Implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline). Steps use checkbox syntax.

**Goal:** Mobile shows `friendlyExplanation` and refreshes the itinerary detail after a create that answered `explanationPending: true`.

**Architecture:** Domain entities and models carry the new fields. A pure domain service decides when the AI sentence has arrived and merges it. `PendingExplanation` travels in the go_router `extra`. `ItineraryDetailCubit` owns the timers.

**Tech Stack:** Flutter, flutter_bloc, go_router, flutter_test, bloc_test, fake_async.

**Spec:** `specs/UC-10-friendly-explanation-mobile-spec.md`

## Global Constraints
- Delays after `createdAt`: 20, 45, 75, 110 seconds. Sentence shown: trimmed non-empty `friendlyExplanation`, else trimmed non-empty `recommendationReason`, else `'Địa điểm gợi ý'`.
- `PendingExplanation` is used only when its `itineraryId` equals the route's. No global state. No new UI element.
- Per `AGENTS.md`: no commit, push or PR unless the developer asks. Before reporting: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`.

## Review Focus
1. Whitespace-only `friendlyExplanation` must not hide `recommendationReason` (Task 2).
2. `extra` for another itinerary id is ignored (Task 4).
3. A failed attempt is ignored and later ones run; a late result after `close()` emits nothing (Task 3).
4. An edit, accept or regenerate returns a new itinerary id: attempts for the old id stop and never overwrite the new version (Task 3).
5. Opened after 110 s, or a fresh detail with unknown `sequenceNo`: no request / no crash (Tasks 3, 4).

---

### Task 1: Entities and models carry the new fields
**Files:** Modify `lib/features/traveler/domain/entities/itinerary_generation.dart`, `.../itinerary_detail.dart`, `lib/features/traveler/data/models/itinerary_generation_model.dart`, `.../itinerary_detail_model.dart`. Test: `test/features/traveler/data/models/itinerary_generation_model_test.dart`, `.../itinerary_detail_model_test.dart`.

**Produces:** `GeneratedItineraryItem.friendlyExplanation` (`String?`, optional named), `GeneratedItinerary.explanationPending` (`bool`, default `false`), `ItineraryDetailItem.friendlyExplanation` (`String?`, optional named, in `props`).

- [ ] Tests: models parse `friendlyExplanation` string and null/missing; generation model parses `explanationPending: true`, and missing means false; values equal as Equatable.
- [ ] Run `flutter test` on both files; expect FAIL. Implement; expect PASS.

### Task 2: Choose the sentence and show it
**Files:** Modify `lib/features/traveler/presentation/helpers/itinerary_text.dart`, `lib/features/traveler/presentation/widgets/itinerary_stop_card.dart` (the visit branch near line 100). Test: `test/features/traveler/presentation/helpers/itinerary_text_test.dart` (create if absent), `test/features/traveler/presentation/pages/itinerary_detail_page_test.dart`.

**Produces:** `String? stopExplanationText({String? friendlyExplanation, String? recommendationReason})` in `itinerary_text.dart`.

- [ ] Tests: friendly wins; null, `''`, `'   '` friendly fall back to reason; both blank returns null; output trimmed. Widget test: a visit stop with friendly text shows it and not the reason; whitespace friendly shows the reason; neither shows `'Địa điểm gợi ý'`; a rest stop is unchanged.
- [ ] Run; expect FAIL. Implement helper and use it in the visit branch; expect PASS.

### Task 3: Pure explanation rules and cubit refresh
**Files:** Create `lib/features/traveler/domain/entities/pending_explanation.dart`, `lib/features/traveler/domain/services/itinerary_explanation.dart`. Modify `lib/features/traveler/domain/entities/itinerary_generation.dart` (add `pendingExplanation`), `lib/features/traveler/presentation/cubit/itinerary_detail_cubit.dart`, `.../itinerary_detail_state.dart`. Test: `test/features/traveler/domain/services/itinerary_explanation_test.dart`, `test/features/traveler/presentation/cubit/itinerary_detail_cubit_test.dart`.

**Produces:**
- `const explanationRefreshDelays = <Duration>[Duration(seconds: 20), Duration(seconds: 45), Duration(seconds: 75), Duration(seconds: 110)]`
- `final class PendingExplanation extends Equatable { const PendingExplanation({required int itineraryId, required DateTime createdAt, required Map<int, String> template}); }`
- `GeneratedItinerary.pendingExplanation(DateTime createdAt) -> PendingExplanation?` (null unless `explanationPending`; template = trimmed `friendlyExplanation ?? ''` by `sequenceNo`)
- `bool hasNewExplanation(Map<int, String> template, List<ItineraryDetailItem> items)` and `ItineraryDetail mergeExplanations(ItineraryDetail current, ItineraryDetail fresh)` (same semantics as the Web; returns `current` itself when unchanged)
- `ItineraryDetailState.copyWithDetail(ItineraryDetail detail)` (everything else kept)
- `ItineraryDetailCubit({..., DateTime Function()? now})` and `Future<void> load(int itineraryId, {PendingExplanation? pendingExplanation})`

- [ ] Service tests: `hasNewExplanation` false for equal, whitespace-only, null; true for a changed sentence and for a `sequenceNo` missing from the template; `mergeExplanations` copies only `friendlyExplanation`, ignores unknown `sequenceNo` and blank fresh sentences, returns the same instance when unchanged; `pendingExplanation` returns null when not pending and trims the template.
- [ ] Cubit tests with `fakeAsync` and an injected `now` (`base + async.elapsed`): no attempts without `pendingExplanation`; attempts at 20/45/75/110 s from `createdAt`, none after; loading 30 s after `createdAt` skips the 20 s attempt; stops after the first changed result and the emitted state keeps `editRevision`, `undoStops` and `shiftedArrivals`; a throwing attempt does not stop later ones; `close()` before an in-flight result resolves emits nothing; after `accept()` returns a new itinerary id no later attempt calls `getById` and nothing overwrites the new detail; the first load already having the AI sentence makes no attempt; a `pendingExplanation` whose `itineraryId` differs from `load`'s id is ignored.
- [ ] Run; expect FAIL. Implement; expect PASS.

### Task 4: Route and create page wiring
**Files:** Modify `lib/features/traveler/presentation/pages/create_itinerary_page.dart` (success listener ~99), `lib/app/router/app_router.dart` (~425-440), `lib/features/traveler/presentation/pages/itinerary_detail_page.dart` (constructor, `initState`). Test: `test/features/traveler/presentation/pages/create_itinerary_page_test.dart`, `test/features/traveler/presentation/pages/itinerary_detail_page_test.dart`.

**Interfaces:** `ItineraryDetailPage({required int itineraryId, PendingExplanation? pendingExplanation, ...existing})`; the page calls `cubit.load(widget.itineraryId, pendingExplanation: widget.pendingExplanation)`. The create page passes `extra: state.result!.pendingExplanation(DateTime.now())`; the route builder passes `extra` on only when it is a `PendingExplanation` with `itineraryId` equal to the route's.

- [ ] Tests: create page: a pending result pushes the detail route with a `PendingExplanation` extra for that id; a non-pending result pushes with null extra. Detail page: given `pendingExplanation` it calls `load` with it; a router test (or builder unit) shows an `extra` for another id is not forwarded.
- [ ] Run; expect FAIL. Implement; expect PASS.

### Task 5: Verification
- [x] Result (2026-11-17): `flutter analyze` no issues; `flutter test` 2788 passed, 4 skipped (traveler baseline before the change: 659 passed). `dart format --set-exit-if-changed .` exits 1 only because `integration_test/uc70_emergency_device_test.dart` is already unformatted on `develop`; every file of this change is formatted. `flutter pub get` rewrites `pubspec.lock` with the local Flutter 3.44 (CD pins 3.47.9), so that file and the integration test were restored and are not part of the change.
- [ ] Present merge / PR / keep / discard to the developer. Do not commit unless asked.
