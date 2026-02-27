create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_uuid uuid not null,
  token text not null unique check (char_length(token) between 16 and 4096),
  platform text not null check (platform in ('ios', 'android', 'web')),
  locale text,
  app_version text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index if not exists idx_push_tokens_user_active
  on public.push_tokens(user_uuid, last_seen_at desc)
  where revoked_at is null;

create index if not exists idx_push_tokens_platform_active
  on public.push_tokens(platform, last_seen_at desc)
  where revoked_at is null;

alter table public.push_tokens enable row level security;

create policy push_tokens_select_self_policy
on public.push_tokens
for select
using (user_uuid = auth.uid());

create policy push_tokens_insert_service_policy
on public.push_tokens
for insert
with check (auth.role() = 'service_role');

create policy push_tokens_update_service_policy
on public.push_tokens
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy push_tokens_delete_service_policy
on public.push_tokens
for delete
using (auth.role() = 'service_role');

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  recipient_uuid uuid not null,
  event_type text not null check (event_type in ('reply', 'reaction', 'challenge_entry', 'system')),
  actor_uuid uuid,
  post_id uuid references public.posts(id) on delete set null,
  reply_id uuid references public.replies(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  delivery_attempts integer not null default 0 check (delivery_attempts >= 0),
  last_error text
);

create index if not exists idx_notification_events_recipient_created
  on public.notification_events(recipient_uuid, created_at desc);

create index if not exists idx_notification_events_delivery_queue
  on public.notification_events(created_at asc)
  where delivered_at is null;

alter table public.notification_events enable row level security;

create policy notification_events_select_self_policy
on public.notification_events
for select
using (recipient_uuid = auth.uid());

create policy notification_events_insert_service_policy
on public.notification_events
for insert
with check (auth.role() = 'service_role');

create policy notification_events_update_service_policy
on public.notification_events
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy notification_events_delete_service_policy
on public.notification_events
for delete
using (auth.role() = 'service_role');

create or replace function public.queue_notification_event(
  target_recipient uuid,
  event_kind text,
  target_actor uuid,
  target_post uuid,
  target_reply uuid,
  event_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_id uuid;
begin
  if target_recipient is null then
    return null;
  end if;

  if target_actor is not null and target_recipient = target_actor then
    return null;
  end if;

  if public.is_user_banned(target_recipient) then
    return null;
  end if;

  insert into public.notification_events (
    recipient_uuid,
    event_type,
    actor_uuid,
    post_id,
    reply_id,
    payload
  ) values (
    target_recipient,
    event_kind,
    target_actor,
    target_post,
    target_reply,
    coalesce(event_payload, '{}'::jsonb)
  )
  returning id into inserted_id;

  return inserted_id;
end;
$$;

revoke all on function public.queue_notification_event(uuid, text, uuid, uuid, uuid, jsonb) from public;

create or replace function public.notify_on_reply_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  post_owner uuid;
begin
  select p.user_uuid
  into post_owner
  from public.posts p
  where p.id = new.post_id
    and p.expires_at > now();

  perform public.queue_notification_event(
    post_owner,
    'reply',
    new.user_uuid,
    new.post_id,
    new.id,
    jsonb_build_object('preview', left(new.body, 140))
  );

  return new;
end;
$$;

create or replace function public.notify_on_reaction_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  post_owner uuid;
begin
  select p.user_uuid
  into post_owner
  from public.posts p
  where p.id = new.post_id
    and p.expires_at > now();

  perform public.queue_notification_event(
    post_owner,
    'reaction',
    new.user_uuid,
    new.post_id,
    null,
    jsonb_build_object('kind', new.kind)
  );

  return new;
end;
$$;

create or replace function public.notify_on_challenge_entry_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  challenge_owner uuid;
begin
  select c.creator_uuid
  into challenge_owner
  from public.challenges c
  where c.id = new.challenge_id
    and c.expires_at > now();

  perform public.queue_notification_event(
    challenge_owner,
    'challenge_entry',
    new.user_uuid,
    new.post_id,
    null,
    jsonb_build_object('challengeId', new.challenge_id)
  );

  return new;
end;
$$;

drop trigger if exists trig_notify_on_reply_insert on public.replies;
create trigger trig_notify_on_reply_insert
after insert on public.replies
for each row
execute function public.notify_on_reply_insert();

drop trigger if exists trig_notify_on_reaction_insert on public.reactions;
create trigger trig_notify_on_reaction_insert
after insert on public.reactions
for each row
execute function public.notify_on_reaction_insert();

drop trigger if exists trig_notify_on_challenge_entry_insert on public.challenge_entries;
create trigger trig_notify_on_challenge_entry_insert
after insert on public.challenge_entries
for each row
execute function public.notify_on_challenge_entry_insert();
