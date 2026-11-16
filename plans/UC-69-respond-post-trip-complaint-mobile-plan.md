# UC-69 — Respond to Post-Trip Complaint (Mobile) Plan

## Task 1 — Confirm cross-system contract

Obtain the merged UC-69 Backend OpenAPI/DTO contract and verify the list,
detail, response request/result, error-code mapping, signed-evidence URL shape,
pagination limits and `availableActions`. Record any mismatch as a dependency;
do not add a mock production contract or invent fields.

## Task 2 — Domain and data foundation

Create the focused `operator_complaints` domain entities, repository contract,
list/detail/respond use cases, DTOs, explicit mappers and remote data source.
Use the existing centralized Dio/error infrastructure. Keep decimal currency and
deadline parsing at the data/domain boundary and never use a DTO as a UI state.

## Task 3 — State management and dependency injection

Add feature-scoped list and detail/response Cubits with explicit loading,
content, empty, submitting, success, permission and recoverable-failure states.
Register repositories, use cases and Cubits in `get_it`, following the existing
operator-bookings factory/lifecycle conventions. Generate and retain an
idempotency key for one in-flight response attempt.

## Task 4 — Operator list and detail UI

Build responsive Material 3 list and detail screens under the existing Tour
Operator shell. Add server-backed status filtering, pagination, refresh and
retry. Render only server-owned complaint data and action controls allowed by
`availableActions`; provide confirmation, partial-amount and rejection-reason
forms with accessible validation and keyboard-safe scrolling.

## Task 5 — Evidence and routing

Add named GoRouter routes beneath `/operator/post-trip-complaints`, guarded the
same way as the current operator booking routes. Reuse the approved external
browser `url_launcher` pattern for only current HTTPS signed evidence links.
Do not add Admin or Staff routes, store evidence URLs, or add a payment/refund
execution path.

## Task 6 — Tests and verification

Add focused mapper/repository tests, Cubit state-transition tests, widget tests
for list/detail/loading/empty/error/validation/duplicate-submit states, and
route guard/deep-link tests. Cover stale/deadline/permission/error mapping and
evidence-launch failure. Before a pull request, run:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Run `flutter build apk --debug` if Android/plugin configuration changes. Perform
manual testing against the approved Backend contract with a Tour Operator and a
Traveler session, including the three response actions and expired deadline.
