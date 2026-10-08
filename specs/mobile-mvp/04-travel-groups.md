# 04 — Travel Groups (Screens #55–#62, UC-17…UC-23)

> **Revision 2026-10-08 (QA) — how to read this file.** Preservation records P-56, P-58, P-62, P-57a remain valid. Sections S-55, S-57, S-59, S-60, S-61 remain the structural design; `13-v2-completion-specs.md` Part 2 adds the V2 layer (BR-45/48/49/50/51, MSG59–MSG63, MSG130) and replaces their status lines and `SRS_TEXT_REQUIRED` placeholders. **Stale statements below:** S-59/S-60 say `NOT_STARTED` — fail-closed dialogs are on develop (PR #26). S-61 says `NOT_STARTED`/`UNMERGED_BRANCH_NO_PR` — the settings UI is on develop (PR #27), production pending. #62 was refined by PR #30.

Standards: `C-*` in `01-mobile-shells-and-navigation.md` §1. All group features are `MOBILE_ONLY` (R3 Table 3 via `WEB_SCOPE_MATRIX`).
Reminder (AGENTS.md): a **Group Host is a Traveler**, never a Tour Operator.

---

## Part 1 — EXISTING SCREEN PRESERVATION RECORDS

### P-56 Create Travel Group (UC-17) — `MERGED_IMPLEMENTED`
- Route `/traveler/groups/create` (requires `CreateTravelGroupRouteArgs{itineraryId > 0, itineraryTitle}` in `extra`, otherwise "A valid itinerary is required.") · `create_travel_group_page.dart` · `CreateTravelGroupCubit` · `TravelGroupRepositoryImpl.createTravelGroup`.
- Tests: `create_travel_group_page_test`, `create_travel_group_cubit_test`, `travel_group_model_test`, `travel_group_repository_impl_test`. Spec: `specs/TM-63-spec.md`.

**BACKEND INTEGRATION CONTRACT**
- API: `POST /api/v1/travel-groups` · Auth: Traveler JWT · Header `Idempotency-Key` (reused on retry)
- Request: `{ groupName, itineraryId }` · Response keys: `groupId, groupName, inviteCode, itineraryId`
- Errors: through `ErrorMapper`; group name validation per TM-63 spec
- Context in: `itineraryId`, `itineraryTitle` (from #48). Context out: created `TravelGroup` → #57
- **INTEGRATION CONTRACT: FROZEN.** Safe: form layout, copy, success presentation. Must not change: field names, idempotency lifecycle, required itinerary context (no standalone group without an itinerary — SRS-aligned in PR #9).

### P-58 Invite Group Members (UC-18) — `MERGED_IMPLEMENTED`
- Route `/traveler/groups/:groupId/invitation` · `invite_group_members_page.dart` (393 lines) · `InviteGroupMembersCubit` · device: QR render (`qr_flutter`), share sheet (`share_plus`).
- Tests: `invite_group_members_page_test`, `invite_group_members_cubit_test`, `group_invitation_model_test`.

**BACKEND INTEGRATION CONTRACT**
- API: `POST /api/v1/travel-groups/{groupId}/invitation` (get-or-create) and `POST /api/v1/travel-groups/{groupId}/invitation/regenerate` · Auth Traveler (host) · Header `Idempotency-Key`
- Response keys: `groupId, groupName, inviteCode, qrData, expiresAt` — **`qrData` comes from the Backend**; the client renders it, never builds it
- Error code mapped: `travel_group.invitation_unavailable`
- **FROZEN.** Safe: QR card, copy/share layout. Must not change: server-owned `qrData`, regenerate semantics (old code validity is BE-owned), host-only access.

### P-62 Join Shared Group Trip (UC-23) — `MERGED_IMPLEMENTED`
- Route `/traveler/groups/join` · `join_travel_group_page.dart` · `JoinTravelGroupCubit` · device: camera via `qr_scanner_dialog.dart` (`mobile_scanner`) + `qr_invitation_parser`.
- Tests: `join_travel_group_page_test`, `join_travel_group_cubit_test`, `qr_scanner_dialog_test`, `qr_invitation_parser_test`.

**BACKEND INTEGRATION CONTRACT**
- API: `POST /api/v1/travel-groups/join` · Auth Traveler · Header `Idempotency-Key`
- Request: `{ invitationCode }` (client trims and upper-cases) · Response: same group keys as P-56
- Scan result only pre-fills the code; **authoritative validation is server-side** (parsing a QR locally is not a successful join).
- Deep link: OS-level invitation links are not implemented (`DEVICE_INTEGRATION_MISSING`); manual code + in-app scan only.
- **FROZEN.** Safe: scanner overlay, permission states presentation. Must not change: code normalisation, server-side validation, idempotency.

### P-57a Group Members (UC-19) — members part of #57 — `MERGED_IMPLEMENTED`
- Route `/traveler/groups/:groupId/members` · `travel_group_members_page.dart` · `TravelGroupMembersCubit` (`..load(groupId)`) · tests `travel_group_members_page_test`, `travel_group_members_cubit_test`, `travel_group_members_model_test`.

**BACKEND INTEGRATION CONTRACT**
- API: `GET /api/v1/travel-groups/{groupId}/members` · Auth Traveler (member)
- Response keys: `groupId, groupName, itineraryId, memberCount, members[]`; member keys `memberId, displayName, avatarUrl, isHost, joinedAtUtc, locationSharingEnabled`
- **FROZEN.** Safe: list item visuals, host badge. Must not change: field mapping, `avatarUrl` optional handling.
- Useful facts for the missing parts below: this single read already carries the group name, linked `itineraryId`, member count, host flag per member and each member's `locationSharingEnabled`.

---

## Part 2 — DESIGN SPECIFICATIONS FOR MISSING / PARTIAL SCREENS

### S-55 Travel Groups (list)

- **Screen Index:** 55 · **UC:** entry to UC-17…UC-23 (list capability not owned by one UC; `SRS_TEXT_REQUIRED`) · **Screen Name:** Travel Groups · **Domain:** Social · **Role:** Traveler · **Platform:** Mobile
- **Presentation Type:** FULL_PAGE · **Route:** `/traveler/groups` (constant `AppRoutes.travelerTravelGroups` exists; **no GoRoute registered**) · **Parent Shell:** Traveler ("Chuyến đi" tab section)
- **Implementation Status:** NOT_STARTED · **Implementation Nature:** NOT_STARTED · **Backend Integration:** NONE · **UI Design Permission:** FULL · **Backend Contract Status:** `BACKEND CAPABILITY REQUIRED` — no endpoint lists the user's groups
- **Previous Screen:** Chuyến đi tab · **Next Screen:** #57 · **Alternative Destinations:** #56 (via an itinerary), #62 join
- **Entry Points:** Chuyến đi tab, #44 · **Entry Conditions:** Traveler · **Exit Conditions:** open group / create / join
- **User Goal:** find the groups I belong to and continue a shared trip
- **Page Header:** "Travel groups" + Join action · **Layout:** list of group cards; empty state with two actions
- **Sections:** my groups (host/member badge, member count, linked itinerary title) · Join with code (→#62)
- **Components:** feature-local `TravelGroupCard`, `StatusBadge` (Host/Member, icon + text), `AppButton`, `ErrorView`, `LoadingIndicator`
- **Primary Action:** open a group · **Secondary Actions:** Join with code; Create (explains that a group is created from an itinerary → goes to #48/planner)
- **Navigation:** card → `/traveler/groups/:groupId` with `groupId`
- **Displayed Data (semantic):** group name, my role, member count, linked itinerary, created/joined date. `DESIGN_ONLY_FIELD` + `BACKEND_SUPPORT_REQUIRED` for all (no list source)
- **Form Inputs / Validation:** none
- **Loading State:** list skeleton · **Empty State:** "You are not in a group yet" + Join / Plan a trip (distinguishes "none" from "could not load")
- **Error State:** C-STATE; retry on read failure · **Success State:** list rendered
- **Dialogs / Sheets:** none · **Offline State:** show last loaded list labelled "offline", no mutation (only if caching is later approved; none is invented)
- **Permission State:** none · **Responsive / Accessibility:** C-RESP, C-A11Y (role badge icon + text; each card one semantic button)
- **Reusable / Unique Components:** reuse list/empty/error; unique `TravelGroupCard`
- **Visual Tokens:** C-TOKENS
- **Context Received:** none · **Context Passed Forward:** `groupId` (+ nothing else; details re-read from Backend)
- **Backend Readiness (C-BE):** A user from token · B my groups (id, name, role, member count, itinerary link) · C none · D Backend · E pagination if >N (`SRS_TEXT_REQUIRED`) · F none · G none · H most recent first (BE-defined) · I 401/403/5xx · J JWT · K own groups only · L none · M deep link to a group · N none · O NO · P **list-my-groups capability** · Q all fields · R retry on network · S pull-to-refresh · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRAVEL_GROUP_LIST_CONTRACT_MISSING` (semantic: the authenticated Traveler's group memberships with identity, role, member count and linked itinerary)
- **Device Dependencies:** none · **Deep-Link Behavior:** `/traveler/groups` registered when implemented; guard handles auth
- **Demo / Production Boundary:** no fabricated groups. **Recommended current behaviour:** `PENDING_INTEGRATION_STATE` — page shows Join and "Your groups will appear here when available"; or omit the route and keep entry buttons on the tab
- **Design-only Assumptions:** card content
- **Implementation Notes:** until BE exists a group is only reachable immediately after create/join (route `extra`) or via `/traveler/groups/:id` by id.
- **Non-goals:** group chat, group search
- **Acceptance Criteria:** AC1 no invented groups; AC2 empty and error states distinct; AC3 route registered only when data exists; AC4 role badge not colour-only; AC5 guard behaviour unchanged.

### S-57 Group Details & Members (missing part: details + role actions)

- **Screen Index:** 57 · **UC:** UC-19 (members, done), UC-20/UC-21 entry points, UC-22 entry · **Screen Name:** Travel Group Details & Members · **Domain:** Social · **Role:** Traveler (host or member) · **Platform:** Mobile
- **Presentation Type:** FULL_PAGE · **Route:** `/traveler/groups/:groupId` (+ existing `/members`) · **Parent Shell:** Traveler
- **Implementation Status:** MERGED_PARTIAL · **Implementation Nature:** PARTIAL_BE_INTEGRATION — `TravelGroupDetailsPage` is a thin shell: title from route `extra` or `Travel Group #<id>`, "View members", host-only "Invite Members"; **no Backend read**, host flag only known when arriving from create · **Backend Integration:** PARTIAL (members endpoint real; no group-detail endpoint) · **UI Design Permission:** MISSING_PART_ONLY · **Backend Contract Status:** details can be composed from the verified members read; role actions have no Backend capability
- **Previous Screen:** #55 / #56 / #62 · **Next Screen:** #58 · **Alternative Destinations:** #59, #60, #61, #48 (linked itinerary)
- **Entry Points:** create success, join success, #55, deep link · **Entry Conditions:** member of the group · **Exit Conditions:** back, leave, removed
- **User Goal:** see the group, its members and trip, and manage my place in it
- **Page Header:** group name (Backend) + member count · **Layout:** header card → trip card → members list → role actions. Visual reference: `chi_ti_t_nh_m_amp_m_m_i_tripmate`
- **Sections:** (1) group header (name, `memberCount`) (2) linked trip card (`itineraryId` → #48) (3) invite code (host only, from existing invitation read) (4) members list (avatar, `displayName`, Host badge, joined date, sharing indicator) (5) actions: host → Invite, Remove (per member); member → Leave; both → Location sharing
- **Components:** `AppPageScaffold`, `StatusBadge`, `Avatar` (NEW_SHARED), feature-local `GroupMemberTile`, `ConfirmationDialog` (NEW_SHARED, see #59/#60)
- **Primary Action:** Invite members (host) / Share trip location settings (member) · **Secondary Actions:** Remove member, Leave group, View itinerary
- **Navigation:** pushes #58 / #61 / #48; dialogs for #59/#60
- **Displayed Data:** all from `GET /travel-groups/{id}/members` (group name, itinerary id, member count, per-member `memberId/displayName/avatarUrl?/isHost/joinedAtUtc/locationSharingEnabled`). "Which member am I" is **not** provided → `BACKEND_SUPPORT_REQUIRED` (needed to hide Remove on self and to choose Leave vs host actions). Until then the host flag must come from a Backend-confirmed source, not from route args alone
- **Form Inputs / Validation:** none
- **Loading State:** header skeleton + list skeleton · **Empty State:** members list never empty (host exists); if it is, show error · **Error State:** 403 not a member → "You are not a member of this group" (no retry); 404 → "Group not found"; read failure → retry
- **Success State:** after any mutation the screen **re-reads** the members endpoint (no optimistic edit)
- **Dialogs / Sheets:** remove-member and leave-group confirmations (#59, #60)
- **Offline State:** read-only if cached copy exists; mutations disabled
- **Permission State:** none here (location permission lives in #61)
- **Responsive / Accessibility:** C-RESP, C-A11Y; member rows are single focusable items with "Host" spoken; destructive buttons labelled with the member's name
- **Reusable / Unique Components:** reuse; NEW_SHARED `Avatar`, `ConfirmationDialog`
- **Visual Tokens:** C-TOKENS (destructive actions use `error` + icon + text)
- **Context Received:** `groupId` (required), optional `TravelGroup`/`isHost` hint (display-only until verified) · **Context Passed Forward:** `groupId`, `memberId` (for #59), `itineraryId`
- **Backend Readiness (C-BE):** A `groupId` · B members read (verified) · C remove/leave/sharing (see #59–#61) · D Backend · E none · F none · G none · H joined order (BE) · I 401/403/404/5xx · J JWT · K member-only; host-only for remove/invite · L none · M `/traveler/groups/:id` · N none · O NO · P **self identity marker; group detail beyond members** · Q none besides above · R retry reads; no auto-retry of mutations · S pull-to-refresh re-calls members · T invite code (host) · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRAVEL_GROUP_SELF_MEMBER_MARKER_MISSING`
- **Device Dependencies:** none · **Deep-Link Behavior:** valid entry after guard; `from` returns here after login
- **Demo / Production Boundary:** none; `Travel Group #<id>` placeholder title must be replaced by loading → real name
- **Design-only Assumptions:** trip card content
- **Implementation Notes:** keep `TravelGroupMembersCubit` and the members endpoint; extend, do not replace.
- **Non-goals:** chat, expense splitting
- **Acceptance Criteria:** AC1 header data comes from the members read; AC2 host actions only for a Backend-confirmed host; AC3 every mutation is followed by a re-read; AC4 no `#<id>` placeholder shown after load; AC5 members contract unchanged.

### S-59 Remove Group Member Confirmation

- **Screen Index:** 59 · **UC:** UC-20 · **Screen Name:** Remove Group Member Confirmation · **Domain:** Social · **Role:** Traveler (host) · **Platform:** Mobile
- **Presentation Type:** MODAL (confirmation dialog inside #57) · **Route:** none (dialog) · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Implementation Nature:** NOT_STARTED · **Backend Integration:** NONE · **UI Design Permission:** FULL · **Backend Contract Status:** `BACKEND CAPABILITY REQUIRED` (no remove-member endpoint in BE develop)
- **Previous Screen:** #57 · **Next Screen:** #57 (refreshed) · **Alternative Destinations:** none
- **Entry Points:** Remove action on a member row (host, not self, not host) · **Entry Conditions:** viewer is host, target is another member · **Exit Conditions:** confirm → request; cancel → close
- **User Goal:** remove a member without doing it by accident
- **Page Header:** "Remove <displayName>?" · **Layout:** title, consequence text, two buttons
- **Sections:** consequence text ("They will lose access to this group's trip and location sharing" — wording `SRS_TEXT_REQUIRED`), optional reason field only if SRS requires it
- **Components:** NEW_SHARED `ConfirmationDialog`, `AppButton` (destructive style), `AppAlert`
- **Primary Action:** Remove (destructive) · **Secondary Actions:** Cancel (default focus)
- **Navigation:** closes dialog; refreshes #57
- **Displayed Data:** member display name, avatar
- **Form Inputs / Validation:** none
- **Loading State:** Remove button progress, both buttons disabled · **Empty State:** n/a
- **Error State:** 403 not host, 404 member already gone (treat as refreshed state), 409 rule violation (e.g. cannot remove host; `SRS_TEXT_REQUIRED`), network → message, no auto-retry; **unknown outcome** after timeout → "Check the member list before trying again"
- **Success State:** dialog closes, #57 re-reads members; member no longer present (Backend truth)
- **Dialogs / Sheets:** this dialog · **Offline State:** Remove disabled
- **Permission State:** none · **Responsive / Accessibility:** C-RESP, C-A11Y; initial focus on Cancel; destructive button announces the member name
- **Reusable / Unique Components:** NEW_SHARED `ConfirmationDialog` (shared with #60, #70, #80 submit-for-approval, #86, #87) · none unique
- **Visual Tokens:** C-TOKENS
- **Context Received:** `groupId`, `memberId`, `displayName` · **Context Passed Forward:** none
- **Backend Readiness (C-BE):** A `groupId`, `memberId` · B none · C remove member · D Backend · E–H none · I 400/401/403/404/409/5xx · J JWT · K host-only (server-enforced, never trusted from client) · L none · M none · N none · O **NO** · P **endpoint missing** · Q optional reason · R no auto-retry; user-initiated retry only after re-reading state · S re-read members · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRAVEL_GROUP_REMOVE_MEMBER_CONTRACT_MISSING`
- **Device Dependencies:** none · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** until BE exists the Remove action is hidden (not shown and failing)
- **Design-only Assumptions:** consequence wording
- **Implementation Notes:** use one confirmation component for all destructive flows (see `10`).
- **Non-goals:** ban list, re-invite rules
- **Acceptance Criteria:** AC1 only the host sees it; AC2 success only after Backend confirms; AC3 member list re-read after; AC4 Cancel is the default focus; AC5 hidden while capability is missing.

### S-60 Leave Travel Group Confirmation

- **Screen Index:** 60 · **UC:** UC-21 · **Screen Name:** Leave Travel Group Confirmation · **Domain:** Social · **Role:** Traveler (member; host behaviour `SRS_TEXT_REQUIRED`) · **Platform:** Mobile
- **Presentation Type:** MODAL inside #57 · **Route:** none · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED · **Backend Integration:** NONE · **UI Design Permission:** FULL · **Backend Contract Status:** `BACKEND CAPABILITY REQUIRED`
- **Previous Screen:** #57 · **Next Screen:** #55 (or Chuyến đi tab) · **Alternative Destinations:** stay
- **Entry Points:** "Leave group" action · **Entry Conditions:** viewer is a member · **Exit Conditions:** left, or cancelled
- **User Goal:** leave a group deliberately
- **Page Header:** "Leave <groupName>?" · **Layout:** title, consequence text, buttons
- **Sections / Components:** consequence ("You will lose access to this group's trip and stop sharing your location"; wording `SRS_TEXT_REQUIRED`) · `ConfirmationDialog`
- **Primary Action:** Leave (destructive) · **Secondary Actions:** Stay
- **Navigation:** success → pop to #55 / tab; replace #57 in the stack
- **Displayed Data:** group name · **Form Inputs / Validation:** none
- **Loading/Empty/Error:** as #59; 409 host cannot simply leave → host-specific message when SRS defines the rule
- **Success State:** only after Backend confirms; then the group disappears from #55 (Backend truth)
- **Dialogs / Sheets:** this dialog · **Offline State:** disabled · **Permission State:** none
- **Responsive / Accessibility:** C-RESP, C-A11Y
- **Reusable / Unique Components:** `ConfirmationDialog`
- **Visual Tokens:** C-TOKENS
- **Context Received:** `groupId`, `groupName`, role · **Context Passed Forward:** none
- **Backend Readiness (C-BE):** A `groupId` · B none · C leave · D Backend · E–H none · I 401/403/404/409/5xx · J JWT · K member · L none · M none · N none · O **NO** · P **endpoint missing; host-leave semantics (transfer/disband) undefined** · Q none · R user-initiated after re-read · S re-read groups · T none · U Backend
- **Authoritative State Owner:** Backend · **Required Backend Capability:** `TRAVEL_GROUP_LEAVE_CONTRACT_MISSING`
- **Device Dependencies:** stop location publishing on leave (ties to #61 device service) · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** action hidden until capability exists
- **Design-only Assumptions:** wording · **Implementation Notes:** shares component with #59
- **Non-goals:** transfer host UI (not specified)
- **Acceptance Criteria:** AC1 no success without Backend; AC2 location publishing stops once leave is confirmed; AC3 hidden until capability exists; AC4 destructive button labelled; AC5 host rule not invented.

### S-61 Group Location Sharing Settings

- **Screen Index:** 61 · **UC:** UC-22 · **Screen Name:** Group Location Sharing Settings · **Domain:** Social/Privacy · **Role:** Traveler · **Platform:** Mobile
- **Presentation Type:** FULL_PAGE (privacy/settings) · **Route:** `/traveler/groups/:groupId/location-sharing` PROPOSED (the unmerged branch registers `groupLocationSharing`) · **Parent Shell:** Traveler
- **Implementation Status:** NOT_STARTED **on develop** · **Implementation Nature:** `UNMERGED_BRANCH_NO_PR` — branch `feature/khanhpq-configure-group-location-sharing` (commit `523b23c`, 19 files, +1814) adds `location_sharing_page`, `LocationSharingCubit`, `ForegroundGroupLocationPublisher`, `GeolocatorGroupLocationDevice`, tests; **no PR exists** · **Backend Integration:** NONE verified · **UI Design Permission:** FULL (but reuse the branch work; do not re-implement) · **Backend Contract Status:** `CONTRACT_UNVERIFIED` — the branch calls `…/travel-groups/{id}/location-sharing` (GET/PUT), `…/locations`, `…/location` (PUT/DELETE) and `/travel-groups/location-sharing/active`; **none of these routes exist in `Capstone_BE` develop** (verified: no controller references location). The only Backend trace is `locationSharingEnabled` per member in the verified members read.
- **Previous Screen:** #57 · **Next Screen:** #57 · **Alternative Destinations:** system settings (permission)
- **Entry Points:** #57 "Location sharing" · **Entry Conditions:** member of group · **Exit Conditions:** setting saved/cancelled
- **User Goal:** control whether and how my location is shared with this group
- **Page Header:** "Share my location" · **Layout:** privacy card, toggle, explanation, permission status, "who can see" list. Visual reference: `c_u_h_nh_chia_s_v_tr_gps_tripmate_mobile`
- **Sections:** toggle (share with this group) · what is shared and when (foreground only? `SRS_TEXT_REQUIRED`) · device permission status · group sharing status (members' indicators from members read)
- **Components:** `SwitchListTile`, `StatusBadge`, `AppAlert`, `AppButton` (open settings)
- **Primary Action:** toggle sharing · **Secondary Actions:** Open system settings, Stop sharing
- **Navigation:** back to #57
- **Displayed Data:** my setting (Backend), per-member `locationSharingEnabled` (verified field). Live positions of others — `BACKEND_SUPPORT_REQUIRED`
- **Form Inputs / Validation:** toggle only
- **Loading State:** toggle shows progress, disabled · **Empty State:** n/a
- **Error State:** permission denied / services off → explanatory state + settings action, **toggle stays off**; Backend write failed → toggle reverts (no optimistic) with message; unknown outcome → re-read setting
- **Success State:** state shown **only after Backend confirms**; stopping clears the last published position (BE-defined)
- **Dialogs / Sheets:** first-enable explanation sheet (privacy wording `SRS_TEXT_REQUIRED`)
- **Offline State:** toggle disabled; publishing is suspended and never shown as active
- **Permission State:** location permission states: not determined / denied / denied forever / services off / while-in-use granted. Background location is **not** assumed
- **Responsive / Accessibility:** C-RESP, C-A11Y; toggle state announced; privacy text readable at 200 %
- **Reusable / Unique Components:** reuse; unique `LocationPermissionStatusCard`
- **Visual Tokens:** C-TOKENS
- **Context Received:** `groupId` · **Context Passed Forward:** none
- **Backend Readiness (C-BE):** A `groupId` · B my sharing setting, members' sharing flags · C set my sharing on/off, publish/clear location · D Backend · E none · F none · G none · H none · I 401/403/404/5xx, permission failures · J JWT · K member · L GPS + permission, foreground service decision · M none · N none · O **NO** (privacy-sensitive; never show "sharing" before confirmation) · P **setting + location publish/read capability not in BE develop** · Q others' live location · R no auto-retry of writes · S re-read setting · T **precise location (PII)**; never logged, never cached beyond need · U Backend
- **Authoritative State Owner:** Backend (for the setting), device (for permission)
- **Required Backend Capability:** `GROUP_LOCATION_SHARING_CONTRACT_MISSING` (semantic: per-member, per-group sharing preference, publish/clear own position, read members' positions with consent)
- **Device Dependencies:** GPS (`geolocator`), permission handling, foreground service/notification decision · **Deep-Link Behavior:** none
- **Demo / Production Boundary:** production shows the page only when Backend support is confirmed; otherwise `PENDING_INTEGRATION_STATE`
- **Design-only Assumptions:** consent copy, update frequency
- **Implementation Notes:** **action for the team:** open a PR for the existing branch for review; confirm routes with the BE owner before merging. This audit did not modify the branch.
- **Non-goals:** background tracking, history trail, geofencing
- **Acceptance Criteria:** AC1 no "sharing on" state without Backend confirmation; AC2 denied permission keeps toggle off with a settings route; AC3 stop clears published position; AC4 locations never logged; AC5 branch contracts verified against BE before merge.
