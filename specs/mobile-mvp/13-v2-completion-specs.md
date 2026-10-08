# 13 — Report 3 V2 Completion Specifications (Mobile MVP)

> Design documentation only. No Flutter code is changed by this document.
> Revision 2026-10-08. Baseline: Mobile develop `acfde81`, BE develop `0075fcb`, Report 3 V2.
> **How this file combines with `02`–`06` (QA revision):** the earlier S-xx sections in `02`–`06`
> remain the **structural design** (layout, components, C-BE readiness block, deep links, offline,
> non-goals). This file is the **Report 3 V2 layer**: exact V2 fields, rules, messages, conflicts
> and corrected statuses. A screen's implementation spec = the `02`–`06` section **plus** the
> section here. Where the two disagree (status, field list, message, `SRS_TEXT_REQUIRED`
> placeholders), this file wins.
> Specs for existing screens are **completion specs**: they list only what must be added or
> corrected. Preserved behaviour is named so it is not redesigned.
> Readiness of each spec is assessed in §6 (`IMPLEMENTATION_READY` vs `DESIGN_PARTIAL`).

## 0. Common rules (apply to every spec below)

### 0.1 Requirements mapped to Flutter

| V2 rule | Mobile implementation rule |
|---|---|
| CR-01 | Lists load 20 records per page, show the total count when the BE returns it, and keep page/filters/sort when returning from a detail screen (keep the list Cubit alive above the detail route or pass the query back). On mobile, "pagination control" = infinite scroll with a visible "Load more" fallback button for accessibility. |
| CR-02 | Search runs on submit (keyboard action or Search button), never per keystroke. Empty result = explicit empty state: POI list MSG24, tour lists MSG64, all other lists MSG128. |
| CR-03 / CR-04 | Client validation for presence, length, format; errors inline under the field (`errorText`), never only a SnackBar. The server is still the authority. |
| CR-05 | Irreversible actions (cancel, remove, leave, discard) use the shared `ConfirmationDialog` (see `10`) before the request is sent. Default focus on the non-destructive action. |
| CR-06 | A successful create/update/delete shows a SnackBar with the action's success copy and leaves the user on a screen that reflects the new state. |
| CR-07 | Dates `dd/MM/yyyy`, times `HH:mm` 24-hour, converted to Asia/Ho_Chi_Minh from UTC. |
| CR-08 | Money in whole Vietnamese dong with a thousands separator, no decimals (e.g. `1,450,000 VND`). Amounts always come from the BE. |
| CR-09 | English UI copy from resource files (ARB), never hard-coded in widgets. Blocked on decision D-03; until then new widgets must read copy from a single feature-local resource class so migration is mechanical. |
| CR-10 | 401/expired session → Sign In (#36) with the session-expired copy (MSG125), preserving the intended route and restoring it after sign-in. |
| CR-11 | 403 → permission copy (MSG126) inline; never assume the hidden entry point was enough. |
| CR-12 | Network/server failure → MSG127 copy, client state unchanged, retry available; never report success that was not received. |
| CR-13 | Submit controls are disabled while a request is in flight. |
| CR-15 | Show only the personal data the UC needs; never show tokens, full payment instrument numbers or passwords. |

### 0.2 Standard screen states

Every screen implements this state set in its Cubit (`initial → loading → success | empty | failure`), with the specific failures listed per screen:

| State | Rendering |
|---|---|
| Initial | Form or skeleton; no spinner on a form that needs no data |
| Loading | `LoadingIndicator` (existing, currently unused — adopt it) with a semantic label |
| Empty | `EmptyState` (new shared component, `10`) with message and one recovery action |
| Validation error | Inline field errors; first invalid field receives focus |
| Network/server error | `ErrorView` with MSG127 copy and Retry |
| Unauthorized (401) | CR-10 redirect |
| Forbidden (403) | MSG126 inline, no data rendered |
| Backend pending | `AppAlert` (info) "This feature is not available yet." + disabled primary action; **no** simulated success, numbers or records |
| Offline | Only where V2 allows offline use (UC-16). Elsewhere treat as a network error |

### 0.3 Demo boundary

Demo fixtures are reachable only when `kDebugMode && ?demo=true` (existing router convention) and the Cubit `isDemoMode` flag is set. Demo results carry a visible "Demo" label. Production code paths never import demo stores. Demo copy follows CR-09 too and never shows raw `BR-`/`MSG` identifiers.

### 0.4 Accessibility and responsive baseline

- Minimum touch target 48×48 dp; `Semantics` labels on icon-only buttons; decorative icons excluded from semantics.
- Text scaling up to 200%: no clipped labels; forms in `SingleChildScrollView`; buttons wrap rather than truncate.
- Colour is never the only status signal (`StatusBadge` = icon + text).
- Focus order follows visual order; dialogs trap focus and return it to the trigger.
- `SafeArea` on every page; keyboard avoidance via `Scaffold.resizeToAvoidBottomInset` plus scrollable bodies; primary action stays reachable above the keyboard.
- Layout validated at 360×640 (small Android), 412×915 (typical), 600 dp+ (large phone / small tablet: content max width 600 dp, centred).

### 0.5 Copy convention

Copy is written as `key: "English text"`. V2 message IDs are given as references only. `V2_MESSAGE_CONFLICT` marks a message whose UC-section ID and §5.3 meaning differ; implementation uses the semantic text given here and never renders the numeric ID.

---

## Part 1 — Public, authentication and account

### S-35 Home Page (Guest)

**A. Identity** — Screen #35 · no distinct UC (`SCREEN_WITHOUT_DISTINCT_UC`) · Guest (Table 5: Guest only) · V2 Table 4.2 describes it as the **"Mobile landing screen for unauthenticated guests"** · `NOT_STARTED` on Mobile.

**B. Purpose** — V2 description: display **trending tours, featured POIs, itinerary planning shortcuts and sign-in prompts**. Entry: app launch without a session (today the splash routes to `/explore` or `/auth/login`). Exit: a tour (#65), a POI (#51), the planner (via sign-in, #47), #36, #38. Outcome: user reaches a public function or an auth screen.

**C. Structure** — App bar: brand logo, "Sign in" text button. Body (scroll):
1. Hero line + "Sign in" (primary) / "Create an account" (secondary, → #38) prompts.
2. **Trending tours** section — **mandatory V2 content** (Table 4.2 #35). Cards come from the BE only, using existing `TourListCard`; "See all" → #63. The criterion that makes a tour "trending" is undefined in V2 (C-11) and pending D-14; the section is **not optional** while D-14 is open.
3. **Featured places** section — **mandatory V2 content**. Cards from the BE only, using existing `PoiListCard`; "See all" → #50. The "featured" criterion is pending D-14.

   *Interim data rule until D-14 (proposed, not approved):* populate both sections from the existing public lists (`GET /api/v1/tours`, `GET /api/v1/pois`) in BE order and title them neutrally ("Tours", "Places to explore") so the screen does not claim a ranking that does not exist. Once D-14 defines the criteria and source, switch to the V2 titles and the agreed source; the layout does not change.
4. **Plan a day trip** shortcut → sign-in with `from=/traveler/itineraries/create`.
5. "Register your tour business" link (→ #40, subject to D-01).
Reuse `AppPageScaffold`, `AppButton`, `TourListCard`, `PoiListCard`, `LoadingIndicator`, `EmptyState`.

**D. Interaction** — Cards open #65 (when available) / #51. Sections load independently; one failing section does not block the others. Pull to refresh reloads both sections. Signed-in users never see #35 (route guard sends them to their role shell).

**E. States** — Per section: loading (skeleton cards), empty (section heading kept with a short empty message — the section is mandatory), error (inline "Couldn't load tours/places" + Retry, MSG127 semantics). Static parts render immediately. No counts, ratings or labels that the BE did not return.

**F. A11y/responsive** — Horizontal card rails have "See all" as an accessible alternative; section headings are semantic headers; 200% text: rails become vertical lists.

**G. Data** — `GET /api/v1/tours`, `GET /api/v1/pois` (both anonymous, verified on BE develop). "Trending" and "featured" ordering: **no contract** (D-14). Route proposal `/` for Guest (replace the splash redirect target) — routing change needs the owner's approval.

**H. Acceptance** — (1) A Guest opening the app sees #35 with the sections above. (2) Every tour/POI shown comes from the BE response; nothing is fabricated. (3) Both sections are always present (loading, content, empty or error state) — never omitted as optional. (4) "Trending"/"Featured" titles are used only once D-14 defines the criteria; until then the interim neutral titles apply. (5) An authenticated Traveler is redirected to `/traveler`. (6) All copy is resource-backed English.

Copy: `home.title: "Plan your day trip in Central Vietnam"`, `home.trendingTours: "Trending tours"` (after D-14), `home.featuredPlaces: "Featured places"` (after D-14), `home.toursSection: "Tours"` (interim), `home.placesSection: "Places to explore"` (interim), `home.sectionEmpty: "Nothing to show yet."`, `home.seeAll: "See all"`, `home.planTrip: "Plan a day trip"`, `home.createAccount: "Create an account"`, `home.signIn: "Sign in"`, `home.registerBusiness: "Register your tour business"`, `home.sectionError: "Couldn't load this section."`.

### S-40 Tour Operator Registration & Verification — completion

**A. Identity** — Screen #40 · UC-02 · Guest · **V2 allocates UC-02 to the Web** (§3.2.2 Interface: "Tour Operator Registration screen on the responsive Next.js web application"). Mobile already implements #40 (PR #34). This is a **platform mismatch between implementation and V2**, recorded as C-04; Mobile evidence does not change the SRS allocation. Status: `IMPLEMENTED_PARTIAL` (PR #34) + `BLOCKED_BY_BACKEND` (BE PR #52) + `BLOCKED_BY_SRS` (BA adjudication D-01).

**B. Purpose** — Submit a Tour Operator application. Until D-01 is decided, no new Mobile work is scheduled on #40; the existing PR #34 wizard (phases editing → awaiting verification → submitted / uncertain) is preserved as-is.

**C. Completion items** (apply only if BA adjudicates that #40 stays on Mobile):
1. V2 layout fields not confirmed in the Mobile form must be checked against PR #34: Company Name, Business Licence Number, Tax Code, Business Address, Contact Person, Contact Phone Number; account Email/Password/Confirm.
2. Upload area for the Business Licence and supporting documents (needs an approved file-picker dependency, `10` dependency notes).
3. One checkbox covering Terms of Service, Privacy Policy **and Partner Agreement**.

**D. Interaction** — `[Submit Application]` disabled in flight (CR-13); `[Back to Sign In]`.

**E. States** — Validation (required, email format, password policy, confirm mismatch); duplicate email; duplicate licence/tax code; missing mandatory document; unsupported file type/size; application already pending; server failure (MSG127). **Backend pending:** while BE PR #52 is unmerged the submit result must be the failure state, never success.

**F. A11y** — Upload area announces file name, type and size; remove-file button labelled "Remove {file name}".

**G. Data** — Endpoint consumed by Mobile: `POST /api/v1/auth/register/operator` (BE PR #52, not on develop). Do not add fields that the PR #52 contract does not accept.

**H. Acceptance** — (1) Against BE develop, submitting never shows a success message. (2) Each validation case shows inline errors and does not call the server. (3) After BE #52 merges, success shows the application-submitted copy (catalogue MSG08) and routes to #41.

Copy (`V2_MESSAGE_CONFLICT` for §3.2.2 MSG19/22/23/26): `op.reg.missingDocument: "Upload the business licence before submitting."`, `op.reg.fileRejected: "This file type or size is not supported."`, `op.reg.duplicateBusiness: "This business licence number or tax code is already registered."`, `op.reg.alreadyPending: "An application for this account is already under review."`, `op.reg.submitted: "Your business profile has been submitted for verification."` (MSG08).

### S-41 Operator Application Status — completion

**A. Identity** — Screen #41 · UC-03 · Tour Operator whose latest application is Rejected (status view for Pending) · **V2 allocates UC-03 to the Web** (§3.2.3 Interface); Mobile implements #41 → platform mismatch C-04, BA adjudication D-01 · `IMPLEMENTED_PARTIAL` + `NO_BACKEND`.

**Defect on develop (A-09):** `OperatorApplicationCubit` defaults to `rejected` with a fabricated file name a fabricated licence file name, offers `selectDemoLicence()`, and `submit()` simulates success after 500 ms. This is reachable in production builds on develop; PR #25 addresses it.

**B. Purpose** — Show the application status and, when Rejected, the rejection reason with a resubmission form.

**C. Structure (preserve PR #25 layout)** — Read-only: status badge, rejection reason, review timestamp (CR-07). Editable (Rejected only): company fields as #40; document replace/add. Buttons: `[Resubmit Application]`, `[Cancel]`.

**D. Interaction** — Resubmission offered only when the latest status is Rejected (BR-09). After success the status becomes Pending Review and the form becomes read-only.

**E. States** — Loading status; Pending (read-only, no resubmit); Rejected (form); Approved (route guard sends to `/operator`); status unresolved (existing "Application status unavailable"); validation; duplicate licence/tax; server failure. **Backend pending:** the status is available from the session (`applicationStatus`), but the rejection reason, a status refresh and resubmission have no contract → production shows the session status, no reason text, resubmit disabled.

**G. Data** — Status: session `applicationStatus` (verified, `12` §M). No BE endpoint for the rejection reason, a status refresh or resubmission. Required data per V2: status, rejection reason, review timestamp, resubmission count.

**H. Acceptance** — (1) Production never shows a demo rejection reason or a simulated resubmission. (2) Pending applicants cannot resubmit. (3) PR #25 P1 (cross-account identity) is fixed before #41 is considered complete.

Copy (`V2_MESSAGE_CONFLICT` MSG25): `op.app.notResubmittable: "This application cannot be resubmitted in its current status."`, `op.app.resubmitted: "Application resubmitted. It is now pending review."`.

### S-42 Password Reset — correction

**A** — Screen #42 · UC-06 · registered user · Mobile + Web · `IMPLEMENTED_PARTIAL`.
**C/D (preserve)** — Existing single-page three-step flow (email → code → new password) satisfies V2's three screens; no restructuring.
**Correction** — The code hint says "expires in 3 minutes" (`password_recovery_page.dart:117`); V2 BR-14 requires a **15-minute** single-use code. V2 is authoritative: the target copy is 15 minutes. Defect A-03 stays open in the register; if the BE currently issues a different lifetime, that is a BE defect against BR-14, not a reason to change the requirement. No Flutter change is made by this documentation task.
**E** — Unknown email still shows the neutral "code sent" state (non-disclosure). Incorrect/expired/consumed code: one shared message.
**H** — (1) The lifetime shown equals the BE value. (2) An unknown email is indistinguishable from a known one.
Copy (`V2_MESSAGE_CONFLICT` §3.2.6 MSG14/MSG15): `reset.codeSent: "If an account exists for this email, a reset code has been sent."`, `reset.codeInvalid: "The code is incorrect, expired or already used. Request a new code."`, `reset.success: "Your password has been reset. Sign in with your new password."` (MSG16).

### S-43 Change Password — new

**A. Identity** — Screen #43 · UC-07 · Traveler, Tour Operator (Administrator is web) · Mobile + Web · `NOT_STARTED` + `BLOCKED_BY_BACKEND`.

**B. Purpose** — Replace the password while proving the current one. Entry: Account settings (`/traveler/settings` → "Change password"; operator settings when it exists). Precondition: authenticated. Outcome: password changed, other sessions invalidated, current session holds new tokens (PC-03).

**C. Structure** — App bar "Change password" with back. Body: `AppPasswordField` × 3 — Current password, New password (with policy helper text), Confirm new password. Buttons: `[Change Password]` (primary), `[Cancel]` (secondary). Route proposal (same as `01` §3 and `02` S-43): `/traveler/security/password` and `/operator/security/password`.

**D. Interaction** — Validate on submit and on field blur after first submit. `[Cancel]` with unsaved input → discard confirmation (CR-05). Keyboard: next/done actions in order; done submits.

**E. States**

| State | Behaviour |
|---|---|
| Validation | Required (MSG01); policy (8+ chars, uppercase, digit, special — BR-02); confirm mismatch; new equals current |
| Current password wrong | Inline under Current password |
| Success | SnackBar "Password updated successfully." (MSG18); store the new tokens returned by the BE; pop to settings |
| Server failure | MSG127, fields keep values except passwords are cleared only on success |
| Backend pending | Entry point visible but the screen shows the pending alert and a disabled submit |

**F. A11y** — Each password field has show/hide with label "Show password"/"Hide password"; error text is announced.

**G. Data** — Input: current, new, confirm. Contract: **none on BE develop** (D-06). Must return new tokens per BR-15/PC-03. Do not implement without the contract.

**H. Acceptance** — (1) No request is sent while validation fails. (2) Wrong current password shows the inline message and keeps the user on the screen. (3) On success the old refresh token is no longer used by the client. (4) Production without the endpoint never shows success.

Copy (`V2_MESSAGE_CONFLICT` §3.2.7 MSG03/MSG04 vs catalogue): `pwd.currentWrong: "Current password does not match our records."` (MSG17), `pwd.policy: "Use at least 8 characters with an uppercase letter, a number and a special character."`, `pwd.mismatch: "Passwords do not match."`, `pwd.sameAsCurrent: "Choose a password different from your current one."`, `pwd.success: "Password updated successfully."` (MSG18).

### S-44 Traveler Home / Dashboard — completion

**A** — Screen #44 · no distinct UC · Traveler · `IMPLEMENTED_PARTIAL` (`TravelerShellPage`).
**C (preserve)** — `NavigationBar` with **five** destinations (develop: "Trang chủ", "Chuyến đi", "Khám phá", "Đặt chỗ", "Hồ sơ") and the home quick actions.
**V2 description (Table 4.2):** access to trip planning, active trips, tour bookings, recommendations, travel groups and other personal travel functions.
**Completion** — (1) Replace Vietnamese labels with resource-backed English: Home, Trips, Explore, Bookings, Profile; quick actions "Search tours", "Account settings", "Join travel group", "Create an itinerary" (A-04). (2) Add entries required by V2: "My travel groups" → #55, "Recommended tours" → #64 (after PR #31), "My bookings" → #68 (after UC-27–29). Until a destination exists, its entry shows the backend-pending state, not an empty fake list. (3) "Active trips": no list contract exists; the entry is reached from an itinerary (#48 → #52) until a trip-list contract exists (`02` S-44 `TRAVELER_TRIP_LIST_CONTRACT_MISSING`).
**H** — No Vietnamese strings; every entry resolves to an existing route or an explicit pending state.

### S-45 Traveler Profile — completion

**A. Identity** — Screen #45 · UC-08 · Traveler · Mobile + Web · `IMPLEMENTED_PARTIAL` + `NO_BACKEND`; PR #25 open.

**Defect on develop (A-08, P1 truthfulness):** `traveler_profile_page.dart` pre-fills the form with hard-coded identity constants (a sample full name, phone number, date of birth and city — values intentionally not reproduced here) displayed as the signed-in user's data, and confirms "saved locally for the demo". Reachable in production builds on develop. PR #25 addresses it.

**B. Purpose** — View and edit profile fields used by booking, group and review functions.

**C. Structure** — Read-only: Email Address. Editable: Full Name, Phone Number, Date of Birth (date picker, CR-07), Gender (select), Address, Avatar (`[Change Avatar]`). Buttons: `[Save Changes]`, `[Cancel]`.

**D. Interaction** — Edit in place; `[Cancel]` with changes → discard confirmation. Avatar: pick → preview → saved with the form (BR-16: image, ≤ 5 MB). Leaving with unsaved changes → confirmation (catalogue MSG23).

**E. States** — Loading profile; load failure (no editing offered, MSG127); validation (required; phone format; DOB in the past and age ≥ 16 — BR-18); avatar rejected (type/size) keeps other fields saveable; save failure keeps previous values; success SnackBar; **backend pending:** fields read-only, save disabled, info alert — no "saved locally" success (A-06).

**F. A11y** — Avatar button label "Change profile photo"; date picker has a text alternative.

**G. Data** — Contract: none on BE develop. Required data per V2: full name, phone, DOB, gender, address, avatar file/reference, email (read-only).

**H. Acceptance** — (1) Production never shows "saved locally". (2) Email is never editable. (3) Underage DOB is rejected inline. (4) PR #25 P1 fix: another account's name/email is never restored (test required).

Copy (`V2_MESSAGE_CONFLICT` §3.2.8 MSG02 for phone/DOB and MSG19 for avatar): `profile.phoneInvalid: "Enter a valid phone number."`, `profile.dobInvalid: "Enter a past date. You must be at least 16 years old."`, `profile.avatarRejected: "Avatar must be an image under 5 MB."`, `profile.saved: "Profile updated successfully."`.

### S-46 Travel Preferences — completion

**A** — Screen #46 · UC-09 · Traveler · `IMPLEMENTED_PARTIAL` + `NO_BACKEND` + `BLOCKED_BY_SRS` (C-08, decision D-04).

**C** — V2 §3.2.9 layout: multi-select Interest tags, single-select Travel style, single-select Budget level (each list introduced with "for example"); `[Save Preferences]`, `[Reset]`, `[Skip]`.

**Governing rules (UC-section numbering, §3.2.9):** **BR-19** — preference values must belong to the option sets defined in the **system configuration**; free text is not accepted. **BR-20** — preferences are optional; UC-25 needs at least one interest tag. (In the UC-section numbering **BR-24** is the Active-POI/route rule of §3.3.1, not a preference rule.)

**Genuine gaps against V2:** (1) the implemented page hard-codes its option lists (transport, pace, interests, food, risk) instead of loading the configured option sets → violates BR-19 (implementation gap A-13); (2) its groups differ from the §3.2.9 layout (no travel style or budget level groups). **BR numbering note (C-08):** V2 §5.1 appendix uses a different numbering; its entry *numbered* BR-24 lists "transportation mode, pace, food preferences, interests, risk tolerance" as stored preferences, which matches the implemented groups. Which attribute set is authoritative is for BA adjudication (D-04). **Do not change the option groups until D-04**; in all outcomes the values must come from configuration (BR-19).

**E** — Option sets unavailable (MSG127, no selection offered); over the configured maximum tags (inline); save failure; skip leaves values unchanged; **backend pending:** selection allowed but Save disabled with the pending alert, no local "saved" toast.

**H** — (1) No local-only success in production. (2) After D-04, the rendered groups match the decided option set exactly.

Copy: `prefs.saved: "Your travel preferences have been saved."` (MSG21), `prefs.tooMany: "You selected more interests than allowed."`.

### S-47 Trip / Itinerary Planner — V2 gap record

**Status:** `IMPLEMENTED_PARTIAL` against V2 (UI + BE integration verified for the implemented model; **implementation gap** A-12 against §3.3.1). Readiness: `DESIGN_PARTIAL` (pending D-02).

**V2 requirement (authoritative, preserved):** inputs Destination, Start Date, End Date, Number of Travelers, Budget, Interest tags (pre-filled from preferences), Preferred pace; `[Generate Itinerary]`, `[Cancel]`. BR-21 destination + date range + ≥ 1 interest tag; BR-22 start ≥ today, end ≥ start; **BR-23 duration ≤ 30 days**; BR-24 (UC numbering) Active POIs/routes only; BR-25 opening hours and travel time; BR-26 versioned itinerary.

**Implemented (Mobile + BE `POST /scheduling-requests`):** a one-day model — start place, explore-around area, finish place / return to start, start time, time available, transport, break preference, search radius, optional budget, up to 6 must-see places. Missing against V2: end date / multi-day range, number of travelers, interest tags, preferred pace; budget is optional while V2 requires a positive value when given (MSG01).

**Context:** V2 §1 Product Overview describes "one-day trips"; §3.3.1 allows up to 30 days. This tension is recorded as C-05 for BA adjudication (D-02). **V2 §3.3.1 is not narrowed to one day by this document.** Until D-02: preserve the implemented form (no regression), schedule no change, and keep the gap visible in `00`/`09`.

---

## Part 2 — Offline and travel groups

### S-49 Offline Map & Itinerary — completion contract

**A. Identity** — Screen #49 · UC-16 · Traveler (itinerary owner) · Mobile only · `IMPLEMENTED_PARTIAL` (PR #24) + `BLOCKED_BY_BACKEND`.

**B. Purpose** — Download itinerary items, related POIs, route information and map data of the itinerary area for offline use (BR-36). Entry: itinerary detail (#48) and active trip (#52). Outcome: itinerary marked available offline only after every component is stored (BR-38).

**C. Structure (preserve PR #24 demo layout as the target)** — Header: itinerary title, date range, downloaded version, offline availability badge. Information line: estimated size and the 150 MB limit (BR-37). Progress: per component (itinerary, POI, map). Buttons: `[Download for Offline Use]`, `[Cancel Download]`, `[Remove Offline Data]`. Superseded-copy banner with `[Download current version]`.

**D. Interaction** — Download → progress → available. Cancel discards partial data. Remove → confirmation (CR-05). Online + superseded local version → offer refresh; the old copy stays usable until the new one is complete (alternative flow).

**E. States**

| State | Production today | Target behaviour |
|---|---|---|
| Not available | "Offline package is not available yet" (preserve) | Until the data source exists |
| Ready to download | — | Shows size estimate from the BE/package source |
| Downloading | — | Per-component progress; Cancel available |
| Insufficient storage / > 150 MB | — | MSG107; nothing stored |
| Network interrupted | — | MSG106; partial data discarded |
| Available offline | — | Version + downloaded timestamp (CR-07) |
| Superseded | — | Banner + refresh action |
| Not found / not accessible | — | MSG126 (`MSG32` in §3.3.7 is a `V2_MESSAGE_CONFLICT`; use "This itinerary is not available.") |

**F. A11y** — Progress announced as percentage per component via `Semantics(value:)`; no colour-only state.

**G. Data** — Itinerary content: `GET /api/v1/itineraries/{id}` (exists). Map data and package size/version source: **undecided** (D-07). Device storage check needs an approved platform API. No server-side package entity (PC-04).

**H. Acceptance** — (1) Production never displays a size, progress or "available offline" without a real stored package. (2) A failed component never results in "available offline". (3) Demo copy has no Vietnamese and no `BR-`/`MSG` identifiers (fix A-01).

### S-55 Travel Groups — new

**A. Identity** — Screen #55 · no distinct UC (hub for UC-17…UC-23) · Traveler · Mobile only · `NOT_STARTED` (route constant `/traveler/groups` exists without a `GoRoute`).

**B. Purpose** — List the travel groups where the Traveler is an active member and give entry to create/join. Entry: #44 quick action "My travel groups"; return from #56/#62/#57. Outcome: user opens a group (#57), creates one (#56) or joins one (#62).

**C. Structure** — App bar "My travel groups". Actions row: `[Create group]` (→ #56, requires itinerary selection per UC-17), `[Join with a code]` (→ #62). List item (only fields the BE returns): group name, associated itinerary title, role badge Host/Member (`StatusBadge` with icon), member count if provided. Tap → `/traveler/groups/{id}`.

**D. Interaction** — Pull to refresh; CR-01 paging if the list contract pages. Returning from a group keeps scroll position.

**E. States** — Loading; empty (MSG128-style: "You are not in any travel group yet." + Create/Join actions); failure (MSG127 + Retry); **backend pending:** BE develop has **no "list my groups" endpoint** → production shows the pending alert with the Create and Join actions still available (both have contracts).

**F. A11y** — Each list item reads "Group {name}, {role}, {n} members".

**G. Data** — Contract needed (D-08): list of the caller's active memberships with group id, name, itinerary title, role. Do not derive the list from local storage.

**H. Acceptance** — (1) `/traveler/groups` resolves to #55. (2) Without a list contract no group is fabricated; Create and Join still work. (3) A group link opens #57 for that id.

### S-57 Travel Group Details & Members — completion

**A** — Screen #57 · UC-19 (host actions for UC-18/20/21/22) · active member · `IMPLEMENTED_PARTIAL`.

**C (preserve)** — Member list from `GET /travel-groups/{id}/members` (avatar, display name, Host badge, joined date, location sharing state), `[Invite Members]` and `[Remove]` for the Host only (BR-45: not on self), `[Leave Group]`, `[Location Sharing]`.

**Completion** — Header per V2: group name, associated itinerary, group status, member count. The verified members read (`GET /travel-groups/{id}/members`) already returns `groupName`, `itineraryId` and `memberCount` (`04` P-57a), but `TravelGroupDetailsPage` on develop does not use it: its title comes from route `extra` or the placeholder `Travel Group #<id>`. Rule: compose the header from the members response (loading → real values); never show the `#<id>` placeholder after load. **Group status** and a self-member marker ("which member am I", needed to hide `[Remove]` on self and choose Leave vs host actions) are not in any response → D-08.

**E** — Not an active member → MSG126 and leave the screen; empty member list → MSG128; failure → MSG127.

**H** — (1) Deep link `/traveler/groups/{id}` never shows invented names. (2) `[Remove]` never appears on the Host's own row or for non-hosts.

### S-59 Remove Group Member Confirmation — completion contract

**A** — Screen #59 · UC-20 · Group Host · `IMPLEMENTED_PARTIAL` (fail-closed dialog) + `NO_BACKEND`.
**C (preserve)** — CR-05 dialog: "Are you sure you want to remove {Member_Name} from this group?" (MSG59), `[Remove]` (destructive) / `[Cancel]` (default focus).
**E** — Production: confirming shows "Server support pending…" (preserve). Target: success → SnackBar "{Member_Name} has been removed from the group." (MSG60) and the row disappears; not host → MSG126; member no longer active → silent refresh; failure → MSG127, list unchanged; selecting the Host → direct to Leave (#60).
**G** — Contract needed (D-09).
**H** — No optimistic removal before the server confirms.

### S-60 Leave Travel Group Confirmation — completion contract

**A** — Screen #60 · UC-21 · active member · `IMPLEMENTED_PARTIAL` + `NO_BACKEND`.
**C** — Three dialog variants (V2 layout): (1) non-host: "Leave this group?" `[Leave Group]`/`[Cancel]`; (2) host with others: MSG61 naming the successor (earliest joined active member, BR-49) — the name must come from the server, never computed client-side from a possibly stale list; (3) host is last member: closure confirmation (MSG130 generic) — group closes.
**E** — Production: "Server support pending…" (preserve). Target: success → leave the group screens, return to #55, SnackBar; transfer or closure failure → stay a member, MSG127.
**G** — Contract needed (D-09) including successor preview.
**H** — The client never shows a successor name it computed itself.

### S-61 Group Location Sharing Settings — completion contract

**A** — Screen #61 · UC-22 · active member · `IMPLEMENTED_PARTIAL` + `NO_BACKEND`.
**C (preserve)** — Toggle "Share my location with this group"; permission state line; who can see; `[Open Device Settings]` when denied; `[Close]`.
**E** — Production: switch disabled with the pending message (preserve). Target: enabling with permission denied → MSG46 and switch stays off; enabled → MSG62; disabled → MSG63; save failure → previous value + MSG127; permission revoked later → sharing stops, opt-in stays (7.a1).
**G** — Contract needed (D-10) for opt-in persistence and the sharing transport.
**H** — Location is shared only when both opt-in and OS permission are true (BR-50).

---

## Part 3 — Tours, booking, payment and e-ticket

Funnel rule for #64–#70: every step works from BE data only. Availability shown is never a reservation (BR-55/BR-59); amounts are always BE-computed (BR-63/BR-69); the gateway return is never authoritative (BR-73). Until contracts exist, production shows the backend-pending state at the first step that needs a missing contract and offers no further step.

### S-63 Search Tours — completion

**A** — Screen #63 · UC-24 · Guest/Traveler · `IMPLEMENTED_PARTIAL`.
**C (preserve)** — Existing list, thumbnails, price filter sheet, infinite paging.
**Completion per V2 layout** — Search keyword field; filters Destination, Departure **date range** (today a single date), Price range, Duration, Tour category, Minimum rating; sort Relevance / Price ↑ / Price ↓ / Rating / Departure date; `[Search]`, `[Apply Filters]`, `[Clear Filters]`; result item adds Remaining slots and Aggregate rating. **Add only controls that `GET /tours` supports** (confirm, `08` Q3); unsupported controls are omitted, not rendered as no-ops.
**E** — Invalid range (min > max, start > end) → inline, no request (MSG29 is a `V2_MESSAGE_CONFLICT`; use "Check the range: the minimum must not exceed the maximum."); empty → MSG64; failure → MSG127 with previous results kept (7.a1); a tour whose availability cannot be read shows no slot count and cannot be opened for booking.
**H** — Search never fires per keystroke; applied criteria survive opening #65 and returning.

### S-64 Tour Recommendations — completion of PR #31

**A** — Screen #64 · UC-25 · Traveler · `OPEN_PR_PARTIAL` + `NO_BACKEND`.
**C** — List item: thumbnail, name, destination, duration, price (CR-08), matching score (MSG68 "Matching score: {Score}% based on your travel style and preferences."), remaining slots. Info label: "Recommendations are based on your travel preferences." Link → #46. `[Refresh Recommendations]`, `[View Details]` (→ #65). CR-01 paging.
**E** — No interest tag → MSG28 semantics ("Add at least one interest in Travel preferences to get recommendations.") with link to #46 (`V2_MESSAGE_CONFLICT` MSG28); none above 80% → MSG64 with link to #63; failure → MSG127 keep previous list; **backend pending (production today):** pending alert, no items, no scores.
**H** — No score is ever shown that the BE did not return; items ≤ 80% never shown (BR-58).

### S-65 Tour Details — completion of PR #31

**A** — Screen #65 · UC-26 · Guest/Traveler · `OPEN_PR_PARTIAL` + `NO_BACKEND`.
**C** — Gallery; Name, Destination, Duration, Price per participant, Aggregate rating, Operator name; sections Description, Day-by-day itinerary, Inclusions/Exclusions, Cancellation policy, Reviews; departure schedule list (departure/return dates CR-07, remaining slots, price); `[Book Now]`, `[Back to Results]`.
**D** — Selecting a schedule enables `[Book Now]`. Guest → Sign In, then return here with the schedule preserved (alt flow, CR-10 mechanics).
**E** — Unpublished/not found → MSG65 and pop; all schedules sold out/past → MSG65, Book disabled; no reviews → MSG128 in the Reviews section only; failure → MSG127 + Retry; sold out at selection → MSG65 and refresh availability; **backend pending:** pending alert, no fixture detail.
**H** — `[Book Now]` enabled only with an available schedule; Guest returns to the same schedule after sign-in.

### S-66 Tour Booking Confirmation — new on develop (branch exists)

**A. Identity** — Screen #66 · UC-27 · Traveler · `NOT_STARTED` on develop (`BRANCH_NO_PR`) + `NO_BACKEND`.

**B** — Create a Pending Payment booking for a selected schedule. Entry: #65 `[Book Now]`. Outcome: booking created → #67.

**C** — Summary (tour, departure/return, price per participant, remaining slots); Number of participants stepper; per-participant group (Full name, Date of birth, Identity document number, Phone); contact group (name, email, phone — prefilled from profile when available); Voucher code with `[Apply Voucher]`/`[Remove Voucher]`; price breakdown (Subtotal, Discount, Total — BE values only); `[Confirm Booking]`, `[Cancel]`.

**D** — Participant groups expand/collapse; changing the count adds/removes groups (confirm removal of filled data). Voucher apply/remove recomputes via the BE. Back with entered data → discard confirmation.

**E** — Required empty (MSG01); participant invalid → MSG78 and focus the first invalid participant; count > remaining → MSG77 ("Only {Remaining_Slots} seats left…"); voucher invalid → MSG101, minimum spend → MSG102, applied → MSG100, removed → MSG103; too many unpaid bookings → MSG126 with a link to #68; schedule unavailable → MSG65; success → MSG79 then #67; failure → MSG127, nothing held.

**F** — Long forms: one scroll view, sticky total + primary button above the keyboard; ID number field obscures nothing (PII shown only to the owner, CR-15).

**G** — Contract needed (D-11). Input per V2 Data. The client never sends amounts (BR-63).

**H** — (1) Totals displayed equal BE values. (2) Exceeding capacity never creates a booking. (3) Production without a contract shows the pending state on entry and no form submission.

### S-67 Electronic Payment (+ S-70 Confirm Cancellation Modal)

**A** — Screen #67, #70 · UC-28 · booking owner · `NOT_STARTED` on develop + `NO_BACKEND`.

**C** — Booking summary (code, tour, departure, participants, total CR-08); countdown of the 15-minute window (from the BE expiry timestamp, not a client timer start); method selection VNPay, PayOS; `[Proceed to Payment]`, `[Cancel Booking]`; result area after return.

**D** — Proceed → MSG85 ("Redirecting to the secure payment gateway…" — catalogue mentions VNPay only; copy must name the selected gateway) → external gateway → return → **pending verification** (MSG90 semantics, `V2_MESSAGE_CONFLICT`: use "We are confirming your payment. This can take a moment.") → poll/query the BE for the verified result. `[Cancel Booking]` → #70 confirmation (MSG81 prompt) → cancelled → MSG82.

**E** — Not owner → MSG126; window expired → MSG80 and booking Expired; already paid → MSG88; gateway timeout → MSG89; verified success → MSG86 → #69; failed/cancelled at gateway → MSG87 (booking stays Pending Payment); amount mismatch → MSG92; result not persisted (`V2_MESSAGE_CONFLICT` MSG91) → "We could not confirm this payment yet. Do not pay again; check My Bookings."

**G** — Contract needed (D-11); deep-link return scheme needs approval. BR-73: never set Confirmed from the return URL.

**#70 scope note:** V2 Table 4.2 describes #70 as cancelling "an eligible booking" and reviewing "the applicable refund policy". Its only V2 flow is the UC-28 alternative flow (cancel a Pending Payment booking instead of paying), specified here. `05` S-70 also places #70 on #69 for **confirmed** bookings; a Traveler-initiated cancellation of a confirmed booking has no V2 UC or contract, so that use is not specified (C-10, D-11).

**H** — (1) Returning from the gateway alone never shows success. (2) Countdown matches the BE expiry. (3) Cancel requires the confirmation modal.

### S-68 My Tour Bookings — new

**A** — Screen #68 · entry for UC-29 (C-10) · Traveler · `NOT_STARTED` + `NO_BACKEND`.
**C** — List (CR-01): booking code, tour, departure (CR-07), participants, total (CR-08), status badge (Pending Payment / Confirmed / Cancelled / Expired). Tap → #69 (Confirmed) or #67 (Pending Payment).
**E** — Empty → MSG128 with "Search tours" action; failure → MSG127; backend pending → pending alert.
**H** — Status labels come from the BE; Pending Payment items show the remaining time from the BE.

### S-69 Booking Details & QR E-ticket — new on develop

**A** — Screen #69 · UC-29 · booking owner · `NOT_STARTED` on develop + `NO_BACKEND`.
**C** — QR area renders the **server payload as-is** (BR-83); info: booking code, tour, operator, departure, meeting point, participants; ticket status label (Not Yet Active / Valid / Used / Cancelled / Expired) with icon; validity note; `[Refresh QR Code]`, `[Back]`.
**E** — Not owner → MSG126, no QR; not confirmed → "Your payment is still being confirmed." and no QR (`V2_MESSAGE_CONFLICT` MSG90); available → MSG93; before window → MSG98, Not Yet Active; used → MSG95 semantics "This ticket has already been used.", Used; cancelled → "This booking was cancelled.", Cancelled (`V2_MESSAGE_CONFLICT` MSG74); past window → "The departure window has passed.", Expired (`V2_MESSAGE_CONFLICT` MSG99); failure → MSG127.
**F** — Raise screen brightness while the QR is shown (approved plugin required) — optional; QR has an accessible description "Ticket QR code for booking {code}".
**H** — No QR is drawn without a server payload; refresh replaces the payload and status.

---

## Part 4 — Commercial services

### S-71 / S-72 Commercial Services (UC-30 detail part) — completion of PR #32

**A** — Screens #71 (list/search), #72 (detail; its booking part is UC-31, out of scope) · UC-30 · Traveler · Platform: V2 §2.2.2 UC-30 says "provided on the mobile application only" while §3.6.1 Interface names both applications (C-12) — Mobile is in scope in every reading · `OPEN_PR_PARTIAL` + `BE_AVAILABLE_NOT_INTEGRATED`.

**C (#71, V2 §2.2.2 UC-30)** — Browse the list and run multi-criteria searches; filters: **service category** (Hotel / Vehicle Rental / Restaurant), **location**, **date**, **price range**; results show stored details and current availability. CR-01 paging (20), CR-02 search on submit with an explicit empty state (MSG128 semantics). BE develop supports only `Category`, `Search`, `Page`, `PageSize` (`08` UC-30): location, date and price-range filters are rendered only when the BE supports them, never as no-op controls.

**B** — Show a commercial service so the Traveler can decide whether to book. Entry points in PR #32: POI detail, itinerary detail, shell.

**C (#72, V2 layout)** — Gallery; Service name, Category (Hotel / Vehicle Rental / Restaurant only, BR-87), Address, Opening hours, Contact, Price range (CR-08), Aggregate rating; category area (room types / vehicle types / menu highlights and table capacity); availability indicator for the selected date; `[Book Service]` (UC-31, out of scope — render disabled with "Booking is not available yet." unless UC-31 is approved), `[View on Map]`, `[Back]`.

**D** — `[View on Map]` opens the map centred on the POI and returns to #72 (alt flow). Date selection refreshes availability (BR-55).

**E** — POI not active / gone → MSG34 semantics "This place is no longer available." and pop (`V2_MESSAGE_CONFLICT`); non-commercial category → plain POI detail, no booking action; not open for booking → MSG75 semantics "This service is not accepting bookings right now." (`V2_MESSAGE_CONFLICT`), booking disabled; availability unavailable → indicator hidden, booking disabled; failure → MSG127 + Retry.

**G** — Replace PR #32's demo store with `GET /api/v1/commercial-services` and `/{id}` (verified on BE develop). Map DTO fields only as returned; do not add fields the response lacks. Visibility question C-09.

**H** — (1) Production #71/#72 show only BE records. (2) Only the three commercial categories expose a booking action. (3) PR #32 is rebased (conflicting today) before review.

---

## Part 5 — Journeys, order and decisions

### 5.1 MVP journey map (gaps marked ✗)

| Journey | Path | Gaps |
|---|---|---|
| Public & auth | #35 ✗ → #36/#37 → (#38 → #39) → #44 | #35 missing; #42 copy (A-03) |
| Account | #44 → Settings → #43 ✗ / #45 / #46 / Sign out | #43 missing; #45/#46 truthful pending (PR #25) |
| Operator onboarding | #40 → #41 | BE PR #52; D-01 platform decision |
| Planning & offline | #44 → #47 → #48 → #49 / #52 | #49 production pending (data source) |
| Travel groups | #44 → #55 ✗ → #56 / #62 → #57 → #58 / #59 / #60 / #61 | #55 missing; #59/#60/#61 contracts |
| Tours & booking | #63 → #65 ✗(PR) → #66 ✗ → #67 ✗ → #69 ✗; #64 ✗(PR) → #65; #44 → #68 ✗ | PR #31 + booking branch, all `NO_BACKEND` |
| Commercial | #51/#48 → #72 ✗(PR) | PR #32 integration |

Dead ends today: links to `/traveler/groups` (no route); "Bookings" destination in the shell has no booking data.

### 5.2 Recommended implementation order

1. PR #25 P1 fix and merge (truthful #40/#41/#45/#46).
2. D-03 localization layer + extract `ConfirmationDialog`, `EmptyState`, `PriceText`, date formatting helper (`10`).
3. #55 Travel Groups list (with D-08 contract or truthful pending), #44 copy, #42 copy.
4. UC-30: rebase PR #32, integrate `/commercial-services`.
5. UC-24 completion (BE-supported controls only).
6. PR #31 (UC-25/26), then a PR for the booking branch (UC-27–29) — production remains truthful pending.
7. #43 (needs D-06), #59/#60/#61 (D-09/D-10), #49 (D-07) as contracts arrive.

### 5.3 Decisions requiring Tech Lead / BA approval

Status of every row: **PENDING**. The "Recommended resolution" column is a proposal from this design audit only; it is **not approved** and must not be implemented as if decided.

| ID | Decision | Owner | Evidence | Recommended resolution (proposed, not approved) | Impact if unresolved |
|---|---|---|---|---|---|
| D-01 | Platform of UC-02/UC-03 (#40/#41) | BA (SRS owner) + Tech Lead | `00` C-04: §3.2.2/§3.2.3 Interface (Web only) vs §1 and Table 1 (both platforms); Mobile PR #34 merged | Amend §3.2.2/§3.2.3 Interface to name both applications, matching §1/Table 1 and the existing Mobile implementation | #40/#41 cannot be completed or accepted on Mobile; PR #25 and S-40/S-41 stay `DESIGN_PARTIAL` |
| D-02 | UC-10 trip duration and request model | BA (SRS owner) | `00` C-05 (§1 "one-day trips" vs §3.3.1 BR-23 ≤ 30 days); implementation gap A-12 | Decide whether MVP keeps §3.3.1 multi-day requests or V2 is amended to the one-day model; then align BE and Mobile | #47 stays partial against V2; S-47 `DESIGN_PARTIAL`; scheduling acceptance cannot pass |
| D-03 | Localization mechanism for CR-09 | Tech Lead | `00` C-06, G-01; A-04, A-11 | Adopt `flutter_localizations` + `gen-l10n` ARB files (needs dependency approval) | Every screen keeps CR-09 debt; new screens accumulate hard-coded strings |
| D-04 | UC-09 preference attribute set | BA (SRS owner) | `00` C-08 (§3.2.9 vs appendix entry numbered BR-24); BE `TravelerProfile` fields; A-13 | Choose one attribute set and record it in §3.2.9 and §5.1 with consistent BR numbers; keep BR-19 configured option sets in all cases | #46 option groups cannot be finalized; S-46 `DESIGN_PARTIAL`; UC-25 personalization inputs unclear |
| D-05 | "Remember me" on Mobile Sign In | BA + Tech Lead | §3.2.4 Screen Layout (checkbox); Mobile keeps sessions in secure storage | Treat secure-storage persistence as the Mobile equivalent and omit the checkbox on Mobile, or add it — record the choice in V2 | Minor layout mismatch on #36 |
| D-06 | Change-password contract (UC-07) | Backend | `08` UC-07 (no endpoint); §3.2.7 BR-15 token rotation | Provide an authenticated endpoint that verifies the current password and returns rotated tokens | #43 cannot ship; UC-07 stays `NOT_STARTED` |
| D-07 | Offline map data and package metadata source (UC-16) | Tech Lead + Backend | `08` UC-16; §3.3.7 BR-36…BR-40 | Select a map tile provider and define where package size/version come from | #49 remains "not available yet" in production |
| D-08 | Group list read; group status and self-member marker | Backend | `08` UC-19, `13` S-55/S-57 | Add a "my groups" list and include status and the caller's membership flag in the members read | #55 shows a pending state; #57 cannot reliably hide Remove on self or show status |
| D-09 | Remove member, leave group, host succession | Backend | §3.4.4/§3.4.5 BR-45/48/49; `08` UC-20/21 | Contracts that perform removal/leave atomically and return the successor host from the server | #59/#60 stay fail-closed |
| D-10 | Location-sharing opt-in persistence and transport | Backend + Tech Lead | §3.4.6 BR-50/51; `08` UC-22 | Opt-in persistence endpoint plus a sharing transport decision | #61 stays pending in production |
| D-11 | Tour detail, recommendations, booking, payment, e-ticket, payment return deep link | Backend + Tech Lead | §3.5.2–§3.5.6; `08` UC-25…UC-29 | Deliver contracts in funnel order (detail → booking → payment → ticket) and approve a return-link scheme | #64–#70 cannot leave pending states; S-67/S-69 `DESIGN_PARTIAL` |
| D-12 | UC-31 booking on #72 and web allocation of UC-30/UC-31 | BA | `00` C-12; MVP scope list | Keep UC-31 out of the MVP and render the #72 booking action disabled; amend §2.2.2/§3.6.x to one platform statement | PR #32 scope stays ambiguous |
| D-13 | Message catalogue reconciliation | BA (SRS owner) | `00` C-03 | Renumber UC-section references to the §5.3 catalogue meanings | UI keeps semantic copy; traceability to MSG IDs stays weak |
| D-14 | Criteria and source for "trending tours" and "featured POIs" on #35 | BA + Backend | `00` C-11; Table 4.2 #35 | Define the criteria (e.g. booking volume, curated flag) and expose them through public endpoints | #35 ships with the interim data rule and neutral titles |

**Total: 14 pending decisions** (D-01…D-14).

## 6. Implementation-readiness audit (QA revision)

Checklist per spec (combined with its `02`–`06` structural section where one exists):
① exact UC/Screen mapping · ② actor & authorization · ③ entry/exit navigation · ④ complete UI structure · ⑤ interaction · ⑥ loading/empty/error/success states · ⑦ offline behaviour where required · ⑧ backend readiness classification · ⑨ localization & accessibility · ⑩ acceptance criteria · ⑪ component reuse · ⑫ implementation dependency.

`IMPLEMENTATION_READY` = all twelve satisfied **and** no open SRS adjudication on the screen's content. A screen can be design-ready while its implementation is still blocked by a missing backend contract; that blocker is listed separately.

| Spec | Screen(s) | Structural source | Fails | Readiness | Implementation blocker |
|---|---|---|---|---|---|
| S-35 | #35 | `02` S-35 + `13` (V2 content) | — (mandatory sections fully specified; interim data rule given) | `IMPLEMENTATION_READY` | Route-guard change approval; D-14 for the trending/featured criteria and final titles |
| S-40 | #40 | `02` S-40 (partly stale) + `13` | ④ (upload area undecided), open D-01 | `DESIGN_PARTIAL` | D-01, BE PR #52, file-picker dependency |
| S-41 | #41 | `02` S-41 + `13` | open D-01 | `DESIGN_PARTIAL` | D-01, no status/resubmit contract |
| S-42 | #42 | `02` P-42 + `13` | — (copy correction only) | `IMPLEMENTATION_READY` | none (A-03 copy) |
| S-43 | #43 | `02` S-43 + `13` | — | `IMPLEMENTATION_READY` | D-06 contract |
| S-44 | #44 | `02` S-44 + `13` | — | `IMPLEMENTATION_READY` | entries wait for #55/#64/#68 |
| S-45 | #45 | `02` S-45 + `13` | — | `IMPLEMENTATION_READY` | PR #25 (P1), profile contract |
| S-46 | #46 | `02` S-46 + `13` | ④ option groups, open D-04 | `DESIGN_PARTIAL` | D-04, preferences contract |
| S-47 | #47 | `03` P-47 + `13` gap record | ④/⑤ for the V2 fields, open D-02 | `DESIGN_PARTIAL` | D-02 |
| S-49 | #49 | `03` O-49 + `13` | — | `IMPLEMENTATION_READY` | D-07 data source |
| S-55 | #55 | `04` S-55 + `13` | — | `IMPLEMENTATION_READY` | D-08 list contract (Create/Join work without it) |
| S-57 | #57 | `04` S-57 + `13` | — | `IMPLEMENTATION_READY` | D-08 detail contract (optional) |
| S-59 | #59 | `04` S-59 + `13` | — | `IMPLEMENTATION_READY` | D-09 |
| S-60 | #60 | `04` S-60 + `13` | — | `IMPLEMENTATION_READY` | D-09 |
| S-61 | #61 | `04` S-61 + `13` | — | `IMPLEMENTATION_READY` | D-10 |
| S-63 | #63 | `05` P-63 + `13` | ④ filter set depends on BE support | `DESIGN_PARTIAL` | `08` Q3 (BE query support) |
| S-64 | #64 | `05` S-64 + `13` | — | `IMPLEMENTATION_READY` | D-11 |
| S-65 | #65 | `05` S-65 + `13` | — | `IMPLEMENTATION_READY` | D-11 |
| S-66 | #66 | `05` S-66 + `13` | — | `IMPLEMENTATION_READY` | D-11 |
| S-67 | #67, #70 | `05` S-67/S-70 + `13` | ⑫ payment return deep link undecided | `DESIGN_PARTIAL` | D-11 (gateway + deep link) |
| S-68 | #68 | `05` S-68 + `13` | — | `IMPLEMENTATION_READY` | D-11 |
| S-69 | #69 | `05` S-69 + `13` | ⑦ offline ticket display undecided (`05` S-69) | `DESIGN_PARTIAL` | D-11, offline-ticket decision |
| S-71/72 | #71, #72 (one spec group) | `06` S-71/S-72 (stale BE note) + `13` | ④ #71 filter set (V2: category, location, date, price range) exceeds BE support (category + search only) | `DESIGN_PARTIAL` | BE query support (`08` Q7); PR #32 rebase; D-12 for the #72 booking part |

**Counts:** 23 specification groups covering 25 screen IDs — 21 groups cover one screen, 2 groups cover two (S-67: #67 + #70; S-71/72: #71 + #72). The other 7 of the 32 MVP screens (#36, #37, #38, #39, #56, #58, #62) are `IMPLEMENTED_VERIFIED` and covered by preservation records in `02` (P-36, P-38, P-39; #37 within P-36/S-37) and `04` (P-56, P-58, P-62); they need no new spec. `IMPLEMENTATION_READY` **15**, `DESIGN_PARTIAL` **8** (S-40, S-41, S-46, S-47, S-63, S-67, S-69, S-71/72). The earlier claim "23 implementation-ready specifications" was incorrect. S-47 is a gap record, not a new-screen design.
