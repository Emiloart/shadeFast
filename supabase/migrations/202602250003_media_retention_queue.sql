create table if not exists public.expired_media_queue (
  id uuid primary key default gen_random_uuid(),
  media_url text not null unique,
  source_post_id uuid references public.posts(id) on delete set null,
  enqueued_at timestamptz not null default now(),
  processed_at timestamptz,
  last_error text
);

create index if not exists idx_expired_media_queue_pending
  on public.expired_media_queue(processed_at, enqueued_at);

alter table public.expired_media_queue enable row level security;

create policy expired_media_queue_select_service_policy
on public.expired_media_queue
for select
using (auth.role() = 'service_role');

create policy expired_media_queue_insert_service_policy
on public.expired_media_queue
for insert
with check (auth.role() = 'service_role');

create policy expired_media_queue_update_service_policy
on public.expired_media_queue
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy expired_media_queue_delete_service_policy
on public.expired_media_queue
for delete
using (auth.role() = 'service_role');

create or replace function public.expire_ephemeral_content()
returns table (
  expired_posts integer,
  expired_replies integer,
  expired_private_chats integer,
  expired_chat_messages integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_posts integer := 0;
  deleted_replies integer := 0;
  deleted_private_chats integer := 0;
  deleted_chat_messages integer := 0;
begin
  insert into public.expired_media_queue (media_url, source_post_id)
  select p.image_url, p.id
  from public.posts p
  where p.expires_at <= now()
    and p.image_url is not null
  on conflict (media_url) do nothing;

  insert into public.expired_media_queue (media_url, source_post_id)
  select p.video_url, p.id
  from public.posts p
  where p.expires_at <= now()
    and p.video_url is not null
  on conflict (media_url) do nothing;

  delete from public.chat_messages
  where expires_at <= now();
  get diagnostics deleted_chat_messages = row_count;

  delete from public.private_chats
  where expires_at <= now();
  get diagnostics deleted_private_chats = row_count;

  delete from public.replies
  where expires_at <= now();
  get diagnostics deleted_replies = row_count;

  delete from public.posts
  where expires_at <= now();
  get diagnostics deleted_posts = row_count;

  return query
  select
    deleted_posts,
    deleted_replies,
    deleted_private_chats,
    deleted_chat_messages;
end;
$$;
