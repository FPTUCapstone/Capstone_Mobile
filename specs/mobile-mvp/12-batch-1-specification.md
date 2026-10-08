# 12 — Batch 1 Specification: Production Truthfulness (#40, #41, #45, #46)

> **Revision 2026-10-08 (QA).** This batch is implemented in PR #25 (OPEN, conflicting, reviewer P1 on cross-account identity restore — see `11` R-2). Its behaviour remains the baseline for `13` S-40/S-41/S-45/S-46, which add the Report 3 V2 field lists, conflicts (C-04, C-08) and decisions (D-01, D-04).
> **Corrections to §D below:** (a) item 2 cites "appendix BR-24" — that is the §5.1 appendix numbering; in the UC-section numbering UC-09 is governed by BR-19/BR-20 and BR-24 is the Active-POI rule (see `00` C-08). (b) Item 8 concludes that Mobile is "allowed/required" for UC-02/03 — superseded: V2 interface text allocates them to the Web, Table 4.2 is captioned "Web Application Screen List" and Table 5 is platform-neutral, so the mismatch is recorded as C-04 for BA adjudication (D-01) instead of being resolved here.

Status: **SPECIFICATION ONLY — awaiting developer approval.** No Dart, no branch, no commit.
Written 2026-10-02/03 after reading the ONLINE Report 3. This file **supersedes** the corresponding parts of `02-public-auth-and-account.md`, which were derived from an incomplete SRS and contain errors listed in §D.12.

## A. Source check

| # | Source | URL / location | Opened | Relevant section | Authority | Conflict |
|---|---|---|---|---|---|---|
| 1 | Online Report 3 (Google Docs) | `docs.google.com/document/d/1VwPkqRyC6ZlbXBQC0ztdektt0vAyE3qt/edit` | **YES** — direct page fetch failed (response > 10 MB), so the **export of the same document** was read: `export?format=txt` (505 KB, HTTP 200) and `export?format=docx` (5.7 MB, HTTP 200, figures extracted) | §2.2 catalog rows UC-02/03/08/09; §3.1.2.2 Mobile Screen Index #40/#41/#45/#46; §3.1.3 Screen Authorization; §3.2.2, 3.2.3, 3.2.8, 3.2.9 in full; §5.1–5.3 rules/messages | PRIMARY product authority | yes — see §D |
| 2 | Capstone_Docs `CLAUDE.md` | `FPTUCapstone/Capstone_Docs@main` (via `gh api`) | YES | whole file | governance of analysis docs (does not override Report 3) | none |
| 3 | UC-02 requirement | `requirements/register-tour-operator-account.md` | YES | whole file | supporting analysis | SOURCE_CONFLICT_UC02 |
| 4 | UC-03 requirement | `requirements/resubmit-tour-operator-application.md` | YES | whole file | supporting analysis | SOURCE_CONFLICT_UC03 |
| 5 | UC-08 requirement | `requirements/update-traveler-profile.md` | YES | whole file | supporting analysis | SOURCE_CONFLICT_UC08 (email) |
| 6 | UC-09 requirement | `requirements/update-travel-preferences.md` | YES | whole file | supporting analysis | SOURCE_CONFLICT_UC09 (model) |
| 7 | WEB_SCOPE_MATRIX | `Capstone_FE@develop docs/WEB_SCOPE_MATRIX.md` (commit `12312d1`, 2026-09-06) | YES | UC-02/03/08/09 rows | PLATFORM scope | PLATFORM_SCOPE_CONFLICT (low) |
| 8 | Mobile `AGENTS.md` | `origin/develop` (identical to local) | YES | all | engineering | none |
| 9 | Mobile `CONTRIBUTING.md` | `origin/develop` | YES | all | engineering | note: says "branch from main"; task + team rule = develop |
| 10 | Mobile `docs/CODEBASE_RULES.md` | `origin/develop` | YES | all | engineering | none |
| 11 | current `origin/develop` | `af8daa012c599ad14a923dc53a5aece7ad93563b` (unchanged since last audit) | VERIFIED | — | current implementation | — |
| 12 | relevant open PRs | `gh pr list` | VERIFIED | only #24 open; **no PR owns UC-02/03/08/09** | ownership | — |
| 13 | PR #24 | `feature/mobile-active-trip` | VERIFIED | head `f46734d`, **3 commits** (new: `fix(traveler): remove remaining production demo leakage`) | out of scope | my register `11-…` is stale for this PR |
| 14–21 | Stitch `screen.png` + `code.html` for #40, #41, #45, #46 | `stitch_tripmate_adaptive_journey_system/<folder>/` | **all 8 opened** (images viewed; HTML parsed for structure/labels/buttons, CSS ignored) | see §N | VISUAL ONLY | see §N |
| 22 | `specs/mobile-mvp/` | worktree (untracked) | YES | 00, 01, 02, 08, 09, 10, 11 | DERIVED | corrections in §D.12 |

