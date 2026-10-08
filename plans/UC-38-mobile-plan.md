# UC-38 Mobile Coupon Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an approved Tour Operator create a coupon in Flutter through the UC-38 backend contract.

**Architecture:** Implement a feature-first `coupon` package: DTO/source/repository in Data, entities/repository/use case in Domain, and Cubit/Page in Presentation. UI calls Cubit only; Dio stays in the remote data source.

**Tech Stack:** Flutter, Dart, flutter_bloc, get_it, Dio, go_router, bloc_test.

**Spec:** `specs/UC-38-mobile-spec.md`

## Global Constraints

- Preserve `Presentation -> Domain <- Data`; use central `DioClient`, `get_it`, and `GoRouter`.
- Route only under `/operator/*`; never add administrator Flutter UI.
- Convert local date/time to UTC at the request boundary. Do not hard-code URLs or tokens.
- Do not implement coupon listing, edit/deactivation, redemption or booking-price calculation.

## Review Focus

- Flat discount removes stale cap input after type switch.
- Conflict/retry preserves the form.
- Late async completions after disposal/supersession cannot emit stale state.
- No eligible tours blocks submission with useful guidance.
- Date validation, keyboard inset and large text do not hide submit.

---

### Task 1: Domain/data coupon contract

**Files:** create `lib/features/coupon/{data,domain}/...`; test `test/features/coupon/data/coupon_repository_impl_test.dart`

- [ ] Write failing tests for JSON mapping, UTC payloads, cap omission and safe error mapping.
- [ ] Run focused Flutter tests; confirm RED.
- [ ] Implement `CouponRepository.getEligibleTours()` / `createCoupon()` plus DTO, source, repository and use case.
- [ ] Run focused tests; confirm GREEN.
- [ ] Commit this task.

### Task 2: Cubit and dependency injection

**Files:** create `lib/features/coupon/presentation/cubit/create_coupon_{cubit,state}.dart`; modify `lib/core/di/service_locator.dart`; test `test/features/coupon/presentation/cubit/create_coupon_cubit_test.dart`

- [ ] Write failing bloc tests for load, empty state, conflict retention, duplicate-submit and stale operation suppression.
- [ ] Run focused tests; confirm RED.
- [ ] Implement Cubit/state and registrations.
- [ ] Run focused tests; confirm GREEN.
- [ ] Commit this task.

### Task 3: Form page and route

**Files:** create `lib/features/coupon/presentation/pages/create_coupon_page.dart` and selector widget; modify `lib/app/router/app_routes.dart`, `lib/app/router/app_router.dart`; test page interactions.

- [ ] Write failing widget tests for cap visibility, selection, error retention, loading/empty states, keyboard-safe submit and success actions.
- [ ] Run focused tests; confirm RED.
- [ ] Implement the grouped Material 3 form, searchable selection, VND preview, timezone-aware dates and action footer.
- [ ] Run focused tests; confirm GREEN.
- [ ] Run `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` when supported; commit.
