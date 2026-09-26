# TM-56 Mobile POI Pagination Design

## Scope

Resolve the remaining UC-10 Mobile review gate by retaining all selectable POI
search pages and automatically loading another page near the bottom of the
picker list.

## Decisions

- The picker requests pages of 50 items, retains `totalCount`, and requests the
  next page only when the user scrolls near the end.
- A new query, changed search text, changed center, or changed radius cancels
  the logical result set: late responses from earlier searches are ignored.
- Only one page request may run for the current query at a time. No request is
  made once loaded item count reaches `totalCount`.
- The picker displays an inline loading indicator for an additional page and
  keeps already selected POIs selectable while that page loads.
- Multi-day is the product source of truth. One-day is the special case where
  start and end dates are the same. This PR retains the reviewed one-day UI;
  multi-day planning is a separately planned scope.

## Verification

- Model and repository tests retain `totalCount` and request the expected page.
- Cubit tests cover append, no duplicate concurrent load, exhausted results,
  and stale-response suppression.
- Widget tests scroll near the end and verify the next page appears without
  replacing prior results or selected POIs.
