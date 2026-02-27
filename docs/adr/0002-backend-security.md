# ADR 0002: Backend Security Model

## Status
Accepted

## Context

Anonymous UX still needs enforceable security boundaries and abuse controls. Direct unrestricted writes from clients are hard to audit and increase moderation risk.

## Decision

Use Supabase Postgres with deny-by-default RLS, plus Edge Functions for sensitive writes.

## Consequences

- Pros: strong server-side policy enforcement with minimal backend ops.
- Pros: write paths are auditable and easier to rate-limit.
- Cons: policy design complexity increases development overhead.
- Cons: function layer is required for non-trivial mutations.
