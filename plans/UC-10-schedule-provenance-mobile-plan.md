# UC-10: Schedule provenance on Mobile (ADR-002 G3)

The backend (ADR-002 G2) returns `provenance` on the itinerary detail. It also returns HTTP 503 with
`planning.generation_timeout` or `itinerary.generation_timeout` when the CSP times out and no heuristic plan exists.

Mobile shows no CSP or "optimal" claim on the itinerary screens, so its scope is the SRS MSG35 notice and the retryable
error.

| Task | Files | Verification |
|---|---|---|
| Parse `provenance`. Missing or malformed values become null and never fail the page | `itinerary_detail_model.dart`, `itinerary_detail.dart` (`ScheduleProvenance`) | `itinerary_detail_model_test.dart` |
| Show the MSG35 card (`schedule_fallback_notice`) at the top of the detail only for `CspFallback` | `itinerary_detail_page.dart` | `itinerary_detail_page_test.dart` |
| Map the 503 generation timeouts to a retryable `ServerFailure` message | `core/error/error_mapper.dart` | `error_mapper_test.dart` |

Checks: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`.
