create table if not exists public.enforcement_actions (
  id uuid primary key default gen_random_uuid(),
  user_uuid uuid not null,
  action text not null check (action in ('warn', 'ban_temp', 'ban_permanent')),
  reason text,
  expires_at timestamptz,
  created_by_uuid uuid,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index if not exists idx_enforcement_actions_user_created
  on public.enforcement_actions(user_uuid, created_at desc);

create index if not exists idx_enforcement_actions_active
  on public.enforcement_actions(user_uuid, action, revoked_at, expires_at);

alter table public.enforcement_actions enable row level security;

create policy enforcement_actions_select_service_policy
on public.enforcement_actions
for select
using (auth.role() = 'service_role');

create policy enforcement_actions_insert_service_policy
on public.enforcement_actions
for insert
with check (auth.role() = 'service_role');

create policy enforcement_actions_update_service_policy
on public.enforcement_actions
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy enforcement_actions_delete_service_policy
on public.enforcement_actions
for delete
using (auth.role() = 'service_role');

create or replace function public.is_user_banned(target_user uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.enforcement_actions e
    where e.user_uuid = target_user
      and e.action in ('ban_temp', 'ban_permanent')
      and e.revoked_at is null
      and (
        e.expires_at is null
        or e.expires_at > now()
      )
  );
$$;

revoke all on function public.is_user_banned(uuid) from public;

create policy communities_insert_not_banned_policy
on public.communities
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy memberships_insert_not_banned_policy
on public.community_memberships
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy posts_insert_not_banned_policy
on public.posts
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy replies_insert_not_banned_policy
on public.replies
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy reactions_insert_not_banned_policy
on public.reactions
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy polls_insert_not_banned_policy
on public.polls
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy poll_votes_insert_not_banned_policy
on public.poll_votes
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy challenges_insert_not_banned_policy
on public.challenges
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy reports_insert_not_banned_policy
on public.reports
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy private_chats_insert_not_banned_policy
on public.private_chats
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy private_chat_participants_insert_not_banned_policy
on public.private_chat_participants
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));

create policy chat_messages_insert_not_banned_policy
on public.chat_messages
as restrictive
for insert
with check (not public.is_user_banned(auth.uid()));
