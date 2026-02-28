# Phase 2 UX Bug Bash

Date: 2026-02-27
Owner: engineering

## Scope

- Onboarding auth bootstrap
- Join-by-code input flow
- Post creation entry points (global/community)

## Findings and fixes

1. `onboarding` recovery gap:
   - Issue: auth bootstrap failures had no in-app recovery action.
   - Fix: added retry action in onboarding status panel to invalidate and rerun auth bootstrap + feature flag fetch.
   - Files: `apps/mobile/lib/features/onboarding/presentation/onboarding_screen.dart`

2. `join code` input friction:
   - Issue: join code accepted any characters and relied on backend rejection.
   - Fix: added client-side input formatter and validator for strict 8-char alphanumeric uppercase codes.
   - Files: `apps/mobile/lib/features/communities/presentation/join_community_dialog.dart`

3. `post flow` observability gaps:
   - Issue: no lifecycle events for post dialog open/cancel/success/failure in global/community contexts.
   - Fix: added telemetry events to both post creation entry points.
   - Files:
     - `apps/mobile/lib/features/feed/presentation/global_feed_screen.dart`
     - `apps/mobile/lib/features/feed/presentation/community_feed_screen.dart`

## Acceptance checklist

- [x] Onboarding auth errors expose an actionable retry path.
- [x] Join code input rejects symbols/spaces and enforces 8 uppercase alphanumeric chars.
- [x] Global post flow emits open/cancel/success/failure telemetry events.
- [x] Community post flow emits open/cancel/success/failure telemetry events.
