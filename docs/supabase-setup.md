# Supabase Setup Runbook

## Prerequisites

- Supabase project created (`dev`, `staging`, `prod` recommended).
- Supabase CLI installed locally.
- Project URL and anon key available.

## Local setup

1. Authenticate CLI:
   - `supabase login`
2. Link local repo to your project:
   - `supabase link --project-ref <project_ref>`
3. Push schema migration:
   - `supabase db push`
4. Verify RLS is enabled for all public tables:
   - `supabase db remote commit` (optional audit checkpoint)

## Secrets and environment

1. Root `.env` should never be committed.
2. Copy `.env.example` to `.env` and fill:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. For mobile app, copy `apps/mobile/.env.example` to `apps/mobile/.env` and wire via `--dart-define`.
4. Use environment-specific templates for deployment targets:
   - `.env.development.example`
   - `.env.staging.example`
   - `.env.production.example`

## Recommended environment model

- `dev`: rapid schema iteration
- `staging`: release candidate validation
- `prod`: protected migrations only through PR + approval

## Migration policy

1. One feature per migration file.
2. No destructive migration without rollback note.
3. RLS policy changes require explicit reviewer sign-off.

## Verification checks

- Confirm expected tables exist in `public` schema.
- Confirm read access for public communities works with anonymous session.
- Confirm private community feed is inaccessible without membership.
- Confirm expired posts are filtered by `expires_at` checks.
- Confirm `public.expire_ephemeral_content()` exists and cron job
  `shadefast-expire-content` is registered (when `pg_cron` is available).
- Confirm `public.media_policy_checks` exists and receives rows after media upload.
- Confirm `public.challenge_entries` exists and challenge ranking endpoints return data.
- Confirm `public.push_tokens` and `public.notification_events` exist and populate on reactions/replies.
- Confirm `public.subscription_products` and `public.user_entitlements` exist and entitlement APIs return expected active state.
- Confirm `public.sponsored_community_templates` exists and `list-sponsored-community-templates` returns active templates.
- Confirm `public.feature_flags` and `public.experiment_events` exist and experiment APIs return/record expected data.
- Confirm anonymous auth sign-in is enabled and returns `is_anonymous=true` users.
- If Supabase local stack is unavailable, run `./scripts/validate-migrations-postgres.sh` for schema/policy application validation on isolated Postgres.
- Run remote smoke validation with `./scripts/smoke-remote.sh`.

## Edge Functions deploy

1. Set function secrets:
   - Reserved Supabase secrets (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) are managed by the platform and cannot be set manually.
   - optional webhook moderation:
     - `supabase secrets set UPLOAD_POLICY_WEBHOOK_URL=<...>`
     - `supabase secrets set UPLOAD_POLICY_WEBHOOK_TOKEN=<...>`
     - `supabase secrets set UPLOAD_POLICY_STRICT_MODE=true`
   - push delivery provider:
     - `supabase secrets set PUSH_PROVIDER_WEBHOOK_URL=<...>`
     - `supabase secrets set PUSH_PROVIDER_WEBHOOK_TOKEN=<...>`
     - `supabase secrets set PUSH_PROVIDER_STRICT_MODE=true`
2. Deploy baseline functions:
   - Use these flags for deploy parity with current remote runtime behavior:
     - `--import-map supabase/functions/deno.json`
     - `--no-verify-jwt`
     - `--use-api`
   - Recommended:
     - `./scripts/deploy-functions-remote.sh`
   - Example single function:
     - `supabase functions deploy create-community --import-map supabase/functions/deno.json --no-verify-jwt --use-api`

## Media retention automation

1. Local/manual trigger:
   - `make expire-content-dry-run`
   - `make expire-content`
   - requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in shell env.
2. Scheduled trigger:
   - workflow: `.github/workflows/media-retention.yml`
   - required repo secrets:
     - `SUPABASE_URL`
     - `SUPABASE_SERVICE_ROLE_KEY`

## Push delivery automation

1. Local/manual trigger:
   - `make push-delivery-dry-run`
   - `make push-delivery`
   - requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in shell env.
2. Scheduled trigger:
   - workflow: `.github/workflows/push-delivery.yml`
   - required repo secrets:
     - `SUPABASE_URL`
     - `SUPABASE_SERVICE_ROLE_KEY`

## Storage bucket

1. Create media bucket:
   - name: `media`
   - visibility: `public` (MVP baseline)
2. Add retention policy/job before production:
   - enforce max object age aligned to content TTL requirements.

## Deep-link domain files

1. Update and publish:
   - `deploy/domain/.well-known/assetlinks.json`
   - `deploy/domain/.well-known/apple-app-site-association`
2. Validate locally before publish:
   - `./scripts/validate-domain-association.sh`
3. Follow release details in `docs/deep-link-release.md`.
