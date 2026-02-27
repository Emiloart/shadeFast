# ShadeFast

Anonymous, ephemeral, community-first social platform.

## Current status

Phase 1 (foundation) is complete in this repository with:
- architecture and execution planning docs
- CI foundation checks
- Supabase schema + RLS baseline migration
- environment templates and repository structure
- Flutter app shell scaffold
- anonymous auth bootstrap (mobile baseline)
- create/join community edge function contracts
- create-post edge function + text/image composer with storage upload
- video upload + playback baseline in feeds
- media uploads now use 48-hour signed URLs
- global/community feed query and pagination baseline
- reaction baseline with post like-count synchronization
- threaded replies baseline on post feeds
- report + block controls baseline (`report-content`, `block-user`)
- private link chat lifecycle baseline (`create-private-chat-link`, `join-private-chat`)
- read-once message consumption path (`read-private-message-once`)
- media retention queue + cleanup maintenance function (`expire-content`)
- moderation triage + abuse rate limit contracts (`list-reports`, `review-report`, `bump_rate_limit`)
- enforcement actions baseline (`enforce-user`, active ban checks)
- automated media safety checks (`moderate-upload`, `media_policy_checks`, create-post policy gate)
- polls/challenges growth baseline (`create-poll`, `vote-poll`, ranking feeds, challenge entry submission UX)
- push notification baseline (token registration, behavior-triggered queue, scheduled delivery worker, in-app center)
- premium entitlement baseline (`subscription_products`, `user_entitlements`, trial activation, private-link gating, premium screen)
- sponsored community templates baseline (`sponsored_community_templates`, brand-safe templates, onboarding create flow defaults)
- experiment framework baseline (`feature_flags`, `experiment_events`, rollout-aware mobile gating + event tracking)
- in-app legal surfaces (`/legal` Terms/Privacy/Guidelines)
- incident response runbook (`docs/incident-runbook.md`)

Track progress in `docs/phase-1-status.md`.
Validate baseline migrations locally with `make validate-migrations`.
Run full local foundation checks (includes `flutter pub get`) with `make bootstrap`.
If Flutter is not on `PATH`, run `FLUTTER_BIN=/path/to/flutter make bootstrap`.
Run remote smoke validation with `./scripts/smoke-remote.sh`.

## Repository structure

- `docs/`: roadmap, architecture, and delivery backlog
- `supabase/`: SQL migrations and function contracts
- `apps/mobile/`: Flutter app implementation
- `scripts/`: local validation and development scripts
- `.github/workflows/`: CI pipelines

## Next steps

1. Enable anonymous sign-ins in Supabase Auth for mobile onboarding (`signInAnonymously` path).
2. Configure domain association files for production deep links (`assetlinks.json` + `apple-app-site-association`).
3. Wire production push provider webhook secrets and run non-dry-run delivery validation.

See `docs/api-contracts.md` for current edge function payloads.
