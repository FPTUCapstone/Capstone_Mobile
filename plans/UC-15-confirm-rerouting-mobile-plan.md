# UC-15 Confirm Re-routing — Mobile plan

**Spec:** `specs/UC-15-confirm-rerouting-mobile-spec.md`. Branch `feature/hoangtv-uc15-confirm-rerouting-mobile` (worktree `_wt/Capstone_Mobile_uc15`, base `origin/develop` 969bdd0). TDD per task; run the touched test files after each task; no commit/push/PR until the developer asks.

## Tasks

- [ ] **T1 Domain + errors.** Rewrite `lib/features/traveler/domain/entities/reroute_proposal.dart` (`RerouteProposal`, `RerouteStop`, `RerouteStopChange`, `RerouteReason`; `RerouteStatus` unchanged). Add `ReroutingFailure`/`ReroutingFailureReason` to `core/error/failures.dart`. Add `lib/features/traveler/domain/repositories/rerouting_proposal_repository.dart` (`getProposal`, `acceptProposal` → `NavigationSession`, `rejectProposal`). Test: `reroute_proposal_test.dart` (equality, `isExpiredAt`).
- [ ] **T2 Data.** `data/models/reroute_proposal_model.dart` (`fromJson`, `Rejected`→declined, UTC→DateTime) and implement the interface in `NavigationSessionRepositoryImpl` (paths above, MSG44 mapping of `rerouting.*`, MSG127 text for network/5xx). Register in `core/di/service_locator.dart`. Tests: model test + extend `trip_alert_repository_contract_test.dart` style file `rerouting_repository_contract_test.dart` (paths, methods, parsed fields, 409/404/500 mapping).
- [ ] **T3 Cubit.** In `ActiveTripCubit`/`ActiveTripState`: optional `ReroutingProposalRepository`; `openRerouteProposal(TripAlert)`, async `acceptRerouteProposal`/`declineRerouteProposal`, `expireRerouteProposal` driven by a timer, `clearRerouteProposal` in `copyWith`, route-guidance reset on accept, MSG42/43/44/127 feedback, retry, offline and double-tap guards. Remove local accept/decline simulation. Rewrite the reroute tests in `active_trip_cubit_test.dart` with a `FakeReroutingRepository`.
- [ ] **T4 UI.** `RerouteProposalSheet` renders the new entity (tags, removed stops, derived reason, no demo rows); `TripAlertBanner`/`TripAlertsSheet` show Review on `reroutingProposalId != null` and pass the alert; `ActiveTripPage` wires the new cubit API and `ActiveTripPage` creation injects `locateOptional<ReroutingProposalRepository>()`. Update `reroute_proposal_sheet_test.dart`, `active_trip_page_test.dart`, `test/support/trip_alert_test_data.dart`.
- [ ] **T5 Docs + verification.** Add the UC-15 endpoints to `docs/mobile-api-contract.md`; run `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`; report results and limits honestly.

## Review focus (pinned by tests)

- Accept replay / double tap sends one request.
- Proposal already past `expiresAt`, or `Expired`/`Accepted`/`Rejected` from the server, is never shown.
- 409 closes the sheet, shows MSG44, refreshes session and alerts; 500/offline keeps the proposal and offers Retry.
- After accept the stale route guidance and old target are dropped; reached stops stay reached.
- A finished trip ignores reroute actions.
