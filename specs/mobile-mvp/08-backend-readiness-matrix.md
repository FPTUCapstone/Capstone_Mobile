# 08 — Backend Readiness Matrix (revision 2026-10-08)

Source: `Capstone_BE` `origin/develop` = `0075fcb`, read-only (controller `[Route]` and `[Http*]` attributes). Open BE PRs are listed separately and are **never** treated as deployed. No endpoint, DTO field, status value or payload in this file is invented; a missing capability is written as "none".

## 1. Verified Backend surface relevant to the Mobile MVP

| Method | Path | Notes |
|---|---|---|
| POST | `/api/v1/auth/register` | Traveler registration |
| POST | `/api/v1/auth/verify-email` | Email verification |
| POST | `/api/v1/auth/google` | Google sign-in (mobile) |
| POST | `/api/v1/auth/login` | Mobile sign-in |
| POST | `/api/v1/auth/logout` | Mobile sign-out |
| POST | `/api/v1/auth/password-reset/request`, `/confirm` | Reset password |
| POST | `/api/v1/scheduling-requests` | UC-10 (one-day model; see C-05) |
| GET | `/api/v1/points-of-interest/search` | Must-see POI search for UC-10 |
| GET / POST / PUT | `/api/v1/itineraries/{id}`, `/accept`, `/regenerate`, `/items` | UC-11 (out of scope; UC-16 input) |
| GET | `/api/v1/pois`, `/api/v1/pois/{id}` | UC-12 (out of scope) |
| POST | `/api/v1/travel-groups` | UC-17 |
| POST | `/api/v1/travel-groups/{groupId}/invitation`, `/invitation/regenerate` | UC-18 |
| GET | `/api/v1/travel-groups/{groupId}/members` | UC-19 |
| POST | `/api/v1/travel-groups/join` | UC-23 |
| GET | `/api/v1/tours` | UC-24 search (query support not re-verified field by field) |
| GET | `/api/v1/commercial-services`, `/api/v1/commercial-services/{id}` | UC-30; `[AllowAnonymous]` |
| POST | `/api/v1/poi-recommendations`, `/api/v1/recommendation-feedback` | POI recommendations — **not** tour recommendations |

Absent on BE develop (searched): `/auth/register/operator`, operator application resubmission, change password, traveler profile read/update, travel preferences, group detail, member removal, leave group / host succession, group location sharing, `/tours/{id}`, tour recommendations, bookings, payments, gateway callbacks, e-tickets, offline package metadata.

## 2. Open Backend PRs relevant to the Mobile MVP (not deployed)

| BE PR | Branch | Relevance |
|---|---|---|
| #52 | `feature/linhnv-register-tour-operator` | UC-02 `/auth/register/operator` consumed by merged Mobile PR #34 |
| #50 | `feature/staff-role-foundation` | Web administration only |
| #44 | `feature/khanhpq-create-coupon` | UC-38 (out of MVP scope; Mobile PR #29 merged) |
| #30 | `feature/datmnt-submit-trip-review` | UC-33 (out of MVP scope; Mobile PR #33) |

## 3. Readiness matrix (25 MVP UCs)

