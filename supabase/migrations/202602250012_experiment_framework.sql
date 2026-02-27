create table if not exists public.feature_flags (
  id text primary key,
  description text,
  is_enabled boolean not null default false,
  rollout_percentage integer not null default 0 check (rollout_percentage between 0 and 100),
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.experiment_events (
  id uuid primary key default gen_random_uuid(),
  user_uuid uuid not null,
  event_name text not null,
  event_properties jsonb,
  app_version text,
  platform text,
  created_at timestamptz not null default now()
);

create index if not exists idx_feature_flags_enabled_rollout
  on public.feature_flags(is_enabled, rollout_percentage, created_at desc);

create index if not exists idx_experiment_events_user_created
  on public.experiment_events(user_uuid, created_at desc);

create index if not exists idx_experiment_events_name_created
  on public.experiment_events(event_name, created_at desc);

alter table public.feature_flags enable row level security;
alter table public.experiment_events enable row level security;

create policy feature_flags_select_policy
on public.feature_flags
for select
using (auth.uid() is not null or auth.role() = 'service_role');

create policy feature_flags_insert_service_policy
on public.feature_flags
for insert
with check (auth.role() = 'service_role');

create policy feature_flags_update_service_policy
on public.feature_flags
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy feature_flags_delete_service_policy
on public.feature_flags
for delete
using (auth.role() = 'service_role');

create policy experiment_events_insert_policy
on public.experiment_events
for insert
with check (user_uuid = auth.uid() or auth.role() = 'service_role');

create policy experiment_events_select_policy
on public.experiment_events
for select
using (user_uuid = auth.uid() or auth.role() = 'service_role');

create policy experiment_events_update_service_policy
on public.experiment_events
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy experiment_events_delete_service_policy
on public.experiment_events
for delete
using (auth.role() = 'service_role');

create or replace function public.resolve_feature_flags(target_user uuid)
returns table(
  id text,
  enabled boolean,
  rollout_percentage integer,
  config jsonb
)
language sql
stable
as $$
  with seeded_flags as (
    select
      f.id,
      f.is_enabled,
      f.rollout_percentage,
      f.config,
      decode(md5(coalesce(target_user::text, 'anonymous') || ':' || f.id), 'hex') as hash_bytes
    from public.feature_flags f
  )
  select
    s.id,
    case
      when s.is_enabled = false then false
      when s.rollout_percentage >= 100 then true
      when s.rollout_percentage <= 0 then false
      else (
        (
          (get_byte(s.hash_bytes, 0)::int * 256)
          + get_byte(s.hash_bytes, 1)::int
        ) % 100
      ) < s.rollout_percentage
    end as enabled,
    s.rollout_percentage,
    s.config
  from seeded_flags s;
$$;

insert into public.feature_flags (id, description, is_enabled, rollout_percentage, config)
values
  (
    'sponsored_templates',
    'Enable sponsored community template picker during community creation.',
    true,
    100,
    '{}'::jsonb
  ),
  (
    'premium_entry',
    'Enable premium route entry points in onboarding/feed surfaces.',
    true,
    100,
    '{}'::jsonb
  ),
  (
    'notifications_center',
    'Enable notifications center route and related actions.',
    true,
    100,
    '{}'::jsonb
  ),
  (
    'experiment_debug_panel',
    'Internal debug tools for experimentation and rollout diagnostics.',
    false,
    0,
    '{}'::jsonb
  )
on conflict (id) do update
set
  description = excluded.description,
  is_enabled = excluded.is_enabled,
  rollout_percentage = excluded.rollout_percentage,
  config = excluded.config,
  updated_at = now();
