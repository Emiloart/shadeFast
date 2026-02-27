# Architecture Baseline

## Stack

- Frontend: Flutter (iOS + Android), Riverpod, GoRouter.
- Backend: Supabase (Postgres, Auth, Realtime, Storage, Edge Functions).
- Video: Cloudflare Stream (recommended integration in Phase 3).
- Ops: GitHub Actions CI, Sentry, OpenTelemetry (Phase 2 onward).

## Core Principles

1. Anonymous-by-default UX with secure session primitives.
2. Ephemeral data model enforced server-side, not just in UI.
3. Deny-by-default row-level security on all tables.
4. Write paths through controlled APIs/functions for auditability.
5. Fast perceived performance: optimistic UI, pagination, caching.

## Data Access Model

- Client reads only policy-allowed rows via RLS.
- Client writes through Edge Functions for complex operations.
- Background cleanup jobs enforce TTL expiry and retention windows.

## Service Boundaries

- `apps/mobile`: all UI and client state management.
- `supabase/migrations`: schema evolution and security policy.
- `supabase/functions`: protected business logic endpoints.
- `docs`: architecture, roadmap, and operational processes.

## Early Risks and Mitigations

- Abuse/spam risk: add rate limiting and moderation queue in Phase 2.
- Feed performance risk: index-first query planning from migration v1.
- Policy compliance risk: keep report/block actions available in-app.
