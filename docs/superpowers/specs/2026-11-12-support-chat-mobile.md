# Support chat mobile

Approved scope comes from the implementation request. Work is confined to this
mobile worktree. API model, retrieval and backend implementation belong to the
other repositories.

## Acceptance criteria

- Authenticated traveler home has an accessible support entry and guarded route.
- Page → Cubit → use case → repository → data source uses the existing Dio and DI.
- POST /api/v1/support-chat/messages sends message, at most ten transient history
  entries, and an explicitly selected optional tour, refund or itinerary context.
- Messages and history content have 1–2000 characters. Context IDs are positive
  decimal strings within Int64, accepting leading zeros. General help requires no
  context. Selecting a result action preserves chat and sends its supplied prompt.
- Parse the direct response contract strictly. Render answers and source titles
  as plain text. Mobile sources have no clickable URL action. Reject returned
  context that differs from the requested resource, comparing IDs numerically.
- Safe failure states cover 400, 401, 403, 404, 429 and 503, network failures and
  malformed responses. Authentication expiry uses the existing login flow.
- Loading, keyboard insets, scroll, retry, disposal and context/session changes
  are handled. No conversations or credentials are persisted by this feature.
- The per-request receive timeout is 65 seconds for the backend's 60-second
  deadline. Provider credentials and Gemini integration remain server-side.

## Implementation plan

1. Add focused failing domain, parser, transport/repository and Cubit tests under
   test/features/support_chat, including stale responses and disposal.
2. Implement lib/features/support_chat/domain, data and presentation/cubit.
   Validate payload bounds, strict parsing and safe mapped failures.
3. Add widget tests first, then the page and contextual entry actions. Register feature
   dependencies in core/di/service_locator.dart, add centralized routes in
   app/router and an entry in traveler_shell_page.dart.
4. Review contract and architecture, format, analyze, run focused/full tests and
   attempt Android debug build when supported. Record actual results.

History lives only in the route-scoped Cubit and clears on page close or session
transition. Context comes from an explicit support action on the real refund or
itinerary page via route extra. Users never enter internal IDs. The refund action
passes bookingId and supports both mobile roles through their guarded routes.
Itinerary context is exposed only on the traveler itinerary page. The backend
remains authoritative for ownership and returns 403 for operator itinerary lookup.
The page offers Clear chat to discard the current transient conversation.
The refund support action is visible only after progress successfully loads.
The selected context label includes its resource ID to disambiguate records.

Outstanding chat HTTP requests are cancelled when the conversation resets,
the selected context changes, the authenticated session changes or the Cubit
closes. A framework-independent cancellation future passes through the use case
and repository to a request-local Dio CancelToken.
The shared auth interceptor binds refresh and replay to the original session
credentials. A late 401 or refresh completion from an ended session must never
replay history with a new account's credentials, overwrite its access token or
invalidate its login. Concurrent refreshes remain shared within their session.

## Validation results

- `flutter pub get` passed.
- Repository-wide Dart formatting checked 824 files with zero changes.
- `flutter analyze` passed with zero issues.
- Focused feature and entry-point tests passed all 52 tests.
- Full Flutter suite passed 2,468 tests and skipped four environment-dependent tests.
- `git diff --check` passed.

Windows native-asset test compilation required a temporary short-path alias to the existing Flutter SDK because the original SDK path contains spaces. Android APK, physical-device validation and live authenticated Backend/Gemini verification are pending.

## Approved actionable-chat extension

- Domain replies and messages carry typed navigation and context-selection actions.
  Absent or null `actions` means an empty list. Inactive variant properties may
  be absent or null. Non-null conflicting properties, malformed actions, invalid
  contexts and selection prompts outside 1–2000 characters fail strict parsing.
- Navigation accepts exact allowlisted Web paths and maps them through existing
  `AppRoutes`. Supported destinations are `/tours`, `/tours/{id}`, a tour booking
  with `scheduleId` and optional `adults`, `/account/trips`, `/itinerary/{id}` and
  `/bookings/{id}/refund`. Resource IDs must be positive Int64 decimal strings.
  Unknown query keys, duplicates, encoding, external URLs and fragments are omitted.
