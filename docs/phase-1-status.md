# Phase 1 Status

Date: 2026-02-25
State: complete

## Completed

- Repository initialized and structured for app, backend, docs, scripts, and CI.
- Detailed roadmap and execution backlog documented.
- Baseline architecture and ADR decisions recorded.
- Initial Supabase migration created with core tables, indexes, and RLS policies.
- CI workflow added with foundation validation checks.
- Flutter app shell scaffold added (`pubspec`, router, theme, starter screens).
- Setup runbook and bootstrap scripts added.
- Environment templates added for dev/staging/prod.
- Edge API contracts documented for create/join community and create-post flows.
- Baseline migration validated on isolated Postgres with scripted harness.
- Flutter toolchain bootstrap and `flutter pub get` validation completed.

## In progress

- Environment provisioning for dev/staging/prod projects.
- Early Phase 2 kickoff:
  - anonymous auth bootstrap in mobile app
  - create/join community edge function contracts + deep-link entry wiring
  - create-post edge function + text/image/video composer baseline
  - global/community feed pagination and realtime refresh baseline
  - reactions + threaded replies baseline (heart interaction + reply bottom sheet)
  - report + block controls baseline (`report-content` and `block-user`)
  - private link chat lifecycle baseline (`create-private-chat-link` + `/chat/:token`)
  - read-once private message retrieval baseline (`read-private-message-once`)
  - media retention queue + maintenance cleanup function (`expire-content`)
  - video upload compression/transcode baseline (`video_compress`) with playback support
  - scheduled media retention automation (`.github/workflows/media-retention.yml`)
  - moderation triage contracts baseline (`list-reports` + `review-report`)
  - abuse rate limiting baseline (`bump_rate_limit` + edge-function checks)
  - enforcement actions baseline (`enforce-user` + ban-aware RLS checks)
  - legal/safety surfaces in mobile app (`/legal` screen)
  - incident runbook (`docs/incident-runbook.md`)
  - upload policy enforcement (`moderate-upload` + `media_policy_checks`)
  - phase 5 engagement baseline complete (`create-poll`, `vote-poll`, `submit-challenge-entry`, trending ranking feeds)
  - push notifications baseline complete (`register-push-token`, `list-notification-events`, delivery worker)
  - premium entitlement baseline complete (`subscription_products`, `user_entitlements`, trial activation, private-link premium gating, premium screen)
  - sponsored community template baseline complete (`sponsored_community_templates`, template listing API, onboarding create flow integration)
  - experiment framework baseline complete (`feature_flags`, `experiment_events`, rollout-aware onboarding instrumentation)

## Blockers

- None for Phase 1 completion.

## Immediate next actions

1. (Optional) Link Supabase dev project and run `supabase db push` against remote.
2. Deploy latest migrations/functions to remote Supabase environments.
