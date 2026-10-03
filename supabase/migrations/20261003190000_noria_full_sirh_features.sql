-- Éléments complémentaires du cahier des charges Noria.
alter table public.employees add column if not exists phone_number text;
alter table public.employees add column if not exists end_date date;
alter table public.employees add column if not exists work_percentage numeric(5,2) not null default 100
  check (work_percentage > 0 and work_percentage <= 100);
alter table public.hr_accounts add column if not exists must_change_password boolean not null default false;
alter table public.hr_accounts add column if not exists session_version integer not null default 1;
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
alter table public.attendance_change_requests enable row level security;
alter table public.profile_change_requests enable row level security;

-- Deny direct Data API access even if a table grant is later added by mistake.
drop policy if exists noria_no_client_access on public.employees;
create policy noria_no_client_access on public.employees for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.hr_accounts;
create policy noria_no_client_access on public.hr_accounts for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.leave_requests;
create policy noria_no_client_access on public.leave_requests for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.attendance_records;
create policy noria_no_client_access on public.attendance_records for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.job_postings;
create policy noria_no_client_access on public.job_postings for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.candidates;
create policy noria_no_client_access on public.candidates for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.training_courses;
create policy noria_no_client_access on public.training_courses for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.training_enrollments;
create policy noria_no_client_access on public.training_enrollments for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.employee_documents;
create policy noria_no_client_access on public.employee_documents for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.performance_reviews;
create policy noria_no_client_access on public.performance_reviews for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.employee_change_log;
create policy noria_no_client_access on public.employee_change_log for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.noria_notifications;
create policy noria_no_client_access on public.noria_notifications for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.noria_audit_log;
create policy noria_no_client_access on public.noria_audit_log for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.noria_settings;
create policy noria_no_client_access on public.noria_settings for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.noria_login_attempts;
create policy noria_no_client_access on public.noria_login_attempts for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.leave_policies;
create policy noria_no_client_access on public.leave_policies for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.organization_holidays;
create policy noria_no_client_access on public.organization_holidays for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.leave_balance_transactions;
create policy noria_no_client_access on public.leave_balance_transactions for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.onboarding_tasks;
create policy noria_no_client_access on public.onboarding_tasks for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.attendance_change_requests;
create policy noria_no_client_access on public.attendance_change_requests for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.profile_change_requests;
create policy noria_no_client_access on public.profile_change_requests for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.attendance_period_closures;
drop policy if exists noria_no_client_access on public.attendance_period_closures;
create policy noria_no_client_access on public.attendance_period_closures for all to anon, authenticated using (false) with check (false);

revoke all on public.employees, public.hr_accounts, public.leave_requests,
  public.attendance_records, public.job_postings, public.candidates,
  public.training_courses, public.training_enrollments,
  public.employee_documents, public.performance_reviews,
  public.employee_change_log, public.noria_notifications, public.noria_audit_log,
  public.noria_settings, public.noria_login_attempts, public.leave_policies, public.organization_holidays,
  public.leave_balance_transactions, public.onboarding_tasks,
  public.attendance_change_requests, public.profile_change_requests, public.attendance_period_closures from anon, authenticated;
grant usage on schema public to service_role;
grant all on public.employees, public.hr_accounts, public.leave_requests,
  public.attendance_records, public.job_postings, public.candidates,
  public.training_courses, public.training_enrollments,
  public.employee_documents, public.performance_reviews,
  public.employee_change_log, public.noria_notifications, public.noria_audit_log,
  public.noria_settings, public.noria_login_attempts, public.leave_policies, public.organization_holidays,
  public.leave_balance_transactions, public.onboarding_tasks,
  public.attendance_change_requests, public.profile_change_requests, public.attendance_period_closures to service_role;

