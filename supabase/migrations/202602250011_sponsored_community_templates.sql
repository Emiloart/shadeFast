create table if not exists public.sponsored_community_templates (
  id text primary key,
  display_name text not null,
  description text,
  category text not null check (category in ('school', 'workplace', 'faith', 'neighborhood', 'other')),
  default_title text not null,
  default_description text,
  default_is_private boolean not null default false,
  rules jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_sponsored_templates_active_category
  on public.sponsored_community_templates(is_active, category, created_at desc);

alter table public.communities
  add column if not exists sponsored_template_id text references public.sponsored_community_templates(id);

create index if not exists idx_communities_sponsored_template
  on public.communities(sponsored_template_id)
  where sponsored_template_id is not null;

alter table public.sponsored_community_templates enable row level security;

create policy sponsored_templates_select_active_policy
on public.sponsored_community_templates
for select
using (is_active = true or auth.role() = 'service_role');

create policy sponsored_templates_insert_service_policy
on public.sponsored_community_templates
for insert
with check (auth.role() = 'service_role');

create policy sponsored_templates_update_service_policy
on public.sponsored_community_templates
for update
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy sponsored_templates_delete_service_policy
on public.sponsored_community_templates
for delete
using (auth.role() = 'service_role');

insert into public.sponsored_community_templates (
  id,
  display_name,
  description,
  category,
  default_title,
  default_description,
  default_is_private,
  rules,
  is_active
)
values
  (
    'campus-club-safe',
    'Campus Club Safe Template',
    'School-focused space with clear rules and low moderation risk prompts.',
    'school',
    'Campus Tea Circle',
    'Keep it sharp but avoid naming private individuals or sharing personal info.',
    false,
    jsonb_build_array(
      'No doxxing or personal contact info.',
      'No threats, hate speech, or explicit harassment.',
      'Keep screenshots redacted before posting.'
    ),
    true
  ),
  (
    'workplace-watercooler-safe',
    'Workplace Watercooler Template',
    'Anonymous workplace venting with guardrails for legal and safety compliance.',
    'workplace',
    'Workplace Hot Takes',
    'Discuss culture and process. Do not post names, salaries, or legal-sensitive data.',
    true,
    jsonb_build_array(
      'Avoid naming employees or leadership directly.',
      'No confidential business data or customer data.',
      'Use role descriptions instead of real identities.'
    ),
    true
  ),
  (
    'faith-circle-safe',
    'Faith Circle Template',
    'Respectful discussion format for churches, mosques, and other faith groups.',
    'faith',
    'Faith Circle Voices',
    'Share experiences and concerns without personal attacks or private family details.',
    true,
    jsonb_build_array(
      'No slurs, sectarian hate, or incitement.',
      'No private confessions involving identifiable minors.',
      'Protect identities when discussing sensitive situations.'
    ),
    true
  ),
  (
    'neighborhood-watch-safe',
    'Neighborhood Watch Template',
    'Local discussion channel optimized for rumors control and safer reporting.',
    'neighborhood',
    'Neighborhood Pulse',
    'Share location-level updates only. No exact addresses or personal accusations.',
    false,
    jsonb_build_array(
      'No exact addresses, license plates, or phone numbers.',
      'No unverified criminal accusations against named people.',
      'Escalate emergencies to local services, not the app.'
    ),
    true
  )
on conflict (id) do update
set
  display_name = excluded.display_name,
  description = excluded.description,
  category = excluded.category,
  default_title = excluded.default_title,
  default_description = excluded.default_description,
  default_is_private = excluded.default_is_private,
  rules = excluded.rules,
  is_active = excluded.is_active,
  updated_at = now();
