# Execution Backlog

Legend:
- Status: `todo`, `in_progress`, `blocked`, `done`
- Priority: `P0` critical, `P1` high, `P2` medium

## Phase 1: Foundation

| ID | Priority | Status | Task | Output |
|---|---|---|---|---|
| FND-001 | P0 | done | Initialize repository + base structure | root folders, git init, conventions |
| FND-002 | P0 | done | Write roadmap and execution backlog | `docs/roadmap.md`, `docs/execution-backlog.md` |
| FND-003 | P0 | done | Create CI baseline workflow | `.github/workflows/ci.yml` |
| FND-004 | P0 | done | Define initial Supabase schema + RLS | `supabase/migrations/202602250001_initial_schema.sql` |
| FND-005 | P0 | done | Scaffold Flutter app shell | `apps/mobile/` app skeleton |
| FND-006 | P0 | done | Add architecture decision record (ADR) set | `docs/architecture.md`, `docs/adr/` |
| FND-007 | P1 | done | Add local dev bootstrap scripts | `scripts/bootstrap-local.sh`, `Makefile` |
| FND-008 | P1 | done | Configure staging/prod env strategy | `.env.*.example`, `docs/supabase-setup.md` |
| FND-009 | P0 | done | Apply baseline migrations in local validation environment | `scripts/validate-migrations-postgres.sh` (isolated Postgres) |
| FND-010 | P0 | done | Run Flutter dependency/bootstrap validation | `scripts/bootstrap-local.sh` + `flutter pub get` |
| FND-011 | P1 | done | Define edge API contracts | `docs/api-contracts.md` |
| FND-012 | P1 | todo | Link remote Supabase dev project | optional: requires project credentials |

## Phase 2: Core Features

| ID | Priority | Status | Task | Output |
|---|---|---|---|---|
| CORE-001 | P0 | done | Anonymous auth bootstrap | app startup init + anonymous session provider |
| CORE-002 | P0 | done | Community create flow | create dialog + `create-community` edge function |
| CORE-003 | P0 | done | Community join by code/link | join dialog + edge function + `/join/:code` + platform deep links |
| CORE-004 | P0 | done | Global feed v1 | cursor pagination + realtime refresh subscriptions |
| CORE-005 | P0 | done | Community feed v1 | membership-aware query path + community route |
| CORE-006 | P0 | done | Post composer (text/image) | text + image composer with storage upload |
| CORE-007 | P0 | done | Reactions + reply threads | likes + threaded replies baseline |
| CORE-008 | P0 | done | Report + block v1 | user safety controls |

## Phase 3: Ephemeral + Video

| ID | Priority | Status | Task | Output |
|---|---|---|---|---|
| EPH-001 | P0 | done | Expiry worker + visibility filters | migration + cleanup function + pg_cron schedule |
| EPH-002 | P0 | done | Video pipeline integration | upload + compression/transcode + playback baseline |
| EPH-003 | P0 | done | Private link chat room lifecycle | tokenized join + TTL + realtime room UI |
| EPH-004 | P0 | done | Read-once message semantics | `read-private-message-once` + client polling consumption |
| EPH-005 | P1 | done | Media retention enforcement | queue + `expire-content` + scheduled automation workflow |

## Phase 4: Safety + Compliance

| ID | Priority | Status | Task | Output |
|---|---|---|---|---|
| SAFE-001 | P0 | done | Moderation intake queue | triage schema + `list-reports` + `review-report` contracts |
| SAFE-002 | P0 | done | Abuse rate limiting | per-user limits on post/report/private-link actions |
| SAFE-003 | P0 | done | Device-level enforcement actions | `enforce-user` + active-ban checks in key write flows |
| SAFE-004 | P0 | done | In-app legal surfaces | legal tab screen + onboarding entry route |
| SAFE-005 | P1 | done | Incident runbooks | `docs/incident-runbook.md` |
| SAFE-006 | P0 | done | Automated unsafe-upload policy checks | `moderate-upload` + `media_policy_checks` + create-post gate |

## Phase 5: Growth + Revenue

| ID | Priority | Status | Task | Output |
|---|---|---|---|---|
| GRW-001 | P1 | done | Polls/challenges v2 | create/vote/ranking APIs + challenge-entry UX in mobile |
| GRW-002 | P1 | done | Push notification system | trigger queue + token APIs + delivery worker + mobile notification center |
| GRW-003 | P1 | done | Premium subscriptions | entitlement schema + APIs + private-link gating + premium screen |
| GRW-004 | P2 | done | Sponsored community tools | sponsored templates schema + API + create-community template flow |
| GRW-005 | P2 | done | Experiment framework | rollout-aware feature flags + experiment event tracking |

## Definition of Done (Global)

1. Code merged with CI passing.
2. Unit/integration tests added for business logic.
3. Metrics/logging/error handling included.
4. Security and RLS implications documented.
5. Product acceptance criteria validated.
