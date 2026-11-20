# Implementation plan

User-approved scope and calculation proposal: four dashboard metrics only.

1. Backend: authenticated read-only metrics endpoint, scoped counts and existing
   revenue aggregation; boundary, isolation and eligibility tests. No migration.
2. Mobile: domain snapshot/repository, strict HTTP mapper, DI and Cubit. Test the
   contract, failure/retry and duplicate-load guard before implementing.
3. Replace only the dashboard's metrics grid with a live panel. Preserve demo,
   other content and four existing navigation targets. Test zero/loading/error,
   retry, activation refresh and small screen layout.
4. Format, analyze and run related Flutter tests; run backend focused tests and
   formatting/build validation. Independent compliance and quality review.
   Do not build/install APK, modify local data or push.
