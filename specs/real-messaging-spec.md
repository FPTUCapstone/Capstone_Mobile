# Real group and direct messaging

User-approved scope: authenticated group chat and one-to-one messages. Any Active account can find other Active accounts by name and start a private conversation. No embedded demo messages, fabricated user IDs, or seeded bank accounts. Local test fixtures belong only in a dedicated database.

## Acceptance

- A usable Messages entry opens real conversation history; existing group chat routes remain usable.
- Use the reviewed Backend REST contracts for bounded listing/history, server-confirmed saves, stable client nonce retries, read cursors, and interactions.
- SignalR events trigger authorized reloads; app resume catches up missed pages. Access is checked by Backend, including guessed IDs.
- Preserve drafts on failure, newer edits, and thread switching. Reject stale results after navigation/session/disposal.
- Group polls (including cancel), explicit broadcast acknowledgements, roll call, and accurate integer VND shares use real member IDs and confirmed counters. VietQR uses entered recipient details; self-reported payment is explicitly not bank verification.
- Direct chat has real recipient search, unread/read state, privacy-safe profiles, and no group-only tools.
- Clear loading/empty/error/read-only states, safe 401 reauthentication, precise validation messages, small-screen/keyboard/accessibility support.

## Validation

Domain parsing and Cubit regression tests, Flutter analyze/tests/debug APK, followed by actual emulator interactions against local SQL Server. Test Web first, then Mobile; record failures and reruns honestly. No commits or remote changes without a user request.