- `/itineraries` and `/partner/bookings` have no independently routable Mobile
  list screens. Their actions are omitted individually while the reply and its
  supported actions remain available.
- Context-selection actions must belong to the current route-scoped conversation.
  Selecting a result preserves earlier turns, cancels an outstanding request and
  sends the supplied prompt with the explicit record context. Generation and
  session guards prevent late replies and old actions from restoring cleared data.
- Accessible action buttons wrap long labels and descriptions in the existing
  single message scroll. Action replies preserve unsent composer drafts. The
  selected-context hint stays visible, and the toolbar action reads Clear chat.
- Booking navigation uses the real booking route and selected schedule. An optional
  adult count from 1 through 50 initializes counts before the first quote. Children
  and infants are zero for adult-only handoffs. The two-adult handoff has total two.
  Omitted or invalid counts use the existing manual-booking defaults. The normal
  editable form, terms acceptance and final confirmation govern booking submission.
- Source titles remain plain text. Source URLs never become navigation actions.
  Chat history stays in memory in the route-scoped Cubit. Back from a pushed booking
  returns to the current chat, while removing the chat route destroys its history.

The extension was implemented in parallel atomic parser, booking-handoff and
presentation/navigation tasks. Focused TDD covers parser compatibility and conflicts,
URL safety, record selection, stale/session cancellation, draft retention, narrow
screens, route lifetime and the actual booking handoff. The quote transport test
uses the production Cubit, use cases, repository and Dio data source with fixture
HTTP responses and verifies the exact selected schedule and participant counts.
Live authenticated Backend quote and device verification remain pending.

Latest unified-assistant validation passed 84 focused chatbot, booking and route
tests, then 2,511 full-suite tests with four skipped. Repository formatting and
static analysis passed with zero issues. The booking handoff quote was verified
through the production data stack with HTTP fixtures. APK and physical-device
verification for this expansion remain pending.

## Review corrections and latest validation

- The manual-test follow-up preserves children and infants in server action links, Mobile route mapping, dependency injection and the first booking quote. Total participant counts remain bounded at the handoff. Focused chatbot, booking and route validation passed 86 tests. Device verification remains pending.

- Added request cancellation through all chat layers and original-session guards around refresh, replay and expiry cleanup.
- Serialized credential updates across login, logout, password changes and token renewal. Guarded expiry rechecks session identity after push cleanup and restores push registration when cancellation preserves the active login.
- Regression tests cover late 401 after account switching, switching during refresh, a gated credential-write race, explicit Firebase requests during storage failure, cancellation during refresh and real push restoration after abandoned expiry.
- Final focused network, push, chatbot, authentication and change-password tests passed all 204 tests.
- Final full Flutter suite passed 2,481 tests with four environment-dependent tests skipped.
- Final `flutter analyze --no-pub` passed with zero issues. Repository-wide formatting checked 824 files with zero changes. `git diff --check` passed.

## Android greeting and layout follow-up

The user reported greetings falling through to the missing-knowledge answer and
cramped, duplicate tour actions on Android. Backend now recognizes bounded social
messages while preserving the normal grounding path for business questions.
Mobile groups matching tour actions into padded full-width cards, separates user
and assistant bubbles, wraps action labels and collapses source details.

Regression verification passed all 63 focused support-chat tests, including grouped
actions, source expansion, safe navigation and 320-pixel large-text/keyboard layout.
Full static analysis passed with zero issues. Android rebuild and emulator visual
verification are tracked separately below when completed.

Android follow-up verification completed on Pixel_8 emulator-5554. The updated
debug APK built successfully and was installed as an update. Real authenticated
chat returned the friendly hi reply, public tour recommendations rendered as
three consistently padded cards, View tour opened the matching live detail, and
returning preserved the conversation. Ask about tour selected tour 101 and returned
current price/departure/capacity information through the real Backend/Gemini flow.
The emulator and local Backend remain running for user testing. Physical-device
verification remains pending. Existing Android build-tool deprecation warnings remain.
