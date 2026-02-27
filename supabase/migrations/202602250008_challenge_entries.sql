create table if not exists public.challenge_entries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  user_uuid uuid not null,
  created_at timestamptz not null default now(),
  unique (challenge_id, post_id)
);

create index if not exists idx_challenge_entries_challenge_created
  on public.challenge_entries(challenge_id, created_at desc);

create index if not exists idx_challenge_entries_post
  on public.challenge_entries(post_id);

alter table public.challenge_entries enable row level security;

create policy challenge_entries_read_policy
on public.challenge_entries
for select
using (
  exists (
    select 1
    from public.challenges c
    where c.id = challenge_id
      and c.expires_at > now()
  )
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

create policy challenge_entries_insert_policy
on public.challenge_entries
for insert
with check (
  auth.uid() is not null
  and user_uuid = auth.uid()
  and not public.is_user_banned(auth.uid())
  and exists (
    select 1
    from public.challenges c
    where c.id = challenge_id
      and c.expires_at > now()
  )
  and exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.user_uuid = auth.uid()
      and p.expires_at > now()
      and (
        p.community_id is null
        or public.can_access_community(p.community_id)
      )
  )
);

create policy challenge_entries_delete_policy
on public.challenge_entries
for delete
using (user_uuid = auth.uid());
