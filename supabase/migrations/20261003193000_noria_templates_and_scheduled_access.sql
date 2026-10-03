alter table public.hr_accounts
  add column if not exists active_from date not null default current_date;

create table if not exists public.onboarding_task_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  phase text not null default 'arrival'
    check (phase in ('pre_arrival', 'arrival', 'departure')),
  items jsonb not null default '[]'::jsonb,
  enabled boolean not null default true,
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.onboarding_task_templates enable row level security;
drop policy if exists noria_no_client_access on public.onboarding_task_templates;
create policy noria_no_client_access on public.onboarding_task_templates
  for all to anon, authenticated using (false) with check (false);
revoke all on public.onboarding_task_templates from anon, authenticated;
grant all on public.onboarding_task_templates to service_role;
