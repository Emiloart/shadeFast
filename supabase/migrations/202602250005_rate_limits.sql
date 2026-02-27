create table if not exists public.rate_limits (
  id uuid primary key default gen_random_uuid(),
  user_uuid uuid not null,
  action text not null,
  window_start timestamptz not null,
  request_count integer not null default 0 check (request_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_uuid, action, window_start)
);

create index if not exists idx_rate_limits_action_window
  on public.rate_limits(action, window_start desc);

create index if not exists idx_rate_limits_user_action_window
  on public.rate_limits(user_uuid, action, window_start desc);

alter table public.rate_limits enable row level security;

create policy rate_limits_select_service_policy
on public.rate_limits
for select
using (auth.role() = 'service_role');

create policy rate_limits_insert_service_policy
on public.rate_limits
for insert
with check (auth.role() = 'service_role');

create policy rate_limits_update_service_policy
on public.rate_limits
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy rate_limits_delete_service_policy
on public.rate_limits
for delete
using (auth.role() = 'service_role');

create or replace function public.bump_rate_limit(
  target_user uuid,
  target_action text,
  window_seconds integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  bucket_start timestamptz;
  next_count integer;
begin
  if target_user is null then
    raise exception 'target_user_required';
  end if;

  if target_action is null or char_length(trim(target_action)) = 0 then
    raise exception 'target_action_required';
  end if;

  if window_seconds is null or window_seconds < 1 then
    raise exception 'window_seconds_invalid';
  end if;

  bucket_start := to_timestamp(
    floor(extract(epoch from now()) / window_seconds) * window_seconds
  );

  insert into public.rate_limits (
    user_uuid,
    action,
    window_start,
    request_count
  )
  values (
    target_user,
    target_action,
    bucket_start,
    1
  )
  on conflict (user_uuid, action, window_start)
  do update set
    request_count = public.rate_limits.request_count + 1,
    updated_at = now()
  returning request_count into next_count;

  return next_count;
end;
$$;

revoke all on function public.bump_rate_limit(uuid, text, integer) from public;
