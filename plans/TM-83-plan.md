# TM-83 implementation plan

1. Capture focused baseline and inspect authoring, shared readiness and submission paths.
2. Add failing tests for legacy missing data, note/timestamp persistence, ownership/roles, concurrent duplicate submission and migration parity.
3. Extend the existing Backend slice and mappings without weakening public visibility or Staff authorization.
4. Extend Web and Mobile contracts and confirmation/read-only behavior with regression tests first.
5. Run appropriate automated checks, independently review, fix findings and rerun affected checks.
6. Run isolated local services, seed local-only fixtures and exercise real browser/emulator flows. Inspect screenshots, requests and errors; fix observable problems and report evidence and limits.
