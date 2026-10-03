create table if not exists public.hr_interview_reasons (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  form_fields jsonb not null default '[]'::jsonb,
  enabled boolean not null default true,
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.hr_letter_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  subject text not null default '',
  opening text not null default '',
  body text not null default '',
  closing text not null default '',
  signature text not null default '',
  enabled boolean not null default true,
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.hr_interview_reason_letters (
  reason_id uuid not null references public.hr_interview_reasons(id) on delete cascade,
  template_id uuid not null references public.hr_letter_templates(id) on delete cascade,
  generation_stage text not null default 'scheduled'
    check (generation_stage in ('scheduled', 'completed', 'manual')),
  created_at timestamptz not null default now(),
  primary key (reason_id, template_id)
);

alter table public.performance_reviews
  add column if not exists interview_reason_id uuid references public.hr_interview_reasons(id) on delete set null;
alter table public.performance_reviews
  add column if not exists interview_data jsonb not null default '{}'::jsonb;

create table if not exists public.hr_generated_letters (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.performance_reviews(id) on delete cascade,
  template_id uuid references public.hr_letter_templates(id) on delete set null,
  template_name text not null,
  template_snapshot jsonb not null,
  interview_data_snapshot jsonb not null default '{}'::jsonb,
  employee_snapshot jsonb not null default '{}'::jsonb,
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (review_id, template_name)
);

alter table public.hr_interview_reasons enable row level security;
alter table public.hr_letter_templates enable row level security;
alter table public.hr_interview_reason_letters enable row level security;
alter table public.hr_generated_letters enable row level security;
drop policy if exists noria_no_client_access on public.hr_interview_reasons;
create policy noria_no_client_access on public.hr_interview_reasons for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.hr_letter_templates;
create policy noria_no_client_access on public.hr_letter_templates for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.hr_interview_reason_letters;
create policy noria_no_client_access on public.hr_interview_reason_letters for all to anon, authenticated using (false) with check (false);
drop policy if exists noria_no_client_access on public.hr_generated_letters;
create policy noria_no_client_access on public.hr_generated_letters for all to anon, authenticated using (false) with check (false);
revoke all on public.hr_interview_reasons, public.hr_letter_templates,
  public.hr_interview_reason_letters, public.hr_generated_letters from anon, authenticated;
grant all on public.hr_interview_reasons, public.hr_letter_templates,
  public.hr_interview_reason_letters, public.hr_generated_letters to service_role;

insert into public.hr_interview_reasons (name, description, form_fields)
values
('Entretien préalable à un licenciement', 'Préparer la convocation, consigner les éléments échangés et rédiger un projet de courrier de décision.',
 '[{"key":"event_time","label":"Heure de l’entretien","type":"text","required":true,"stage":"scheduled"},{"key":"event_place","label":"Lieu ou lien de l’entretien","type":"text","required":true,"stage":"scheduled"},{"key":"faits","label":"Faits exposés pendant l’entretien","type":"textarea","required":true,"stage":"meeting"},{"key":"observations","label":"Observations du collaborateur","type":"textarea","required":false,"stage":"meeting"},{"key":"decision_motif","label":"Motif factuel du projet de décision","type":"textarea","required":true,"stage":"completed"},{"key":"decision_date","label":"Date d’effet à confirmer","type":"date","required":false,"stage":"completed"}]'::jsonb),
('Entretien avertissement de comportement', 'Documenter les faits, les observations et le projet de courrier lié au comportement.',
 '[{"key":"event_time","label":"Heure de l’entretien","type":"text","required":true,"stage":"scheduled"},{"key":"event_place","label":"Lieu ou lien de l’entretien","type":"text","required":true,"stage":"scheduled"},{"key":"faits","label":"Faits et contexte présentés","type":"textarea","required":true,"stage":"meeting"},{"key":"observations","label":"Observations du collaborateur","type":"textarea","required":false,"stage":"meeting"},{"key":"comportement_attendu","label":"Comportement attendu et rappel à formuler","type":"textarea","required":true,"stage":"completed"},{"key":"mesures","label":"Mesures ou accompagnement convenus","type":"textarea","required":false,"stage":"completed"}]'::jsonb)
on conflict (name) do nothing;

insert into public.hr_letter_templates (name, subject, opening, body, closing, signature)
values
('Convocation — entretien préalable', 'Convocation à un entretien — {{employe.nom_complet}}', 'Madame, Monsieur {{employe.nom_complet}},', E'Nous vous invitons à un entretien le {{entretien.date}} à {{entretien.event_time}}, à {{entretien.event_place}}.\n\nObjet de l’entretien : {{motif.nom}}.\n\n{{organisation.nom}} — {{organisation.adresse}}', 'Nous vous prions de confirmer la bonne réception de cette convocation.', '{{signataire.nom}}\n{{signataire.fonction}}'),
('Projet — notification de licenciement', 'Projet de notification — {{employe.nom_complet}}', 'Madame, Monsieur {{employe.nom_complet}},', E'À la suite de l’entretien du {{entretien.date}}, voici le projet de courrier relatif à la décision envisagée.\n\nÉléments factuels : {{entretien.faits}}\n\nObservations recueillies : {{entretien.observations}}\n\nMotif du projet : {{entretien.decision_motif}}\n\nDate d’effet envisagée : {{entretien.decision_date}}', 'Document de travail à relire et valider avant toute notification.', '{{signataire.nom}}\n{{signataire.fonction}}'),
('Convocation — entretien de comportement', 'Convocation à un entretien — {{employe.nom_complet}}', 'Madame, Monsieur {{employe.nom_complet}},', E'Nous vous invitons à un entretien le {{entretien.date}} à {{entretien.event_time}}, à {{entretien.event_place}}.\n\nObjet de l’entretien : {{motif.nom}}.\n\n{{organisation.nom}} — {{organisation.adresse}}', 'Nous vous prions de confirmer la bonne réception de cette convocation.', '{{signataire.nom}}\n{{signataire.fonction}}'),
('Projet — avertissement de comportement', 'Projet d’avertissement — {{employe.nom_complet}}', 'Madame, Monsieur {{employe.nom_complet}},', E'À la suite de l’entretien du {{entretien.date}}, voici le projet relatif aux faits examinés.\n\nFaits et contexte : {{entretien.faits}}\n\nObservations recueillies : {{entretien.observations}}\n\nComportement attendu : {{entretien.comportement_attendu}}\n\nMesures ou accompagnement : {{entretien.mesures}}', 'Document de travail à relire et valider avant toute notification.', '{{signataire.nom}}\n{{signataire.fonction}}')
on conflict (name) do nothing;

insert into public.hr_interview_reason_letters (reason_id, template_id, generation_stage)
select r.id, t.id, links.generation_stage
from (values
  ('Entretien préalable à un licenciement', 'Convocation — entretien préalable', 'scheduled'),
  ('Entretien préalable à un licenciement', 'Projet — notification de licenciement', 'completed'),
  ('Entretien avertissement de comportement', 'Convocation — entretien de comportement', 'scheduled'),
  ('Entretien avertissement de comportement', 'Projet — avertissement de comportement', 'completed')
) as links(reason_name, template_name, generation_stage)
join public.hr_interview_reasons r on r.name = links.reason_name
join public.hr_letter_templates t on t.name = links.template_name
on conflict (reason_id, template_id) do nothing;
