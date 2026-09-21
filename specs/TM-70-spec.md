# TM-70 / UC-24 — Search Tours — Feature Specification

## Overview

Add a public Tour Search screen to the TripMate Flutter mobile app. Both **Guest** (unauthenticated) and **Traveler** (authenticated) users can browse published tours from the real backend API, apply filters (destination, departure date, price range), paginate results, and reset filters.

## Actor & Access

| Actor | Auth required | API token sent |
|---|---|---|
| Guest | No | No (`skipAuth: true`) |
| Traveler | Yes (already logged in) | No (endpoint is `AllowAnonymous`) |

The same screen, same route, and same API call serve both actors. No role-based branching in UI beyond what the existing `/explore` pattern already handles (showing a login button for guests).

## Backend API Contract

### Endpoint

`GET /api/v1/tours` — **AllowAnonymous**, no request body.

### Query Parameters

| Parameter | Type | Required | Default | Constraints |
|---|---|---|---|---|
| `destination` | `string` | No | — | Max 300 UTF-16 code units after NFC normalization |
| `departureDate` | `string` | No | — | ISO `yyyy-MM-dd`, interpreted as Vietnam timezone day |
| `minPrice` | `integer` | No | — | `0 ≤ value ≤ 9,999,999,999`, whole VND |
| `maxPrice` | `integer` | No | — | `0 ≤ value ≤ 9,999,999,999`, whole VND, `≥ minPrice` |
| `page` | `integer` | No | `1` | `≥ 1` |
| `pageSize` | `integer` | No | `20` | `1–100` |

**Client rules:**
- Omit parameter entirely when not set by user (do not send empty strings or zeros).
- `minPrice ≤ maxPrice` — validate client-side before sending.
- Changing any filter resets `page` to 1.
- Only ASCII digits for price fields (no commas, decimals, signs).
- `destination` is a single literal string, not multi-select.

### Response `200 OK`

```json
{
  "page": 1,
  "pageSize": 20,
  "totalCount": 2,
  "totalPages": 1,
  "asOfUtc": "2026-09-21T00:00:00Z",
  "items": [
    {
      "tourId": "123",
      "title": "Tour Đà Nẵng – Hội An",
      "destinations": ["Đà Nẵng", "Hội An"],
      "operatorName": "TripMate Tour Operator",
      "durationDays": 3,
      "basePrice": 1500000,
      "currency": "VND",
      "representativeScheduleId": "456",
      "departureAtUtc": "2026-10-01T01:00:00Z",
      "availabilityStatus": "available",
      "remainingSlots": 6
    }
  ]
}
```

### `availabilityStatus` Values

| Value | Meaning | Nullable fields |
|---|---|---|
| `"available"` | Has future departure with seats | `representativeScheduleId` ✓, `departureAtUtc` ✓, `remainingSlots` > 0 |
| `"soldOut"` | All future departures full | `remainingSlots` = 0 |
| `"noUpcomingSchedule"` | No upcoming departures | `representativeScheduleId` = null, `departureAtUtc` = null, `remainingSlots` = null |
| `"unknown"` | Corrupt capacity data | All nullable schedule fields = null |

### Error Responses

| Status | Body | Handling |
|---|---|---|
| `400` | `ValidationProblemDetails` | Map to `ValidationFailure` |
| `500` | `ProblemDetails` | Map to `ServerFailure` |
| Timeout / No connection | — | Map to `NetworkFailure` |

## Functional Requirements

### FR-1: View Public Tour List
- On screen open, fetch page 1 with no filters.
- Display tour cards showing: title, destinations (joined), operator name, duration, base price formatted as VND, availability status, remaining slots (when available), departure date (when available).

### FR-2: Filter by Destination
- Single text input for destination string.
- Trimmed; omitted if empty.
- Max 300 characters enforced client-side.

### FR-3: Filter by Departure Date
- Date picker bound to `yyyy-MM-dd`.
- Only future dates selectable.
- Omitted if not selected.

### FR-4: Filter by Price Range
- Two integer-only text fields: min price, max price.
- VND whole numbers only.
- Client-side validation: `0 ≤ min ≤ max ≤ 9,999,999,999`.
- Omitted individually if not entered.

### FR-5: Reset Filters
- Clear all filter inputs and reset to page 1.
- Re-fetch unfiltered results.

### FR-6: Pagination (Load More)
- Infinite scroll: trigger load-more at ~85% scroll extent.
- Append new items to existing list (deduplicate by `tourId`).
- Show loading indicator at bottom during load-more.
- `canLoadMore` = `page < totalPages`.

### FR-7: Pull-to-Refresh
- Pull-to-refresh resets to page 1 with current filters.

### FR-8: Availability Display
- `"available"`: Show departure date + "Còn N chỗ" in success color.
- `"soldOut"`: Show "Hết chỗ" in error/coral color.
- `"noUpcomingSchedule"`: Show "Chưa có lịch khởi hành".
- `"unknown"`: Show "Liên hệ nhà tổ chức" in muted style.

## UI States

| State | Trigger | Display |
|---|---|---|
| **Initial/Loading** | First load or filter change with no existing data | Skeleton placeholder list |
| **Success** | Items returned | Tour card list with count header |
| **Empty** | `items: []` and `totalCount: 0` | Centered empty state with reset action |
| **Error (no data)** | Network/server failure with empty list | Centered error state with retry button |
| **Error (has data)** | Failure during load-more or refresh with existing data | Inline error banner above list |
| **Validation error** | Client-side or 400 response | Inline validation notice |
| **Loading more** | Pagination in progress | Bottom spinner below last card |

## Non-Functional Requirements

- Responsive for common Android screen sizes.
- Safe area handling (notch, navigation bar).
- Keyboard dismissal on scroll/tap outside.
- Text scaling support.
- Accessibility: semantic labels on cards, filter controls, status badges.
- Touch targets ≥ 48dp.
- No hard-coded data or mock data.

## Out of Scope

The following are **explicitly excluded** from TM-70:

- TripMatch Persona / Recommendation (TM-71 / UC-25)
- Match scores, recommendation carousel
- Tour images/thumbnails
- Rating and review counts
- Favorite/save tour functionality
- Verified badges
- Category chips / keyword search / sort dropdown
- "AI pricing" or special pricing
- Languages, inclusions, highlights
- "Book now" / booking flow
- Tour detail page (TM-72 / UC-26)
- Create/update/approve tours
- Any production-like fake data

## Design Language

Follow the Stitch reference for visual tone while using **existing Material 3 theme tokens only**:

- Use `AppColors`, `AppSpacing`, `AppTypography` from `lib/app/theme/`.
- Feature-local palette class (`TourSearchPalette`) for tour-specific accents (following the `PoiPalette` pattern).
- Card with `rounded-2xl` corners, subtle elevation/border.
- Filter area in a collapsible/expandable bottom sheet or inline section.
- Navy/teal/emerald tones consistent with Stitch visual language.
- No magic colors or magic spacing values scattered in widgets.
