create table if not exists public.subscription_products (
  id text primary key,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.subscription_products (id, name, description, is_active)
values
  ('premium_monthly', 'ShadeFast Premium Monthly', 'Ads off, higher limits, premium-only features.', true),
  ('premium_yearly', 'ShadeFast Premium Yearly', 'Best value annual premium subscription.', true)
on conflict (id) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

create table if not exists public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_uuid uuid not null,
  product_id text not null references public.subscription_products(id),
  status text not null check (status in ('active', 'expired', 'revoked')),
  source text,
  started_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_entitlements_user_created
  on public.user_entitlements(user_uuid, created_at desc);

create index if not exists idx_user_entitlements_active
  on public.user_entitlements(user_uuid, product_id, status, expires_at, revoked_at)
  where status = 'active';

alter table public.subscription_products enable row level security;
alter table public.user_entitlements enable row level security;

create policy subscription_products_read_policy
on public.subscription_products
for select
using (is_active = true or auth.role() = 'service_role');

create policy subscription_products_insert_service_policy
on public.subscription_products
for insert
with check (auth.role() = 'service_role');

create policy subscription_products_update_service_policy
on public.subscription_products
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy subscription_products_delete_service_policy
on public.subscription_products
for delete
using (auth.role() = 'service_role');

create policy user_entitlements_select_self_policy
on public.user_entitlements
for select
using (user_uuid = auth.uid() or auth.role() = 'service_role');

create policy user_entitlements_insert_service_policy
on public.user_entitlements
for insert
with check (auth.role() = 'service_role');

create policy user_entitlements_update_service_policy
on public.user_entitlements
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy user_entitlements_delete_service_policy
on public.user_entitlements
for delete
using (auth.role() = 'service_role');

create or replace function public.has_active_entitlement(target_user uuid, target_product text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.user_entitlements e
    where e.user_uuid = target_user
      and e.product_id = target_product
      and e.status = 'active'
      and e.revoked_at is null
      and (
        e.expires_at is null
        or e.expires_at > now()
      )
  );
$$;

create or replace function public.has_any_premium_entitlement(target_user uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.user_entitlements e
    where e.user_uuid = target_user
      and e.product_id in ('premium_monthly', 'premium_yearly')
      and e.status = 'active'
      and e.revoked_at is null
      and (
        e.expires_at is null
        or e.expires_at > now()
      )
  );
$$;

revoke all on function public.has_active_entitlement(uuid, text) from public;
revoke all on function public.has_any_premium_entitlement(uuid) from public;
