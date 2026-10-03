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
  status text not null default 'registered' check (status in ('registered','completed','cancelled')),
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

-- Deny direct Data API access even if a table grant is later added by mistake.
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

revoke all on public.employees, public.hr_accounts, public.leave_requests,
  public.attendance_records, public.job_postings, public.candidates,
  public.training_courses, public.training_enrollments,
  public.employee_documents, public.performance_reviews from anon, authenticated;
grant usage on schema public to service_role;
grant all on public.employees, public.hr_accounts, public.leave_requests,
  public.attendance_records, public.job_postings, public.candidates,
  public.training_courses, public.training_enrollments,
  public.employee_documents, public.performance_reviews to service_role;

