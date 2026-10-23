# TripMate Mobile MVP — Design Baseline (Report 3 V2)

Entry point for the Mobile MVP design documentation. It is delivered by **PR #35** (open, documentation-only, branch `docs/mobile-mvp-v2-design-baseline`). Nothing in this folder changes Flutter code, backend contracts or the SRS.

| Item | Value |
|---|---|
| Canonical requirements | `Report3_Software-Requirement-Specification-V2.docx` (older Report 3 versions are obsolete) |
| Mobile baseline | `origin/develop` `acfde81` |
| Backend reference | `Capstone_BE` `origin/develop` `0075fcb` (read-only) |
| Scope | 25 UCs: UC-01…UC-10, UC-16…UC-23, UC-24…UC-30 |
| Revision | 2026-10-08, including the QA revision; PR #35 review remediation 2026-10-09 (findings F-01…F-06) |

## Read in this order

1. [00 — Audit](00-mobile-mvp-audit.md): baseline, UC status, defects (A-xx), SRS conflicts (C-xx).
2. [09 — Screen Index](09-mobile-mvp-screen-index.md): Screen Index #35–#92 mapping and coverage.
3. [13 — V2 completion specs](13-v2-completion-specs.md): **current V2 specifications**, readiness audit (§6) and the 17 pending decisions (§5.3).
4. [08 — Backend readiness](08-backend-readiness-matrix.md): backend contracts per UC.
5. [11 — Open PR register](11-open-pr-and-review-register.md): open PRs, unmerged branch, merge order.
6. [10 — Component ownership](10-component-ownership-map.md): reuse and new shared components.
7. Structural design detail referenced by `13`: [01](01-mobile-shells-and-navigation.md), [02](02-public-auth-and-account.md), [03](03-planning-poi-and-active-trip.md), [04](04-travel-groups.md), [05](05-tour-discovery-booking.md), [06](06-commercial-services-history-review.md), [12](12-batch-1-specification.md). Out of MVP scope: [07](07-tour-operator-mobile.md).

## Document status

| File | Status | Notes |
|---|---|---|
| `00`, `08`, `09`, `11`, `13` | **Current (V2)** | Rewritten or created on 2026-10-08 |
| `10` | Current, with a revision section | Original table kept below the revision |
| `01`–`06` | **Structural design, superseded in part** | Each starts with a banner listing stale statements; status lines and `SRS_TEXT_REQUIRED` placeholders are replaced by `13` |
| `07` | Out of the 25-UC MVP | Tour Operator screens #75–#92; future input only |
| `12` | Historical batch spec | Implemented by open PR #25 (#41, #45, #46; #40 now carries the PR #34 wizard) |

Rule: where `13` and `01`–`06` disagree, `13` wins. A screen's implementation spec = its `02`–`06` structural section + its `13` section.

## Key figures (verified in the QA revision; recounted in the 2026-10-09 remediation)

| Figure | Value | Source |
|---|---|---|
| In-scope UCs audited | 25 / 25 | `00` §G |
| UC status | 6 IMPLEMENTED_VERIFIED · 12 IMPLEMENTED_PARTIAL · 3 OPEN_PR_PARTIAL · 4 NOT_STARTED | `00` §G |
| MVP screen IDs | 32 (incl. hubs #35, #44, #55) | `09` §4 |
| Present on develop (any status) | 20 | `09` §4 |
| Missing on develop | 12 (#35, #43, #55, #64–#72) | `09` §4 |
| Specification groups in `13` | 23 groups covering 25 screen IDs (S-67 = #67 + #70; S-71/72 = #71 + #72) | `13` §6 |
| MVP screens without a new spec | 7 (#36–#39, #56, #58, #62): implemented; preservation records in `02`/`04` | `13` §6 |
| Implementation-ready / design-partial groups | 13 / 10 (S-35 and S-45 are `DESIGN_PARTIAL`; S-42 is design-ready but `IMPLEMENTATION_BLOCKED_BY_BACKEND_CONTRACT`) | `13` §6 |
| Pending decisions | 17 (D-01…D-17) | `13` §5.3 |
| Conflicts recorded | C-01…C-17: 12 SRS (C-01…C-05, C-08, C-12…C-17), 3 SRS-GAP (C-06, C-10, C-11), 2 BE (C-07 `UC06_OTP_TTL_SRS_VS_BACKEND`, C-09) | `00` §K |
| Backend readiness (25 UCs) | 9 verified · 1 `BACKEND_CONTRACT_GAP` (UC-06) · 1 not integrated · 1 BE PR open · 13 no backend | `08` §4 |
| Implementation defects and gaps recorded | A-01…A-13 (P1: A-06, A-07, A-08, A-09, A-12) | `00` §J |

"Implemented" never means UAT: evidence is code reading plus repository tests only.

## Pending decisions (summary)

D-01 platform of UC-02/03 · D-02 UC-10 scheduling model · D-03 localization layer (CR-09) · D-04 UC-09 preference attribute set · D-05 "Remember me" · D-06 change-password contract · D-07 offline map/package source · D-08 group list/detail reads · D-09 remove/leave/host succession · D-10 location sharing · D-11 tour detail, recommendations, booking, payment, e-ticket, payment deep link · D-12 UC-31 booking on #72 · D-13 message catalogue reconciliation · D-14 #35 trending/featured criteria · D-15 UC-08 profile field rules (required fields, Gender values, email editability) · D-16 Administrator/Staff on Mobile UC-04/06/07 and phone/OTP sign-in · D-17 landing-page platform and #35 ownership. All are **pending**; owners, evidence, proposed (unapproved) resolutions and impact: `13` §5.3.

## Design verification checklist

Use before handing any screen to implementation.

| # | Check | Where |
|---|---|---|
| 1 | Screen ID, name and UC match V2 Table 4.2 and §2.2.2 | `09` §1–§2 |
| 2 | Platform taken from the UC Interface text (not the Table 4.2 caption) | `09` header |
| 3 | V2 fields, business rules and validations listed; no field invented | `13` section |
| 4 | Messages are semantic; `V2_MESSAGE_CONFLICT` marked; no numeric IDs rendered | `13` §0.5 |
| 5 | All states defined: loading, empty, validation, network, 401, 403, backend pending, offline where relevant | `13` §0.2 |
| 6 | Production/demo boundary explicit; no fabricated data or success | `13` §0.3, `01` C-DEMO |
| 7 | Backend classification from `08`; no endpoint assumed from an open PR | `08` §3 |
| 8 | Copy resource-backed English (CR-09) | `13` §0.1 |
| 9 | Accessibility and responsive baseline met | `13` §0.4, `01` C-RESP/C-A11Y |
| 10 | Reuses existing components; new shared components justified | `10` |
| 11 | Acceptance criteria cover positive, negative and regression cases | `13` section H |
| 12 | Open SRS decision on the screen? Then it is `DESIGN_PARTIAL` | `13` §6 |

## Not done here

PR #35 is open and documentation-only: it changes only `specs/mobile-mvp/**`. It contains no Flutter, Backend or Web implementation and no dependency change. Approving PR #35 does not approve any pending decision (D-01…D-17), and every implementation task needs its own separate approval.
