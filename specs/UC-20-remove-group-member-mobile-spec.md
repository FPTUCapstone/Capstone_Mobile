# UC-20 Remove Group Member — Mobile specification

**Status:** Approved by user for implementation, 2026-10-27.

**Sources:** `.scratch/uc20/spec.md`, `.scratch/uc20/decisions.md`, `Capstone_Docs/requirements/mvp/remove-group-member-mvp.md`, `Capstone_Docs/ux/screen-specifications/remove-group-member-screen-spec.md`, and the implemented Backend contract in `Capstone_BE_UC20/specs/UC-20-remove-group-member-spec.md`.

## Scope

Complete the existing Host Remove action on Flutter Mobile and add a minimal authenticated `InApp` inbox so the removed Traveler can read the notification. The Backend alone decides Host role, membership, removal outcome, and access. UC-20 does not remove the Host, transfer Host, leave/close a group, affect Booking/payment/tickets or itinerary ownership, or add a Web screen.

## Host flow

1. Load `GET /api/v1/travel-groups/{groupId}/members`. Show Remove only when the authenticated Traveler ID matches the sole Host in the server response, and only for another active member in that response. Unknown identity hides Remove. Never trust route `extra` or a local `isHost` flag as authority.
2. The existing confirmation dialog shows exact MSG59: `Are you sure you want to remove {Member_Name} from this group?` Cancel sends no request.
3. Confirm sends `DELETE /api/v1/travel-groups/{groupId}/members/{memberUserId}` with no body and a newly generated UUID `Idempotency-Key`. Keep that key for uncertain retries of the same attempt. Disable duplicate submission while pending. A later independent removal uses a new key.
4. Only HTTP `200` means committed success. Parse `{ groupId, memberUserId, memberName, removedAtUtc }`, refresh the server member list, then show exact MSG60: `{Member_Name} has been removed from the group.` A replay may describe a historical removal after a rejoin, so the refreshed list determines current membership. Never remove a tile optimistically.
5. `401`: MSG125 and sign-in handoff. `403`: MSG126 and refresh/exit protected group view. `404`: group unavailable. `409` inactive target or closed group: reload state; key-payload mismatch: stop retrying that key for a changed target. `400`: validation error. Network/timeout/`5xx`: MSG127 and retry with the same key, without claiming success. Do not show raw server diagnostics.
6. When the viewer loses group access, leave protected group member/detail/location views and clear group-only in-memory state. Preserve independently owned itinerary/navigation and Booking/ticket data. Self-removal belongs to UC-21.

## Recipient `InApp` inbox

- One minimal authenticated Traveler inbox is shared with UC-21. `GET /api/v1/notifications?unreadOnly={bool}&limit={1..50}&beforeId={optional}` returns `{ items, nextBeforeId }`, newest ID first. Items contain `id`, `type`, `title`, `body`, `relatedEntityType`, `relatedEntityId`, `createdAtUtc`, and `isRead`. Provide loading, empty, retryable error, unread filter, pagination, and end-of-list states. Authentication identifies the recipient; never send a recipient ID.
- `POST /api/v1/notifications/{notificationId}/read` returns `204`, is safe to retry, and returns `404` for an absent or inaccessible item. Update displayed read state only after confirmed success.
- Display `TravelGroupMemberRemoved` and the captured group name. Its `relatedEntityId` is metadata, not permission; do not make this event open protected group details or expose members, itinerary, or location. On stale protected screens, an access-denied response clears group-only state and returns to a safe Traveler route.
- No push/email/SMS, background worker, or separate inbox protocol. The Mobile feature requires the UC-20 removal and shared notification endpoints to be deployed; the isolated BE implementation is not yet merged/deployed.

## Acceptance and testing

- Host-only visible action, cancel without request, one DELETE per confirmation, double-tap block, stable-key retry, replay-after-rejoin refresh, exact MSG59/MSG60, and safe 400/401/403/404/409/network outcomes.
- Recipient can see the notice, paginate/filter, and mark it read; another user cannot request their inbox via Mobile. Removal notice never reopens protected group data; personal trip access remains.
- Reuse repository/Dio tests for HTTP mapping, Cubit tests for attempt state, and widget/router tests for Host visibility, dialogs, inbox, and denied navigation. Test behavior at these existing seams rather than private fields.
