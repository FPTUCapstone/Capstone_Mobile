# 00 — TripMate Mobile MVP Audit (Report 3 V2 revision)

> Documentation only, delivered through the documentation-only PR #35. No Flutter source, API client, `pubspec.yaml`, Backend or Web change.
> Revision date: **2026-10-08**, with the PR #35 review remediation of **2026-10-09** (F-01…F-06). This revision supersedes the 2026-10-02 audit (which was written
> before Report 3 V2 was available and against `develop` `af8daa0`).

## A. Baseline

| Item | Value |
|---|---|
| Mobile `origin/develop` | `acfde81c96afaced1dc1b8db3a61b2277de4b143` — `feat(auth): implement UC-02 operator registration` (PR #34 merge) |
| Method | `origin/develop` exported with `git archive` to a scratch directory. The local worktree (branch `fix/mobile-production-truthfulness`, PR #25) was not checked out, reset, stashed or rebased. |
| Documentation location (QA revision) | Isolated worktree `../Capstone_Mobile_MVP_Docs`, branch `docs/mobile-mvp-v2-design-baseline` created from `origin/develop` `acfde81`. The original untracked copy in the PR #25 worktree is left untouched (pre-QA version). |
| Backend reference (read-only) | `Capstone_BE` `origin/develop` `0075fcb` |
| Web reference (read-only) | `Capstone_FE` `origin/develop` |
| Canonical SRS | `D:\Capstone_Project_Production\Report3_Software-Requirement-Specification-V2.docx` (SHA-256 `08941571…8786785`), full text extracted including content controls |
| Older Report 3 | Obsolete. Not used. |
| `Capstone_Docs` repository | Not present on this machine. Not used. |

## B. Source hierarchy applied

1. Report 3 V2 (§2.2.2 UC table, §3.1.2.2 Table 4.2, §3.1.3 Table 5, §3.2–§3.6, §5.2 CR-01…CR-15, §5.3 MSG01…MSG130).
2. No approved decision newer than V2 was found in the repositories.
3. Screen numbering: V2 Table 4.2 (#35–#92). **Note:** V2 captions Table 4.2 as *"Web Application Screen List"*, although it contains mobile-only screens (#49, #52–#54). Recorded as `V2_SPEC_CONFLICT` C-02. **Namespace:** V2 defines no global screen ID. Table 4.1 (Administration workspace) is numbered #1–#41 and Table 4.2 starts at #35, so #35–#41 occur in both tables (for example Table 4.1 #35 Staff Dashboard and Table 4.2 #35 Home Page). Every `#nn` in this documentation means the **Table 4.2** number; Table 4.1 screens are named, not numbered.
4. Implementation evidence: Mobile `develop`, open PRs #25/#31/#32/#33, unmerged branch `feature/mobile-tour-booking-payment-ticket`.
5. Backend contracts: `Capstone_BE` `develop` controllers (see `08-backend-readiness-matrix.md`).

## C. Merged since the previous audit (`af8daa0` → `acfde81`)

| PR | Merged | Merge | Scope | Effect |
|---|---|---|---|---|
| #24 | 2026-10-04 | `bdd1f12` | UC-13–UC-16 active trip, alerts, reroute, offline package | #49/#52/#53/#54 now on develop |
| #26 | 2026-10-05 | `0e4b427` | UC-20/UC-21 UI scaffold | #59/#60 fail-closed dialogs |
| #27 | 2026-10-05 | `1f17a61` | UC-22 location sharing settings UI | #61 truthful pending in production |
| #28 | 2026-10-05 | `6d509cc` | Real tour search thumbnails | #63 refinement |
| #29 | 2026-10-06 | `5697eb3` | UC-38 operator coupon flow | out of MVP scope (existing dependency) |
| #30 | 2026-10-06 | `a547442` | UC-23 join shared group trip (Screen #62) | #62 refinement |
| #34 | 2026-10-08 | `acfde81` | UC-02 operator registration | #40 calls `/auth/register/operator` (BE PR #52 still open) |

## D. Open PRs and unmerged work (verified 2026-10-08; PR #25 refreshed 2026-10-09)

| Item | State | Scope | MVP relevance |
|---|---|---|---|
| PR #25 `fix/mobile-production-truthfulness` | OPEN, MERGEABLE, REVIEW_REQUIRED, head `2e6defd`. The reviewer P1 (cross-account identity restore) remediation is pushed (`a85a8fd`) and `develop` `acfde81` is merged in; re-review by PQKhanh294 is **pending**, so the P1 is not closed | #41/#45/#46 truthfulness hardening; #40 now carries the PR #34 wizard from develop | UC-02, UC-03, UC-08, UC-09 |
| PR #31 `feature/mobile-tour-recommendations-details` | OPEN, MERGEABLE, REVIEW_REQUIRED, head `e6a1a94`, 3 behind develop | #64, #65 | UC-25, UC-26 |
| PR #32 `feature/mobile-commercial-services` | OPEN, **CONFLICTING**, REVIEW_REQUIRED, head `6739bdf` | #71, #72 | UC-30 (in scope), UC-31 (out of scope) |
| PR #33 `feature/mobile-trip-history-reviews` | OPEN, MERGEABLE, REVIEW_REQUIRED, head `be66c60` | #73, #74 | UC-32/UC-33 — **out of MVP scope** |
| Branch `feature/mobile-tour-booking-payment-ticket` | **No PR**; 6 commits ahead, 3 behind develop | #66–#70 | UC-27, UC-28, UC-29 |

CodeRabbit reports "review skipped" on every Mobile PR; that is **not** a review.

## E. PR #24 (merged) — re-evaluation on develop `acfde81`

| Historical concern | Result on develop | Evidence |
|---|---|---|
| Deep links restoring fabricated itinerary names | **Resolved for production.** The fallback names `Đà Nẵng Day Trip` / `Đà Nẵng City Explorer` are applied only when `kDebugMode && ?demo=true`. Production uses the navigation `extra` title or `null`; the offline cubit falls back to `Trip #<id>` (not a fabricated place name). | `lib/app/router/app_router.dart` (activeTripLive, offlinePackage builders); `offline_trip_package_cubit.dart` |
| UC-16 offline package metrics without verified data | **Resolved for production.** Production renders the truthful "Offline package is not available yet" view; package size and device storage are `0.0` and never rendered; download actions return early outside demo. | `offline_trip_package_page.dart` (production view), `offline_trip_package_cubit.dart` (`if (!state.isDemoMode) return;`) |
| Remaining defects | Demo-only copy still contains Vietnamese strings and raw identifiers (`(BR-37)`, `(MSG107)`), and fixed demo sizes `85.0 MB / 2.5 MB / 31.0 MB`. Demo-gated, so not a production fact claim, but it violates CR-09 within the demo and exposes rule identifiers. | `offline_trip_package_page.dart` lines ~255, 529–574 |

These are recorded as A-01/A-02 in §J. They are not fixed by this task.

## F. MVP scope (25 UCs) — exact V2 titles

UC-01 Register Traveler Account · UC-02 Register Tour Operator Account · UC-03 Resubmit Tour Operator Application · UC-04 Sign In · UC-05 Sign Out · UC-06 Reset Password · UC-07 Change Password · UC-08 Update Traveler Profile · UC-09 Update Travel Preferences · UC-10 Create Scheduling Request · UC-16 Download Offline Map & Itinerary · UC-17 Create Travel Group · UC-18 Invite Group Members · UC-19 View Group Members · UC-20 Remove Group Member · UC-21 Leave Travel Group · UC-22 Configure Group Location Sharing · UC-23 Join Shared Group Trip · UC-24 Search Tours · UC-25 Receive Tour Recommendations · UC-26 View Tour Details · UC-27 Book Tour · UC-28 Make Electronic Payment · UC-29 View QR E-ticket · UC-30 View Commercial Service.

Existing out-of-scope dependencies preserved (not redesigned): UC-11 (#48), UC-12 (#50/#51), UC-13–UC-15 (#52–#54), UC-31 (PR #32), UC-32/33 (PR #33), UC-38 (mobile coupon, PR #29).

## G. UC implementation matrix (develop `acfde81` + open work)

Columns: **UI** = presentation on develop; **BE** = backend contract integrated; **Tests** = widget/unit tests present; **UAT** = not verified by this audit unless stated.

**Evidence level (QA revision):** `IMPLEMENTED_VERIFIED` means the code on develop and the BE contract were verified **by reading** and tests exist in the repository. It does **not** mean visual, device-level or UAT verification — none was performed. Passing unit tests are not UAT evidence.

| UC | V2 actor | V2 platform (interface) | Screens | Route(s) on develop | Page / Cubit | Data source | Status | Related work | Missing behaviour (V2) |
|---|---|---|---|---|---|---|---|---|---|
| UC-01 | Guest | Mobile + Web | #38, #39, #37 (Google path) | `/auth/register/traveler`, `/auth/verify-email` | `TravelerRegistrationPage`, `VerifyEmailPage`, `AuthSessionCubit` | BE `/auth/register`, `/auth/verify-email`, `/auth/google` | `IMPLEMENTED_VERIFIED` (UI+BE+tests; UAT not verified) | PR #6, #16 | Message IDs conflict (C-03); copy not resource-backed (C-06) |
| UC-02 | Guest | **Web only** (§3.2.2 interface) | #40 | `/auth/register/operator`, `/auth/operator/verify-email` | `OperatorRegistrationPage` | `/auth/register/operator` — **not on BE develop** (BE PR #52 open) | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` + `BLOCKED_BY_SRS` (platform mismatch C-04) | PR #34 (merged), PR #25 | V2 allocates UC-02 to the Web; Mobile implementation exceeds that allocation pending BA adjudication (D-01). If kept: document upload, Partner Agreement checkbox |
| UC-03 | Tour Operator (rejected application) | **Web only** (§3.2.3 interface) | #41 | `/operator/application` | `OperatorApplicationPage`, `OperatorApplicationCubit` | **Simulated** resubmission on develop (500 ms delay → pending, fabricated file names — A-09); no BE resubmit endpoint | `IMPLEMENTED_PARTIAL` + `NO_BACKEND` + `BLOCKED_BY_SRS` (C-04) | PR #25 (open, P1 finding) | Platform adjudication (D-01); rejection reason and status refresh (status itself comes from the session `applicationStatus`); resubmission contract |
| UC-04 | Traveler / Tour Operator / Administrator (§3.2.4; Administrator on Mobile contradicts Table 1 — C-13) | Mobile + Web | #36, #37 | `/auth/login` | `LoginPage`, `AuthSessionCubit` | BE `/auth/login`, `/auth/google` | `IMPLEMENTED_VERIFIED` | PR #13, #16 | "Remember me" (V2 layout) absent — decision D-05 |
| UC-05 | Traveler / Tour Operator / Administrator | Mobile + Web | — (account menu action) | `/traveler/settings`, shell action | `TravelerSettingsPage`, `AuthSessionCubit.signOut` | BE `/auth/logout` | `IMPLEMENTED_VERIFIED` | PR #15 | — |
| UC-06 | Traveler / Tour Operator / Administrator (§3.2.6; Administrator on Mobile contradicts Table 1 — C-14) | Mobile + Web | #42 | `/auth/forgot-password` | `PasswordRecoveryPage`, `PasswordRecoveryCubit` | BE `/auth/password-reset/request` and `/auth/password-reset/confirm` | `IMPLEMENTED_PARTIAL` + `BACKEND_CONTRACT_GAP` | PR #20 | BE issues codes that expire after **3 minutes**; V2 §3.2.6 BR-14 requires **15 minutes** (C-07 `UC06_OTP_TTL_SRS_VS_BACKEND`). Mobile copy hard-codes "3 minutes" (A-03) |
| UC-07 | Traveler / Tour Operator / Administrator (§3.2.7; Administrator on Mobile contradicts Table 1 — C-15) | Mobile + Web | #43 | none | none | **No BE endpoint** | `NOT_STARTED` + `BLOCKED_BY_BACKEND` | — | Whole screen |
| UC-08 | Traveler | Mobile + Web | #45 | `/traveler/profile` | `TravelerProfilePage` (local state) | Local only; form pre-filled with **hard-coded identity constants** shown as the user's data (A-08) and "saved locally for the demo" | `IMPLEMENTED_PARTIAL` + `NO_BACKEND` + `OPEN_PR_REVIEW_REQUIRED` (#25) | PR #25 | Real profile load/save, avatar upload (BR-16), DOB rule (BR-18) |
| UC-09 | Traveler | Mobile + Web | #46 | `/traveler/preferences` | `TravelPreferencesPage`, `TravelPreferencesCubit` | Local demo only | `IMPLEMENTED_PARTIAL` + `NO_BACKEND` + `BLOCKED_BY_SRS` (C-08) | PR #25 | Option values hard-coded instead of configured (BR-19); §3.2.9 groups (interest tags, travel style, budget level) vs implemented groups — BR-numbering conflict (C-08, D-04); persistence |
| UC-10 | Traveler | Mobile + Web | #47 (→ #48) | `/traveler/itineraries/create`, `/result` | `CreateItineraryPage`, `CreateItineraryCubit` | BE `/scheduling-requests`, `/points-of-interest/search` | `IMPLEMENTED_PARTIAL` — **implementation gap** A-12 vs V2 §3.3.1 (implemented one-day model is BE-integrated) + `BLOCKED_BY_SRS` (C-05, D-02) | PR #18 | V2 requires date range (≤ 30 days, BR-23), number of travelers, interest tags (BR-21), preferred pace; V2 is **not** narrowed to one day |
| UC-16 | Traveler | Mobile only | #49 | `/traveler/trips/:id/offline` | `OfflineTripPackagePage`, `OfflineTripPackageCubit` | Production: truthful pending; demo fixtures | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` (offline data/map source undecided) | PR #24 | Real download, 150 MB check, version refresh (BR-36…BR-40) |
| UC-17 | Traveler | Mobile only | #56 | `/traveler/groups/create` | `CreateTravelGroupPage`, `CreateTravelGroupCubit` | BE `POST /travel-groups` | `IMPLEMENTED_VERIFIED` | PR #5, #9 | — |
| UC-18 | Traveler (Group Host) | Mobile only | #58 | `/traveler/groups/:id/invitation` | `InviteGroupMembersPage` | BE invitation + regenerate | `IMPLEMENTED_VERIFIED` | PR #8 | — |
| UC-19 | Traveler | Mobile only | #57 | `/traveler/groups/:id`, `/members` | `TravelGroupDetailsPage`, `TravelGroupMembersPage` | BE `GET /travel-groups/{id}/members` (returns `groupName`, `itineraryId`, `memberCount`, members); no group-detail endpoint | `IMPLEMENTED_PARTIAL` | PR #23 | Details page ignores the members response for its header (uses route `extra` or `Travel Group #<id>`); group status and self-member marker unavailable (D-08) |
| UC-20 | Traveler (Group Host) | Mobile only | #59 (on #57) | dialog | `RemoveGroupMemberDialog` | Fail-closed "Server support pending" | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` | PR #26 | Removal contract |
| UC-21 | Traveler | Mobile only | #60 | dialog | `LeaveTravelGroupDialog` | Fail-closed | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` | PR #26 | Leave + host succession (BR-49) + closure contracts |
| UC-22 | Traveler | Mobile only | #61 | `/traveler/groups/:id/location-sharing` | `GroupLocationSharingPage`, `GroupLocationSharingCubit` | Production pending; demo permutations | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` | PR #27 | Opt-in persistence contract |
| UC-23 | Traveler | Mobile only | #62 | `/traveler/groups/join` | `JoinTravelGroupPage`, `JoinTravelGroupCubit` | BE `POST /travel-groups/join`; QR camera | `IMPLEMENTED_VERIFIED` | PR #14, #30 | — |
| UC-24 | Guest / Traveler | Mobile + Web | #63 | `/explore/tours` | `TourSearchPage`, `TourSearchCubit` | BE `GET /tours` | `IMPLEMENTED_PARTIAL` | PR #19, #28 | V2 keyword, departure date **range**, duration, category, minimum rating, sorting; BE filter support unverified |
| UC-25 | Traveler | Mobile + Web | #64 | PR #31 only | `TourRecommendationsPage` (PR) | **No tour-recommendation endpoint** (`/poi-recommendations` is POI-only) | `OPEN_PR_PARTIAL` + `NO_BACKEND` | PR #31 | Real data; MSG28/MSG64/MSG68 states |
| UC-26 | Guest / Traveler | Mobile + Web | #65 | PR #31 only | `TourDetailPage` (PR) | PR calls `/api/v1/tours/{id}` — **not on BE develop** | `OPEN_PR_PARTIAL` + `NO_BACKEND` | PR #31 | Real detail, schedules, reviews |
| UC-27 | Traveler | Mobile + Web | #66 | branch only | `tour_booking` (branch) | Demo store; **no booking endpoint** | `NOT_STARTED` on develop (`BRANCH_NO_PR`) + `NO_BACKEND` | branch | Whole flow on develop |
| UC-28 | Traveler | Mobile + Web | #67, #70 | branch only | `ElectronicPaymentPage` (branch) | Demo; **no payment endpoint** | `NOT_STARTED` on develop (`BRANCH_NO_PR`) + `NO_BACKEND` | branch | Whole flow on develop |
| UC-29 | Traveler | Mobile + Web | #69 (#68 entry) | branch only | QR e-ticket (branch) | Demo; **no ticket endpoint** | `NOT_STARTED` on develop (`BRANCH_NO_PR`) + `NO_BACKEND` | branch | Whole flow on develop |
| UC-30 | Traveler | Mobile + Web | #72 (#71 entry) | PR #32 only | `CommercialServiceDetailPage` (PR) | PR uses a **demo store**; BE `GET /commercial-services`, `/{id}` exist | `OPEN_PR_PARTIAL` + `BE_AVAILABLE_NOT_INTEGRATED` | PR #32 (conflicting) | Integrate the real contract; MSG34/MSG75 conflicts (C-03) |

**Counts (25 UCs, primary classification):**

| Classification | UCs | Count |
|---|---|---|
| `IMPLEMENTED_VERIFIED` | UC-01, 04, 05, 17, 18, 23 | 6 |
| `IMPLEMENTED_PARTIAL` | UC-02, 03, 06, 08, 09, 10, 16, 19, 20, 21, 22, 24 | 12 |
| `OPEN_PR_PARTIAL` | UC-25, 26, 30 | 3 |
| `NOT_STARTED` (on develop) | UC-07, 27, 28, 29 | 4 |
| **Total** | | **25** |

QA revision: UC-10 moved from `IMPLEMENTED_VERIFIED` to `IMPLEMENTED_PARTIAL`. Its one-day implementation is BE-integrated, but V2 §3.3.1 (date range ≤ 30 days, travelers, interest tags, pace) is not implemented; V2 is not narrowed to the implementation.

Evidence separation (no double counting):

| Evidence class | UCs |
|---|---|
| Merged into develop and backend-integrated | 01, 04, 05, 06 (BE code lifetime differs from V2, C-07), 10 (one-day model), 17, 18, 19 (members), 23, 24 (partial filters) |
| Merged into develop, demo/local or fail-closed only | 02 (calls an endpoint absent on BE develop), 03, 08, 09, 16, 20, 21, 22 |
| Open PR only | 25, 26 (PR #31), 30 (PR #32) |
| Unmerged branch, no PR | 27, 28, 29 (`feature/mobile-tour-booking-payment-ticket`) |
| Design only (nothing in code) | 07 |
| Blocked by SRS adjudication | 02, 03 (C-04), 09 (C-08), 10 (C-05) |
Secondary blockers (`BLOCKED_BY_BACKEND`, `NO_BACKEND`, `BLOCKED_BY_SRS`) are listed per row above.

## H. Screen Index coverage (#35–#92)

Full mapping in `09-mobile-mvp-screen-index.md`. Summary for the 25-UC MVP:

| Group | Screens in MVP | On develop | Partial / pending | Missing on develop |
|---|---|---|---|---|
| Public & auth & account | #35–#43, #45, #46 | #36–#42, #45, #46 | #40, #41, #42, #45, #46 | #35 (no UC), #43 |
| Planning & offline | #47, #49 | #47, #49 | #47 (implementation gap A-12; SRS C-05), #49 | — |
| Travel groups | #55–#62 | #56–#62 | #57, #59, #60, #61 | #55 (route constant only, no `GoRoute`) |
| Tours & booking | #63–#70 | #63 | #63 | #64–#70 (PR #31 / branch only) |
| Commercial | #71, #72 | — | — | #71, #72 (PR #32 only) |
| Shell | #44 | `TravelerShellPage` | #44 (no V2 UC; Vietnamese labels) | — |

## I. Global findings

| ID | Finding |
|---|---|
| G-01 | **CR-09 not met on Mobile.** No localization/resource layer exists (`lib/l10n` absent, no `flutter_localizations`/`intl` in `pubspec.yaml`). Strings are hard-coded; several are Vietnamese (`TravelerShellPage`: "Trang chủ", "Chuyến đi", "Khám phá", "Đặt chỗ", "Tìm kiếm Tour"). |
| G-02 | Demo gating on develop is consistent: `kDebugMode && ?demo=true` in the router plus `isDemoMode` defaulting to `false` in cubits. Production views are truthful-pending where BE is absent. |
| G-03 | Route `/traveler/groups` (`AppRoutes.travelerTravelGroups`) is referenced but has no `GoRoute`; Screen #55 is missing. |
| G-04 | V2 message identifiers conflict between UC sections and §5.3 for most MVP UCs (C-03). Specs in `13-v2-completion-specs.md` use semantic copy and mark `V2_MESSAGE_CONFLICT`. |

## J. Audit register (implementation defects found; not fixed here)

| ID | Location | Defect | Severity |
|---|---|---|---|
| A-01 | `offline_trip_package_page.dart`, router demo titles | Demo copy in Vietnamese and raw `BR-37`/`MSG107` identifiers | P2 (demo-only) |
| A-02 | `offline_trip_package_page.dart` | Fixed demo component sizes (85.0/2.5/31.0 MB) — must stay demo-only | P3 |
| A-03 | `password_recovery_page.dart:117` | Copy hard-codes a code lifetime ("The code is single-use and expires in 3 minutes."). It matches the current BE (3 minutes) but not V2 §3.2.6 BR-14 (15 minutes), so neither value may be promised while C-07 is open. Target: neutral wording without a duration until the BE contract is corrected (`13` S-42). Changing the Flutter copy is a separate implementation task | P2 |
| A-04 | `traveler_shell_page.dart` | Vietnamese navigation labels (CR-09) | P2 |
| A-05 | `app_routes.dart:22` | `/traveler/groups` without a route (#55) | P2 |
| A-06 | `traveler_profile_page.dart`, `travel_preferences_page.dart` on develop | "saved locally for the demo" actions are reachable in production builds on develop (PR #25 addresses this; still open, re-review pending) | P1 until PR #25 lands |
| A-07 | PR #25 | Reviewer P1: identity snapshot can restore account A's name/email for account B. Remediation pushed to PR #25 (`a85a8fd`, head `2e6defd`); stays open until the reviewer re-reviews | P1 (fix pushed, re-review pending) |
| A-08 | `traveler_profile_page.dart:15-18` on develop | Form pre-filled with hard-coded identity (a sample full name, phone number, date of birth and city — values intentionally not reproduced here) displayed as the signed-in user's profile | P1 (found in QA revision; PR #25 addresses) |
| A-09 | `operator_application_cubit.dart` on develop | Defaults to `rejected` with fabricated a fabricated licence file name; `selectDemoLicence()`; `submit()` simulates success after 500 ms — reachable in production | P1 (found in QA revision; PR #25 addresses) |
| A-10 | `app_router.dart:170` | `TravelPreferencesCubit()` created per route entry, so even local selections are lost on leaving while the UI claims they were saved | P2 |
| A-11 | `tour_search/presentation/widgets/tour_list_card.dart:153-175` | Availability labels in Vietnamese ("Còn N chỗ", "Hết chỗ", "Chưa có lịch khởi hành", "Tình trạng chỗ chưa xác định") — CR-09 | P2 |
| A-12 | UC-10 `create_itinerary_page.dart` + BE `POST /scheduling-requests` | **Implementation gap vs V2 §3.3.1:** one-day model (start time, time available, transport, radius, must-see POIs); missing date range ≤ 30 days (BR-22/BR-23), number of travelers, interest tags (BR-21), preferred pace; budget optional instead of positive when given | P1 against V2 (blocked on D-02; existing behaviour preserved) |
| A-13 | `travel_preferences_page.dart` | Option values hard-coded in the client instead of loaded from configured option sets (BR-19), plus pre-selected defaults | P2 (attribute set pending D-04) |

## K. SRS conflicts (summary; details in `09` and `13`)

Type: **SRS** = contradiction inside Report 3 V2 · **SRS-GAP** = V2 leaves something undefined · **BE** = V2 vs backend contract. Implementation gaps against V2 are **not** listed here; they are in §J (A-xx).

| ID | Type | Conflict (exact V2 evidence) | Handling |
|---|---|---|---|
| C-01 | SRS | Table 5 authorization matrix has no Staff column (web concern) | Not applicable to Mobile |
| C-02 | SRS | Table 4.2 is captioned "Web Application Screen List" but holds mobile-only screens (#35 is described as the "Mobile landing screen"; #49, #52–#54 are mobile-only) | Treat #35–#92 as the shared Guest/Traveler/Operator index; platform per UC Interface text |
| C-03 | SRS | `V2_MESSAGE_CONFLICT`: UC sections use MSG IDs whose §5.3 meaning differs (e.g. §3.2.1 MSG03 = password policy vs catalogue MSG03 = email exists; §3.2.4 MSG10/MSG11 swapped vs catalogue; §3.3.1 MSG28/29/31 and §3.3.7 MSG32 vs POI/budget catalogue entries; §3.5.5 MSG90/91 vs refund entries; §3.5.6 MSG74; §3.6.1 MSG34/MSG75) | Semantic copy, no numeric IDs in UI; D-13 |
| C-04 | SRS | **UC-02/UC-03 platform.** §3.2.2 and §3.2.3 Interface: "responsive Next.js web application" only. Against: §1 "registers a Traveler or Tour Operator account. These functions are available on both platforms"; Table 1 (Tour Operator) "On both platforms: … resubmits a rejected application". Table 4.2 descriptions of #40/#41 state no platform. Mobile already implements #40/#41 — that is evidence of the conflict, not a resolution of it. | Pending BA adjudication D-01; no new Mobile work on #40/#41 until decided |
| C-05 | SRS | **UC-10 trip duration.** §1 "plan, book, and complete one-day trips" and "receives a one-day itinerary" vs §3.3.1 date range with BR-23 "must not exceed 30 days". | V2 §3.3.1 requirements are preserved; BA adjudication D-02. The separate implementation gap (one-day model on Mobile and BE) is A-12 |
| C-06 | SRS-GAP | CR-09 requires resource-backed English UI; V2 does not define the localization mechanism | D-03 (adopt `flutter_localizations` + ARB). Implementation debt: A-04, A-11, G-01 |
| C-07 | BE | **`UC06_OTP_TTL_SRS_VS_BACKEND`.** V2 §3.2.6 BR-14: "A password reset code is single-use and expires 15 minutes after it is issued". BE develop `0075fcb`: `PasswordResetPolicy.OtpTimeToLive = TimeSpan.FromMinutes(3)`, also used by the reset e-mail text; the request response returns only a generic `Message`, no expiry. The endpoints exist, but the behaviour does not meet V2. The §5.1 appendix entry numbered BR-14 states no lifetime; that is a less specific entry, not a contradiction, so no SRS conflict is recorded. *(Replaces the earlier reclassification of C-07 as a Mobile copy defect only.)* | UC-06 = `BACKEND_CONTRACT_GAP` (`08`). **Backend follow-up:** the BE owner reconciles the 3-minute implementation with BR-14 and verifies the associated tests and API behaviour. Mobile must not promise 15 minutes while the BE expires codes after 3; copy stays neutral (`13` S-42). Mobile copy defect: A-03 |
| C-08 | SRS | **BR-numbering.** In the UC-section numbering UC-09 is governed by BR-19 (values from configured option sets; free text refused) and BR-20 (optional; UC-25 needs ≥ 1 interest tag); BR-24 there is the Active-POI/route rule and is **not** redefined here. The §5.1 appendix reuses numbers differently: its entry numbered BR-24 lists preference attributes (transportation mode, pace, food preferences, interests, risk tolerance), while the §3.2.9 layout lists interest tags, travel style and budget level. Evidence that the appendix set is what was built: BE develop `0075fcb` entity `TravelerProfile` (`InterestTagsJson`, `PreferredTransportMode`, `TravelPace`, `RiskTolerance`, `FoodPreferencesJson`, `DefaultBudget`; no travel style) and the Mobile page groups. | BA adjudication D-04 on the attribute set. BR-19 applies in every reading; the hard-coded option values are implementation gap A-13 |
| C-09 | BE | UC-30 data: §3.6.1 "the information itself is visible to any signed-in Traveler"; BE `PublicCommercialServicesController` is `[AllowAnonymous]` | Mobile keeps the Traveler route; BE owner to confirm |
| C-10 | SRS-GAP | #68 My Tour Bookings and #70 Confirm Cancellation Modal have no exclusive UC. #70's description ("cancel an eligible booking and review the applicable refund policy") is only backed by the UC-28 alternative flow (cancel a Pending Payment booking) | Specified within UC-28/UC-29; Traveler cancellation of a confirmed booking is not specified |
| C-11 | SRS-GAP | Table 4.2 #35 **requires** trending tours and featured POIs; V2 defines no criterion for "trending" or "featured" | Sections are mandatory content (`13` S-35); only the selection criteria are pending D-14 |
| C-12 | SRS | **Commercial services platform.** UC-30: §2.2.2 UC table "This function is provided on the mobile application only" vs §3.6.1 Interface "Flutter mobile application and … Next.js responsive web application". UC-31: §1 "On the mobile application, the Traveler can additionally … book commercial services" and Table 1 (Traveler) "On mobile only: … commercial service booking" vs §3.6.2 Interface (both applications). | Mobile is in scope in every reading, so Mobile UC-30 is not blocked. The web allocation is for BA (D-12, which also covers UC-31 scope) |
| C-13 | SRS | **UC-04 Administrator on Mobile.** §3.2.4 Actors: "Traveler, Tour Operator, Administrator"; Interface: "Sign In screen on the Flutter mobile application and the responsive Next.js web application". Against: Table 1 (Administrator) "Web application only"; §1 "Administrators use the web application" and "The administration workspace is provided exclusively through the web application"; Table 4.1 #2 Administration Login (Administrator or Staff); Table 4.2 #36 "Allows a Traveler or Tour Operator to authenticate to the TripMate mobile application"; Table 5 "Mobile Sign In" = Guest, "Admin Login" = Admin. *Not a conflict:* the §2.2.2 actor "Guest" vs the §3.2.4 roles — a Guest holding a registered account signs in and continues in the assigned role, two perspectives of the same flow. *Missing detail, not counted as a conflict:* §2.2.2 ("such as … phone number/OTP") and the §5.1 appendix entry numbered BR-09 name phone number/OTP sign-in, but §3.2.4 specifies only email/password and Google and defines no phone/OTP flow; phone/OTP sign-in is not designed here and is raised with D-16. | Impacted: #36, #37; Administrator role. Proposed (not approved): §3.2.4 Administrator sign-in means the Web Administration Login only; Mobile #36/#37 serve Traveler and Tour Operator. Decision D-16 (BA + Tech Lead), **PENDING**. Implication: no Administrator Flutter functionality is designed; the existing Mobile refusal of Administrator sign-in is kept. Adding Administrator to Mobile would need new approved requirements |
| C-14 | SRS | **UC-06 Administrator on Mobile.** §3.2.6 Actors: "Traveler, Tour Operator, Administrator"; Interface: "Forgot Password, Enter Reset Code and Set New Password screens on the Flutter mobile application and the responsive Next.js web application". Against: Table 1 (Administrator "Web application only"); Table 4.1 #3 Administration Reset Password (Administrator); Table 4.2 #42 "Allows a Traveler or Tour Operator …"; Table 5 "Password Reset" = Guest, "Admin Reset Password" = Admin. *Not a conflict:* §2.2.2 actor "Guest" (the user is unauthenticated while resetting). *Scope note, not counted separately:* §2.2.2 says "registered email address or phone number" and "a reset link or OTP"; §3.2.6 specifies a single-use code sent to the registered email address only. The detailed section is more specific; a phone channel is not specified and is not designed. | Impacted: #42; Administrator role. Proposed (not approved): Mobile #42 serves Traveler and Tour Operator; Administrator reset is the Web Administration Reset Password. Decision D-16, **PENDING**. Implication: no Administrator path on Mobile; #42 design is unchanged for Traveler and Tour Operator |
| C-15 | SRS | **UC-07 Administrator on Mobile.** §2.2.2 and §3.2.7 Actors: "Traveler / Tour Operator / Administrator"; §3.2.7 Interface: "Change Password screen in the account settings area of the Flutter mobile application and the responsive Next.js web application". Against: Table 1 (Administrator "Web application only"); Table 4.1 #4 Administration Change Password (Administrator **or Staff** — Staff is absent from the UC-07 actors); Table 4.2 #43 "Allows an authenticated Traveler or Tour Operator …"; Table 5 "Change Password" = Traveler, Tour Operator; "Admin Change Password" = Admin. | Impacted: #43; Administrator and Staff roles. Proposed (not approved): Mobile #43 serves Traveler and Tour Operator; Administrator/Staff use the Web Administration Change Password. Decision D-16, **PENDING**. Implication: S-43 is designed for Traveler and Tour Operator only |
| C-16 | SRS | **Home / landing page platform (#35).** §1: "Guest browses the landing page … These functions are available on both platforms". Table 1 (Guest): "the public landing page is part of the web application". Table 4.1 #1 "TripMate Landing Page" (Web). Table 4.2 #35 "Home Page — Mobile landing screen for unauthenticated guests", inside a table captioned "Web Application Screen List" (C-02). Table 5: "Home Page (Guest)" = Guest only; "TripMate Landing Page" = Guest, Admin. No UC owns #35. The overlapping number Table 4.1 #35 (Staff Dashboard) is a separate namespace (§B), not part of this conflict. | Impacted: #35; Guest. Proposed (not approved): two distinct screens — the Web public landing page (Table 4.1 #1) and the Mobile Guest home (Table 4.2 #35) — with Table 1's sentence referring to the Web page only. Decision D-17 (BA), **PENDING**. Implication: S-35 stays in the Mobile MVP and `DESIGN_PARTIAL` (also D-14); no Web landing-page design is derived from #35 |
| C-17 | SRS | **UC-08 email editability.** §3.2.8 BR-17: "The account email address is not editable through the profile function"; Screen Layout "Read-only field: Email Address". Against: §2.2.2 UC-08 "update supported personal profile information such as full name, avatar, phone number, email address …" and the §5.1 appendix entry numbered BR-23 "can modify only profile fields (name, avatar, phone, email, etc.)". | Impacted: #45. The design keeps the email read-only per the detailed §3.2.8 rule (proposed, not approved). Decision D-15 (BA), **PENDING**, together with the required-field set and the Gender value set |

## L. Recommended order (design and implementation)

1. Land PR #25 once the reviewer re-reviews the pushed P1 fix (removes A-06/A-08/A-09 from production paths; unblocks truthful #41/#45/#46).
2. CR-09 resource layer decision (D-03) — prerequisite for every new screen.
3. #55 Travel Groups list (no BE dependency beyond existing reads; closes a dead link).
4. UC-30 on PR #32 — rebase and replace the demo store with `/commercial-services`.
5. UC-24 filter/sort completion once BE query support is confirmed.
6. UC-25/UC-26 (PR #31), then UC-27→UC-29 (open a PR for the booking branch) — all `NO_BACKEND`; keep production truthful.
7. UC-07 #43 when a change-password endpoint exists.
8. UC-20/21/22 and UC-16 completion when their contracts exist.
