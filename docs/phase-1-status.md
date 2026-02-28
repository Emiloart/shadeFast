# Phase 1 Status

Date: 2026-02-27
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
- Remote Supabase dev project linked and synchronized.
- Anonymous sign-ins enabled in Supabase Auth and verified.
- Remote edge functions deployed with `--import-map supabase/functions/deno.json --no-verify-jwt --use-api`.
- Remote smoke test harness added (`scripts/smoke-remote.sh`) and validated:
  - anonymous auth signup path
  - feature/template function probes
  - private link lifecycle + read-once message consumption
  - maintenance workers dry-run (`expire-content`, `send-push-notifications`)

## In progress

- None for Phase 1.

## Blockers

- None for Phase 1 completion.

## Immediate next actions

1. Keep remote function deploys aligned with `--import-map supabase/functions/deno.json --no-verify-jwt --use-api`.
2. Phase 2 hardening is complete; track forward work in roadmap and execution backlog.
