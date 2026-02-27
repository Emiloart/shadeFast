create table if not exists public.media_policy_checks (
  id uuid primary key default gen_random_uuid(),
  user_uuid uuid not null,
  object_path text not null unique,
  media_type text not null check (media_type in ('image', 'video')),
  mime_type text,
  byte_size integer not null check (byte_size >= 0),
  status text not null check (status in ('approved', 'blocked', 'error')),
  provider text not null default 'builtin',
  provider_reference text,
  reason text,
  confidence numeric(5,4),
  labels jsonb,
  checked_at timestamptz not null default now()
);

create index if not exists idx_media_policy_checks_user_checked
  on public.media_policy_checks(user_uuid, checked_at desc);

create index if not exists idx_media_policy_checks_status_checked
  on public.media_policy_checks(status, checked_at desc);

alter table public.media_policy_checks enable row level security;

create policy media_policy_checks_select_service_policy
on public.media_policy_checks
for select
using (auth.role() = 'service_role');

create policy media_policy_checks_insert_service_policy
on public.media_policy_checks
for insert
with check (auth.role() = 'service_role');

create policy media_policy_checks_update_service_policy
on public.media_policy_checks
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy media_policy_checks_delete_service_policy
on public.media_policy_checks
for delete
using (auth.role() = 'service_role');
