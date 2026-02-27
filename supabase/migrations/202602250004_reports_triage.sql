alter table public.reports
  add column if not exists status text not null default 'open'
    check (status in ('open', 'in_review', 'resolved', 'dismissed')),
  add column if not exists priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'critical')),
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by_uuid uuid,
  add column if not exists resolution_note text;

create index if not exists idx_reports_status_created
  on public.reports(status, created_at desc);
