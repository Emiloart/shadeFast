# ShadeFast Roadmap

## Objectives

1. Deliver a stable anonymous social app with top-tier UX and reliable moderation controls.
2. Reach a production-ready architecture that scales to 100k DAU without a rewrite.
3. Preserve the core product promise: no profile friction, ephemeral content, community-first experience.

## Phase Plan

### Phase 1: Foundation (Week 1-2) - Complete

Scope:
- repository scaffolding and standards
- environment and CI setup
- initial Supabase schema + RLS baseline
- architecture and operational plan

Deliverables:
- [x] repository initialized with baseline structure
- [x] roadmap + execution backlog docs
- [x] initial SQL migration with core tables/indexes/policies
- [x] CI workflow validating foundational files
- [x] migration validation harness (`scripts/validate-migrations-postgres.sh`)
- [x] Flutter app shell (`apps/mobile`) with Riverpod + router + theming
- [x] Supabase runbook and local bootstrap scripts
- [x] Flutter SDK + dependency bootstrap validation on target machine
- [ ] Supabase project linkage and migration push on remote dev environment (optional follow-up)

Exit criteria:
- CI green on every push
- migrations applied successfully in local validation database harness
- architecture choices documented and accepted

### Phase 2: Core Product Surfaces (Week 3-4) - Complete

Scope:
- anonymous onboarding and session bootstrap
- community create/join/discovery
- global + community feeds (text + image)

Deliverables:
- [x] onboarding flow with anonymous Supabase auth (baseline wiring)
- [x] community create flow (dialog + edge function baseline)
- [x] join-code/deep-link community entry (edge function + in-app route + Android/iOS wiring)
- [x] post composer (text/image) baseline (edge function + dialog + image upload)
- [x] feed pagination and realtime refresh baseline (global + community)
- [x] reactions baseline (heart toggle + backend count sync + threaded replies baseline)
- [x] report and block controls on posts

Exit criteria:
- end-to-end post flow working in dev + staging
- crash-free sessions > 99% in internal testing

### Phase 3: Ephemeral + Video (Week 5-6) - Complete

Scope:
- expiring posts and cleanup jobs
- video upload/transcode/playback pipeline
- private link chat (time-boxed/read-once)

Deliverables:
- [x] scheduled expiry worker active
- [x] video upload/playback baseline complete with client transcode/compression
- [x] signed media URLs with expiration
- [x] private chat lifecycle with strict TTL
- [x] read-once message consumption path
- [x] media retention queue + storage cleanup job wiring

Exit criteria:
- no expired content visible in feeds
- private message deletion verified by integration tests

### Phase 4: Safety, Compliance, and Beta Hardening (Week 7-8) - Complete

Scope:
- moderation queue and enforcement actions
- abuse rate limiting and heuristics
- app-store readiness and policy artifacts

Deliverables:
- [x] report triage dashboard flow (admin-side API contract)
- [x] abuse rate limiting baseline across high-risk actions
- [x] device-level enforcement baseline (warn/temp/permanent ban + revoke)
- [x] automated policy checks for unsafe uploads (`moderate-upload` + create-post enforcement)
- [x] legal docs and moderation policy surfaced in-app
- [x] incident runbook published

Exit criteria:
- moderation SLA playbook published
- app passes internal policy QA checklist

### Phase 5: Growth and Monetization (Week 9-12)

Scope:
- polls/challenges v2
- ranking improvements + notifications
- premium and sponsored surfaces

Deliverables:
- [x] polls/challenges v2 baseline (create/vote/ranking + challenge-entry flow)
- [x] push notification baseline (trigger queue + token registration + delivery worker)
- [x] engagement experiments framework (feature flags + experiment events + onboarding instrumentation)
- [x] premium entitlements wiring (schema + APIs + private-link gating + mobile premium screen)
- [x] sponsored community templates baseline (brand-safe templates + create flow defaults)
- performance tuning against SLOs

Exit criteria:
- P95 feed render and startup SLOs met
- 7-day retention experiments running

## Technical Milestones

1. Data correctness milestone: schema finalized, RLS audited, migration rollback plan defined.
2. UX milestone: first-run to first-post journey under 45 seconds median.
3. Reliability milestone: crash-free sessions > 99.7%, API error rate < 1%.
4. Trust milestone: report queue median triage time < 15 minutes (beta operations).

## Product KPIs

- Activation: first community joined or created in first session.
- Engagement: posts per DAU, replies per post, likes per session.
- Retention: D1, D7, D30 by cohort (school/workplace/faith/city).
- Safety: report rate, confirmed violation rate, repeat-offender suppression.