| UC | Classification | Endpoint / DTO reference (verified) | Mobile consumer | Auth context | Expected response / error states (V2) | Integration blocker | UI design implication |
|---|---|---|---|---|---|---|---|
| UC-01 | `BE_AVAILABLE_AND_VERIFIED` | `/auth/register`, `/auth/verify-email`, `/auth/google` | `AuthRemoteDataSource` | Anonymous | Duplicate email, policy failure, invalid/expired code, server failure | — | Keep existing screens |
| UC-02 | `BE_PR_OPEN` | none on develop (BE PR #52) | `AuthRemoteDataSource.registerOperator` (`/auth/register/operator`) | Anonymous | Duplicate email/licence/tax code, missing document, file type/size, pending duplicate | Merged Mobile code calls an endpoint that develop does not serve | Production must show a truthful failure, never success, until BE #52 merges |
| UC-03 | `NO_BACKEND` (resubmission) | Status only: `applicationStatus` in the login/session response (`/auth/login`), mapped by `RouteGuards` | `OperatorApplicationCubit` (local) | Tour Operator, Pending/Rejected | Not-rejected, missing field/document, duplicate licence/tax | No rejection-reason read, no status refresh, no resubmit contract | Status from session; reason and resubmit unavailable in production |
| UC-04 | `BE_AVAILABLE_AND_VERIFIED` | `/auth/login`, `/auth/google` | `AuthRemoteDataSource` | Anonymous | Invalid credentials, locked, unverified, server failure | — | Keep |
| UC-05 | `BE_AVAILABLE_AND_VERIFIED` | `/auth/logout` | `AuthSessionCubit.signOut` | Authenticated | Missing/malformed token still clears client | — | Keep |
| UC-06 | `BE_AVAILABLE_AND_VERIFIED` | `/auth/password-reset/request`, `/confirm` | `PasswordRecoveryRemoteDataSource` | Anonymous | Non-disclosure on unknown email; invalid/expired/consumed code; policy | Code lifetime copy (C-07) | Copy correction only |
| UC-07 | `NO_BACKEND` | none | none | Authenticated | Wrong current password, policy, same password | No endpoint | Screen specified; production action must be unavailable |
| UC-08 | `NO_BACKEND` | none | `TravelerProfilePage` (local) | Traveler | Retrieval failure, required field, phone/DOB format, avatar type/size | No profile contract | Truthful read-only/pending in production |
| UC-09 | `NO_BACKEND` + `SRS_CONFLICT` | none | `TravelPreferencesCubit` (local) | Traveler | Option-set violation, limit, persistence failure | No contract (preferences + configured option sets, BR-19); attribute set pending BR-numbering adjudication (C-08) | Truthful pending; option groups await D-04 |
| UC-10 | `BE_AVAILABLE_AND_VERIFIED` (one-day model) + `SRS_CONFLICT` | `/scheduling-requests`, `/points-of-interest/search` | `ItineraryRepositoryImpl`, `PointOfInterestRepositoryImpl` | Traveler | Missing criteria, invalid range, no feasible itinerary, server failure | BE contract implements a one-day model; V2 §3.3.1 date-range/travelers/interest-tags/pace inputs have no BE support (C-05) | Preserve implemented form; V2 inputs need a BE contract after D-02 |
| UC-16 | `NO_BACKEND` (map/offline data source) | itinerary read exists (`GET /itineraries/{id}`); no map-tile or package metadata source | `OfflineTripPackageCubit` | Traveler (owner) | Not found, not accessible, insufficient storage, > 150 MB, network loss | Map data provider and package-size source undecided | Production stays "not available yet" |
| UC-17 | `BE_AVAILABLE_AND_VERIFIED` | `POST /travel-groups` | `TravelGroupRepositoryImpl` | Traveler | 401/403, required field, itinerary not owned, persistence failure | — | Keep |
| UC-18 | `BE_AVAILABLE_AND_VERIFIED` | `/invitation`, `/invitation/regenerate` | `TravelGroupRepositoryImpl` | Group Host | Not host, generation failure | — | Keep |
| UC-19 | `BE_AVAILABLE_AND_VERIFIED` (members only) | `GET /travel-groups/{id}/members` | `TravelGroupMembersCubit` | Active member | Not member, retrieval failure, empty | Members response already carries `groupName`, `itineraryId`, `memberCount`; missing: group status and a self-member marker | Compose the header from the members response; no `#<id>` placeholder after load |
| UC-20 | `NO_BACKEND` | none | `RemoveGroupMemberDialog` | Group Host | Not host, not active, update failure | No removal contract | Keep fail-closed dialog |
| UC-21 | `NO_BACKEND` | none | `LeaveTravelGroupDialog` | Active member | Host succession, closure, update failure | No leave/succession contract | Keep fail-closed dialog |
| UC-22 | `NO_BACKEND` | none | `GroupLocationSharingCubit` | Active member | Permission denied, save failure | No opt-in persistence or broadcast | Keep production pending |
| UC-23 | `BE_AVAILABLE_AND_VERIFIED` | `POST /travel-groups/join` | `JoinTravelGroupCubit` | Traveler | Empty code, invalid/expired, already member, failure | — | Keep |
| UC-24 | `BE_AVAILABLE_AND_VERIFIED` (partial query) | `GET /tours` | `TourSearchRemoteDataSource` | Anonymous | Invalid range, empty result, failure | V2 filters beyond destination/date/price and sorting not confirmed on BE | Add only BE-supported controls; others hidden, not faked |
| UC-25 | `NO_BACKEND` | none (POI recommendations are a different resource) | PR #31 `TourRecommendationsCubit` | Traveler | No interest tag, below threshold, failure | No contract | Production truthful pending |
| UC-26 | `NO_BACKEND` | none (`/tours/{id}` absent) | PR #31 `TourDetailCubit` | Anonymous to view | Unpublished/sold out, no reviews, failure | No contract | Production truthful pending |
| UC-27 | `NO_BACKEND` | none | branch `TourBookingCubit` | Traveler | Capacity, participants, voucher, unpaid limit, failure | No contract | Production unavailable |
| UC-28 | `NO_BACKEND` | none | branch `ElectronicPaymentPage` | Booking owner | Window expired, already paid, gateway timeout, pending verification, amount mismatch | No contract; return path non-authoritative (BR-73) | Never infer success from a deep-link return |
| UC-29 | `NO_BACKEND` | none | branch ticket page | Booking owner | Not confirmed, not yet active, used, cancelled, expired | No contract | No QR without a server payload |
| UC-30 | `BE_AVAILABLE_NOT_INTEGRATED` | `GET /commercial-services` (query: `Category` ∈ Hotel/Vehicle/Restaurant, `Search`, `Page`, `PageSize` default 20), `/{id}` | PR #32 uses a demo store; V2 UC-30 also filters by location, date and price range, which the BE query does not support | BE anonymous; V2 signed-in Traveler (C-09) | Not active, non-commercial category, not open for booking, failure | PR #32 conflicting and not wired to BE | Integrate before merge |

## 4. Summary counts (25 UCs)

| Primary classification | Count | UCs |
|---|---|---|
| `BE_AVAILABLE_AND_VERIFIED` | 10 | 01, 04, 05, 06, 10, 17, 18, 19 (members only), 23, 24 (partial query) |
| `BE_AVAILABLE_NOT_INTEGRATED` | 1 | 30 |
| `BE_PR_OPEN` | 1 | 02 |
| `NO_BACKEND` | 13 | 03, 07, 08, 09, 16, 20, 21, 22, 25, 26, 27, 28, 29 |
| **Total** | **25** | |

Secondary `SRS_CONFLICT`: UC-09 (attribute set, C-08) and UC-10 (trip duration, C-05; the one-day BE contract is implementation gap A-12).

## 5. Contract questions for Backend / BA (not decided here)

1. UC-02: release plan for BE PR #52; until then Mobile #40 must not present success.
2. UC-19: can the members read (or a detail read) add the group status and a self-member marker? Name, itinerary and member count are already returned.
3. UC-24: which V2 filters and sort options does `GET /tours` support?
4. UC-30: should `/commercial-services` remain anonymous given V2 §3.6.1?
5. UC-06: actual reset-code lifetime used by the BE (V2 BR-14: 15 minutes).
6. UC-16: map data provider and the source of package size/version for the 150 MB rule.
7. UC-30: will `GET /commercial-services` support the V2 filters location, date and price range (today: `Category`, `Search`, `Page`, `PageSize`)?
