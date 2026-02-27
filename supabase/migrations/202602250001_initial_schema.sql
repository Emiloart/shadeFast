create extension if not exists pgcrypto;

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  description text,
  category text not null default 'other',
  join_code text not null unique check (char_length(join_code) = 8),
  is_private boolean not null default false,
  creator_uuid uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.community_memberships (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  user_uuid uuid not null,
  role text not null default 'member' check (role in ('member', 'moderator', 'owner')),
  created_at timestamptz not null default now(),
  unique (community_id, user_uuid)
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  community_id uuid references public.communities(id) on delete cascade,
  user_uuid uuid not null,
  content text,
  image_url text,
  video_url text,
  like_count integer not null default 0,
  view_count integer not null default 0,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  check (
    content is not null
    or image_url is not null
    or video_url is not null
  )
);

create table if not exists public.replies (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  parent_reply_id uuid references public.replies(id) on delete cascade,
  user_uuid uuid not null,
  body text not null check (char_length(body) between 1 and 1500),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create table if not exists public.reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_uuid uuid not null,
  kind text not null default 'heart' check (kind in ('heart')),
  created_at timestamptz not null default now(),
  unique (post_id, user_uuid, kind)
);

create table if not exists public.polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  question text not null check (char_length(question) between 3 and 280),
  options jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.polls(id) on delete cascade,
  option_index integer not null,
  user_uuid uuid not null,
  created_at timestamptz not null default now(),
  unique (poll_id, user_uuid)
);

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 120),
  description text,
  creator_uuid uuid not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days')
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade,
  reply_id uuid references public.replies(id) on delete cascade,
  reason text not null,
  details text,
  reporter_uuid uuid not null,
  created_at timestamptz not null default now()
);

create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_uuid uuid not null,
  blocked_uuid uuid not null,
  created_at timestamptz not null default now(),
  unique (blocker_uuid, blocked_uuid)
);

create table if not exists public.private_chats (
  id uuid primary key default gen_random_uuid(),
  link_token text not null unique,
  creator_uuid uuid not null,
  read_once boolean not null default true,
  expires_at timestamptz not null default (now() + interval '1 hour'),
  created_at timestamptz not null default now()
);

create table if not exists public.private_chat_participants (
  id uuid primary key default gen_random_uuid(),
  private_chat_id uuid not null references public.private_chats(id) on delete cascade,
  user_uuid uuid not null,
  created_at timestamptz not null default now(),
  unique (private_chat_id, user_uuid)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  private_chat_id uuid not null references public.private_chats(id) on delete cascade,
  sender_uuid uuid not null,
  body text not null check (char_length(body) between 1 and 2000),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '1 hour')
);

create index if not exists idx_communities_join_code on public.communities(join_code);
create index if not exists idx_communities_public_created on public.communities(is_private, created_at desc);

create index if not exists idx_memberships_user on public.community_memberships(user_uuid, created_at desc);
create index if not exists idx_memberships_community on public.community_memberships(community_id, created_at desc);

create index if not exists idx_posts_global_feed on public.posts(created_at desc, like_count desc)
  where community_id is null;
create index if not exists idx_posts_community_feed on public.posts(community_id, created_at desc, like_count desc);
create index if not exists idx_posts_expiry on public.posts(expires_at);

create index if not exists idx_replies_post_created on public.replies(post_id, created_at asc);
create index if not exists idx_replies_expiry on public.replies(expires_at);

create index if not exists idx_reactions_post on public.reactions(post_id, created_at desc);
create index if not exists idx_reports_created on public.reports(created_at desc);

create index if not exists idx_private_chats_token on public.private_chats(link_token);
create index if not exists idx_private_chats_expiry on public.private_chats(expires_at);
create index if not exists idx_chat_messages_chat_created on public.chat_messages(private_chat_id, created_at asc);
create index if not exists idx_chat_messages_expiry on public.chat_messages(expires_at);

alter table public.communities enable row level security;
alter table public.community_memberships enable row level security;
alter table public.posts enable row level security;
alter table public.replies enable row level security;
alter table public.reactions enable row level security;
alter table public.polls enable row level security;
alter table public.poll_votes enable row level security;
alter table public.challenges enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.private_chats enable row level security;
alter table public.private_chat_participants enable row level security;
alter table public.chat_messages enable row level security;

create or replace function public.can_access_community(target_community_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.communities c
    where c.id = target_community_id
      and (
        c.is_private = false
        or c.creator_uuid = auth.uid()
        or exists (
          select 1
          from public.community_memberships m
          where m.community_id = c.id
            and m.user_uuid = auth.uid()
        )
      )
  );
$$;

create or replace function public.is_chat_participant(target_chat_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.private_chat_participants p
    where p.private_chat_id = target_chat_id
      and p.user_uuid = auth.uid()
  );
$$;

create policy communities_read_policy
on public.communities
for select
using (
  is_private = false
  or creator_uuid = auth.uid()
  or exists (
    select 1
    from public.community_memberships m
    where m.community_id = id
      and m.user_uuid = auth.uid()
  )
);

create policy communities_insert_policy
on public.communities
for insert
with check (
  auth.uid() is not null
  and creator_uuid = auth.uid()
);

create policy communities_update_policy
on public.communities
for update
using (creator_uuid = auth.uid())
with check (creator_uuid = auth.uid());

create policy communities_delete_policy
on public.communities
for delete
using (creator_uuid = auth.uid());

