# 09 — Mobile MVP Screen Index (#35–#92) — Report 3 V2 revision 2026-10-08

Screen numbers are the V2 §3.1.2.2 Table 4.2 identifiers, not UC numbers. V2 captions Table 4.2 as "Web Application Screen List" although it includes mobile-only screens (conflict C-02); this index treats it as the shared Guest / Traveler / Tour Operator screen list. The Administration screens (Table 4.1 #1–#41) are web-only and are never part of Mobile.

Platform comes from each UC's V2 "Interface" sentence, not from the table caption.

**QA verification against V2 Table 4.2 descriptions (all 32 MVP screen IDs re-read):** every ID/name below matches V2. Only two descriptions state a platform: #35 "Mobile landing screen for unauthenticated guests" and #36 "…the TripMate mobile application". The others are platform-neutral, so their platform is taken from the UC Interface text. Descriptions that add requirements beyond the UC sections and are reflected in `13`: #35 (trending tours, featured POIs, planning shortcuts, sign-in prompts → C-11/D-14), #39 ("email OTP or … verification link"; Mobile uses the link), #44 (entries for active trips, bookings, recommendations, groups), #70 (Traveler cancels an eligible booking and reviews the refund policy), #72 (also creates an eligible service booking → UC-31, out of scope).

## 1. UC → Screen mapping (25-UC MVP)

| UC | V2 title | Screens | Platform (V2 interface) | Mapping note |
|---|---|---|---|---|
| UC-01 | Register Traveler Account | #38, #39, #37 | Mobile + Web | #37 is the Google path shared with UC-04 |
| UC-02 | Register Tour Operator Account | #40 | Web (interface text) | C-04: Mobile already implements #40 |
| UC-03 | Resubmit Tour Operator Application | #41 | Web (interface text) | C-04 |
| UC-04 | Sign In | #36, #37 | Mobile + Web | |
| UC-05 | Sign Out | — | Mobile + Web | Account-menu action with confirmation dialog; no index screen |
| UC-06 | Reset Password | #42 | Mobile + Web | V2 describes three steps (email, code, new password) |
| UC-07 | Change Password | #43 | Mobile + Web | |
| UC-08 | Update Traveler Profile | #45 | Mobile + Web | |
| UC-09 | Update Travel Preferences | #46 | Mobile + Web | |
| UC-10 | Create Scheduling Request | #47 | Mobile + Web | Hands off to #48 (UC-11, out of scope) |
| UC-16 | Download Offline Map & Itinerary | #49 | Mobile only | |
| UC-17 | Create Travel Group | #56 | Mobile only | |
| UC-18 | Invite Group Members | #58 | Mobile only | |
| UC-19 | View Group Members | #57 | Mobile only | |
| UC-20 | Remove Group Member | #59 (on #57) | Mobile only | |
| UC-21 | Leave Travel Group | #60 | Mobile only | |
| UC-22 | Configure Group Location Sharing | #61 | Mobile only | |
| UC-23 | Join Shared Group Trip | #62 | Mobile only | |
| UC-24 | Search Tours | #63 | Mobile + Web | |
| UC-25 | Receive Tour Recommendations | #64 | Mobile + Web | |
| UC-26 | View Tour Details | #65 | Mobile + Web | |
| UC-27 | Book Tour | #66 | Mobile + Web | |
| UC-28 | Make Electronic Payment | #67, #70 | Mobile + Web | #70 serves the V2 "Cancel the booking instead of paying" alternative flow (C-10) |
| UC-29 | View QR E-ticket | #69, #68 | Mobile + Web | #68 is the entry list; no exclusive UC (C-10) |
| UC-30 | View Commercial Service | #72 (#71 entry) | Mobile + Web | #72 also hosts UC-31 booking (out of scope) |
| — | (no distinct UC) | #35 Home Page, #44 Traveler Home / Dashboard, #55 Travel Groups | — | `SCREEN_WITHOUT_DISTINCT_UC`; navigation hubs required by the MVP journeys |

## 2. Screen Index #35–#92 implementation matrix

Status vocabulary: see `00-mobile-mvp-audit.md` §G. "MVP" = belongs to the 25-UC scope.

| # | Screen | UC | MVP | Mobile route / page on develop `acfde81` | Status | Evidence / note |
|---|---|---|---|---|---|---|
| 35 | Home Page | — | hub | none (Guest lands on `/explore` or `/auth/login`) | `NOT_STARTED` | Spec S-35; V2 content C-11/D-14 |
| 36 | Sign In | UC-04 | yes | `/auth/login` `LoginPage` | `IMPLEMENTED_VERIFIED` | PR #13 |
| 37 | Sign In with Google | UC-01/04 | yes | button on `LoginPage` | `IMPLEMENTED_VERIFIED` | `/auth/google` |
| 38 | Traveler Registration | UC-01 | yes | `/auth/register/traveler` | `IMPLEMENTED_VERIFIED` | PR #6 |
| 39 | Confirm Email | UC-01 | yes | `/auth/verify-email` | `IMPLEMENTED_VERIFIED` | PR #6 |
| 40 | Tour Operator Registration & Verification | UC-02 | yes | `/auth/register/operator` | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` + `BLOCKED_BY_SRS` | PR #34 merged; BE PR #52 open |
| 41 | Operator Application Status | UC-03 | yes | `/operator/application` | `IMPLEMENTED_PARTIAL` + `NO_BACKEND` | PR #25 open |
| 42 | Password Reset | UC-06 | yes | `/auth/forgot-password` | `IMPLEMENTED_PARTIAL` | A-03 code lifetime copy |
| 43 | Change Password | UC-07 | yes | none | `NOT_STARTED` + `BLOCKED_BY_BACKEND` | Spec S-43 |
| 44 | Traveler Home / Dashboard | — | hub | `/traveler` `TravelerShellPage` | `IMPLEMENTED_PARTIAL` | Vietnamese labels (A-04) |
| 45 | Traveler Profile | UC-08 | yes | `/traveler/profile` | `IMPLEMENTED_PARTIAL` + `NO_BACKEND` | PR #25 open |
| 46 | Travel Preferences | UC-09 | yes | `/traveler/preferences` | `IMPLEMENTED_PARTIAL` + `NO_BACKEND` + `BLOCKED_BY_SRS` | C-08 |
| 47 | Trip / Itinerary Planner | UC-10 | yes | `/traveler/itineraries/create` | `IMPLEMENTED_PARTIAL` (gap A-12) + `BLOCKED_BY_SRS` | SRS C-05; implementation gap A-12 |
| 48 | Suggested Itinerary | UC-11 | no | `/traveler/itineraries/:id`, `/result` | `IMPLEMENTED_VERIFIED` (out of scope) | PR #21 |
| 49 | Offline Map & Itinerary | UC-16 | yes | `/traveler/trips/:id/offline` | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` | PR #24 |
| 50 | POI Explore / List | UC-12 | no | `/explore` | `IMPLEMENTED_VERIFIED` (out of scope) | PR #12 |
| 51 | POI Details | UC-12 | no | `/explore/poi/:id` | `IMPLEMENTED_VERIFIED` (out of scope) | PR #12 |
| 52 | Live Trip Navigation | UC-13 | no | `/traveler/trips/:id/live` | `IMPLEMENTED_PARTIAL` (out of scope) | PR #24 |
| 53 | Real-Time Trip Alert | UC-14 | no | `/traveler/trips/:id/alerts` | `IMPLEMENTED_PARTIAL` (out of scope) | PR #24 |
| 54 | Re-routing Proposal | UC-15 | no | sheet on #52 | `IMPLEMENTED_PARTIAL` (out of scope) | PR #24 |
| 55 | Travel Groups | — | hub | none (`/traveler/groups` constant only) | `NOT_STARTED` | A-05, spec S-55 |
| 56 | Create Travel Group | UC-17 | yes | `/traveler/groups/create` | `IMPLEMENTED_VERIFIED` | PR #5, #9 |
| 57 | Travel Group Details & Members | UC-19 | yes | `/traveler/groups/:id`, `/members` | `IMPLEMENTED_PARTIAL` | header not server-backed |
| 58 | Invite Group Members | UC-18 | yes | `/traveler/groups/:id/invitation` | `IMPLEMENTED_VERIFIED` | PR #8 |
| 59 | Remove Group Member Confirmation | UC-20 | yes | dialog on #57 | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` | PR #26 |
| 60 | Leave Travel Group Confirmation | UC-21 | yes | dialog on #57 | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` | PR #26 |
| 61 | Group Location Sharing Settings | UC-22 | yes | `/traveler/groups/:id/location-sharing` | `IMPLEMENTED_PARTIAL` + `BLOCKED_BY_BACKEND` | PR #27 |
| 62 | Join Shared Group Trip | UC-23 | yes | `/traveler/groups/join` | `IMPLEMENTED_VERIFIED` | PR #14, #30 |
| 63 | Search Tours | UC-24 | yes | `/explore/tours` | `IMPLEMENTED_PARTIAL` | filters/sort subset |
| 64 | Tour Recommendations | UC-25 | yes | PR #31 | `OPEN_PR_PARTIAL` + `NO_BACKEND` | |
| 65 | Tour Details | UC-26 | yes | PR #31 | `OPEN_PR_PARTIAL` + `NO_BACKEND` | |
| 66 | Tour Booking Confirmation | UC-27 | yes | branch only | `NOT_STARTED` (`BRANCH_NO_PR`) + `NO_BACKEND` | |
| 67 | Electronic Payment | UC-28 | yes | branch only | `NOT_STARTED` (`BRANCH_NO_PR`) + `NO_BACKEND` | |
| 68 | My Tour Bookings | UC-29 entry (C-10) | yes | branch only | `NOT_STARTED` + `NO_BACKEND` | |
| 69 | Booking Details & QR E-ticket | UC-29 | yes | branch only | `NOT_STARTED` (`BRANCH_NO_PR`) + `NO_BACKEND` | |
| 70 | Confirm Cancellation Modal | UC-28 alt (C-10) | yes | branch only | `NOT_STARTED` + `NO_BACKEND` | |
| 71 | Commercial Services Search & List | UC-30 entry | yes | PR #32 | `OPEN_PR_PARTIAL` + `BE_AVAILABLE_NOT_INTEGRATED` | |
| 72 | Commercial Service Details & Booking | UC-30 (UC-31 booking) | yes (detail part) | PR #32 | `OPEN_PR_PARTIAL` + `BE_AVAILABLE_NOT_INTEGRATED` | booking part out of scope |
| 73 | Trip History | UC-32 | no | PR #33 | `OPEN_PR_REVIEW_REQUIRED` (out of scope) | |
| 74 | Trip Review & Rating | UC-33 | no | PR #33 | `OPEN_PR_REVIEW_REQUIRED` (out of scope) | |
| 75 | Tour Operator Dashboard | — | no | `/operator` `OperatorShellPage` | `OUT_OF_MVP_SCOPE` | existing shell preserved |
| 76 | Tour Operator Profile | UC-34 | no | none | `OUT_OF_MVP_SCOPE` | |
| 77 | Tour Packages List | UC-35/36 | no | none | `OUT_OF_MVP_SCOPE` | |
| 78 | Create Tour Package | UC-35 | no | none | `OUT_OF_MVP_SCOPE` | |
| 79 | Update Tour Package | UC-36 | no | none | `OUT_OF_MVP_SCOPE` | |
| 80 | Tour Preview & Submit for Approval | UC-37 | no | none | `OUT_OF_MVP_SCOPE` | |
| 81 | Promotional Coupons List | UC-38/39 | no | none | `OUT_OF_MVP_SCOPE` | |
| 82 | Create Coupon | UC-38 | no | `/operator/coupons/create` | `OUT_OF_MVP_SCOPE` (implemented, PR #29) | BE PR #44 open |
| 83 | Update Coupon | UC-39 | no | none | `OUT_OF_MVP_SCOPE` | |
| 84 | Customer Bookings List | UC-40 | no | none | `OUT_OF_MVP_SCOPE` | |
| 85 | Booking Details & Passenger Manifest | UC-40 | no | none | `OUT_OF_MVP_SCOPE` | |
| 86 | Cancel Customer Booking | UC-41 | no | none | `OUT_OF_MVP_SCOPE` | |
| 87 | Initiate Booking Refund | UC-42 | no | none | `OUT_OF_MVP_SCOPE` | |
| 88 | Tour Participant QR Check-in Scanner | UC-43 | no | none | `OUT_OF_MVP_SCOPE` | mobile-only per §1 |
| 89 | Revenue & Analytics | UC-44 | no | none | `OUT_OF_MVP_SCOPE` | |
| 90 | Export Revenue Report | UC-45 | no | none | `OUT_OF_MVP_SCOPE` | |
| 91 | Payout Settlement History | UC-46 | no | none | `OUT_OF_MVP_SCOPE` | |
| 92 | Payout Request | UC-46 | no | none | `OUT_OF_MVP_SCOPE` | |

## 3. Index findings

| Check | Result |
|---|---|
| Duplicate screens | None found on develop. Risk: PR #31 and the booking branch both add `tour_detail` (`TourDetailCubit`, `tour_detail_page.dart`); the booking branch depends on PR #31 code. Merge order must be #31 first. |
| Missing screens (MVP) | #35, #43, #55 on develop; #64–#72 only in PRs/branch. |
| Incorrect UC mapping | None in code. Index ambiguity: #68 and #70 have no exclusive UC (C-10). |
| Actor ownership | Group Host actions (#58, #59) are gated by host checks; Host is a Traveler, not a Tour Operator. Correct. |
| Platform allocation | #40/#41: V2 allocates UC-02/UC-03 to the Web; Mobile implements them — mismatch C-04, BA adjudication D-01. |
| Missing routes | `/traveler/groups` (#55). |
| Broken journeys | Join → "open group list" path targets `/traveler/groups/{id}` (works); any link to `/traveler/groups` alone has no route. Tour search has no route to #65 on develop (PR #31). |
| Missing states | #45/#46 on develop show local "saved for demo" success (A-06); #45 shows hard-coded identity as the user's data (A-08); #41 simulates resubmission (A-09). All addressed by open PR #25. |
| Permission handling | Location (#61) and camera (#62) permission states exist. Avatar picker (#45) not implemented. |
| Conflicts with V2 | SRS: C-04, C-05, C-08, C-12; undefined in V2: C-10, C-11 (see `00` §K). Implementation gaps vs V2 are A-xx (e.g. A-03 reset-code copy, A-12 UC-10 model, A-13 option values). |

## 4. Totals

| Scope | Screens | On develop (any status) | Missing on develop |
|---|---|---|---|
| MVP screens (incl. hubs #35, #44, #55) | 32 (#35–#47, #49, #55–#72) | 20 | 12 (#35, #43, #55, #64–#72) |
| Out of MVP (#48, #50–#54, #73–#92) | 26 | 8 (#48, #50–#54, #75, #82) | 18 |
| **Index total** | **58** | **28** | **30** |
