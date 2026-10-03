create index if not exists hr_interview_reasons_created_by_idx
  on public.hr_interview_reasons (created_by);
create index if not exists hr_letter_templates_created_by_idx
  on public.hr_letter_templates (created_by);
create index if not exists hr_interview_reason_letters_template_id_idx
  on public.hr_interview_reason_letters (template_id);
create index if not exists performance_reviews_interview_reason_id_idx
  on public.performance_reviews (interview_reason_id);
create index if not exists hr_generated_letters_template_id_idx
  on public.hr_generated_letters (template_id);
create index if not exists hr_generated_letters_created_by_idx
  on public.hr_generated_letters (created_by);