create policy memberships_read_policy
on public.community_memberships
for select
using (
  user_uuid = auth.uid()
  or exists (
    select 1
    from public.communities c
    where c.id = community_id
      and c.creator_uuid = auth.uid()
  )
);

create policy memberships_insert_policy
on public.community_memberships
for insert
with check (
  auth.uid() is not null
  and user_uuid = auth.uid()
  and public.can_access_community(community_id)
);

create policy memberships_delete_policy
on public.community_memberships
for delete
using (
  user_uuid = auth.uid()
  or exists (
    select 1
    from public.communities c
    where c.id = community_id
      and c.creator_uuid = auth.uid()
  )
);

create policy posts_read_policy
on public.posts
for select
using (
  expires_at > now()
  and (
    community_id is null
    or public.can_access_community(community_id)
  )
);

create policy posts_insert_policy
on public.posts
for insert
with check (
  auth.uid() is not null
  and user_uuid = auth.uid()
  and expires_at > now()
  and (
    community_id is null
    or public.can_access_community(community_id)
  )
);

create policy posts_update_policy
on public.posts
for update
using (user_uuid = auth.uid())
with check (user_uuid = auth.uid());

create policy posts_delete_policy
on public.posts
for delete
using (user_uuid = auth.uid());

create policy replies_read_policy
on public.replies
for select
using (
  expires_at > now()
  and exists (
    select 1
    from public.posts p
    where p.id = post_id
      and (
        p.community_id is null
        or public.can_access_community(p.community_id)
      )
  )
);

create policy replies_insert_policy
on public.replies
for insert
with check (
  auth.uid() is not null
  and user_uuid = auth.uid()
  and exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.expires_at > now()
      and (
        p.community_id is null
        or public.can_access_community(p.community_id)
      )
  )
);

create policy replies_delete_policy
on public.replies
for delete
using (user_uuid = auth.uid());

create policy reactions_read_policy
on public.reactions
for select
using (
  exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.expires_at > now()
      and (
        p.community_id is null
        or public.can_access_community(p.community_id)
      )
  )
);

create policy reactions_insert_policy
on public.reactions
for insert
with check (
  auth.uid() is not null
  and user_uuid = auth.uid()
  and exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.expires_at > now()
      and (
        p.community_id is null
        or public.can_access_community(p.community_id)
      )
  )
);

create policy reactions_delete_policy
on public.reactions
for delete
using (user_uuid = auth.uid());

create policy polls_read_policy
on public.polls
for select
using (
  exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.expires_at > now()
      and (
        p.community_id is null
        or public.can_access_community(p.community_id)
      )
  )
);

create policy polls_insert_policy
on public.polls
for insert
with check (
  exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.user_uuid = auth.uid()
  )
);

create policy poll_votes_read_policy
on public.poll_votes
for select
using (
  exists (
    select 1
    from public.polls pl
    join public.posts p on p.id = pl.post_id
    where pl.id = poll_id
      and p.expires_at > now()
      and (
        p.community_id is null
        or public.can_access_community(p.community_id)
      )
  )
);

create policy poll_votes_insert_policy
on public.poll_votes
for insert
with check (
  auth.uid() is not null
  and user_uuid = auth.uid()
  and exists (
    select 1
    from public.polls pl
    join public.posts p on p.id = pl.post_id
    where pl.id = poll_id
      and p.expires_at > now()
      and (
        p.community_id is null
        or public.can_access_community(p.community_id)
      )
  )
);

create policy challenges_read_policy
on public.challenges
for select
using (expires_at > now());

create policy challenges_insert_policy
on public.challenges
for insert
with check (
  auth.uid() is not null
  and creator_uuid = auth.uid()
);

create policy reports_insert_policy
on public.reports
for insert
with check (
  auth.uid() is not null
  and reporter_uuid = auth.uid()
  and (post_id is not null or reply_id is not null)
);

create policy blocks_read_policy
on public.blocks
for select
using (blocker_uuid = auth.uid());

create policy blocks_insert_policy
on public.blocks
for insert
with check (
  auth.uid() is not null
  and blocker_uuid = auth.uid()
  and blocker_uuid <> blocked_uuid
);

create policy blocks_delete_policy
on public.blocks
for delete
using (blocker_uuid = auth.uid());

create policy private_chats_read_policy
on public.private_chats
for select
using (
  creator_uuid = auth.uid()
  or public.is_chat_participant(id)
);

create policy private_chats_insert_policy
on public.private_chats
for insert
with check (
  auth.uid() is not null
  and creator_uuid = auth.uid()
);

create policy private_chat_participants_read_policy
on public.private_chat_participants
for select
using (user_uuid = auth.uid());

create policy private_chat_participants_insert_policy
on public.private_chat_participants
for insert
with check (
  auth.uid() is not null
  and user_uuid = auth.uid()
);

create policy chat_messages_read_policy
on public.chat_messages
for select
using (
  expires_at > now()
  and public.is_chat_participant(private_chat_id)
);

create policy chat_messages_insert_policy
on public.chat_messages
for insert
with check (
  auth.uid() is not null
  and sender_uuid = auth.uid()
  and public.is_chat_participant(private_chat_id)
  and expires_at > now()
);

create policy chat_messages_update_policy
on public.chat_messages
for update
using (public.is_chat_participant(private_chat_id))
with check (public.is_chat_participant(private_chat_id));
