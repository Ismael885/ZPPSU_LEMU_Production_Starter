-- ZPPSU LEMU initial schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  role text not null default 'student' check (role in ('student','admin')),
  program text check (program in ('BEED','BSED') or program is null),
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected')),
  payment_status text not null default 'unsubmitted' check (payment_status in ('unsubmitted','pending','verified','rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  program text not null check (program in ('BEED','BSED','Both')),
  subject text not null,
  prompt text not null,
  choices jsonb not null check (jsonb_typeof(choices)='array' and jsonb_array_length(choices)=4),
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

-- Correct answers and explanations are kept in a separate table that students cannot read.
create table if not exists public.question_answers (
  question_id uuid primary key references public.questions(id) on delete cascade,
  correct_index integer not null check (correct_index between 0 and 3),
  explanation text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.payment_submissions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  reference_number text not null,
  amount numeric(10,2) not null check (amount > 0),
  receipt_url text,
  status text not null default 'pending' check (status in ('pending','verified','rejected')),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.exam_attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  program text not null check (program in ('BEED','BSED')),
  score integer not null check (score >= 0),
  total integer not null check (total > 0 and score <= total),
  answers jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Create a profile automatically after Supabase Auth signup.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,email,program)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name','Student'),new.email,new.raw_user_meta_data->>'program');
 return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.questions enable row level security;
alter table public.question_answers enable row level security;
alter table public.payment_submissions enable row level security;
alter table public.exam_attempts enable row level security;

-- Helper: admin role lookup. Security definer avoids recursive profile RLS.
create or replace function public.is_lemu_admin()
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;

create policy "profile read own or admin" on public.profiles for select
using (id=auth.uid() or public.is_lemu_admin());
-- Students cannot update approval, payment, or role fields directly.
-- Add a narrowly scoped profile-edit API if editable fields are needed.
create policy "admin manage profiles" on public.profiles for all
using (public.is_lemu_admin()) with check (public.is_lemu_admin());

create policy "published questions readable" on public.questions for select
using (is_published=true or public.is_lemu_admin());
create policy "admin manage questions" on public.questions for all
using (public.is_lemu_admin()) with check (public.is_lemu_admin());
create policy "admin manage question answers" on public.question_answers for all
using (public.is_lemu_admin()) with check (public.is_lemu_admin());

create policy "student submit own payment" on public.payment_submissions for insert
with check (student_id=auth.uid());
create policy "student read own payment or admin" on public.payment_submissions for select
using (student_id=auth.uid() or public.is_lemu_admin());
create policy "admin review payment" on public.payment_submissions for update
using (public.is_lemu_admin()) with check (public.is_lemu_admin());

create policy "student read own attempts or admin" on public.exam_attempts for select
using (student_id=auth.uid() or public.is_lemu_admin());
create policy "approved student submit attempt" on public.exam_attempts for insert
with check (student_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.approval_status='approved'));


-- Server-side grading: student browsers never receive correct_index or explanations
-- until an authorized post-exam review workflow is added.
create or replace function public.submit_lemu_exam(p_program text, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_score integer;
  v_total integer;
  v_attempt uuid;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.profiles
    where id = v_uid and approval_status = 'approved' and program = p_program
  ) then raise exception 'An approved account for this program is required'; end if;
  if p_program not in ('BEED','BSED') then raise exception 'Invalid program'; end if;
  if jsonb_typeof(p_answers) <> 'object' then raise exception 'Answers must be a JSON object'; end if;

  select count(*)::integer,
         count(*) filter (where (p_answers ->> q.id::text) ~ '^[0-3]$'
             and (p_answers ->> q.id::text)::integer = a.correct_index)::integer
    into v_total, v_score
  from public.questions q
  join public.question_answers a on a.question_id = q.id
  where q.is_published = true and q.program in (p_program, 'Both');

  if coalesce(v_total,0) = 0 then raise exception 'No validated published questions are available'; end if;

  insert into public.exam_attempts(student_id,program,score,total,answers)
  values(v_uid,p_program,coalesce(v_score,0),v_total,p_answers)
  returning id into v_attempt;

  return jsonb_build_object('attempt_id',v_attempt,'score',coalesce(v_score,0),'total',v_total);
end;
$$;

revoke all on function public.submit_lemu_exam(text,jsonb) from public;
grant execute on function public.submit_lemu_exam(text,jsonb) to authenticated;
