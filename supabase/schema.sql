-- Noria SIRH — schéma initial. À exécuter dans le SQL Editor du projet Supabase choisi.
-- Les requêtes de l’application passent par le serveur Vercel avec la clé secrète.
-- Les tables sont donc inaccessibles aux clients anon/authenticated.

create extension if not exists pgcrypto;

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  staff_number text not null unique,
  first_name text not null,
  last_name text not null,
  job_title text,
  department text,
  contract_type text not null default 'CDI',
  start_date date not null default current_date,
  location text,
  status text not null default 'active' check (status in ('active','inactive','onboarding')),
  role text not null default 'employee' check (role in ('admin','manager','employee')),
  manager_id uuid references public.employees(id) on delete set null,
  leave_balance numeric(6,2) not null default 25 check (leave_balance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.hr_accounts (
  employee_id uuid primary key references public.employees(id) on delete cascade,
  identifier text not null unique,
  password_hash text not null,
  role text not null check (role in ('admin','manager','employee')),
  enabled boolean not null default true,
  last_login_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  leave_type text not null default 'Congés payés',
  start_date date not null,
  end_date date not null,
  days numeric(5,1) not null check (days > 0),
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  note text,
  reviewed_by uuid references public.employees(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);
create index if not exists leave_requests_employee_dates on public.leave_requests(employee_id,start_date,end_date);
create index if not exists leave_requests_status_start on public.leave_requests(status,start_date);
create index if not exists leave_requests_reviewer on public.leave_requests(reviewed_by);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  work_date date not null,
  clock_in timestamptz,
  clock_out timestamptz,
  work_minutes integer check (work_minutes is null or work_minutes >= 0),
  note text,
  created_at timestamptz not null default now(),
  unique(employee_id,work_date)
);

create table if not exists public.job_postings (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  department text,
  location text,
  contract_type text,
  status text not null default 'draft' check (status in ('draft','open','paused','closed')),
  description text,
  hiring_manager_id uuid references public.employees(id) on delete set null,
  opened_at date,
  created_at timestamptz not null default now()
);

create table if not exists public.candidates (
  id uuid primary key default gen_random_uuid(),
  job_posting_id uuid references public.job_postings(id) on delete set null,
  first_name text not null,
  last_name text not null,
  stage text not null default 'applied' check (stage in ('applied','screening','interview','offer','hired','declined')),
  source text,
  applied_at date not null default current_date,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.training_courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  provider text,
  description text,
  starts_at date,
  ends_at date,
  seats integer check (seats is null or seats >= 0),
  status text not null default 'planned' check (status in ('planned','open','in_progress','completed','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.training_enrollments (
  id uuid primary key default gen_random_uuid(),
  training_id uuid not null references public.training_courses(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  status text not null default 'registered' check (status in ('registered','waitlisted','completed','cancelled')),
  unique(training_id,employee_id)
);

create table if not exists public.employee_documents (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  title text not null,
  document_type text not null default 'other',
  storage_path text not null,
  visibility text not null default 'private' check (visibility in ('private','hr')),
  uploaded_at timestamptz not null default now()
);

create table if not exists public.performance_reviews (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  reviewer_id uuid references public.employees(id) on delete set null,
  review_type text not null default 'annual',
  scheduled_at date,
  status text not null default 'planned' check (status in ('planned','in_progress','completed','cancelled')),
  summary text,
  goals jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Éléments complémentaires du cahier des charges Noria.
alter table public.employees add column if not exists phone_number text;
alter table public.employees add column if not exists end_date date;
alter table public.employees add column if not exists work_percentage numeric(5,2) not null default 100
  check (work_percentage > 0 and work_percentage <= 100);
alter table public.hr_accounts add column if not exists must_change_password boolean not null default false;
alter table public.hr_accounts add column if not exists session_version integer not null default 1;
alter table public.hr_accounts add column if not exists active_from date not null default current_date;
alter table public.employee_documents add column if not exists retention_until date;
alter table public.employee_documents add column if not exists created_by uuid references public.employees(id) on delete set null;
alter table public.employee_documents add column if not exists version integer not null default 1;
alter table public.candidates add column if not exists privacy_notice_at timestamptz;
alter table public.candidates add column if not exists retention_until date;
alter table public.training_enrollments add column if not exists completed_at timestamptz;
alter table public.training_enrollments add column if not exists completion_note text;
alter table public.training_enrollments drop constraint if exists training_enrollments_status_check;
alter table public.training_enrollments add constraint training_enrollments_status_check check (status in ('registered','waitlisted','completed','cancelled'));
alter table public.performance_reviews add column if not exists validated_at timestamptz;
alter table public.attendance_records add column if not exists breaks jsonb not null default '[]'::jsonb;
alter table public.attendance_records add column if not exists approved_by uuid references public.employees(id) on delete set null;
alter table public.attendance_records add column if not exists approved_at timestamptz;
alter table public.attendance_records add column if not exists closed_at timestamptz;
create table if not exists public.attendance_period_closures (
 id uuid primary key default gen_random_uuid(),
 period_month date not null unique check (extract(day from period_month)=1),
 status text not null default 'closed' check (status in ('closed','reopened')),
 closed_by uuid references public.employees(id) on delete set null,
 closed_at timestamptz not null default now(),
 note text
);
alter table public.attendance_period_closures enable row level security;


create table if not exists public.employee_change_log (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  changed_by uuid references public.employees(id) on delete set null,
  field_name text not null,
  old_value text,
  new_value text,
  effective_at timestamptz not null default now(),
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.noria_notifications (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null default '',
  target_page text,
  target_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.noria_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.employees(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.noria_settings (
  setting_key text primary key,
  setting_value jsonb not null default '{}'::jsonb,
  updated_by uuid references public.employees(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.noria_settings (setting_key, setting_value)
values ('organization', '{"name":"Chromatotec","locations":[]}'), ('retention', '{}')
on conflict (setting_key) do nothing;

create table if not exists public.noria_login_attempts (
  attempt_key_hash text primary key,
  attempts integer not null default 0,
  window_started timestamptz not null default now()
);
create index if not exists noria_login_attempts_window on public.noria_login_attempts(window_started);

create or replace function public.noria_login_attempt(p_key_hash text)
returns integer language plpgsql security invoker set search_path = public as $$
declare attempt_total integer;
begin
  insert into public.noria_login_attempts (attempt_key_hash, attempts, window_started)
  values (p_key_hash, 1, now())
  on conflict (attempt_key_hash) do update
    set attempts = case when public.noria_login_attempts.window_started < now() - interval '10 minutes'
                        then 1 else public.noria_login_attempts.attempts + 1 end,
        window_started = case when public.noria_login_attempts.window_started < now() - interval '10 minutes'
                              then now() else public.noria_login_attempts.window_started end
  returning attempts into attempt_total;
  if random() < 0.01 then
    delete from public.noria_login_attempts where window_started < now() - interval '1 day';
  end if;
  return attempt_total;
end;
$$;
revoke all on function public.noria_login_attempt(text) from public, anon, authenticated;
grant execute on function public.noria_login_attempt(text) to service_role;

create table if not exists public.leave_policies (
  id uuid primary key default gen_random_uuid(),
  leave_type text not null unique,
  counts_weekends boolean not null default false,
  paid boolean not null default false,
  requires_approval boolean not null default true,
  enabled boolean not null default true,
  annual_allowance numeric(6,2),
  effective_from date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
insert into public.leave_policies (leave_type, counts_weekends, paid, requires_approval)
values ('Congés payés', false, true, true), ('RTT', false, false, true),
       ('Maladie', false, false, true), ('Sans solde', false, false, true), ('Autre', false, false, true)
on conflict (leave_type) do nothing;

create table if not exists public.organization_holidays (
  id uuid primary key default gen_random_uuid(),
  holiday_date date not null,
  label text not null,
  location text,
  created_at timestamptz not null default now(),
  unique(holiday_date, location)
);

create table if not exists public.leave_balance_transactions (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  leave_type text not null,
  delta_days numeric(6,2) not null,
  effective_date date not null default current_date,
  source_type text not null,
  source_id uuid,
  created_by uuid references public.employees(id) on delete set null,
  note text,
  created_at timestamptz not null default now(),
  unique(source_type, source_id)
);

create table if not exists public.onboarding_tasks (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  title text not null,
  description text,
  phase text not null default 'arrival' check (phase in ('pre_arrival','arrival','departure')),
  assigned_to uuid references public.employees(id) on delete set null,
  due_date date,
  status text not null default 'todo' check (status in ('todo','in_progress','done','cancelled')),
  completed_at timestamptz,
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.onboarding_task_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  phase text not null default 'arrival' check (phase in ('pre_arrival','arrival','departure')),
  items jsonb not null default '[]'::jsonb,
  enabled boolean not null default true,
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.attendance_change_requests (
  id uuid primary key default gen_random_uuid(),
  attendance_id uuid not null references public.attendance_records(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  requested_clock_in timestamptz,
  requested_clock_out timestamptz,
  reason text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references public.employees(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.attendance_change_requests add column if not exists original_clock_in timestamptz;
alter table public.attendance_change_requests add column if not exists original_clock_out timestamptz;

create table if not exists public.profile_change_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  requested_changes jsonb not null,
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references public.employees(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists employee_change_log_employee on public.employee_change_log(employee_id, effective_at desc);
create index if not exists noria_notifications_inbox on public.noria_notifications(employee_id, created_at desc);
create index if not exists noria_audit_log_recent on public.noria_audit_log(created_at desc);
create index if not exists onboarding_tasks_employee on public.onboarding_tasks(employee_id, status, due_date);
create index if not exists attendance_change_requests_status on public.attendance_change_requests(status, created_at);
create index if not exists profile_change_requests_status on public.profile_change_requests(status, created_at);

create index if not exists employees_manager on public.employees(manager_id);
create index if not exists candidates_job_posting on public.candidates(job_posting_id);
create index if not exists job_postings_hiring_manager on public.job_postings(hiring_manager_id);
create index if not exists training_enrollments_employee on public.training_enrollments(employee_id);
create index if not exists employee_documents_employee on public.employee_documents(employee_id);
create index if not exists performance_reviews_employee on public.performance_reviews(employee_id);
create index if not exists performance_reviews_reviewer on public.performance_reviews(reviewer_id);

alter table public.employees enable row level security;
alter table public.hr_accounts enable row level security;
alter table public.leave_requests enable row level security;
alter table public.attendance_records enable row level security;
alter table public.job_postings enable row level security;
alter table public.candidates enable row level security;
alter table public.training_courses enable row level security;
alter table public.training_enrollments enable row level security;
alter table public.employee_documents enable row level security;
alter table public.performance_reviews enable row level security;
alter table public.employee_change_log enable row level security;
alter table public.noria_notifications enable row level security;
alter table public.noria_audit_log enable row level security;
alter table public.noria_settings enable row level security;
alter table public.noria_login_attempts enable row level security;
alter table public.leave_policies enable row level security;
alter table public.organization_holidays enable row level security;
alter table public.leave_balance_transactions enable row level security;
alter table public.onboarding_tasks enable row level security;
alter table public.onboarding_task_templates enable row level security;
alter table public.attendance_change_requests enable row level security;
alter table public.profile_change_requests enable row level security;

-- Deny direct Data API access even if a table grant is later added by mistake.
drop policy if exists noria_no_client_access on public.employees;
create policy noria_no_client_access on public.employees for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.hr_accounts for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.leave_requests for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.attendance_records for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.job_postings for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.candidates for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.training_courses for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.training_enrollments for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.employee_documents for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.performance_reviews for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.employee_change_log for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.noria_notifications for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.noria_audit_log for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.noria_settings for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.noria_login_attempts for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.leave_policies for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.organization_holidays for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.leave_balance_transactions for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.onboarding_tasks for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.onboarding_task_templates;
create policy noria_no_client_access on public.onboarding_task_templates for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.attendance_change_requests for all to anon, authenticated using (false) with check (false);
create policy noria_no_client_access on public.profile_change_requests for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.attendance_period_closures;
create policy noria_no_client_access on public.attendance_period_closures for all to anon, authenticated using (false) with check (false);

revoke all on public.employees, public.hr_accounts, public.leave_requests,
  public.attendance_records, public.job_postings, public.candidates,
  public.training_courses, public.training_enrollments,
  public.employee_documents, public.performance_reviews,
  public.employee_change_log, public.noria_notifications, public.noria_audit_log,
  public.noria_settings, public.noria_login_attempts, public.leave_policies, public.organization_holidays,
  public.leave_balance_transactions, public.onboarding_tasks,
  public.attendance_change_requests, public.profile_change_requests, public.attendance_period_closures,
  public.onboarding_task_templates from anon, authenticated;
grant usage on schema public to service_role;
grant all on public.employees, public.hr_accounts, public.leave_requests,
  public.attendance_records, public.job_postings, public.candidates,
  public.training_courses, public.training_enrollments,
  public.employee_documents, public.performance_reviews,
  public.employee_change_log, public.noria_notifications, public.noria_audit_log,
  public.noria_settings, public.noria_login_attempts, public.leave_policies, public.organization_holidays,
  public.leave_balance_transactions, public.onboarding_tasks,
  public.attendance_change_requests, public.profile_change_requests, public.attendance_period_closures,
  public.onboarding_task_templates to service_role;