Also read: Report 3 embedded **figures** for the four screens (extracted from the online docx: `image19` UC-02, `image45` UC-03, `image16` UC-08, `image23` UC-09) and `Capstone_BE` `origin/develop` `d198107` (read-only).

**Gate:** ONLINE REPORT 3 = OPENED · Mobile governance = OPENED · origin/develop = VERIFIED · Stitch targets = INSPECTED → proceed.

Note on the earlier hash request: the online document is the authority designated for this task. A Google export is regenerated on each download, so its bytes cannot be compared with SHA-256 `c8d927a5…`; that comparison is therefore **not possible**, and I did not substitute any local copy.

## B. Report 3 URL successfully read
**YES** (via export of the same document).

## C. Report 3 sections used
§2.2.2 Descriptions (UC-02, 03, 08, 09) · §3.1.2.2 Mobile Application Screens (#40, #41, #45, #46) · §3.1.3 Screen Authorization (Guest → #40; Tour Operator → #41; Traveler → #45, #46) · **§3.2.2, §3.2.3, §3.2.8, §3.2.9 in full** (Trigger, Description, Interface, Data Processing, Screen Layout, Data, Business Rules, Validation, Normal/Abnormal flows, Post-Conditions) · §5.1 business rules (appendix) · §5.2 common requirements CR-03, CR-04, CR-05, CR-06, CR-09, CR-12, CR-13 · §5.3 messages MSG01–MSG08, MSG19–MSG23, MSG127.

Useful common requirements: **CR-12 "the client never reports success it has not received"**, CR-04 inline field errors beneath the field (never only a toast), CR-05 irreversible actions confirmed in a modal, CR-06 success via toast only after a success, CR-09 English UI via a resource file, CR-13 submit control disabled while in flight.

## D. Source conflicts found

1. **UC-02 text vs figure (inside Report 3).** Text lists Email, Password, Confirm Password, Company Name, Business Licence Number, Tax Code, Business Address, Contact Person, Contact Phone, Business Licence document + supporting documents, agreement checkbox, `[Submit Application]` `[Back to Sign In]`. The figure shows only Company name, Tax code, Travel business licence (file chip "UPLOADED"), Business email, Business phone, Password, info banner. **Decision: text wins (as instructed); the figure is only a visual style reference.**
2. **UC-09 text vs summary/figure/BR-24 (inside Report 3).** Detailed §3.2.9 = **Interest tags (multi), Travel style (single), Budget level (single)**, option sets from system configuration, `[Save Preferences] [Reset] [Skip]`; global message MSG22 agrees ("select at least one preferred travel style and budget level"). The §2.2.2 summary, appendix BR-24 and the **figure** show transport / pace / interests / food / risk tolerance. **Decision: detailed text wins.** `SOURCE_CONFLICT_UC09` with the BE data model — see D.7.
3. **UC-08 email.** Summary and Capstone_Docs FR2 list **email as editable**. Detailed §3.2.8 states Email is **read-only** (Data Processing, Screen Layout, BR-17 "not editable through the profile function", PC-04). **`EMAIL_RULE: READ_ONLY`.** Docs conflict recorded as `SOURCE_CONFLICT_UC08`.
4. **UC-08 figure vs text.** Figure: Full name, Email + "VERIFIED" chip, Phone + "VERIFY" chip, Date of birth, Home city. Text: Full Name, Phone, Date of Birth, **Gender, Address, Avatar**; no phone/email verification behaviour is defined. Text wins; chips are not adopted.
5. **UC-02 / UC-03 application status name.** UC-02/03 detail: account = *Pending Approval*, application record = *Pending Review* (UC-03 → *Pending Review* after resubmission). Summary, appendix BR-04/BR-07 and Capstone_Docs: *Pending Approval*. `SRS_STATUS_NAME_CONFLICT`. Mobile will display the **Backend-issued** status via the existing `TourOperatorApplicationStatus` mapping and will not invent a string.
6. **Message / rule numbering (inside Report 3).** Detailed sections use MSG numbers that differ from the global list (§5.3): e.g. UC-02 "MSG03 password policy / MSG04 mismatch / MSG05 email exists / MSG21 success / MSG26 licence duplicate", UC-08 "MSG20 success", UC-09 "MSG27 success", UC-03 "MSG24 success" — whereas the global list has MSG03 = email exists, MSG05 = password policy, MSG06 = mismatch, MSG08 = operator submitted, MSG19 = profile updated, MSG20 = avatar invalid, MSG21 = preferences saved, MSG22 = missing preference categories, MSG23 = unsaved-changes confirmation, MSG24 = no POIs, MSG26 = POI updated, MSG27 = deactivate POI. Likewise the **BR-xx in the UC sections differ from the Appendix 5.1** (e.g. appendix BR-07 = resubmission moves status back to Pending Approval). `SRS_MESSAGE_ID_CONFLICT` / `SRS_BR_ID_CONFLICT`. **Decision:** code and tests use **semantic message keys** (no numeric coupling), with wording taken from the global list where the meaning is unambiguous (required, email format, phone, password policy, passwords mismatch, generic failure).
7. **UC-09 vs Backend.** BE `TravelerProfile` (develop) has `InterestTagsJson`, `PreferredTransportMode`, `TravelPace`, `RiskTolerance`, `FoodPreferencesJson`, `DefaultBudget` — i.e. the **summary/figure model**, not "travel style / budget level". There is **no endpoint**. This is the main decision for the developer (§S-1).
8. **Platform (UC-02/03).** §3.2.2/3.2.3 "Interface" name only the responsive Next.js Web; WEB_SCOPE_MATRIX = `SHARED_WEB_MOBILE` with the note "treat the detailed interface as incomplete, not a Mobile removal"; Report 3 §3.1.2.2 lists #40 and #41 as **Mobile** screens and §3.1.3 authorises them. `PLATFORM_SCOPE_CONFLICT` (low): Mobile is **allowed/required** by matrix + Screen Index + Authorization.
9. **Capstone_Docs UC-02 (SOURCE_CONFLICT_UC02).** Docs: license is the only named mandatory document, "business contact details" and "authentication information" are open questions, deferred phone/OTP. Report 3 now defines them (Confirm Password, Business Licence Number, Business Address, Contact Person, Contact Phone, supporting documents, agreement checkbox). Report 3 wins; the Docs remain valid for BR6/BR7/BR8 decisions dated 2026-08-26 (new independent account; licence upload mandatory; edit-and-resubmit the same record) — all consistent with Report 3.
10. **Capstone_Docs UC-03 (SOURCE_CONFLICT_UC03).** Docs MVP suggests no resubmission cap, no history; Report 3 records "resubmission count" and retains the previous rejection record for audit. Stitch shows "0/3" and a 7-day deadline — **not in Report 3 or Docs** → rejected.
11. **Report 3 version provenance.** Two local copies exist that differ from each other and neither matches `c8d927a5…`; per instruction they were not used. The online text for §3.2.2/3.2.3/3.2.8/3.2.9 is identical in substance to the more complete local copy.
12. **Corrections to my derived docs (`02`, `08`, `09`):** (a) UC-08 fields were "name, phone, birth date, city" → canonical: Full Name, Phone, Date of Birth, Gender, Address, Avatar, Email read-only; (b) UC-09 was modelled on the summary (transport/pace/…); canonical is Interest tags / Travel style / Budget level; (c) many `SRS_TEXT_REQUIRED` markers for UC-02/03/08/09 are now resolved; (d) **I assumed real session `fullName`/`email` are available — they are not** (see §G.5); (e) PR #24 register is stale (3 commits now).

## E. UC-02 / Screen #40 — canonical snapshot

| Item | Canonical (Report 3 §3.2.2) |
|---|---|
| Actor / platform | Guest · `SHARED_WEB_MOBILE` (Mobile Screen Index #40, Screen Authorization: Guest) |
| Entry | Guest selects "Register as Tour Operator" (from Sign In); no existing-account upgrade path (Docs BR6) |
| Required data | Email Address, Password, Confirm Password · Company Name, Business Licence Number, Tax Code, Business Address, Contact Person, Contact Phone Number · Business Licence document (mandatory) · acceptance of Terms of Service + Privacy Policy + Partner Agreement |
| Optional | supporting documents (exact mandatory set `UNRESOLVED`: text says "mandatory business documents" but names only the Licence) |
| Read-only | none |
| Mutation | Submit Application → system creates user (role Tour Operator, status Pending Approval) + application record (Pending Review) + stores documents + queues for Admin review |
| Validation | required fields; email format; password policy (≥ 8, upper, digit, special — global MSG05 also says lowercase; reuse the repository validator used by Traveler registration); confirm = password; email unique; licence number/tax code unique; mandatory document present; file type/size (limits not defined); pending application for same identity |
| Success | confirmation that the application was submitted and operator functions unlock only after approval (**only after Backend confirms**) |
| Failure | field-level errors; duplicate email/licence/tax; storage unavailable → generic failure; no account/application created |
| Backend capability | **NONE** — no operator registration or document-upload endpoint (BE `AuthController` registers Travelers only). Admin approve/reject exist. `BACKEND_CAPABILITY_REQUIRED` |
| Visual reference | Report 3 figure (mobile), Stitch `ng_k_i_t_c_l_h_nh_tripmate_partner` (desktop) |
| Known conflicts | D.1, D.5, D.6, D.8, D.9 |
| Implementation gap | form has 5 of 9 required text fields; no Confirm Password, Licence Number, Address, Contact Person, agreement checkbox, supporting docs; **`_DemoLicencePicker` shows "Uploaded"; `submit()` fakes Pending after 500 ms** |

## F. UC-03 / Screen #41 — canonical snapshot

| Item | Canonical (Report 3 §3.2.3) |
|---|---|
| Actor / platform | Tour Operator with a **Rejected** latest application · `SHARED` · Screen Authorization: Tour Operator |
| Entry | operator signs in → Application Status; resubmission offered **only** when the latest application is Rejected (BR-09); Pending/Approved → "not offered" |
| Required data (read-only) | current application status, **rejection reason**, review timestamp (also Application ID, reviewer, resubmission count in system data) |
| Editable | Company Name, Business Licence Number, Tax Code, Business Address, Contact Person, Contact Phone Number; replace/add documents |
| Mutation | Resubmit Application → same application record set to Pending Review (status naming: D.5), timestamp + count recorded, account stays Pending Approval, previous rejection retained for audit; **no new account/application** |
| Validation | as UC-02 (required, mandatory document, file type/size, licence/tax uniqueness excluding own record) |
| Success | resubmission confirmed (only after Backend) |
| Failure | status update fails → **status remains Rejected** + generic failure |
| Backend capability | status read: **YES** (session `applicationStatus`, mapped by `session_response_dto`, enforced by `RouteGuards`). Rejection reason: BE persists it and the Admin API exposes it, but **no operator-facing read** → `BACKEND_CAPABILITY_REQUIRED`. Review timestamp, application data, resubmission: **NONE** |
| Visual reference | Report 3 figure, Stitch `tr_ng_th_i_h_s_n_p_l_i_tripmate_partner` (has a 390×844 mobile handoff frame at the bottom) |
| Known conflicts | D.5, D.6, D.10 |
| Implementation gap | **hard-coded** sample company name and tax code (values not reproduced), **fake rejection reason**, fake address/phone, fake licence "Replaced", local Rejected→Pending, demo copy ("Existing demo sign-in details…"); Pending view says "simulated locally" |

## G. UC-08 / Screen #45 — canonical snapshot

`EMAIL_RULE: READ_ONLY`

| Field | Status | Notes |
|---|---|---|
| Full Name | EDITABLE | required-ness: "a required field is empty → MSG01" — which fields are required is `UNRESOLVED`; registration requires full name |
| Phone Number | EDITABLE | format: 10 digits starting 0 (global MSG04); existing `Validators.phone` |
| Date of Birth | EDITABLE | optional; must be a past date and Traveler ≥ 16 (BR-18 in §3.2.8) |
| Gender | EDITABLE | option set not defined (Stitch: Male/Female/Other = design only) |
| Address | EDITABLE | free text; Stitch shows "City / Country", figure "Home city" → Report 3 term is **Address** |
| Avatar | EDITABLE | image, supported type, ≤ 5 MB (JPG/PNG/WEBP per global MSG20); `[Change Avatar]` |
| Email | **READ_ONLY** | identity of the account (BR-17) |
| Role | not editable | note only (BR-18 appendix) |
| Phone/email verification badges | **NOT_IN_SCOPE** | not defined by UC-08 |
| Bio / emergency contact | **NOT_IN_SCOPE** | not in Report 3 |

Actor Traveler · `SHARED` · buttons `[Save Changes] [Cancel] [Change Avatar]` · retrieval failure → generic failure and **no editing offered** · save failure → previous profile unchanged, no partial update (PC-05) · success "Profile updated successfully." only after Backend.
**Backend capability:** entity `User` has `FullName`, `PhoneNumber`, `AvatarUrl`, `Email` but **no endpoint** to read/update and **no storage for Date of Birth, Gender, Address** → `BACKEND_CAPABILITY_REQUIRED`.
**Implementation gap:** hard-coded identity (sample full name / phone number / date of birth / city — values intentionally not reproduced), email shown as "Email unavailable", simulated phone verification, demo avatar, fake save toast, **and the Mobile session does not retain `fullName`/`email`** (see below).

> **Session identity finding.** `AuthSession` (domain) carries `fullName` and `email`, but `AuthSessionState.authenticated` holds only `role` and `applicationStatus`; secure storage keeps only tokens, role, application status and keep-signed-in. After login the name/email are **discarded**, and there is no JWT-claims decoding. The brief's "reuse actual authenticated-session fields" is therefore **not possible without a (small) change to the frozen auth state** — decision §S-2.

## H. UC-09 / Screen #46 — canonical snapshot

**CANONICAL PREFERENCE MODEL (Report 3 §3.2.9 detailed + MSG22):**
- **Interest tags** — multi-select, maximum count = configured limit
- **Travel style** — single-select
- **Budget level** — single-select
- Option sets come from **system configuration** (BR "values must belong to the configured option set; free text not accepted"). SRS gives only *examples*: Culture, Nature, Food, Adventure, Relaxation, Shopping / Solo, Couple, Family, Group / Economy, Standard, Premium. **No fixed enum is to be hard-coded as authoritative.**
- Actions: **`[Save Preferences]`, `[Reset]`, `[Skip]`** are canonical. Skip = leave without saving, previous values unchanged.
- Preferences are optional, but UC-25 needs ≥ 1 interest tag to personalise (BR-20).
- Abnormal 2.a1: **if the configured option sets cannot be retrieved → generic failure and no selection is offered.**
- Backend: **NONE** (no endpoint; BE models the other schema, D.7). Unsaved-changes confirmation exists (MSG23).
- Implementation gap: current page implements the **non-canonical model** (transport, pace, interests, food, risk) with hard-coded enums and **pre-selected defaults** (Beach, Heritage, Local food, Motorbike, Balanced, Medium) presented as if saved, plus "saved locally for demo"; the cubit is recreated per route so values are lost anyway.

## I. Screen #40 — behaviour specification (production, Backend absent)

- **Layout** (Report 3 mobile figure + Stitch grouping, mapped to Material 3 tokens): app bar "Business Account" · Traveler / Tour Operator segmented control (existing) · info banner · four grouped sections **Account**, **Company & legal**, **Contact person**, **Documents** · agreement checkbox · footer actions. Stitch's marketing panel, hotline, "review in 1–3 days" and 4-step stepper are **not adopted**.
- **Fields (exact):** Email Address · Password · Confirm Password · Company Name · Business Licence Number · Tax Code · Business Address · Contact Person · Contact Phone Number.
- **Documents area:** "Business Licence document" and "Supporting documents" tiles in an **UNAVAILABLE** state — text "Document upload isn't available in the app yet." No picker, no filename, no "Uploaded" chip. A format hint is shown only as design reference text if approved (§S-4).
- **Agreement:** one checkbox "I accept the Terms of Service, the Privacy Policy and the Partner Agreement" (links are not invented; plain text).
- **Validation (client, CR-03/CR-04 inline beneath the field):** required; email format; password policy; confirm match; phone format; checkbox required. Server-side uniqueness errors are not simulated.
- **Capability banner (PENDING_INTEGRATION), shown before any mutation:** "Operator application submission is not available in the mobile app yet." with the reason line "Your application cannot be sent until TripMate connects this form to the service."
- **Primary action:** `Submit application` rendered **disabled** with the explanation visible beside it (not only a tooltip). **Secondary:** `Back to Sign In` (Report 3), existing "Create traveler account" link kept.
- **No local state transition:** the screen never navigates to a Pending view and never shows "Application submitted".
- **States:** form (default) · validation errors · capability-unavailable (permanent in production). No loading/success states exist until a service does.
- **Accessibility:** semantic labels per field, error text announced, checkbox with label, disabled button with `semanticLabel` that includes why, tile status = icon + text.
- **Responsive:** single scroll column, safe area, keyboard inset, no fixed widths; wraps long company names; 48 dp targets.
- **DESIGN_ONLY_FIELDS:** document format/size hint (PDF/JPG/PNG, 10 MB) — from figure/Stitch, not Report 3.

## J. Screen #41 — behaviour specification

- Data source: **session** `applicationStatus` only (existing `RouteGuards` + `TourOperatorApplicationStatus`). No local `OperatorApplicationCubit` state decides the status.
- **Pending** (`pendingApproval`): status badge (icon + text) + neutral guidance "Your application is awaiting Administrator review. Tour publishing and bookings stay unavailable until it is approved." No "demo", no "submitted just now", no timestamps. Label wording: §S-3.
- **Rejected:** badge "Rejected" · section "Rejection reason": **"Reason not available in the app yet."** (no invented reason) · section "Application details": not shown (no data source) · **resubmission area**: the Report 3 editable fields rendered **empty and disabled** under a banner "Resubmission isn't available in the app yet" and a disabled **Resubmit application** button — i.e. visually prepared, truthfully unavailable (alternative: omit the form, §S-5). `Contact TripMate support` shows no invented phone/e-mail (global MSG11 mentions `support@tripmate.com` only for locked accounts; not reused here).
- **Unresolved:** unchanged fail-closed alert (exists, tested). **Approved:** guard routes to `/operator` (unchanged).
- Never: company name/tax code, fake document names, "Replaced", local Rejected→Pending.
- Accessibility/responsive: as #40; long reason text (when a real one exists) wraps and scrolls; large text keeps actions reachable.

## K. Screen #45 — behaviour specification

- **Sections:** header (neutral avatar icon, no stock photo, no fake initials) · "Account" card: **Full name** and **Email address (read-only)** *only if* real session data is available (§S-2), otherwise "Not available" · "Personal details": Phone Number, Date of Birth, Gender, Address rows in an **UNAVAILABLE** state ("Not provided yet") · info banner **PENDING_INTEGRATION**: "Editing your profile isn't available in the app yet." · role note "Your account role is assigned by TripMate and cannot be changed" (Report 3 / figure).
- **Actions:** `Save changes` rendered disabled with the reason; `Change avatar` disabled (no picker); `Cancel/Back`. No toast, no spinner, no `Future.delayed`.
- No verification chips, no hard-coded values, no demo avatar, no local draft retained (a draft would be cross-user state).
- **Stitch:** layout pattern only (avatar header, grouped fields, bottom save bar, "email read-only with verified style" **not** adopted because verification is not defined).
- **Accessibility/responsive:** rows are labelled "Phone number: not provided"; large text safe; 48 dp.

## L. Screen #46 — behaviour specification

- **Layout:** banner (soft-constraint explanation from the figure) · three groups **Interest tags** (multi-select chips with "n of N selected"), **Travel style** (single-select cards), **Budget level** (single-select segments) · footer `Save Preferences` (disabled) · `Reset` · `Skip`.
- **Option sets:** treated as *configured option sets*. In production they cannot be retrieved → per Report 3 abnormal 2.a1 the faithful behaviour is "no selection offered". **Recommended (needs approval §S-1b):** show the SRS example options in an explicitly labelled **preview** ("Preview only — options are configured by TripMate and aren't connected yet") with **ephemeral** selection, so the layout can be reviewed.
- **Banner PENDING_INTEGRATION:** "Saving travel preferences isn't available in the app yet." No success toast; no persistence claim; nothing pre-selected as if it were the user's saved value.
- **Reset:** clears the ephemeral preview selection (local, truthful). **Skip:** leaves the screen; if ephemeral changes exist, the unsaved-changes confirmation (global MSG23 wording) applies.
- **Removed:** transport, pace, food, risk, "apply automatically" toggle (not in the canonical model — `SOURCE_CONFLICT_UC09`).
- **Accessibility:** chips expose selected state (icon + text), counter announced, long labels wrap without overflow.

## M. Backend capability matrix (read-only, BE `d198107`)

| Capability | Verified | Notes |
|---|---|---|
| Operator account registration + documents (UC-02) | **NO** | `AuthController` has Traveler `register`, `verify-email`, `login`, `google`, `logout` only |
| Operator application status read | **PARTIAL** | `applicationStatus` is returned with the session (`AuthResponseDto`) |
| Rejection reason for the operator (UC-03) | **NO** | persisted on the profile and exposed only by the Admin detail DTO |
| Resubmission (UC-03) | **NO** | |
| Traveler profile read/update (UC-08) | **NO** | `User` has FullName/PhoneNumber/AvatarUrl/Email; **no** DOB/Gender/Address columns |
| Avatar storage | **NO** (tour media upload exists for operators, not for avatars) | |
| Preferences read/update + configured option sets (UC-09) | **NO** | persistence model exists (`TravelerProfile`) but uses the transport/pace/food/risk/budget schema; unmerged BE branch `phuctv-tm213` extends it |
| Admin approve/reject application | YES (Web only) | out of Mobile scope |

## N. Stitch inspection report

| Screen | Stitch folder | screen.png | code.html | Patterns used | Rejected assumptions |
|---|---|---|---|---|---|
| #40 | `ng_k_i_t_c_l_h_nh_tripmate_partner` | opened | opened | grouped numbered sections (account / company & legal / contact / documents), required markers, helper text under email, show/hide password, dashed upload zone, agreement checkbox, review note | **desktop 1440 px two-column layout**, marketing panel, hotline "1900 6868", "1–3 business days", 4-step stepper, "Legal representative" wording (Report 3: Contact Person), CCCD document (not in Report 3), pre-filled sample values and an "uploaded" file chip |
| #41 | `tr_ng_th_i_h_s_n_p_l_i_tripmate_partner` | opened | opened | status header + rejection reason card, per-field edit affordance, document replace pattern, **390×844 mobile handoff frame** | application ID `#APP-2024-8829` / dates / "0/3 resubmissions" / "7 days remaining" / reviewer-note box / "12–24 hours" SLA (none in Report 3), sample company data, "Replace file" fake documents |
| #45 | `ch_nh_s_a_h_s_c_nh_n_tripmate_mobile` (the brief's `…_r_i_nh_m_…` name does not exist; this is the real folder) | opened | opened | avatar header with camera badge, role badge, grouped fields, gender segmented control, sticky bottom save bar, read-only email field styling | stock avatar photo, **"Email verified" badge**, +84 country-code picker, "City / Country" (Report 3: Address), sample person data, "Lưu" in app bar as a live action |
| #46 | `s_th_ch_du_l_ch_tripmate` | opened | opened | section numbering, selectable cards for single choice, check-mark chips with "chọn n/6" counter, sticky bottom CTA | **pace, transportation, weather constraints, travel-radius slider** (summary-model fields not in canonical model), "CSP algorithm" chip, CTA "Apply preferences to itinerary", travel-style/budget have **no Stitch visual** → designed with the same card/segment patterns |

Language: Stitch copy is Vietnamese; Report 3 CR-09 specifies English for this version → English copy.

## O. Current implementation gap (summary)

| Screen | Backend | Real production data | Invalid production fixtures |
|---|---|---|---|
| #40 | none | none | demo licence picker "Uploaded"; faked 500 ms submit → Pending; missing 4 required fields + confirm/agreement |
| #41 | status only (session) | status | hard-coded company, tax code, rejection reason, address, phone, licence; local resubmit; "demo/simulated" copy |
| #45 | none | none available today (identity not retained) | hard-coded identity; simulated phone verification; demo avatar; fake save toast; "Email unavailable" |
| #46 | none | none | non-canonical model; hard-coded enums; pre-selected defaults; "saved locally for demo" toast; per-route cubit |

## P. Proposed Batch 1 implementation boundary

**In:** the four screens' presentation, `OperatorApplicationCubit` (remove submission simulation), `TravelPreferencesCubit` (re-model as ephemeral preview state), router provisioning of those cubits, tests. Use existing `AppPageScaffold`, `AppButton`, `AppAlert`, `AppTextField`, `AppPasswordField`, `StatusBadge`, `LoadingIndicator` (only if needed), `Validators`, theme tokens. Capability banners use `AppAlert`; **no new shared component unless a third consumer appears.**
**Conditionally in (needs §S-2):** retaining `fullName`/`email` in `AuthSessionState` (+ secure storage).
**Out:** PR #24, tour search/POI/itinerary/groups, Backend, Web, any new DTO/repository/use case/data source for these four UCs (no phantom layers), dependencies, `pubspec.yaml`, sign-in/registration/verification/reset/logout contracts, `RouteGuards` behaviour.

## Q. Files that would be modified

`lib/features/auth/presentation/pages/operator_registration_page.dart` · `lib/features/auth/presentation/pages/operator_application_page.dart` · `lib/features/auth/presentation/cubit/operator_application_cubit.dart` · `lib/app/router/app_router.dart` (cubit wiring only) · `lib/features/traveler/presentation/pages/traveler_profile_page.dart` · `lib/features/traveler/presentation/pages/travel_preferences_page.dart` · `lib/features/traveler/presentation/cubit/travel_preferences_cubit.dart` · conditional: `lib/features/auth/presentation/cubit/auth_session_cubit.dart`, `auth_session_state.dart`, `lib/core/constants/app_constants.dart`.

## R. Tests to create / update

- **Update (they currently assert fake behaviour):** `operator_registration_page_test.dart` ("success … shows pending state"), `demo_auth_flows_test.dart` ("Travel preferences controls update local Cubit state", "rejected Operator resubmission reaches Pending Approval").
- **Keep green:** `route_guards_test`, `auth_session_cubit_test`, `operator_application_unresolved_test`/router tests (guard behaviour, unresolved fails closed, approved routing).
- **#40:** no `DemoLicencePicker`/"Uploaded" in production; submit unavailable and capability message shown before any mutation; no Pending transition; all 9 Report 3 fields + agreement present; validation messages inline; no HTTP call is made (fake `DioClient` asserts zero requests); renders at 360/390/412 and 200 % text without overflow.
- **#41:** status comes from session; Rejected shows "Reason not available" and no invented reason/company; Resubmit disabled and no local Pending; unresolved fails closed; approved handled by guard; long reason wraps.
- **#45:** no hard-coded identity; (if §S-2 approved) session name/email shown, email read-only; no verification chip; no local-save success; Save unavailable with reason; two sessions never share a draft.
- **#46:** no persistence claim; no pre-selected defaults; Reset clears preview; Skip with unsaved changes asks to confirm; Save unavailable; long labels do not overflow; no network call.
- **Truthfulness grep test (optional):** assert none of the removed demo strings remain in the four pages.

## S. Unresolved questions that genuinely need a decision

1. **UC-09 model.** (a) Confirm the canonical detailed model **Interest tags / Travel style / Budget level** even though the Backend schema (and the Report 3 figure, BR-24, summary, Stitch) use transport / pace / food / risk / interests / default budget. (b) Because the option sets must come from configuration and are unavailable, choose: **preview with SRS example options, clearly labelled, ephemeral** (recommended) or **offer no selection** (literal abnormal flow 2.a1).
2. **Profile identity source.** `fullName`/`email` are not retained after login. Approve a minimal change (store them in `AuthSessionState` and persist next to `role` in secure storage), **or** show "Not available" for them in Batch 1. This touches the otherwise frozen auth state.
3. **Application status label.** Show "Pending approval" (BE/summary/appendix) or "Pending review" (UC-02/03 detail) — recommend deriving the label from the existing enum name `pendingApproval` → "Pending approval".
4. **Document constraints.** Report 3 defines no accepted types/size; figure says "PDF or JPG up to 10 MB", Stitch "PDF/JPG/PNG up to 10 MB", Docs leaves it open. Batch 1 shows **no** constraint (upload is unavailable) unless you want the hint as preview text.
5. **#41 resubmission area.** Show the Report 3 fields empty and disabled (recommended, "visually prepared") or omit the form until a Backend read exists.
6. **Required-field set for UC-08** (which of the profile fields are mandatory) and the **Gender option set** — both undefined in Report 3; Batch 1 does not need them while Save is unavailable.

## T. Final gate

**BATCH 1 SPECIFICATION READY FOR DEVELOPER APPROVAL: YES** — with decisions §S-1…§S-3 required before the implementation plan can be written.
