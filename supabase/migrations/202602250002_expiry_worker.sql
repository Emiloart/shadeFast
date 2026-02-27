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

revoke all on function public.expire_ephemeral_content() from public;

do $$
begin
  if exists (
    select 1
    from pg_available_extensions
    where name = 'pg_cron'
  ) then
    create extension if not exists pg_cron;

    if not exists (
      select 1
      from cron.job
      where jobname = 'shadefast-expire-content'
    ) then
      perform cron.schedule(
        'shadefast-expire-content',
        '*/5 * * * *',
        'select public.expire_ephemeral_content();'
      );
    end if;
  end if;
exception
  when others then
    raise notice 'Skipping pg_cron schedule setup: %', sqlerrm;
end;
$$;
